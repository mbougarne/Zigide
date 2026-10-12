//! Flat piece-table candidate. Owns buffers, piece descriptors and line starts.
const std = @import("std");
const semantics = @import("semantics.zig");
const Source = enum { original, added };
const Piece = struct { source: Source, start: usize, len: usize };
pub const PieceTable = struct {
    allocator: std.mem.Allocator,
    original: []u8,
    added: std.ArrayList(u8) = .empty,
    pieces: std.ArrayList(Piece) = .empty,
    lines: std.ArrayList(usize) = .empty,
    length: usize,
    pub fn init(allocator: std.mem.Allocator, bytes: []const u8) !PieceTable {
        try semantics.validateUtf8(bytes);
        var self: PieceTable = .{ .allocator = allocator, .original = try allocator.dupe(u8, bytes), .length = bytes.len };
        errdefer self.deinit();
        if (bytes.len != 0) try self.pieces.append(allocator, .{ .source = .original, .start = 0, .len = bytes.len });
        self.lines = try self.index(self.pieces.items);
        return self;
    }
    pub fn deinit(self: *PieceTable) void {
        self.allocator.free(self.original);
        self.added.deinit(self.allocator);
        self.pieces.deinit(self.allocator);
        self.lines.deinit(self.allocator);
    }
    pub fn len(self: *const PieceTable) usize {
        return self.length;
    }
    fn slice(self: *const PieceTable, piece: Piece) []const u8 {
        const buffer = switch (piece.source) {
            .original => self.original,
            .added => self.added.items,
        };
        return buffer[piece.start..][0..piece.len];
    }
    fn byteAt(self: *const PieceTable, byte_offset: usize) u8 {
        var remaining = byte_offset;
        for (self.pieces.items) |piece| {
            if (remaining < piece.len) return self.slice(piece)[remaining];
            remaining -= piece.len;
        }
        unreachable;
    }
    pub fn snapshot(self: *const PieceTable, allocator: std.mem.Allocator) ![]u8 {
        const result = try allocator.alloc(u8, self.len());
        var at: usize = 0;
        for (self.pieces.items) |piece| {
            @memcpy(result[at..][0..piece.len], self.slice(piece));
            at += piece.len;
        }
        return result;
    }
    fn append(self: *const PieceTable, list: *std.ArrayList(Piece), piece: Piece) !void {
        if (piece.len == 0) return;
        if (list.items.len > 0) {
            const last = &list.items[list.items.len - 1];
            if (last.source == piece.source and last.start + last.len == piece.start) {
                last.len += piece.len;
                return;
            }
        }
        try list.append(self.allocator, piece);
    }
    fn range(self: *const PieceTable, list: *std.ArrayList(Piece), start: usize, end: usize) !void {
        var at: usize = 0;
        for (self.pieces.items) |piece| {
            const left = @max(at, start);
            const right = @min(at + piece.len, end);
            if (left < right) try self.append(list, .{ .source = piece.source, .start = piece.start + left - at, .len = right - left });
            at += piece.len;
            if (at >= end) break;
        }
    }
    fn index(self: *const PieceTable, pieces: []const Piece) !std.ArrayList(usize) {
        var result: std.ArrayList(usize) = .empty;
        errdefer result.deinit(self.allocator);
        try result.append(self.allocator, 0);
        var at: usize = 0;
        var cr = false;
        for (pieces) |piece| for (self.slice(piece)) |byte| {
            if (cr) {
                if (byte != '\n') try result.append(self.allocator, at);
                cr = false;
            }
            at += 1;
            if (byte == '\n') try result.append(self.allocator, at);
            if (byte == '\r') cr = true;
        };
        if (cr) try result.append(self.allocator, at);
        return result;
    }
    pub fn edit(self: *PieceTable, e: semantics.Edit) !void {
        if (e.start > e.end or e.end > self.len()) return error.InvalidRange;
        for ([_]usize{ e.start, e.end }) |byte_offset| {
            if (byte_offset < self.len() and !semantics.boundary(self.byteAt(byte_offset))) return error.InvalidBoundary;
        }
        try semantics.validateUtf8(e.inserted);
        const length = try std.math.add(usize, self.len() - (e.end - e.start), e.inserted.len);
        if (e.start == e.end and e.inserted.len == 0) return;
        const added_start = self.added.items.len;
        try self.added.appendSlice(self.allocator, e.inserted);
        errdefer self.added.shrinkRetainingCapacity(added_start);
        var next: std.ArrayList(Piece) = .empty;
        errdefer next.deinit(self.allocator);
        try self.range(&next, 0, e.start);
        try self.append(&next, .{ .source = .added, .start = added_start, .len = e.inserted.len });
        try self.range(&next, e.end, self.len());
        const lines = try self.index(next.items);
        self.pieces.deinit(self.allocator);
        self.lines.deinit(self.allocator);
        self.pieces = next;
        self.lines = lines;
        self.length = length;
    }
    pub fn position(self: *const PieceTable, offset_value: usize) semantics.Invalid!semantics.Position {
        if (offset_value > self.len()) return error.InvalidPosition;
        if (offset_value < self.len() and !semantics.boundary(self.byteAt(offset_value))) return error.InvalidBoundary;
        var low: usize = 0;
        var high = self.lines.items.len;
        while (low + 1 < high) {
            const middle = low + (high - low) / 2;
            if (self.lines.items[middle] <= offset_value) low = middle else high = middle;
        }
        return .{ .line = low, .column = offset_value - self.lines.items[low] };
    }
    pub fn offset(self: *const PieceTable, pos: semantics.Position) semantics.Invalid!usize {
        if (pos.line >= self.lines.items.len) return error.InvalidPosition;
        const start = self.lines.items[pos.line];
        const end = if (pos.line + 1 < self.lines.items.len) self.lines.items[pos.line + 1] - 1 else self.len();
        if (pos.column > end - start) return error.InvalidPosition;
        const result = start + pos.column;
        if (result < self.len() and !semantics.boundary(self.byteAt(result))) return error.InvalidBoundary;
        return result;
    }
};
