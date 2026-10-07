const std = @import("std");
const foundation = @import("foundation");
pub const Token = foundation.cancellation.Token;

/// Internal typed values, not an extension wire schema. Text is borrowed for dispatch.
pub const Arguments = union(enum) { none, text: []const u8, integer: i64, boolean: bool };
pub const ArgumentKind = std.meta.Tag(Arguments);
pub const DispatchError = error{ UnknownCommand, DisabledCommand, InvalidArguments, Cancelled, HandlerFailed, ShuttingDown };

/// Borrowed context remains alive until disposal succeeds. Callbacks run on the
/// application thread; lifecycle requests from workers must be marshalled there.
pub const Handler = struct {
    context: *anyopaque,
    argument_kind: ArgumentKind = .none,
    validate: ?*const fn (*anyopaque, Arguments) bool = null,
    enabled: ?*const fn (*anyopaque) bool = null,
    call: *const fn (*anyopaque, Arguments, Token) anyerror!void,
};

const Entry = struct { serial: u64, handler: Handler, active: usize = 0 };

/// Copyable registration identity, never a raw callback. The registry must
/// outlive every handle. A stale copy cannot invoke or remove a replacement.
pub const Registration = struct {
    registry: *Registry,
    serial: u64,

    /// Success permits releasing the borrowed context. CommandInUse means retry
    /// after synchronous dispatch unwinds; it never removes a running callback.
    pub fn dispose(self: Registration) error{CommandInUse}!void {
        const entry = self.registry.find(self.serial) orelse return;
        if (entry.value_ptr.active != 0) return error.CommandInUse;
        const key = entry.key_ptr.*;
        _ = self.registry.entries.remove(key);
        self.registry.allocator.free(key);
    }

    pub fn dispatch(self: Registration, arguments: Arguments, token: Token) DispatchError!void {
        return self.registry.invoke(self.serial, arguments, token);
    }
};

/// Single application-thread owner. Keep at a stable address, never copy after
/// registration, and deinit only after all callbacks and handles finish.
pub const Registry = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMapUnmanaged(Entry) = .empty,
    next_serial: u64 = 1,
    accepting: bool = true,
    closed: bool = false,
    active_dispatches: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        std.debug.assert(self.active_dispatches == 0);
        var keys = self.entries.keyIterator();
        while (keys.next()) |key| self.allocator.free(key.*);
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn close(self: *Registry) void {
        self.accepting = false;
        self.closed = true;
    }

    /// Owns a copy of a case-sensitive, ASCII dot-separated command ID. Failure
    /// leaves previous registrations and caller ownership unchanged.
    pub fn register(self: *Registry, id: []const u8, handler: Handler) error{ InvalidCommandId, DuplicateCommand, OutOfMemory, RegistrationLimit, ShuttingDown }!Registration {
        if (self.closed) return error.ShuttingDown;
        if (!validId(id)) return error.InvalidCommandId;
        if (self.entries.contains(id)) return error.DuplicateCommand;
        if (self.next_serial == std.math.maxInt(u64)) return error.RegistrationLimit;
        const owned_id = try self.allocator.dupe(u8, id);
        errdefer self.allocator.free(owned_id);
        const serial = self.next_serial;
        try self.entries.put(self.allocator, owned_id, .{ .serial = serial, .handler = handler });
        self.next_serial += 1;
        return .{ .registry = self, .serial = serial };
    }

    pub fn lookup(self: *Registry, id: []const u8) error{UnknownCommand}!Registration {
        const entry = self.entries.get(id) orelse return error.UnknownCommand;
        return .{ .registry = self, .serial = entry.serial };
    }

    pub fn dispatch(self: *Registry, id: []const u8, arguments: Arguments, token: Token) DispatchError!void {
        if (!self.accepting) return error.ShuttingDown;
        return (try self.lookup(id)).dispatch(arguments, token);
    }

    fn find(self: *Registry, serial: u64) ?std.StringHashMapUnmanaged(Entry).Entry {
        var iterator = self.entries.iterator();
        while (iterator.next()) |entry| if (entry.value_ptr.serial == serial) return entry;
        return null;
    }

    fn invoke(self: *Registry, serial: u64, arguments: Arguments, token: Token) DispatchError!void {
        if (!self.accepting) return error.ShuttingDown;
        const entry = self.find(serial) orelse return error.UnknownCommand;
        const handler = entry.value_ptr.handler;
        // Pin before *any* callback, including validation and enablement. Never
        // keep a map pointer across user code, which may register other commands.
        entry.value_ptr.active += 1;
        self.active_dispatches += 1;
        defer {
            self.find(serial).?.value_ptr.active -= 1;
            self.active_dispatches -= 1;
        }
        try token.check();
        if (std.meta.activeTag(arguments) != handler.argument_kind) return error.InvalidArguments;
        if (handler.validate) |validate| {
            if (!validate(handler.context, arguments)) return error.InvalidArguments;
        }
        if (!self.accepting) return error.ShuttingDown;
        try token.check();
        if (handler.enabled) |enabled| {
            if (!enabled(handler.context)) return error.DisabledCommand;
        }
        if (!self.accepting) return error.ShuttingDown;
        try token.check();
        handler.call(handler.context, arguments, token) catch |err| {
            if (err == error.Cancelled) return error.Cancelled;
            return error.HandlerFailed;
        };
        try token.check();
    }
};

fn validId(id: []const u8) bool {
    var segments = std.mem.splitScalar(u8, id, '.');
    var count: usize = 0;
    while (segments.next()) |segment| {
        if (segment.len == 0 or !std.ascii.isAlphabetic(segment[0])) return false;
        for (segment[1..]) |byte| {
            if (!std.ascii.isAlphanumeric(byte) and byte != '_' and byte != '-') return false;
        }
        count += 1;
    }
    return count >= 2;
}

const Counter = struct {
    calls: usize = 0,

    fn handler(self: *Counter) Handler {
        return .{ .context = self, .call = increment };
    }

    fn increment(raw: *anyopaque, _: Arguments, _: Token) !void {
        const self: *Counter = @ptrCast(@alignCast(raw));
        self.calls += 1;
    }
};

test "lookup is independent of registration order and resolves the right context" {
    const ids = [_][]const u8{ "zigide.file.open", "zigide.file.close", "example.run-task_2" };
    const orders = [_][3]usize{ .{ 0, 1, 2 }, .{ 0, 2, 1 }, .{ 1, 0, 2 }, .{ 1, 2, 0 }, .{ 2, 0, 1 }, .{ 2, 1, 0 } };
    for (orders) |order| {
        var source: foundation.cancellation.Source = .{};
        var registry = Registry.init(std.testing.allocator);
        defer registry.deinit();
        var counters = [_]Counter{ .{}, .{}, .{} };
        for (order) |index| _ = try registry.register(ids[index], counters[index].handler());
        for (ids, 0..) |id, index| {
            const handler = try registry.lookup(id);
            for (0..index + 1) |_| try handler.dispatch(.none, source.token());
        }
        for (counters, 0..) |counter, index| try std.testing.expectEqual(index + 1, counter.calls);
    }
}

test "duplicate registration never replaces a handler and unknown IDs are explicit" {
    var source: foundation.cancellation.Source = .{};
    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();
    var original: Counter = .{};
    var replacement: Counter = .{};
    try std.testing.expectError(error.UnknownCommand, registry.lookup("zigide.missing"));
    _ = try registry.register("zigide.run", original.handler());
    try std.testing.expectError(error.DuplicateCommand, registry.register("zigide.run", replacement.handler()));
    const handler = try registry.lookup("zigide.run");
    try handler.dispatch(.none, source.token());
    try std.testing.expectEqual(@as(usize, 1), original.calls);
    try std.testing.expectEqual(@as(usize, 0), replacement.calls);
    try std.testing.expectError(error.UnknownCommand, registry.lookup("Zigide.run"));
    try std.testing.expectError(error.UnknownCommand, registry.lookup(""));
}

test "IDs require a namespace and reject malformed or non-ASCII input" {
    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();
    var counter: Counter = .{};
    for ([_][]const u8{ "", "open", ".open", "zigide.", "zigide..open", "1zigide.open", "zigide.2open", "zigide.open file", "zigide.open/other", "zigide.open\x00", "zigide.écrire" }) |id| {
        try std.testing.expectError(error.InvalidCommandId, registry.register(id, counter.handler()));
        try std.testing.expectError(error.UnknownCommand, registry.lookup(id));
    }
    try std.testing.expectEqual(@as(usize, 0), counter.calls);
}

test "registration owns ID bytes and resolved handlers survive map growth" {
    var source: foundation.cancellation.Source = .{};
    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();
    var counter: Counter = .{};
    var id = "zigide.run".*;
    _ = try registry.register(&id, counter.handler());
    @memset(&id, 'x');
    const resolved = try registry.lookup("zigide.run");
    var buffer: [64]u8 = undefined;
    for (0..100) |index| {
        _ = try registry.register(try std.fmt.bufPrint(&buffer, "zigide.command{d}", .{index}), counter.handler());
    }
    try resolved.dispatch(.none, source.token());
    const last = try registry.lookup("zigide.command99");
    try last.dispatch(.none, source.token());
    try std.testing.expectEqual(@as(usize, 2), counter.calls);
}

fn allocationPaths(allocator: std.mem.Allocator) !void {
    var source: foundation.cancellation.Source = .{};
    var registry = Registry.init(allocator);
    defer registry.deinit();
    var original: Counter = .{};
    _ = try registry.register("zigide.original", original.handler());
    var buffer: [64]u8 = undefined;
    for (0..32) |index| {
        const id = try std.fmt.bufPrint(&buffer, "zigide.command{d}", .{index});
        _ = registry.register(id, original.handler()) catch |err| {
            try std.testing.expectError(error.UnknownCommand, registry.lookup(id));
            const handler = try registry.lookup("zigide.original");
            try handler.dispatch(.none, source.token());
            try std.testing.expectEqual(@as(usize, 1), original.calls);
            return err;
        };
    }
}

test "allocation failures release owned IDs and preserve earlier registrations" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationPaths, .{});
}
