//! Fixed regression seeds; failures report the seed and first failing prefix.
const std = @import("std");
const text = @import("text");
const snippets = [_][]const u8{ "", "a", "\r", "\n", "\r\n", "é", "😀", "終\r\na", "abcdef", "\xef\xbb\xbf" };
const Held = struct { snapshot: text.Snapshot, expected: []u8 };

fn compare(doc: *const text.Document, oracle: *const text.Reference) !void {
    const bytes = try doc.copy(std.testing.allocator);
    defer std.testing.allocator.free(bytes);
    errdefer std.debug.print("oracle={any}; actual={any}; starts={any}\n", .{ oracle.bytes, bytes, doc.lines.starts.items });
    try std.testing.expectEqualStrings(oracle.bytes, bytes);
    for (0..oracle.len() + 1) |at| {
        const expected = oracle.position(at) catch |err| {
            try std.testing.expectError(err, doc.position(at));
            continue;
        };
        try std.testing.expectEqual(expected, try doc.position(at));
        try std.testing.expectEqual(at, try doc.offset(expected));
    }
    const eof = try oracle.position(oracle.len());
    try std.testing.expectEqual(eof.line + 1, doc.lineCount());
    for (0..doc.lineCount() + 1) |line| for (0..oracle.len() + 2) |column| {
        const pos: text.Position = .{ .line = line, .column = column };
        const expected = oracle.offset(pos) catch |err| {
            try std.testing.expectError(err, doc.offset(pos));
            continue;
        };
        try std.testing.expectEqual(expected, try doc.offset(pos));
    };
    var lf: usize = 0;
    var crlf: usize = 0;
    var cr: usize = 0;
    var at: usize = 0;
    while (at < bytes.len) : (at += 1) {
        if (bytes[at] == '\r') {
            if (at + 1 < bytes.len and bytes[at + 1] == '\n') {
                crlf += 1;
                at += 1;
            } else cr += 1;
        } else if (bytes[at] == '\n') lf += 1;
    }
    const kinds = @as(u8, @intFromBool(lf > 0)) + @as(u8, @intFromBool(crlf > 0)) + @as(u8, @intFromBool(cr > 0));
    const endings: text.Endings = if (kinds > 1) .mixed else if (lf > 0) .lf else if (crlf > 0) .crlf else if (cr > 0) .cr else .none;
    try std.testing.expectEqual(endings, doc.metadata().endings);
    try std.testing.expectEqual(bytes.len > 0 and (bytes[bytes.len - 1] == '\r' or bytes[bytes.len - 1] == '\n'), doc.metadata().final_newline);
    try std.testing.expectEqual(std.mem.startsWith(u8, bytes, "\xef\xbb\xbf"), doc.metadata().utf8_bom);
}
fn run(seed: u64, count: usize) !void {
    var random = std.Random.DefaultPrng.init(seed);
    var doc = try text.Document.init(std.testing.allocator, "a\r\né😀\n");
    defer doc.deinit();
    var oracle = try text.Reference.init(std.testing.allocator, "a\r\né😀\n");
    defer oracle.deinit();
    var held: std.ArrayList(Held) = .empty;
    defer {
        for (held.items) |*item| {
            item.snapshot.deinit();
            std.testing.allocator.free(item.expected);
        }
        held.deinit(std.testing.allocator);
    }
    var step: usize = 0;
    var batch: [3]text.Edit = undefined;
    var size: usize = 0;
    errdefer {
        std.debug.print("production seed=0x{x}; first failing prefix={d}; final batch:\n", .{ seed, step + 1 });
        for (batch[0..size]) |e| std.debug.print("replace({d}, {d}, {any})\n", .{ e.start, e.end, e.inserted });
    }
    while (step < count) : (step += 1) {
        var points: [6]usize = undefined;
        for (&points) |*point| {
            point.* = random.random().uintLessThan(usize, oracle.len() + 1);
            while (point.* < oracle.len() and oracle.bytes[point.*] & 0xc0 == 0x80) point.* += 1;
        }
        std.mem.sort(usize, &points, {}, std.sort.asc(usize));
        size = 0;
        var changed = false;
        for (0..3) |i| {
            const start = points[i * 2];
            const end = points[i * 2 + 1];
            if (size > 0 and start == batch[size - 1].start) continue;
            const inserted = snippets[random.random().uintLessThan(usize, snippets.len)];
            batch[size] = .{ .start = start, .end = end, .inserted = inserted };
            size += 1;
            changed = changed or start != end or inserted.len > 0;
        }
        const version = doc.version;
        // Reverse order exercises original-coordinate application and sorting.
        std.mem.reverse(text.Edit, batch[0..size]);
        try doc.apply(batch[0..size]);
        for (batch[0..size]) |e| try oracle.edit(e);
        try std.testing.expectEqual(version + @intFromBool(changed), doc.version);
        try compare(&doc, &oracle);
        if (step % 31 == 0) {
            if (held.items.len == 4) {
                var old = held.orderedRemove(0);
                old.snapshot.deinit();
                std.testing.allocator.free(old.expected);
            }
            var snapshot = try doc.snapshot(std.testing.allocator);
            errdefer snapshot.deinit();
            const expected = try oracle.snapshot(std.testing.allocator);
            errdefer std.testing.allocator.free(expected);
            try held.append(std.testing.allocator, .{ .snapshot = snapshot, .expected = expected });
        }
        for (held.items) |item| {
            try std.testing.expectEqualStrings(item.expected, item.snapshot.bytes);
            try std.testing.expect(item.snapshot.version <= doc.version);
        }
        if (step % 17 == 0) {
            const before_version = doc.version;
            try std.testing.expectError(error.InvalidUtf8, doc.apply(&.{ .{ .start = 0, .end = 0, .inserted = "valid" }, .{ .start = doc.len(), .end = doc.len(), .inserted = "\xff" } }));
            try std.testing.expectError(error.InvalidRange, doc.edit(.{ .start = doc.len() + 1, .end = doc.len() + 1, .inserted = "" }));
            try std.testing.expectEqual(before_version, doc.version);
            try compare(&doc, &oracle);
        }
    }
}
test "ZIT-050 32 fixed seeds 512 atomic batches snapshots positions metadata" {
    for (0..32) |i| try run(0x5a4954044051 + i, 512);
}

test "ZIT-050 long lines fragmented storage and far separated batches" {
    const bytes = try std.testing.allocator.alloc(u8, 65536);
    defer std.testing.allocator.free(bytes);
    @memset(bytes, 'a');
    var doc = try text.Document.init(std.testing.allocator, bytes);
    defer doc.deinit();
    var oracle = try text.Reference.init(std.testing.allocator, bytes);
    defer oracle.deinit();
    for (0..256) |i| {
        const at = i * 128;
        const edits = [_]text.Edit{ .{ .start = at + 32768, .end = at + 32769, .inserted = "x" }, .{ .start = at, .end = at + 1, .inserted = "y" } };
        try doc.apply(&edits);
        for (edits) |e| try oracle.edit(e);
    }
    const copy = try doc.copy(std.testing.allocator);
    defer std.testing.allocator.free(copy);
    try std.testing.expectEqualStrings(oracle.bytes, copy);
    try std.testing.expectEqual(@as(usize, 1), doc.lineCount());
    try std.testing.expectEqual(@as(usize, 65536), try doc.offset(.{ .line = 0, .column = 65536 }));
    try std.testing.expectEqual(try oracle.position(32768), try doc.position(32768));
}

test "ZIT-050 regression seed 0x5a4954044051 prefix 26 retains earlier line starts" {
    var doc = try text.Document.init(std.testing.allocator, "\ra\nb\nc\n");
    defer doc.deinit();
    try doc.edit(.{ .start = 5, .end = 6, .inserted = "\r\n" });
    try std.testing.expectEqual(text.Position{ .line = 1, .column = 0 }, try doc.position(1));
    try std.testing.expectEqual(text.Position{ .line = 2, .column = 0 }, try doc.position(3));
}

test "ZIT-050 mixed line suffix updates after randomized insert and delete" {
    var initial: [2048]u8 = undefined;
    // Use whole patterns so UTF-8 is never truncated.
    const pattern = "a\r\nbé\rc\n";
    for (0..initial.len / pattern.len) |i| @memcpy(initial[i * pattern.len ..][0..pattern.len], pattern);
    var doc = try text.Document.init(std.testing.allocator, initial[0 .. initial.len / pattern.len * pattern.len]);
    defer doc.deinit();
    var oracle = try text.Reference.init(std.testing.allocator, initial[0 .. initial.len / pattern.len * pattern.len]);
    defer oracle.deinit();
    var prng = std.Random.DefaultPrng.init(0x044048049);
    for (0..128) |i| {
        var at = prng.random().uintLessThan(usize, oracle.len() + 1);
        while (at < oracle.len() and oracle.bytes[at] & 0xc0 == 0x80) at += 1;
        var end = @min(at + 1, oracle.len());
        while (end < oracle.len() and oracle.bytes[end] & 0xc0 == 0x80) end += 1;
        const edit: text.Edit = .{ .start = at, .end = end, .inserted = snippets[i % snippets.len] };
        try doc.edit(edit);
        try oracle.edit(edit);
        for (0..oracle.len() + 1) |offset| {
            const expected = oracle.position(offset) catch |err| {
                try std.testing.expectError(err, doc.position(offset));
                continue;
            };
            try std.testing.expectEqual(expected, try doc.position(offset));
            try std.testing.expectEqual(offset, try doc.offset(expected));
        }
        const counts = @import("std").mem.count(u8, oracle.bytes, "\n");
        try std.testing.expect(doc.lineCount() >= counts + 1);
    }
}
