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
