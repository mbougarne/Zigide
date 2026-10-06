const std = @import("std");

/// Borrowed callback. Context must remain alive until the registry and all
/// resolved copies are no longer used. Calling a handler is synchronous; argument
/// validation and dispatch policy belong to the later command-dispatch ticket.
pub const Handler = struct {
    context: *anyopaque,
    call: *const fn (*anyopaque) anyerror!void,
};

/// Application-thread-only registry. Owns copied IDs and map storage, borrows
/// handler contexts. Do not copy after registration; deinit exactly once after
/// callers finish. Lookup returns a value, never a pointer into growable storage.
pub const Registry = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMapUnmanaged(Handler) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        var keys = self.entries.keyIterator();
        while (keys.next()) |key| self.allocator.free(key.*);
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    /// IDs are case-sensitive ASCII dot-separated identifiers with at least two
    /// segments. Each segment starts with a letter; subsequent bytes may also be
    /// digits, '_' or '-'. IDs have no normalization or implicit aliases.
    /// Failure preserves all existing registrations and caller ownership.
    pub fn register(self: *Registry, id: []const u8, handler: Handler) error{ InvalidCommandId, DuplicateCommand, OutOfMemory }!void {
        if (!validId(id)) return error.InvalidCommandId;
        if (self.entries.contains(id)) return error.DuplicateCommand;
        const owned_id = try self.allocator.dupe(u8, id);
        errdefer self.allocator.free(owned_id);
        try self.entries.put(self.allocator, owned_id, handler);
    }

    pub fn lookup(self: *const Registry, id: []const u8) error{UnknownCommand}!Handler {
        return self.entries.get(id) orelse error.UnknownCommand;
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

    fn increment(raw: *anyopaque) !void {
        const self: *Counter = @ptrCast(@alignCast(raw));
        self.calls += 1;
    }
};

test "lookup is independent of registration order and resolves the right context" {
    const ids = [_][]const u8{ "zigide.file.open", "zigide.file.close", "example.run-task_2" };
    const orders = [_][3]usize{ .{ 0, 1, 2 }, .{ 0, 2, 1 }, .{ 1, 0, 2 }, .{ 1, 2, 0 }, .{ 2, 0, 1 }, .{ 2, 1, 0 } };
    for (orders) |order| {
        var registry = Registry.init(std.testing.allocator);
        defer registry.deinit();
        var counters = [_]Counter{ .{}, .{}, .{} };
        for (order) |index| try registry.register(ids[index], counters[index].handler());
        for (ids, 0..) |id, index| {
            const handler = try registry.lookup(id);
            for (0..index + 1) |_| try handler.call(handler.context);
        }
        for (counters, 0..) |counter, index| try std.testing.expectEqual(index + 1, counter.calls);
    }
}

test "duplicate registration never replaces a handler and unknown IDs are explicit" {
    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();
    var original: Counter = .{};
    var replacement: Counter = .{};
    try std.testing.expectError(error.UnknownCommand, registry.lookup("zigide.missing"));
    try registry.register("zigide.run", original.handler());
    try std.testing.expectError(error.DuplicateCommand, registry.register("zigide.run", replacement.handler()));
    const handler = try registry.lookup("zigide.run");
    try handler.call(handler.context);
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
    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();
    var counter: Counter = .{};
    var id = "zigide.run".*;
    try registry.register(&id, counter.handler());
    @memset(&id, 'x');
    const resolved = try registry.lookup("zigide.run");
    var buffer: [64]u8 = undefined;
    for (0..100) |index| {
        try registry.register(try std.fmt.bufPrint(&buffer, "zigide.command{d}", .{index}), counter.handler());
    }
    try resolved.call(resolved.context);
    const last = try registry.lookup("zigide.command99");
    try last.call(last.context);
    try std.testing.expectEqual(@as(usize, 2), counter.calls);
}

fn allocationPaths(allocator: std.mem.Allocator) !void {
    var registry = Registry.init(allocator);
    defer registry.deinit();
    var original: Counter = .{};
    try registry.register("zigide.original", original.handler());
    var buffer: [64]u8 = undefined;
    for (0..32) |index| {
        const id = try std.fmt.bufPrint(&buffer, "zigide.command{d}", .{index});
        registry.register(id, original.handler()) catch |err| {
            try std.testing.expectError(error.UnknownCommand, registry.lookup(id));
            const handler = try registry.lookup("zigide.original");
            try handler.call(handler.context);
            try std.testing.expectEqual(@as(usize, 1), original.calls);
            return err;
        };
    }
}

test "allocation failures release owned IDs and preserve earlier registrations" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationPaths, .{});
}
