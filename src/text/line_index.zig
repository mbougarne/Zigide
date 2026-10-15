//! Line starts, including an empty final line. CRLF remains one ending across pieces.
const std = @import("std");
const Storage = @import("storage.zig").Storage;
const semantics = @import("semantics.zig");

pub const LineIndex = struct {
    starts: std.ArrayList(usize) = .empty,
    pub fn deinit(self: *LineIndex, allocator: std.mem.Allocator) void {
        self.starts.deinit(allocator);
    }
    pub fn init(allocator: std.mem.Allocator, storage: *const Storage) !LineIndex {
        var result: LineIndex = .{};
        errdefer result.deinit(allocator);
        try result.starts.append(allocator, 0);
        try result.scan(allocator, storage, 0, storage.len());
        return result;
    }
    fn scan(self: *LineIndex, allocator: std.mem.Allocator, storage: *const Storage, start: usize, end: usize) !void {
        var at = start;
        var cr = false;
        var chunks = storage.chunks(start, end);
        while (chunks.next()) |bytes| for (bytes) |byte| {
            if (cr and byte != '\n') try self.starts.append(allocator, at);
            cr = byte == '\r';
            at += 1;
            if (byte == '\n') try self.starts.append(allocator, at);
        };
        if (cr) try self.starts.append(allocator, at);
    }
    pub fn lineAt(self: *const LineIndex, at: usize) usize {
        var low: usize = 0;
        var high = self.starts.items.len;
        while (low + 1 < high) {
            const mid = low + (high - low) / 2;
            if (self.starts.items[mid] <= at) low = mid else high = mid;
        }
        return low;
    }
    /// With no line-ending bytes touched (including either edge), only offsets
    /// change. This also keeps ordinary edits on a multi-megabyte line bounded.
    pub fn canShift(storage: *const Storage, edits: []const semantics.Edit) bool {
        for (edits) |e| {
            if (std.mem.indexOfAny(u8, e.inserted, "\r\n") != null) return false;
            const start = e.start -| 1;
            const end = @min(e.end +| 1, storage.len());
            var chunks = storage.chunks(start, end);
            while (chunks.next()) |bytes| {
                if (std.mem.indexOfAny(u8, bytes, "\r\n") != null) return false;
            }
        }
        return true;
    }
    pub fn shifted(self: *const LineIndex, allocator: std.mem.Allocator, edits: []const semantics.Edit) !LineIndex {
        var result: LineIndex = .{};
        errdefer result.deinit(allocator);
        try result.starts.ensureTotalCapacityPrecise(allocator, self.starts.items.len);
        var deleted: usize = 0;
        var inserted: usize = 0;
        var i: usize = 0;
        for (self.starts.items) |at| {
            while (i < edits.len and edits[i].end <= at) : (i += 1) {
                deleted += edits[i].end - edits[i].start;
                inserted += edits[i].inserted.len;
            }
            result.starts.appendAssumeCapacity(if (at == 0) 0 else at - deleted + inserted);
        }
        return result;
    }
    pub const Window = struct { start: usize, old_end: usize, new_end: usize };
    /// One unchanged byte at each edge isolates newly joined/split endings.
    /// Expand an edge inside CRLF so scans always see complete terminators.
    pub fn window(_: *const LineIndex, before: *const Storage, after: *const Storage, edits: []const semantics.Edit) Window {
        var start = edits[0].start -| 1;
        if (start > 0 and before.byteAt(start) == '\n' and before.byteAt(start - 1) == '\r') start -= 1;
        var old_end = @min(edits[edits.len - 1].end +| 1, before.len());
        if (old_end > 0 and old_end < before.len() and before.byteAt(old_end - 1) == '\r' and before.byteAt(old_end) == '\n') old_end += 1;
        return .{ .start = start, .old_end = old_end, .new_end = after.len() - (before.len() - old_end) };
    }
    pub fn updated(self: *const LineIndex, allocator: std.mem.Allocator, before: *const Storage, after: *const Storage, edits: []const semantics.Edit) !LineIndex {
        if (canShift(before, edits)) return self.shifted(allocator, edits);
        const span = self.window(before, after, edits);
        const first = self.lineAt(span.start);
        const suffix_line = self.lineAt(span.old_end) + 1;
        const start = span.start;
        const old_end = span.old_end;
        const new_end = span.new_end;
        var result: LineIndex = .{};
        errdefer result.deinit(allocator);
        try result.starts.appendSlice(allocator, self.starts.items[0 .. first + 1]);
        try result.scan(allocator, after, start, new_end);
        for (self.starts.items[suffix_line..]) |at| {
            if (at > old_end) try result.starts.append(allocator, after.len() - (before.len() - at));
        }
        return result;
    }
    pub fn position(self: *const LineIndex, storage: *const Storage, at: usize) semantics.Invalid!semantics.Position {
        if (at > storage.len()) return error.InvalidPosition;
        if (at < storage.len() and !semantics.boundary(storage.byteAt(at))) return error.InvalidBoundary;
        const line = self.lineAt(at);
        return .{ .line = line, .column = at - self.starts.items[line] };
    }
    pub fn offset(self: *const LineIndex, storage: *const Storage, position_value: semantics.Position) semantics.Invalid!usize {
        if (position_value.line >= self.starts.items.len) return error.InvalidPosition;
        const start = self.starts.items[position_value.line];
        const end = if (position_value.line + 1 < self.starts.items.len) self.starts.items[position_value.line + 1] - 1 else storage.len();
        if (position_value.column > end - start) return error.InvalidPosition;
        const at = start + position_value.column;
        if (at < storage.len() and !semantics.boundary(storage.byteAt(at))) return error.InvalidBoundary;
        return at;
    }
};
