//! Deterministic caller-owned doubles. No files, processes, UI, or sleeps.
const std = @import("std");
const ports = @import("ports");
const foundation = @import("foundation");
pub const ManualClock = foundation.clock.ManualClock;

pub const Gate = struct {
    clock: foundation.clock.Clock,
    ready_at: i96 = 0,
    failure: ?ports.Error = null,

    fn check(self: Gate, request: ports.Request) ports.Error!void {
        try request.check(self.clock);
        if (self.failure) |err| return err;
        if (self.clock.monotonic().ns < self.ready_at) return error.Pending;
    }
};

/// Independent instances substitute file and persistent storage ports. Keys and
/// values are owned copies; read results belong to the requesting allocator.
pub const BlobStore = struct {
    allocator: std.mem.Allocator,
    gate: Gate,
    values: std.StringHashMapUnmanaged([]u8) = .empty,

    pub fn init(allocator: std.mem.Allocator, clock: foundation.clock.Clock) BlobStore {
        return .{ .allocator = allocator, .gate = .{ .clock = clock } };
    }
    pub fn deinit(self: *BlobStore) void {
        var iterator = self.values.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.values.deinit(self.allocator);
        self.* = undefined;
    }
    pub fn port(self: *BlobStore) ports.BlobStore {
        return .{ .context = self, .read = read, .write = write };
    }
    fn read(raw: *anyopaque, allocator: std.mem.Allocator, key: []const u8, request: ports.Request) ports.Error![]u8 {
        const self: *BlobStore = @ptrCast(@alignCast(raw));
        try self.gate.check(request);
        return allocator.dupe(u8, self.values.get(key) orelse return error.NotFound);
    }
    fn write(raw: *anyopaque, key: []const u8, value: []const u8, request: ports.Request) ports.Error!void {
        const self: *BlobStore = @ptrCast(@alignCast(raw));
        try self.gate.check(request);
        const copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(copy);
        if (self.values.getPtr(key)) |existing| {
            self.allocator.free(existing.*);
            existing.* = copy;
            return;
        }
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        try self.values.put(self.allocator, owned_key, copy);
    }
};

/// Models one child at a time, with monotonic identities so stale requests cannot
/// terminate a replacement. argv is copied and observable without launching it.
pub const Process = struct {
    allocator: std.mem.Allocator,
    gate: Gate,
    argv: std.ArrayList([]u8) = .empty,
    current: ?ports.ProcessId = null,
    next_id: u64 = 1,
    exit_at: i96 = 0,
    exit_code: u8 = 0,
    terminated: usize = 0,

    pub fn init(allocator: std.mem.Allocator, clock: foundation.clock.Clock) Process {
        return .{ .allocator = allocator, .gate = .{ .clock = clock } };
    }
    pub fn deinit(self: *Process) void {
        self.clearArgs();
        self.* = undefined;
    }
    fn clearArgs(self: *Process) void {
        for (self.argv.items) |arg| self.allocator.free(arg);
        self.argv.deinit(self.allocator);
        self.argv = .empty;
    }
    pub fn port(self: *Process) ports.Process {
        return .{ .context = self, .start = start, .poll = poll, .terminate = terminate };
    }
    fn start(raw: *anyopaque, argv: []const []const u8, request: ports.Request) ports.Error!ports.ProcessId {
        const self: *Process = @ptrCast(@alignCast(raw));
        try self.gate.check(request);
        if (self.current != null) return error.Busy;
        if (argv.len == 0 or argv[0].len == 0 or self.next_id == std.math.maxInt(u64)) return error.InvalidRequest;
        self.clearArgs();
        errdefer self.clearArgs();
        for (argv) |arg| {
            const copy = try self.allocator.dupe(u8, arg);
            errdefer self.allocator.free(copy);
            try self.argv.append(self.allocator, copy);
        }
        const id: ports.ProcessId = @enumFromInt(self.next_id);
        self.next_id += 1;
        self.current = id;
        return id;
    }
    fn poll(raw: *anyopaque, id: ports.ProcessId, request: ports.Request) ports.Error!?u8 {
        const self: *Process = @ptrCast(@alignCast(raw));
        try self.gate.check(request);
        if (self.current != id) return error.NotFound;
        if (self.gate.clock.monotonic().ns < self.exit_at) return null;
        self.current = null;
        return self.exit_code;
    }
    fn terminate(raw: *anyopaque, id: ports.ProcessId) ports.Error!void {
        const self: *Process = @ptrCast(@alignCast(raw));
        if (self.current != id) return error.NotFound;
        self.current = null;
        self.terminated += 1;
    }
};

pub const Scheduler = struct {
    allocator: std.mem.Allocator,
    clock: foundation.clock.Clock,
    ready_at: i96 = 0,
    failure: ?ports.Error = null,
    queue: std.ArrayList(ports.Task) = .empty,

    pub fn init(allocator: std.mem.Allocator, clock: foundation.clock.Clock) Scheduler {
        return .{ .allocator = allocator, .clock = clock };
    }
    /// Discards pending callbacks without invoking borrowed contexts.
    pub fn deinit(self: *Scheduler) void {
        self.queue.deinit(self.allocator);
        self.* = undefined;
    }
    pub fn port(self: *Scheduler) ports.Scheduler {
        return .{ .context = self, .post = post };
    }
    fn post(raw: *anyopaque, task: ports.Task) ports.Error!void {
        const self: *Scheduler = @ptrCast(@alignCast(raw));
        try task.cancellation.check();
        if (self.failure) |err| return err;
        try self.queue.append(self.allocator, task);
    }
    /// FIFO snapshot: reentrant posts run on the next pump, never this one.
    pub fn pump(self: *Scheduler) void {
        if (self.clock.monotonic().ns < self.ready_at) return;
        var pending = self.queue;
        self.queue = .empty;
        defer pending.deinit(self.allocator);
        for (pending.items) |task| if (!task.cancellation.isCancelled()) task.run(task.context);
    }
};
