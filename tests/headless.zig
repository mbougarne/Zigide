const std = @import("std");
const application = @import("application");
const foundation = @import("foundation");
const commands = @import("commands");
const ports = @import("ports");
const doubles = @import("support/ports.zig");

const Log = struct {
    fn write(_: *anyopaque, _: foundation.logging.Event) error{Unavailable}!void {}
    fn sink(self: *Log) foundation.logging.Sink {
        return .{ .context = self, .write = write };
    }
};

const Trace = struct {
    bytes: [128]u8 = undefined,
    count: usize = 0,
    fn add(self: *Trace, value: u8) void {
        self.bytes[self.count] = value;
        self.count += 1;
    }
};

const Service = struct {
    app: *application.Context,
    trace: *Trace,
    id: u8,
    fail_start: bool = false,
    fail_persist: bool = false,
    reenter_start: bool = false,
    request_shutdown: bool = false,
    registration: ?commands.Registration = null,
    released: usize = 0,
    seen_deadline: ?i96 = null,
    clock: ?*doubles.ManualClock = null,

    fn service(self: *Service) application.Service {
        return .{ .context = self, .start = start, .shutdown = shutdown, .release = release };
    }
    fn start(raw: *anyopaque) !void {
        const self: *Service = @ptrCast(@alignCast(raw));
        self.trace.add('0' + self.id);
        var id: [32]u8 = undefined;
        self.registration = try self.app.commands.register(try std.fmt.bufPrint(&id, "test.service{d}", .{self.id}), .{ .context = self, .call = run });
        if (self.reenter_start) try std.testing.expectError(error.Busy, self.app.start(&.{}));
        if (self.request_shutdown) try std.testing.expectError(error.Busy, self.app.shutdown(.{ .ns = 10 }));
        if (self.fail_start) return error.StartRejected;
    }
    fn run(raw: *anyopaque, _: commands.Arguments, _: foundation.cancellation.Token) !void {
        const self: *Service = @ptrCast(@alignCast(raw));
        try std.testing.expectError(error.Busy, self.app.shutdown(.{ .ns = 20 }));
        try std.testing.expectEqual(@as(usize, 0), self.released);
    }
    fn shutdown(raw: *anyopaque, phase: application.Phase, deadline: foundation.clock.MonotonicTime) !void {
        const self: *Service = @ptrCast(@alignCast(raw));
        self.seen_deadline = deadline.ns;
        self.trace.add(switch (phase) {
            .persist => 'p',
            .cancel => 'c',
            .stop => 's',
            .flush => 'f',
        });
        self.trace.add('0' + self.id);
        var source: foundation.cancellation.Source = .{};
        try std.testing.expectError(error.ShuttingDown, self.app.commands.dispatch("test.service1", .none, source.token()));
        try std.testing.expectError(error.Busy, self.app.shutdown(.{ .ns = 999 }));
        if (phase == .stop) {
            if (self.clock) |clock| try clock.advance(100);
        }
        if (phase == .persist and self.fail_persist) return error.PersistRejected;
    }
    fn release(raw: *anyopaque) void {
        const self: *Service = @ptrCast(@alignCast(raw));
        self.trace.add('r');
        self.trace.add('0' + self.id);
        self.released += 1;
        if (self.registration) |registration| registration.dispose() catch unreachable;
    }
};

test "startup and shutdown are ordered idempotent and reject reentrant commands" {
    var clock: doubles.ManualClock = .{};
    var log: Log = .{};
    var app = application.Context.init(std.testing.allocator, .{ .clock = clock.clock(), .log_sink = log.sink() });
    defer app.deinit();
    var trace: Trace = .{};
    var first: Service = .{ .app = &app, .trace = &trace, .id = 1, .reenter_start = true };
    var second: Service = .{ .app = &app, .trace = &trace, .id = 2 };
    const services = [_]application.Service{ first.service(), second.service() };
    var source: foundation.cancellation.Source = .{};
    try std.testing.expectError(error.ShuttingDown, app.commands.dispatch("test.service1", .none, source.token()));
    try app.start(&services);
    try app.start(&services);
    // A shutdown requested from inside a command closes admission but cannot
    // release its own live service until the dispatch pin is gone.
    try app.commands.dispatch("test.service1", .none, source.token());
    try std.testing.expectEqual(application.State.stopping, app.state);
    try std.testing.expectError(error.ShuttingDown, app.commands.dispatch("test.service2", .none, source.token()));
    try app.shutdown(.{ .ns = 999 });
    try app.shutdown(.{ .ns = 999 });
    try std.testing.expectEqual(@as(?i96, 20), first.seen_deadline);
    try std.testing.expectEqualStrings("12p1p2c1c2s2s1f1f2r2r1", trace.bytes[0..trace.count]);
    try std.testing.expectEqual(@as(usize, 1), first.released);
    try std.testing.expectEqual(@as(usize, 1), second.released);
    try std.testing.expectError(error.Stopped, app.start(&services));
}

test "partial startup failure cleans only attempted services in reverse order" {
    var clock: doubles.ManualClock = .{};
    var log: Log = .{};
    var app = application.Context.init(std.testing.allocator, .{ .clock = clock.clock(), .log_sink = log.sink() });
    defer app.deinit();
    var trace: Trace = .{};
    var first: Service = .{ .app = &app, .trace = &trace, .id = 1 };
    var second: Service = .{ .app = &app, .trace = &trace, .id = 2, .fail_start = true };
    var third: Service = .{ .app = &app, .trace = &trace, .id = 3 };
    const services = [_]application.Service{ first.service(), second.service(), third.service() };
    try std.testing.expectError(error.StartupFailed, app.start(&services));
    try std.testing.expectEqual(error.StartRejected, app.cause.?);
    try std.testing.expectEqual(application.State.stopped, app.state);
    try std.testing.expectEqual(@as(usize, 0), third.released);
    try app.shutdown(.{ .ns = 100 });
    try std.testing.expectEqualStrings("12p1p2c1c2s2s1f1f2r2r1", trace.bytes[0..trace.count]);
}

test "shutdown errors and deadline expiry still release every service once" {
    for ([_]bool{ false, true }) |fail_persist| {
        var clock: doubles.ManualClock = .{};
        var log: Log = .{};
        var app = application.Context.init(std.testing.allocator, .{ .clock = clock.clock(), .log_sink = log.sink() });
        defer app.deinit();
        var trace: Trace = .{};
        var first: Service = .{ .app = &app, .trace = &trace, .id = 1, .fail_persist = fail_persist, .clock = &clock };
        const services = [_]application.Service{first.service()};
        try app.start(&services);
        const expected = if (fail_persist) error.ShutdownFailed else error.DeadlineExceeded;
        try std.testing.expectError(expected, app.shutdown(.{ .ns = 10 }));
        try std.testing.expectError(expected, app.shutdown(.{ .ns = 1000 }));
        try std.testing.expectEqualStrings("1p1c1s1f1r1", trace.bytes[0..trace.count]);
        try std.testing.expectEqual(@as(usize, 1), first.released);
    }
}

test "shutdown during startup never starts later services" {
    var clock: doubles.ManualClock = .{};
    var log: Log = .{};
    var app = application.Context.init(std.testing.allocator, .{ .clock = clock.clock(), .log_sink = log.sink() });
    defer app.deinit();
    var trace: Trace = .{};
    var first: Service = .{ .app = &app, .trace = &trace, .id = 1, .request_shutdown = true };
    var second: Service = .{ .app = &app, .trace = &trace, .id = 2 };
    const services = [_]application.Service{ first.service(), second.service() };
    try std.testing.expectError(error.Stopped, app.start(&services));
    try std.testing.expectEqualStrings("1p1c1s1f1r1", trace.bytes[0..trace.count]);
}

const Work = struct {
    calls: usize = 0,
    fn run(raw: *anyopaque) void {
        const self: *Work = @ptrCast(@alignCast(raw));
        self.calls += 1;
    }
};

test "all external ports substitute headlessly with failure delay and cancellation" {
    var clock: doubles.ManualClock = .{};
    var log: Log = .{};
    var files = doubles.BlobStore.init(std.testing.allocator, clock.clock());
    defer files.deinit();
    var storage = doubles.BlobStore.init(std.testing.allocator, clock.clock());
    defer storage.deinit();
    var process = doubles.Process.init(std.testing.allocator, clock.clock());
    defer process.deinit();
    var ui = doubles.Scheduler.init(std.testing.allocator, clock.clock());
    defer ui.deinit();
    var app = application.Context.init(std.testing.allocator, .{
        .clock = clock.clock(),
        .log_sink = log.sink(),
        .files = files.port(),
        .storage = storage.port(),
        .process = process.port(),
        .ui = ui.port(),
    });
    defer app.deinit();
    try app.start(&.{});
    defer app.shutdown(.{ .ns = 1000 }) catch unreachable;
    var source: foundation.cancellation.Source = .{};
    const request: ports.Request = .{ .cancellation = source.token(), .deadline = .{ .ns = 100 } };
    const file = app.external.files.?;
    const store = app.external.storage.?;
    const child = app.external.process.?;
    const scheduler = app.external.ui.?;
    try std.testing.expectError(error.NotFound, file.read(file.context, std.testing.allocator, "source", request));
    try file.write(file.context, "source", "hello", request);
    const bytes = try file.read(file.context, std.testing.allocator, "source", request);
    defer std.testing.allocator.free(bytes);
    try store.write(store.context, "recovery", bytes, request);
    const saved = try store.read(store.context, std.testing.allocator, "recovery", request);
    defer std.testing.allocator.free(saved);
    try std.testing.expectEqualStrings("hello", saved);
    try std.testing.expectError(error.NotFound, file.read(file.context, std.testing.allocator, "recovery", request));
    files.gate.failure = error.AccessDenied;
    try std.testing.expectError(error.AccessDenied, file.write(file.context, "source", "bad", request));
    files.gate.failure = null;
    storage.gate.ready_at = 10;
    try std.testing.expectError(error.Pending, store.write(store.context, "recovery", "later", request));
    process.gate.failure = error.Unavailable;
    try std.testing.expectError(error.Unavailable, child.start(child.context, &.{"fake"}, request));
    process.gate.failure = null;
    process.exit_at = 20;
    const id = try child.start(child.context, &.{ "fake", "--flag" }, request);
    try std.testing.expectEqualStrings("--flag", process.argv.items[1]);
    try std.testing.expect((try child.poll(child.context, id, request)) == null);
    var work: Work = .{};
    ui.failure = error.Unavailable;
    const task: ports.Task = .{ .context = &work, .run = Work.run, .cancellation = source.token() };
    try std.testing.expectError(error.Unavailable, scheduler.post(scheduler.context, task));
    ui.failure = null;
    ui.ready_at = 10;
    try scheduler.post(scheduler.context, task);
    ui.pump();
    try std.testing.expectEqual(@as(usize, 0), work.calls);
    try clock.advance(10);
    ui.pump();
    try std.testing.expectEqual(@as(usize, 1), work.calls);
    try store.write(store.context, "recovery", "later", request);
    try scheduler.post(scheduler.context, task);
    _ = source.cancel();
    ui.pump();
    try std.testing.expectEqual(@as(usize, 1), work.calls);
    try std.testing.expectError(error.Cancelled, scheduler.post(scheduler.context, task));
    try std.testing.expectError(error.Cancelled, file.read(file.context, std.testing.allocator, "source", request));
    try std.testing.expectError(error.Cancelled, store.write(store.context, "recovery", "bad", request));
    try std.testing.expectError(error.Cancelled, child.poll(child.context, id, request));
    try child.terminate(child.context, id);
    try std.testing.expectEqual(@as(usize, 1), process.terminated);
    source = .{};
    const replacement = try child.start(child.context, &.{"fake"}, request);
    try std.testing.expectError(error.NotFound, child.terminate(child.context, id));
    try clock.advance(10);
    try std.testing.expectEqual(@as(?u8, 0), try child.poll(child.context, replacement, request));
    try clock.advance(80);
    try std.testing.expectError(error.DeadlineExceeded, file.read(file.context, std.testing.allocator, "source", request));
}

fn allocationPaths(allocator: std.mem.Allocator) !void {
    var clock: doubles.ManualClock = .{};
    var source: foundation.cancellation.Source = .{};
    const request: ports.Request = .{ .cancellation = source.token(), .deadline = .{ .ns = 100 } };
    var files = doubles.BlobStore.init(allocator, clock.clock());
    defer files.deinit();
    const file = files.port();
    try file.write(file.context, "file", "first", request);
    try file.write(file.context, "file", "replacement", request);
    const bytes = try file.read(file.context, allocator, "file", request);
    defer allocator.free(bytes);
    var process = doubles.Process.init(allocator, clock.clock());
    defer process.deinit();
    const child = process.port();
    _ = try child.start(child.context, &.{ "fake", "one", "two" }, request);
    var ui = doubles.Scheduler.init(allocator, clock.clock());
    defer ui.deinit();
    var work: Work = .{};
    const scheduler = ui.port();
    try scheduler.post(scheduler.context, .{ .context = &work, .run = Work.run, .cancellation = source.token() });
    ui.pump();
    try std.testing.expectEqual(@as(usize, 1), work.calls);
}

test "port doubles release every allocation on success and injected allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationPaths, .{});
}

const Workflow = struct {
    app: *application.Context,
    allocator: std.mem.Allocator,
    work: Work = .{},

    fn run(raw: *anyopaque, args: commands.Arguments, token: foundation.cancellation.Token) !void {
        const self: *Workflow = @ptrCast(@alignCast(raw));
        const external = self.app.external;
        const request: ports.Request = .{ .cancellation = token, .deadline = .{ .ns = external.clock.monotonic().ns + 100 } };
        const files = external.files orelse return error.MissingFiles;
        const storage = external.storage orelse return error.MissingStorage;
        const process = external.process orelse return error.MissingProcess;
        const ui = external.ui orelse return error.MissingScheduler;
        const bytes = try files.read(files.context, self.allocator, args.text, request);
        defer self.allocator.free(bytes);
        try storage.write(storage.context, "snapshot", bytes, request);
        const id = try process.start(process.context, &.{ "fake-build", args.text }, request);
        defer process.terminate(process.context, id) catch unreachable;
        try ui.post(ui.context, .{ .context = &self.work, .run = Work.run, .cancellation = token });
    }
};

test "typed headless command executes with every external port substituted" {
    var clock: doubles.ManualClock = .{};
    var log: Log = .{};
    var files = doubles.BlobStore.init(std.testing.allocator, clock.clock());
    defer files.deinit();
    var storage = doubles.BlobStore.init(std.testing.allocator, clock.clock());
    defer storage.deinit();
    var process = doubles.Process.init(std.testing.allocator, clock.clock());
    defer process.deinit();
    var ui = doubles.Scheduler.init(std.testing.allocator, clock.clock());
    defer ui.deinit();
    var app = application.Context.init(std.testing.allocator, .{
        .clock = clock.clock(),
        .log_sink = log.sink(),
        .files = files.port(),
        .storage = storage.port(),
        .process = process.port(),
        .ui = ui.port(),
    });
    defer app.deinit();
    try app.start(&.{});
    defer app.shutdown(.{ .ns = 1000 }) catch unreachable;
    var source: foundation.cancellation.Source = .{};
    const file = files.port();
    const request: ports.Request = .{ .cancellation = source.token(), .deadline = .{ .ns = 100 } };
    try file.write(file.context, "main.zig", "const value = 1;", request);
    var workflow: Workflow = .{ .app = &app, .allocator = std.testing.allocator };
    const registration = try app.commands.register("test.snapshot", .{ .context = &workflow, .argument_kind = .text, .call = Workflow.run });
    defer registration.dispose() catch unreachable;
    try registration.dispatch(.{ .text = "main.zig" }, source.token());
    try std.testing.expectEqualStrings("const value = 1;", storage.values.get("snapshot").?);
    try std.testing.expectEqualStrings("main.zig", process.argv.items[1]);
    try std.testing.expectEqual(@as(usize, 1), process.terminated);
    try std.testing.expectEqual(@as(usize, 0), workflow.work.calls);
    ui.pump();
    try std.testing.expectEqual(@as(usize, 1), workflow.work.calls);
    files.gate.failure = error.AccessDenied;
    try std.testing.expectError(error.HandlerFailed, registration.dispatch(.{ .text = "main.zig" }, source.token()));
    try std.testing.expectEqual(@as(usize, 1), process.terminated);
}

fn lifecycleAllocationPaths(allocator: std.mem.Allocator) !void {
    var clock: doubles.ManualClock = .{};
    var log: Log = .{};
    var app = application.Context.init(allocator, .{ .clock = clock.clock(), .log_sink = log.sink() });
    defer app.deinit();
    var trace: Trace = .{};
    var first: Service = .{ .app = &app, .trace = &trace, .id = 1 };
    var second: Service = .{ .app = &app, .trace = &trace, .id = 2 };
    const services = [_]application.Service{ first.service(), second.service() };
    app.start(&services) catch |err| {
        try std.testing.expectEqual(error.StartupFailed, err);
        try std.testing.expectEqual(application.State.stopped, app.state);
        return app.cause.?;
    };
    try app.shutdown(.{ .ns = 100 });
}

test "allocation failures during startup release partial registration state" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, lifecycleAllocationPaths, .{});
}
