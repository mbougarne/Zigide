const std = @import("std");
const adapters = @import("adapters");
const framing = adapters.framing;
const rpc = adapters.rpc;
const foundation = @import("foundation");
const limits: framing.Limits = .{ .header = 128, .payload = 512 };

fn exercise(allocator: std.mem.Allocator, bytes: []const u8, chunk_size: usize) !void {
    var decoder = framing.Decoder.init(allocator, limits);
    defer decoder.deinit();
    var clock: foundation.clock.ManualClock = .{};
    var source: foundation.cancellation.Source = .{};
    var pending: rpc.Correlator = .{};
    defer pending.disconnect();
    _ = try pending.begin(.{ .cancellation = source.token(), .deadline = .{ .ns = 20 } }, clock.clock());
    var offset: usize = 0;
    while (offset < bytes.len) {
        const chunk = decoder.feed(bytes[offset..@min(bytes.len, offset + chunk_size)]) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return,
        };
        try std.testing.expect(chunk.consumed > 0);
        offset += chunk.consumed;
        if (offset % 2 == 0) _ = source.cancel();
        try clock.advance(1);
        if (chunk.payload) |payload| {
            defer allocator.free(payload);
            var message = rpc.decode(allocator, payload, limits.payload) catch |err| switch (err) {
                error.OutOfMemory => return err,
                else => continue,
            };
            defer message.deinit();
            _ = pending.complete(message, clock.clock());
        }
        while (pending.poll(clock.clock()) != null) {}
        try std.testing.expect(decoder.header.capacity <= limits.header);
        if (decoder.body) |body| try std.testing.expect(body.len <= limits.payload);
    }
    decoder.finish() catch {};
}

const corpus = [_][]const u8{
    @embedFile("fixtures/protocol/duplicate-length.frame"),
    @embedFile("fixtures/protocol/truncated-body.frame"),
    @embedFile("fixtures/protocol/oversized.frame"),
    @embedFile("fixtures/protocol/late-response.frame"),
};

test "retained framing regressions under every chunk size and allocation failure" {
    for (corpus) |bytes| {
        for (1..bytes.len + 1) |size| try exercise(std.testing.allocator, bytes, size);
        try std.testing.checkAllAllocationFailures(std.testing.allocator, exercise, .{ bytes, @as(usize, 1) });
    }
}

test "seeded malformed, fragmented, combined and cancelled stream stress" {
    var prng = std.Random.DefaultPrng.init(0x5a49542_020026);
    const random = prng.random();
    var bytes: [1024]u8 = undefined;
    for (0..10000) |iteration| {
        const length = random.uintLessThan(usize, bytes.len + 1);
        random.bytes(bytes[0..length]);
        try exercise(std.testing.allocator, bytes[0..length], random.intRangeAtMost(usize, 1, 129));
        const seed = corpus[iteration % corpus.len];
        @memcpy(bytes[0..seed.len], seed);
        if (iteration % 3 != 0) bytes[random.uintLessThan(usize, seed.len)] = random.int(u8);
        try exercise(std.testing.allocator, bytes[0..seed.len], random.intRangeAtMost(usize, 1, 33));
    }
    // A long valid stream proves combined messages do not accumulate in a queue.
    const payload = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}";
    const frame = try framing.encode(std.testing.allocator, payload, limits);
    defer std.testing.allocator.free(frame);
    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    for (0..4096) |_| try stream.appendSlice(std.testing.allocator, frame);
    try exercise(std.testing.allocator, stream.items, 7);
    try exercise(std.testing.allocator, stream.items, stream.items.len);
}

fn fuzzOne(_: void, smith: *std.testing.Smith) !void {
    var bytes: [2048]u8 = undefined;
    const count = smith.sliceWithHash(&bytes, 0x020026);
    try exercise(std.testing.allocator, bytes[0..count], 7);
}

test "coverage-guided framing and dispatch fuzz entry" {
    try std.testing.fuzz({}, fuzzOne, .{ .corpus = &corpus });
}
