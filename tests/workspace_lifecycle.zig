const std = @import("std");
const application = @import("application");
const ports = @import("ports");
const adapters = @import("adapters");
const workspace = @import("workspace");
const foundation = @import("foundation");

const Missing = struct {
    failure: ports.ResourceError = error.NotFound,
    fn resolve(raw: *anyopaque, _: std.mem.Allocator, _: []const u8, _: []const u8, _: ports.ResourceKind) ports.ResourceError!ports.Resource {
        const self: *Missing = @ptrCast(@alignCast(raw));
        return self.failure;
    }
};
test "ZIT-053 resource errors retain contextual cause without changing workspace" {
    var missing: Missing = .{};
    var service = application.Workspace.init(std.testing.allocator, .{ .context = &missing, .resolve = Missing.resolve });
    defer service.deinit();
    for ([_]ports.ResourceError{ error.NotFound, error.AccessDenied, error.NotDirectory }) |err| {
        missing.failure = err;
        try std.testing.expectError(err, service.open("/", "missing", null));
        try std.testing.expectEqual(err, service.last_failure.?.cause);
        try std.testing.expectEqual(.open_workspace, service.last_failure.?.operation);
        try std.testing.expect(service.session.root == null);
    }
}

test "ZIT-052–057 real folder aliases deduplicate and reject symlink escape" {
    const a = std.testing.allocator;
    const io = std.testing.io;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    try temp.dir.createDir(io, "root", .default_dir);
    try temp.dir.createDir(io, "outside", .default_dir);
    try temp.dir.writeFile(io, .{ .sub_path = "root/one.zig", .data = "original\r\n" });
    try temp.dir.writeFile(io, .{ .sub_path = "outside/other.zig", .data = "outside" });
    try temp.dir.symLink(io, "one.zig", "root/alias.zig", .{});
    try temp.dir.symLink(io, "../outside/other.zig", "root/escape.zig", .{});
    var buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const base = buffer[0..try temp.dir.realPath(io, &buffer)];
    var local: adapters.LocalResources = .{ .io = io };
    var service = application.Workspace.init(a, local.port());
    defer service.deinit();
    try service.open(base, "root", null);
    defer service.session.closeWorkspace(.workspace_close, null) catch unreachable;
    const id = try service.openDocument("./one.zig", "original\r\n");
    try std.testing.expectEqual(id, try service.openDocument("alias.zig", "ignored"));
    try std.testing.expectError(error.OutsideWorkspace, service.openDocument("escape.zig", "outside"));
    const generation = service.session.generation;
    try std.testing.expectError(error.NotFound, service.open(base, "missing", null));
    try std.testing.expectEqual(generation, service.session.generation);
    try std.testing.expectEqual(id, service.session.active.?);
    const disk = try temp.dir.readFileAlloc(io, "root/one.zig", a, .limited(1024));
    defer a.free(disk);
    try std.testing.expectEqualStrings("original\r\n", disk);
}

test "ZIT-056 shutdown cancellation precedes application command shutdown" {
    var missing: Missing = .{};
    var service = application.Workspace.init(std.testing.allocator, .{ .context = &missing, .resolve = Missing.resolve });
    defer service.deinit();
    var root = try workspace.Resource.initCanonical(std.testing.allocator, "/work");
    defer root.deinit();
    var resource = try workspace.Resource.initCanonical(std.testing.allocator, "/work/one");
    defer resource.deinit();
    try service.session.openWorkspace(root, null);
    const id = try service.session.openDocument(resource, "text");
    try service.session.edit(id, &.{.{ .start = 0, .end = 0, .inserted = "edited" }});
    var clock: foundation.clock.ManualClock = .{};
    var log: adapters.DiscardLog = .{};
    var context = application.Context.init(std.testing.allocator, .{ .clock = clock.clock(), .log_sink = log.sink() });
    defer context.deinit();
    try context.start(&.{});
    const Choice = struct {
        decision: workspace.lifecycle.Decision = .cancel,
        fn decide(raw: *anyopaque, prompt: workspace.lifecycle.Prompt) !workspace.lifecycle.Decision {
            try std.testing.expectEqual(workspace.lifecycle.Reason.shutdown, prompt.reason);
            const self: *@This() = @ptrCast(@alignCast(raw));
            return self.decision;
        }
    };
    var choice: Choice = .{};
    const policy: workspace.ClosePolicy = .{ .context = &choice, .decide = Choice.decide };
    try std.testing.expectError(error.Cancelled, service.prepareShutdown(policy));
    try std.testing.expectEqual(application.State.running, context.state);
    try std.testing.expect(context.commands.accepting);
    try std.testing.expect((try service.session.view(id)).dirty);
    choice.decision = .discard;
    try service.prepareShutdown(policy);
    try context.shutdown(clock.clock().monotonic());
    try std.testing.expectEqual(application.State.stopped, context.state);
}
