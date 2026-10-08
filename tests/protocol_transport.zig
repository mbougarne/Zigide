const std = @import("std");
const transport = @import("adapters").transport;
const child_path = @import("build_options").protocol_child;

const Flood = struct {
    frames: usize = 0,
    fn converse(session: *transport.Session, raw: *anyopaque) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        try session.send("{}");
        for (0..2049) |index| {
            const payload = (try session.receive()) orelse return error.EarlyEof;
            defer session.allocator.free(payload);
            if (index == 2048) try std.testing.expectEqualStrings("\"spaces ; $(literal)\"", payload);
            self.frames += 1;
        }
        session.closeInput();
        try std.testing.expectError(error.StdinClosed, session.send("{}"));
    }
};
fn empty(_: *transport.Session, _: *anyopaque) !void {}

test "child transport drains simultaneous stdout stderr, preserves argv and observes EOF" {
    var context: Flood = .{};
    const result = try transport.run(std.testing.allocator, std.testing.io, .{ .argv = &.{ child_path, "flood", "spaces ; $(literal)" } }, &context, Flood.converse);
    try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, result.term);
    try std.testing.expectEqual(@as(usize, 2049), context.frames);
    try std.testing.expectEqual(@as(usize, 2048 * 8192), result.stderr_bytes);
    try std.testing.expectEqual(@as(usize, 4096), result.stderr_prefix_len);
}

test "spawn, malformed pipe close, nonzero exit and forced deadline are observable" {
    var context: u8 = 0;
    try std.testing.expectError(error.FileNotFound, transport.run(std.testing.allocator, std.testing.io, .{ .argv = &.{"/nonexistent/zigide-protocol-fixture"} }, &context, empty));
    try std.testing.expectError(error.TruncatedBody, transport.run(std.testing.allocator, std.testing.io, .{ .argv = &.{ child_path, "truncated" } }, &context, empty));
    const result = try transport.run(std.testing.allocator, std.testing.io, .{ .argv = &.{ child_path, "nonzero" } }, &context, empty);
    try std.testing.expectEqual(std.process.Child.Term{ .exited = 7 }, result.term);
    try std.testing.expectError(error.DeadlineExceeded, transport.run(std.testing.allocator, std.testing.io, .{ .argv = &.{ child_path, "hang" }, .timeout = .fromMilliseconds(100) }, &context, empty));
}

test "deadline after stdout and stderr EOF still terminates and reaps the child" {
    var context: u8 = 0;
    try std.testing.expectError(error.DeadlineExceeded, transport.run(std.testing.allocator, std.testing.io, .{ .argv = &.{ child_path, "closed-pipes" }, .timeout = .fromMilliseconds(100) }, &context, empty));
}
