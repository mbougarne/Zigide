//! Maintained workload definitions shared by measurement and evidence validation.
pub const samples = 31;
pub const edits = 1024;
pub const Fixture = struct { name: []const u8, size: usize, pattern: []const u8 };
pub const fixtures = [_]Fixture{
    .{ .name = "small", .size = 4096, .pattern = "const a = 123;\r\n" },
    .{ .name = "medium", .size = 256 * 1024, .pattern = "const a = 123;\r\n" },
    .{ .name = "large", .size = 4 * 1024 * 1024, .pattern = "const a = 123;\r\n" },
    .{ .name = "long-line", .size = 4 * 1024 * 1024, .pattern = "abcdefghijklmnop" },
    .{ .name = "utf8", .size = 256 * 1024, .pattern = "aé😀終\r\n" },
};
pub const Operation = enum { open, insert, delete, replace, snapshot, offset_to_position, position_to_offset, batch };
