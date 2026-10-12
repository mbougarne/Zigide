//! Deliberately simple independent oracle: owned contiguous UTF-8, scanning lookups.
const std = @import("std");
const semantics = @import("semantics.zig");
pub const Reference = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    pub fn init(allocator: std.mem.Allocator, bytes: []const u8) !Reference {
        try semantics.validateUtf8(bytes);
        return .{ .allocator = allocator, .bytes = try allocator.dupe(u8, bytes) };
    }
    pub fn deinit(self: *Reference) void {
        self.allocator.free(self.bytes);
    }
    pub fn len(self: *const Reference) usize {
        return self.bytes.len;
    }
    pub fn snapshot(self: *const Reference, allocator: std.mem.Allocator) ![]u8 {
        return allocator.dupe(u8, self.bytes);
    }
    pub fn edit(self: *Reference, e: semantics.Edit) !void {
        if (e.start > e.end or e.end > self.len()) return error.InvalidRange;
        for ([_]usize{ e.start, e.end }) |byte_offset| {
            if (byte_offset < self.len() and !semantics.boundary(self.bytes[byte_offset])) return error.InvalidBoundary;
        }
        try semantics.validateUtf8(e.inserted);
        const length = try std.math.add(usize, self.len() - (e.end - e.start), e.inserted.len);
        const next = try self.allocator.alloc(u8, length);
        @memcpy(next[0..e.start], self.bytes[0..e.start]);
        @memcpy(next[e.start..][0..e.inserted.len], e.inserted);
        @memcpy(next[e.start + e.inserted.len ..], self.bytes[e.end..]);
        self.allocator.free(self.bytes);
        self.bytes = next;
    }
    pub fn position(self: *const Reference, byte_offset: usize) semantics.Invalid!semantics.Position {
        if (byte_offset > self.len()) return error.InvalidPosition;
        if (byte_offset < self.len() and !semantics.boundary(self.bytes[byte_offset])) return error.InvalidBoundary;
        var line: usize = 0;
        var start: usize = 0;
        var i: usize = 0;
        while (i < byte_offset) {
            const byte = self.bytes[i];
            i += 1;
            if (byte == '\r' and i < self.len() and self.bytes[i] == '\n') {
                if (i == byte_offset) break;
                i += 1;
            }
            if (byte == '\r' or byte == '\n') {
                line += 1;
                start = i;
            }
        }
        return .{ .line = line, .column = byte_offset - start };
    }
    pub fn offset(self: *const Reference, pos: semantics.Position) semantics.Invalid!usize {
        var line: usize = 0;
        var start: usize = 0;
        var i: usize = 0;
        while (line < pos.line and i < self.len()) {
            const byte = self.bytes[i];
            i += 1;
            if (byte == '\r' and i < self.len() and self.bytes[i] == '\n') i += 1;
            if (byte == '\r' or byte == '\n') {
                line += 1;
                start = i;
            }
        }
        if (line != pos.line) return error.InvalidPosition;
        var end = self.len();
        i = start;
        while (i < self.len()) {
            const byte = self.bytes[i];
            i += 1;
            if (byte == '\r' and i < self.len() and self.bytes[i] == '\n') i += 1;
            if (byte == '\r' or byte == '\n') {
                end = i - 1;
                break;
            }
        }
        if (pos.column > end - start) return error.InvalidPosition;
        const result = start + pos.column;
        if (result < self.len() and !semantics.boundary(self.bytes[result])) return error.InvalidBoundary;
        return result;
    }
};
