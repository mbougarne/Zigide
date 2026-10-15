//! Owned production piece storage. Mutable only on the application thread.
const std = @import("std");
const semantics = @import("semantics.zig");
const Source = enum { original, added };
const Piece = struct { source: Source, start: usize, len: usize, end: usize };

pub const Storage = struct {
    allocator: std.mem.Allocator,
    original: []u8,
    added: std.ArrayList(u8) = .empty,
    pieces: std.ArrayList(Piece) = .empty,
    length: usize,

    pub fn init(allocator: std.mem.Allocator, bytes: []const u8) !Storage {
        try semantics.validateUtf8(bytes);
        var self: Storage = .{ .allocator = allocator, .original = try allocator.dupe(u8, bytes), .length = bytes.len };
        errdefer self.deinit();
        if (bytes.len > 0) try self.pieces.append(allocator, .{ .source = .original, .start = 0, .len = bytes.len, .end = bytes.len });
        return self;
    }
    pub fn deinit(self: *Storage) void {
        self.allocator.free(self.original);
        self.added.deinit(self.allocator);
        self.pieces.deinit(self.allocator);
        self.* = undefined;
    }
    pub fn len(self: *const Storage) usize {
        return self.length;
    }
    fn slice(self: *const Storage, piece: Piece) []const u8 {
        const buffer = switch (piece.source) {
            .original => self.original,
            .added => self.added.items,
        };
        return buffer[piece.start..][0..piece.len];
    }
    fn locate(self: *const Storage, at: usize) usize {
        var low: usize = 0;
        var high = self.pieces.items.len;
        while (low < high) {
            const mid = low + (high - low) / 2;
            if (self.pieces.items[mid].end <= at) low = mid + 1 else high = mid;
        }
        return low;
    }
    /// Caller validates at < len first. Binary search bounds fragmented lookups.
    pub fn byteAt(self: *const Storage, at: usize) u8 {
        const piece = self.pieces.items[self.locate(at)];
        return self.slice(piece)[at - (piece.end - piece.len)];
    }
    pub fn validateRange(self: *const Storage, start: usize, end: usize) semantics.Invalid!void {
        if (start > end or end > self.len()) return error.InvalidRange;
        for ([_]usize{ start, end }) |at| {
            if (at < self.len() and !semantics.boundary(self.byteAt(at))) return error.InvalidBoundary;
        }
    }
    /// Copies a validated byte range into an exactly sized caller-owned buffer.
    pub fn read(self: *const Storage, start: usize, end: usize, output: []u8) !void {
        try self.validateRange(start, end);
        if (output.len != end - start) return error.InvalidOutputLength;
        var at = start;
        var written: usize = 0;
        var i = self.locate(start);
        while (at < end) : (i += 1) {
            const piece = self.pieces.items[i];
            const offset = at - (piece.end - piece.len);
            const size = @min(end - at, piece.len - offset);
            @memcpy(output[written..][0..size], self.slice(piece)[offset..][0..size]);
            at += size;
            written += size;
        }
    }
    pub const Chunks = struct {
        storage: *const Storage,
        at: usize,
        end: usize,
        piece: usize,
        pub fn next(self: *Chunks) ?[]const u8 {
            if (self.at == self.end) return null;
            const piece = self.storage.pieces.items[self.piece];
            const offset = self.at - (piece.end - piece.len);
            const size = @min(self.end - self.at, piece.len - offset);
            self.at += size;
            self.piece += 1;
            return self.storage.slice(piece)[offset..][0..size];
        }
    };
    /// Internal validated range iterator. The storage must outlive the iterator.
    pub fn chunks(self: *const Storage, start: usize, end: usize) Chunks {
        return .{ .storage = self, .at = start, .end = end, .piece = self.locate(start) };
    }
    pub fn copy(self: *const Storage, allocator: std.mem.Allocator) ![]u8 {
        const result = try allocator.alloc(u8, self.len());
        errdefer allocator.free(result);
        try self.read(0, self.len(), result);
        return result;
    }
    fn append(self: *const Storage, list: *std.ArrayList(Piece), source: Source, start: usize, size: usize) !void {
        if (size == 0) return;
        const previous_end = if (list.items.len > 0) list.items[list.items.len - 1].end else 0;
        if (list.items.len > 0) {
            const last = &list.items[list.items.len - 1];
            if (last.source == source and last.start + last.len == start) {
                last.len += size;
                last.end += size;
                return;
            }
        }
        try list.append(self.allocator, .{ .source = source, .start = start, .len = size, .end = previous_end + size });
    }
    fn appendRange(self: *const Storage, list: *std.ArrayList(Piece), start: usize, end: usize) !void {
        var at = start;
        var i = self.locate(start);
        while (at < end) : (i += 1) {
            const piece = self.pieces.items[i];
            const offset = at - (piece.end - piece.len);
            const size = @min(end - at, piece.len - offset);
            try self.append(list, piece.source, piece.start + offset, size);
            at += size;
        }
    }
    /// A prepared mutation borrows its owner until commit or deinit. Exactly one
    /// may exist at a time; callers must not access/mutate the owner meanwhile.
    pub const Pending = struct {
        owner: *Storage,
        pieces: std.ArrayList(Piece),
        length: usize,
        added_start: usize,
        compacted: ?Storage = null,
        pub fn view(self: *const Pending) Storage {
            if (self.compacted) |storage| return storage;
            var result = self.owner.*;
            result.pieces = self.pieces;
            result.length = self.length;
            return result;
        }
        pub fn deinit(self: *Pending) void {
            if (self.compacted) |*storage| storage.deinit();
            self.owner.added.shrinkRetainingCapacity(self.added_start);
            self.pieces.deinit(self.owner.allocator);
            self.* = undefined;
        }
        /// Bound dead insertion history. Compaction remains part of the pending
        /// transaction, so allocation failure cannot publish a partial edit.
        pub fn compactIfNeeded(self: *Pending) !void {
            if (self.owner.added.items.len <= @max(self.length, 64 * 1024) *| 2) return;
            const allocator = self.owner.allocator;
            const candidate = self.view();
            var compacted: Storage = .{ .allocator = allocator, .original = try candidate.copy(allocator), .length = self.length };
            errdefer compacted.deinit();
            if (self.length > 0) try compacted.pieces.append(allocator, .{ .source = .original, .start = 0, .len = self.length, .end = self.length });
            self.compacted = compacted;
        }
        pub fn commit(self: *Pending) void {
            if (self.compacted) |storage| {
                const allocator = self.owner.allocator;
                self.owner.deinit();
                self.owner.* = storage;
                self.pieces.deinit(allocator);
                self.* = undefined;
                return;
            }
            self.owner.pieces.deinit(self.owner.allocator);
            self.owner.pieces = self.pieces;
            self.owner.length = self.length;
            self.* = undefined;
        }
    };
    /// Edits must already be validated, sorted and disjoint in original coordinates.
    pub fn prepare(self: *Storage, edits: []const semantics.Edit) !Pending {
        var length = self.len();
        var inserted: usize = 0;
        for (edits) |e| {
            length -= e.end - e.start;
            length = try std.math.add(usize, length, e.inserted.len);
            inserted = try std.math.add(usize, inserted, e.inserted.len);
        }
        const added_start = self.added.items.len;
        try self.added.ensureUnusedCapacity(self.allocator, inserted);
        errdefer self.added.shrinkRetainingCapacity(added_start);
        var next: std.ArrayList(Piece) = .empty;
        errdefer next.deinit(self.allocator);
        var at: usize = 0;
        for (edits) |e| {
            try self.appendRange(&next, at, e.start);
            const start = self.added.items.len;
            self.added.appendSliceAssumeCapacity(e.inserted);
            try self.append(&next, .added, start, e.inserted.len);
            at = e.end;
        }
        try self.appendRange(&next, at, self.len());
        return .{ .owner = self, .pieces = next, .length = length, .added_start = added_start };
    }
    pub fn edit(self: *Storage, edit_value: semantics.Edit) !void {
        try self.validateRange(edit_value.start, edit_value.end);
        try semantics.validateUtf8(edit_value.inserted);
        if (edit_value.start == edit_value.end and edit_value.inserted.len == 0) return;
        var pending = try self.prepare(&.{edit_value});
        pending.commit();
    }
};

test "ZIT-044 owned storage insert delete replace read and allocation failures" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            var model = try Storage.init(allocator, "aé\r\nb");
            defer model.deinit();
            model.edit(.{ .start = 1, .end = 3, .inserted = "😀" }) catch |err| {
                const unchanged = try model.copy(std.testing.allocator);
                defer std.testing.allocator.free(unchanged);
                try std.testing.expectEqualStrings("aé\r\nb", unchanged);
                return err;
            };
            try model.edit(.{ .start = 0, .end = 0, .inserted = "x" });
            try model.edit(.{ .start = 1, .end = 2, .inserted = "" });
            const bytes = try model.copy(allocator);
            defer allocator.free(bytes);
            try std.testing.expectEqualStrings("x😀\r\nb", bytes);
            var output: [4]u8 = undefined;
            try model.read(1, 5, &output);
            try std.testing.expectEqualStrings("😀", &output);
            try std.testing.expectError(error.InvalidBoundary, model.read(2, 5, &output));
            try std.testing.expectError(error.InvalidRange, model.read(0, 99, &output));
            try std.testing.expectError(error.InvalidOutputLength, model.read(1, 1, &output));
        }
    }.run, .{});
}
