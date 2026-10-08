const std = @import("std");

test "executable exits cleanly in an isolated workspace" {
    var workspace = std.testing.tmpDir(.{ .iterate = true });
    defer workspace.cleanup();

    const project_root = try std.process.currentPathAlloc(std.testing.io, std.testing.allocator);
    defer std.testing.allocator.free(project_root);
    const emitted_path = @import("build_options").zigide_executable;
    const executable_path = if (std.fs.path.isAbsolute(emitted_path))
        try std.testing.allocator.dupe(u8, emitted_path)
    else
        try std.fs.path.join(std.testing.allocator, &.{
            project_root,
            emitted_path,
        });
    defer std.testing.allocator.free(executable_path);

    var environment = std.process.Environ.Map.init(std.testing.allocator);
    defer environment.deinit();

    const result = std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = &.{executable_path},
        .cwd = .{ .dir = workspace.dir },
        .environ_map = &environment,
        .stdout_limit = .limited(1024),
        .stderr_limit = .limited(1024),
    }) catch |err| {
        std.debug.print("unable to launch Zigide integration fixture: {s}\n", .{@errorName(err)});
        return err;
    };
    defer std.testing.allocator.free(result.stdout);
    defer std.testing.allocator.free(result.stderr);

    try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, result.term);
    try std.testing.expectEqualStrings("", result.stdout);
    try std.testing.expectEqualStrings("", result.stderr);

    var entries = workspace.dir.iterate();
    try std.testing.expect((try entries.next(std.testing.io)) == null);
}

const application = @import("application");
const foundation = @import("foundation");

const CaptureLog = struct {
    event: ?foundation.logging.Event = null,
    unavailable: bool = false,

    fn write(raw: *anyopaque, event: foundation.logging.Event) error{Unavailable}!void {
        const self: *CaptureLog = @ptrCast(@alignCast(raw));
        if (self.unavailable) return error.Unavailable;
        self.event = event;
    }

    fn sink(self: *CaptureLog) foundation.logging.Sink {
        return .{ .context = self, .write = write };
    }
};

const HeadlessService = struct {
    context: *application.Context,
    calls: usize = 0,

    fn run(raw: *anyopaque, _: @import("commands").Arguments, _: foundation.cancellation.Token) !void {
        const self: *HeadlessService = @ptrCast(@alignCast(raw));
        self.calls += 1;
        if (!self.context.logger.emit(.info, .application, .operation_completed, @enumFromInt(7), null))
            return error.LogUnavailable;
    }
};

test "headless composition substitutes every current external port and wires services" {
    var clock: foundation.clock.ManualClock = .{ .wall_time = .{ .ns = 100 } };
    var log: CaptureLog = .{};
    var context = application.Context.init(std.testing.allocator, .{ .clock = clock.clock(), .log_sink = log.sink() });
    defer context.deinit();
    try context.start(&.{});
    defer context.shutdown(clock.clock().monotonic()) catch unreachable;
    var source: foundation.cancellation.Source = .{};
    var service: HeadlessService = .{ .context = &context };
    _ = try context.commands.register("test.complete", .{ .context = &service, .call = HeadlessService.run });
    const handler = try context.commands.lookup("test.complete");
    try handler.dispatch(.none, source.token());
    try std.testing.expectEqual(@as(usize, 1), service.calls);
    try std.testing.expectEqual(@as(i96, 100), log.event.?.timestamp.ns);
    try std.testing.expectEqual(foundation.logging.Subsystem.application, log.event.?.subsystem);
    try std.testing.expectEqual(@as(foundation.ids.CorrelationId, @enumFromInt(7)), log.event.?.correlation_id);
    try clock.advance(25);
    try handler.dispatch(.none, source.token());
    try std.testing.expectEqual(@as(i96, 125), log.event.?.timestamp.ns);
    log.unavailable = true;
    try std.testing.expectError(error.HandlerFailed, handler.dispatch(.none, source.token()));
    try std.testing.expectEqual(@as(usize, 3), service.calls);
}

test "application contexts are isolated and release only owned registry storage" {
    var clock: foundation.clock.ManualClock = .{};
    var log: CaptureLog = .{};
    const external: application.ExternalPorts = .{ .clock = clock.clock(), .log_sink = log.sink() };
    var first = application.Context.init(std.testing.allocator, external);
    // The nested scope guarantees cleanup before proving borrowed ports survive.
    {
        defer first.deinit();
        var second = application.Context.init(std.testing.allocator, external);
        defer second.deinit();
        var service: HeadlessService = .{ .context = &first };
        _ = try first.commands.register("test.complete", .{ .context = &service, .call = HeadlessService.run });
        try std.testing.expectError(error.UnknownCommand, second.commands.lookup("test.complete"));
    }
    try clock.advance(1);
    const logger: foundation.logging.Logger = .{ .clock = clock.clock(), .sink = log.sink() };
    try std.testing.expect(logger.emit(.info, .application, .operation_completed, @enumFromInt(1), null));
    try std.testing.expectEqual(@as(i96, 1), log.event.?.timestamp.ns);
}

test {
    _ = @import("headless.zig");
    _ = @import("protocol_transport.zig");
    _ = @import("protocol_stress.zig");
}
