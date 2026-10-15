//! Versioned domain text. All coordinates in a batch refer to its starting version.
const std = @import("std");
const semantics = @import("semantics.zig");
const LineIndex = @import("line_index.zig").LineIndex;
const metadata_types = @import("metadata.zig");
const Storage = @import("storage.zig").Storage;

/// Owns an immutable copy using its own allocator. Transfer ownership to one
/// worker; concurrent readers are safe while the snapshot remains alive.
pub const Snapshot = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    metadata: metadata_types.Metadata,
    version: u64,
    pub fn deinit(self: *Snapshot) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const Document = struct {
    storage: Storage,
    lines: LineIndex,
    ending_counts: metadata_types.Counts,
    version: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, bytes: []const u8) !Document {
        var storage = try Storage.init(allocator, bytes);
        errdefer storage.deinit();
        return .{ .storage = storage, .lines = try LineIndex.init(allocator, &storage), .ending_counts = metadata_types.Counts.scan(&storage, 0, storage.len()) };
    }
    pub fn deinit(self: *Document) void {
        self.lines.deinit(self.storage.allocator);
        self.storage.deinit();
        self.* = undefined;
    }
    pub fn len(self: *const Document) usize {
        return self.storage.len();
    }
    pub fn position(self: *const Document, at: usize) semantics.Invalid!semantics.Position {
        return self.lines.position(&self.storage, at);
    }
    pub fn offset(self: *const Document, pos: semantics.Position) semantics.Invalid!usize {
        return self.lines.offset(&self.storage, pos);
    }
    pub fn metadata(self: *const Document) metadata_types.Metadata {
        return metadata_types.Metadata.from(&self.storage, self.ending_counts);
    }
    pub fn lineCount(self: *const Document) usize {
        return self.lines.starts.items.len;
    }
    pub fn read(self: *const Document, range: semantics.Range, output: []u8) !void {
        try self.storage.read(range.start, range.end, output);
    }
    pub fn copy(self: *const Document, allocator: std.mem.Allocator) ![]u8 {
        return self.storage.copy(allocator);
    }
    /// O(bytes + pieces), independent of document storage and lifetime.
    pub fn snapshot(self: *const Document, allocator: std.mem.Allocator) !Snapshot {
        return .{ .allocator = allocator, .bytes = try self.copy(allocator), .version = self.version, .metadata = self.metadata() };
    }
    fn lessThan(_: void, a: semantics.Edit, b: semantics.Edit) bool {
        return a.start < b.start;
    }
    /// Accepts arbitrary input order, rejects overlaps and coincident starts.
    /// Empty batches and empty insertions alone do not advance the version.
    pub fn apply(self: *Document, edits: []const semantics.Edit) !void {
        var changed = false;
        for (edits) |e| {
            try self.storage.validateRange(e.start, e.end);
            try semantics.validateUtf8(e.inserted);
            changed = changed or e.start != e.end or e.inserted.len != 0;
        }
        const allocator = self.storage.allocator;
        const sorted = try allocator.dupe(semantics.Edit, edits);
        defer allocator.free(sorted);
        std.mem.sort(semantics.Edit, sorted, {}, lessThan);
        for (sorted, 0..) |e, i| {
            if (i > 0 and (e.start < sorted[i - 1].end or e.start == sorted[i - 1].start)) return error.OverlappingEdits;
        }
        if (!changed) return;
        const next_version = try std.math.add(u64, self.version, 1);
        var pending = try self.storage.prepare(sorted);
        errdefer pending.deinit();
        try pending.compactIfNeeded();
        const view = pending.view();
        const lines = try self.lines.updated(allocator, &self.storage, &view, sorted);
        var counts = self.ending_counts;
        if (!LineIndex.canShift(&self.storage, sorted)) {
            const span = self.lines.window(&self.storage, &view, sorted);
            const removed = metadata_types.Counts.scan(&self.storage, span.start, span.old_end);
            const inserted = metadata_types.Counts.scan(&view, span.start, span.new_end);
            counts = .{
                .lf = counts.lf - removed.lf + inserted.lf,
                .crlf = counts.crlf - removed.crlf + inserted.crlf,
                .cr = counts.cr - removed.cr + inserted.cr,
            };
        }
        self.lines.deinit(allocator);
        pending.commit();
        self.lines = lines;
        self.ending_counts = counts;
        self.version = next_version;
    }
    pub fn edit(self: *Document, edit_value: semantics.Edit) !void {
        try self.apply(&.{edit_value});
    }
};

test "ZIT-046 atomic unordered batches one version and invalid rollback" {
    var doc = try Document.init(std.testing.allocator, "abcé\r\nxyz");
    defer doc.deinit();
    try doc.apply(&.{ .{ .start = 8, .end = 9, .inserted = "!" }, .{ .start = 0, .end = 1, .inserted = "AA" } });
    const bytes = try doc.copy(std.testing.allocator);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("AAbcé\r\nx!z", bytes);
    try std.testing.expectEqual(@as(u64, 1), doc.version);
    try std.testing.expectError(error.OverlappingEdits, doc.apply(&.{ .{ .start = 1, .end = 3, .inserted = "" }, .{ .start = 2, .end = 2, .inserted = "x" } }));
    try std.testing.expectError(error.OverlappingEdits, doc.apply(&.{ .{ .start = 0, .end = 0, .inserted = "x" }, .{ .start = 0, .end = 0, .inserted = "y" } }));
    try std.testing.expectError(error.InvalidUtf8, doc.apply(&.{ .{ .start = 0, .end = 0, .inserted = "valid" }, .{ .start = 2, .end = 2, .inserted = "\xff" } }));
    try std.testing.expectError(error.InvalidBoundary, doc.edit(.{ .start = 5, .end = 5, .inserted = "x" }));
    try doc.apply(&.{});
    try doc.edit(.{ .start = 0, .end = 0, .inserted = "" });
    const unchanged = try doc.copy(std.testing.allocator);
    defer std.testing.allocator.free(unchanged);
    try std.testing.expectEqualStrings(bytes, unchanged);
    try std.testing.expectEqual(@as(u64, 1), doc.version);
    doc.version = std.math.maxInt(u64);
    try std.testing.expectError(error.Overflow, doc.edit(.{ .start = 0, .end = 1, .inserted = "x" }));
}

fn allocationBatch(allocator: std.mem.Allocator) !void {
    var doc = try Document.init(allocator, "aé\r\nb");
    defer doc.deinit();
    doc.apply(&.{ .{ .start = 0, .end = 1, .inserted = "xyz" }, .{ .start = 3, .end = 5, .inserted = "\n" } }) catch |err| {
        const bytes = try doc.copy(std.testing.allocator);
        defer std.testing.allocator.free(bytes);
        try std.testing.expectEqualStrings("aé\r\nb", bytes);
        try std.testing.expectEqual(@as(u64, 0), doc.version);
        try std.testing.expectEqual(semantics.Position{ .line = 1, .column = 0 }, try doc.position(5));
        try std.testing.expectEqual(metadata_types.Endings.crlf, doc.metadata().endings);
        return err;
    };
    try std.testing.expectEqual(@as(u64, 1), doc.version);
}
test "ZIT-046 batch allocation failure is atomic" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationBatch, .{});
}

fn snapshotFailure(allocator: std.mem.Allocator) !void {
    var doc = try Document.init(std.testing.allocator, "é\r\n");
    defer doc.deinit();
    var old = try doc.snapshot(allocator);
    defer old.deinit();
    try doc.edit(.{ .start = 0, .end = 2, .inserted = "changed" });
    try std.testing.expectEqualStrings("é\r\n", old.bytes);
    try std.testing.expectEqual(@as(u64, 0), old.version);
    var newer = try doc.snapshot(allocator);
    defer newer.deinit();
    try std.testing.expectEqual(@as(u64, 1), newer.version);
}
test "ZIT-047 snapshots survive edits release and document destruction" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, snapshotFailure, .{});
    var doc = try Document.init(std.testing.allocator, "original");
    var snapshot = try doc.snapshot(std.testing.allocator);
    doc.deinit();
    try std.testing.expectEqualStrings("original", snapshot.bytes);
    snapshot.deinit();
    var active = try Document.init(std.testing.allocator, "active");
    defer active.deinit();
    var released = try active.snapshot(std.testing.allocator);
    released.deinit();
    try active.edit(.{ .start = 0, .end = 6, .inserted = "still active" });
}

test "ZIT-048 index matches oracle through CRLF splits and mixed endings" {
    const Reference = @import("reference.zig").Reference;
    for ([_][]const u8{ "", "a\r\nb\rc\n", "é😀\r\n終", "last\n", "\r\r\n\n" }) |initial| {
        var doc = try Document.init(std.testing.allocator, initial);
        defer doc.deinit();
        var oracle = try Reference.init(std.testing.allocator, initial);
        defer oracle.deinit();
        for ([_]semantics.Edit{
            .{ .start = 0, .end = 0, .inserted = "\r" },
            .{ .start = 1, .end = 1, .inserted = "\né" },
            .{ .start = 0, .end = 1, .inserted = "" },
        }) |e| {
            try doc.edit(e);
            try oracle.edit(e);
            for (0..oracle.len() + 1) |at| {
                const expected = oracle.position(at) catch |err| {
                    try std.testing.expectError(err, doc.position(at));
                    continue;
                };
                try std.testing.expectEqual(expected, try doc.position(at));
                try std.testing.expectEqual(at, try doc.offset(expected));
            }
            for (0..doc.lineCount() + 1) |line| for (0..oracle.len() + 2) |column| {
                const pos: semantics.Position = .{ .line = line, .column = column };
                const expected = oracle.offset(pos) catch |err| {
                    try std.testing.expectError(err, doc.offset(pos));
                    continue;
                };
                try std.testing.expectEqual(expected, try doc.offset(pos));
            };
        }
        try std.testing.expectError(error.InvalidPosition, doc.offset(.{ .line = 0, .column = std.math.maxInt(usize) }));
        try std.testing.expectError(error.InvalidPosition, doc.position(std.math.maxInt(usize)));
    }
}

test "ZIT-049 preserve endings final newline BOM and reject invalid UTF-8" {
    const forms = [_]metadata_types.Endings{ .none, .lf, .crlf, .cr, .mixed, .mixed };
    const fixtures = [_][]const u8{ "é", "a\n", "a\r\n", "a\r", "a\r\nb\nlast", "\r\r\n\n" };
    for (fixtures, forms) |initial, form| {
        var doc = try Document.init(std.testing.allocator, initial);
        defer doc.deinit();
        try std.testing.expectEqual(form, doc.metadata().endings);
        try std.testing.expectEqual(initial[initial.len - 1] == '\n' or initial[initial.len - 1] == '\r', doc.metadata().final_newline);
        var snapshot = try doc.snapshot(std.testing.allocator);
        defer snapshot.deinit();
        try std.testing.expectEqualStrings(initial, snapshot.bytes);
        try doc.edit(.{ .start = doc.len(), .end = doc.len(), .inserted = "x" });
        try std.testing.expect(!doc.metadata().final_newline);
        try std.testing.expectEqual(form, doc.metadata().endings);
        const before = doc.metadata();
        try std.testing.expectError(error.InvalidUtf8, doc.edit(.{ .start = 0, .end = 0, .inserted = "\xff" }));
        try std.testing.expectEqual(before, doc.metadata());
    }
    try std.testing.expectError(error.InvalidUtf8, Document.init(std.testing.allocator, "\xed\xa0\x80"));
    var bom = try Document.init(std.testing.allocator, "\xef\xbb\xbftext");
    defer bom.deinit();
    try std.testing.expect(bom.metadata().utf8_bom);
    try bom.edit(.{ .start = 0, .end = 3, .inserted = "" });
    try std.testing.expect(!bom.metadata().utf8_bom);
}

fn compactFailure(allocator: std.mem.Allocator) !void {
    var doc = try Document.init(allocator, "é\r\n");
    defer doc.deinit();
    var old = try doc.snapshot(std.testing.allocator);
    defer old.deinit();
    // A large paste followed by deletion exercises compaction immediately.
    const paste = try std.testing.allocator.alloc(u8, 140 * 1024);
    defer std.testing.allocator.free(paste);
    @memset(paste, 'x');
    try doc.edit(.{ .start = 0, .end = 0, .inserted = paste });
    doc.edit(.{ .start = 0, .end = paste.len, .inserted = "" }) catch |err| {
        try std.testing.expectEqual(@as(u64, 1), doc.version);
        try std.testing.expectEqual(@as(usize, paste.len + 4), doc.len());
        const unchanged = try doc.copy(std.testing.allocator);
        defer std.testing.allocator.free(unchanged);
        try std.testing.expectEqualSlices(u8, paste, unchanged[0..paste.len]);
        try std.testing.expectEqualStrings("é\r\n", unchanged[paste.len..]);
        try std.testing.expectEqual(@as(usize, 2), doc.lineCount());
        try std.testing.expectEqual(metadata_types.Endings.crlf, doc.metadata().endings);
        try std.testing.expectEqualStrings("é\r\n", old.bytes);
        return err;
    };
    try std.testing.expectEqual(@as(usize, 0), doc.storage.added.items.len);
    try std.testing.expectEqual(@as(u64, 2), doc.version);
    const bytes = try doc.copy(std.testing.allocator);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("é\r\n", bytes);
    try std.testing.expectEqualStrings("é\r\n", old.bytes);
}
test "ZIT-051 dead add history compacts atomically including every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, compactFailure, .{});
}

test "ZIT-046 adjacent edits and owned snapshot insertions use original coordinates" {
    var doc = try Document.init(std.testing.allocator, "abc");
    defer doc.deinit();
    var source = try doc.snapshot(std.testing.allocator);
    defer source.deinit();
    try doc.apply(&.{ .{ .start = 1, .end = 2, .inserted = "Y" }, .{ .start = 2, .end = 2, .inserted = source.bytes }, .{ .start = 0, .end = 1, .inserted = "X" } });
    const bytes = try doc.copy(std.testing.allocator);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("XYabcc", bytes);
    try std.testing.expectEqual(@as(u64, 1), doc.version);
}
