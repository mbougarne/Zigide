//! Reproducible differential tests; failures emit the shortest failing prefix.
const std = @import("std");
const text = @import("text");
const snippets = [_][]const u8{ "", "a", "\r", "\n", "\r\n", "é", "😀", "終\r\na", "abcdef" };
const Operation = struct { start: usize, end: usize, snippet: usize };

fn compare(reference: *const text.Reference, table: *const text.PieceTable) !void {
    const snapshot = try table.snapshot(std.testing.allocator);
    defer std.testing.allocator.free(snapshot);
    try std.testing.expectEqualStrings(reference.bytes, snapshot);
    for (0..snapshot.len + 1) |at| {
        const expected = reference.position(at) catch |err| {
            try std.testing.expectError(err, table.position(at));
            continue;
        };
        try std.testing.expectEqual(expected, try table.position(at));
        try std.testing.expectEqual(at, try table.offset(expected));
        try std.testing.expectEqual(at, try reference.offset(expected));
    }
}
fn run(seed: u64, count: usize) !void {
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();
    var reference = try text.Reference.init(std.testing.allocator, "a\r\né😀\n");
    defer reference.deinit();
    var table = try text.PieceTable.init(std.testing.allocator, reference.bytes);
    defer table.deinit();
    var operations: std.ArrayList(Operation) = .empty;
    defer operations.deinit(std.testing.allocator);
    errdefer {
        std.debug.print("text equivalence seed=0x{x}; shortest failing prefix ({d} operations):\n", .{ seed, operations.items.len });
        for (operations.items) |op| std.debug.print("replace({d}, {d}, snippets[{d}])\n", .{ op.start, op.end, op.snippet });
    }
    for (0..count) |_| {
        var start = random.uintLessThan(usize, reference.len() + 1);
        var end = random.uintLessThan(usize, reference.len() + 1);
        while (start < reference.len() and reference.bytes[start] & 0xc0 == 0x80) start += 1;
        while (end < reference.len() and reference.bytes[end] & 0xc0 == 0x80) end += 1;
        if (start > end) std.mem.swap(usize, &start, &end);
        const snippet = random.uintLessThan(usize, snippets.len);
        try operations.append(std.testing.allocator, .{ .start = start, .end = end, .snippet = snippet });
        const edit: text.Edit = .{ .start = start, .end = end, .inserted = snippets[snippet] };
        try reference.edit(edit);
        try table.edit(edit);
        try compare(&reference, &table);
    }
}

test "32 seeds with 512 valid edits and all scalar positions after every edit" {
    for (0..32) |i| try run(0x5a4954027033 + i, 512);
}

fn fuzzOne(_: void, smith: *std.testing.Smith) !void {
    var bytes: [8]u8 = undefined;
    const length = smith.sliceWithHash(&bytes, 0x027033);
    var seed: u64 = 0;
    for (bytes[0..length]) |byte| seed = (seed << 8) | byte;
    try run(seed, 128);
}
test "coverage-guided edit-sequence fuzz entry" {
    try std.testing.fuzz({}, fuzzOne, .{ .corpus = &.{ "", "crlf", "utf8", "\x00\xff\x80" } });
}
