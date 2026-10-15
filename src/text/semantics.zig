const std = @import("std");
pub const Position = struct { line: usize, column: usize };
pub const Edit = struct { start: usize, end: usize, inserted: []const u8 };
pub const Invalid = error{ InvalidUtf8, InvalidRange, InvalidBoundary, InvalidPosition };
pub fn validateUtf8(bytes: []const u8) Invalid!void {
    if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidUtf8;
}
pub fn boundary(byte: u8) bool {
    return byte & 0xc0 != 0x80;
}

/// Normalized half-open byte offsets. Construction does not validate document bounds.
pub const Range = struct {
    start: usize,
    end: usize,
    pub fn normalized(a: usize, b: usize) Range {
        return .{ .start = @min(a, b), .end = @max(a, b) };
    }
    pub fn length(self: Range) Invalid!usize {
        if (self.start > self.end) return error.InvalidRange;
        return self.end - self.start;
    }
};

/// Lexicographic ordering, independent of UI or protocol encodings.
pub fn comparePositions(a: Position, b: Position) std.math.Order {
    const line_order = std.math.order(a.line, b.line);
    return if (line_order == .eq) std.math.order(a.column, b.column) else line_order;
}

test "ZIT-045 normalized byte ranges and position comparison" {
    try std.testing.expectEqual(Range{ .start = 2, .end = 8 }, Range.normalized(8, 2));
    try std.testing.expectEqual(@as(usize, 0), try Range.normalized(5, 5).length());
    try std.testing.expectError(error.InvalidRange, (Range{ .start = 4, .end = 3 }).length());
    try std.testing.expectEqual(std.math.Order.lt, comparePositions(.{ .line = 1, .column = 999 }, .{ .line = 2, .column = 0 }));
    try std.testing.expectEqual(std.math.Order.gt, comparePositions(.{ .line = 1, .column = 2 }, .{ .line = 1, .column = 1 }));
    try std.testing.expectEqual(std.math.Order.eq, comparePositions(.{ .line = 0, .column = 0 }, .{ .line = 0, .column = 0 }));
}
