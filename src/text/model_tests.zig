const std = @import("std");
const Reference = @import("reference.zig").Reference;
const PieceTable = @import("piece_table.zig").PieceTable;
const Edit = @import("semantics.zig").Edit;

fn equivalent(reference: *const Reference, table: *const PieceTable) !void {
    const copy = try table.snapshot(std.testing.allocator);
    defer std.testing.allocator.free(copy);
    try std.testing.expectEqualStrings(reference.bytes, copy);
    for (0..copy.len + 1) |offset| {
        const expected = reference.position(offset) catch |err| {
            try std.testing.expectError(err, table.position(offset));
            continue;
        };
        try std.testing.expectEqual(expected, try table.position(offset));
        try std.testing.expectEqual(offset, try table.offset(expected));
        try std.testing.expectEqual(offset, try reference.offset(expected));
    }
}

test "empty, mixed endings, multibyte, split CRLF and independent snapshots" {
    for ([_][]const u8{ "", "a\r\nb\rc\n", "é😀\r\n終", "last\n", "\r\r\n\n" }) |initial| {
        var reference = try Reference.init(std.testing.allocator, initial);
        defer reference.deinit();
        var table = try PieceTable.init(std.testing.allocator, initial);
        defer table.deinit();
        const old = try table.snapshot(std.testing.allocator);
        defer std.testing.allocator.free(old);
        try equivalent(&reference, &table);
        for ([_]Edit{
            .{ .start = 0, .end = 0, .inserted = "\r" },
            .{ .start = 1, .end = 1, .inserted = "\né" },
            .{ .start = 0, .end = 1, .inserted = "" },
        }) |edit| {
            try reference.edit(edit);
            try table.edit(edit);
            try equivalent(&reference, &table);
        }
        try std.testing.expectEqualStrings(initial, old);
        const replace: Edit = .{ .start = 0, .end = table.len(), .inserted = "" };
        try reference.edit(replace);
        try table.edit(replace);
        try equivalent(&reference, &table);
    }
}

test "invalid UTF-8 ranges boundaries positions fail without mutation" {
    try std.testing.expectError(error.InvalidUtf8, Reference.init(std.testing.allocator, "\xff"));
    try std.testing.expectError(error.InvalidUtf8, PieceTable.init(std.testing.allocator, "\xc0\xaf"));
    var reference = try Reference.init(std.testing.allocator, "é\r\n😀");
    defer reference.deinit();
    var table = try PieceTable.init(std.testing.allocator, reference.bytes);
    defer table.deinit();
    const cases = [_]struct { edit: Edit, err: anyerror }{
        .{ .edit = .{ .start = 3, .end = 2, .inserted = "" }, .err = error.InvalidRange },
        .{ .edit = .{ .start = 0, .end = 99, .inserted = "" }, .err = error.InvalidRange },
        .{ .edit = .{ .start = 1, .end = 2, .inserted = "x" }, .err = error.InvalidBoundary },
        .{ .edit = .{ .start = 0, .end = 5, .inserted = "" }, .err = error.InvalidBoundary },
        .{ .edit = .{ .start = 0, .end = 0, .inserted = "\xed\xa0\x80" }, .err = error.InvalidUtf8 },
    };
    for (cases) |case| {
        try std.testing.expectError(case.err, reference.edit(case.edit));
        try std.testing.expectError(case.err, table.edit(case.edit));
        try equivalent(&reference, &table);
    }
    for (0..4) |line| for (0..16) |column| {
        const pos: @import("semantics.zig").Position = .{ .line = line, .column = column };
        const expected = reference.offset(pos) catch |err| {
            try std.testing.expectError(err, table.offset(pos));
            continue;
        };
        try std.testing.expectEqual(expected, try table.offset(pos));
    };
    try std.testing.expectError(error.InvalidPosition, table.position(99));
    try std.testing.expectError(error.InvalidPosition, table.offset(.{ .line = 99, .column = 0 }));
    try std.testing.expectError(error.InvalidPosition, table.offset(.{ .line = 0, .column = std.math.maxInt(usize) }));
    try std.testing.expectError(error.InvalidBoundary, table.offset(.{ .line = 1, .column = 1 }));
    try std.testing.expectError(error.InvalidPosition, table.offset(.{ .line = 0, .column = 4 }));
}

fn allocationScenario(comptime Model: type) type {
    return struct {
        fn run(allocator: std.mem.Allocator) !void {
            var model = try Model.init(allocator, "a\r\nbé\r");
            defer model.deinit();
            model.edit(.{ .start = 1, .end = 4, .inserted = "😀\r\nx\n" }) catch |err| {
                try std.testing.expectEqual(@as(usize, 7), model.len());
                const unchanged = try model.snapshot(std.testing.allocator);
                defer std.testing.allocator.free(unchanged);
                try std.testing.expectEqualStrings("a\r\nbé\r", unchanged);
                const before = try model.position(4);
                try std.testing.expectEqual(@as(usize, 1), before.line);
                return err;
            };
            const snapshot = try model.snapshot(allocator);
            defer allocator.free(snapshot);
            try std.testing.expectEqualStrings("a😀\r\nx\né\r", snapshot);
        }
    };
}

test "all allocation failures preserve text and release owned resources" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationScenario(Reference).run, .{});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationScenario(PieceTable).run, .{});
}

test "long line lookup and coalescing of sequential appended pieces" {
    const initial = try std.testing.allocator.alloc(u8, 65536);
    defer std.testing.allocator.free(initial);
    @memset(initial, 'a');
    var table = try PieceTable.init(std.testing.allocator, initial);
    defer table.deinit();
    for (0..100) |_| try table.edit(.{ .start = table.len(), .end = table.len(), .inserted = "é" });
    try std.testing.expectEqual(@as(usize, 2), table.pieces.items.len);
    try std.testing.expectEqual(table.len(), try table.offset(.{ .line = 0, .column = table.len() }));
}
