//! Deterministic protocol peer; mode is an argv element, never shell input.
const std = @import("std");
const framing = @import("adapters").framing;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const mode = args[1];
    if (std.mem.eql(u8, mode, "closed-pipes")) {
        std.Io.File.stdout().close(init.io);
        std.Io.File.stderr().close(init.io);
        try std.Io.sleep(init.io, .fromSeconds(60), .awake);
        return;
    }
    if (std.mem.eql(u8, mode, "hang")) {
        try std.Io.sleep(init.io, .fromSeconds(60), .awake);
        return;
    }
    if (std.mem.eql(u8, mode, "nonzero")) std.process.exit(7);
    if (std.mem.eql(u8, mode, "truncated")) {
        try std.Io.File.stdout().writeStreamingAll(init.io, "Content-Length: 4\r\n\r\nx");
        return;
    }
    const payload = "{\"jsonrpc\":\"2.0\",\"method\":\"log\"}";
    const frame = try framing.encode(init.gpa, payload, .{});
    defer init.gpa.free(frame);
    const stderr_block: [8192]u8 = @splat('e');
    for (0..2048) |_| {
        try std.Io.File.stderr().writeStreamingAll(init.io, &stderr_block);
        try std.Io.File.stdout().writeStreamingAll(init.io, frame);
    }
    // Echo the exact argument as JSON to prove spaces/metacharacters stay literal.
    const literal = try std.json.Stringify.valueAlloc(init.gpa, args[2], .{});
    defer init.gpa.free(literal);
    const last = try framing.encode(init.gpa, literal, .{});
    defer init.gpa.free(last);
    try std.Io.File.stdout().writeStreamingAll(init.io, last);
    var buffer: [4096]u8 = undefined;
    while (true) {
        _ = std.Io.File.stdin().readStreaming(init.io, &.{&buffer}) catch |err| switch (err) {
            error.EndOfStream => return,
            else => return err,
        };
    }
}
