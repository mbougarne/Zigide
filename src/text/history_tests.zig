const std = @import("std");
const Document = @import("document.zig").Document;
const h = @import("history.zig");
const Selection = h.Selection;
const a = std.testing.allocator;

fn expectBytes(model: *const Document, bytes: []const u8) !void {
    const actual = try model.copy(a);
    defer a.free(actual);
    try std.testing.expectEqualStrings(bytes, actual);
}
fn edit(history: *h.History, model: *Document, start: usize, end: usize, inserted: []const u8, kind: h.Kind) !void {
    try std.testing.expectEqual(h.Outcome.applied, try history.commit(model, .{ .version = model.version, .edits = &.{.{ .start = start, .end = end, .inserted = inserted }}, .command = .{ .kind = kind } }));
}
fn select(history: *h.History, model: *const Document, anchor: usize, active: usize) !void {
    try history.select(model, try Selection.init(model, .{ .anchor = anchor, .active = active }, model.version));
}

test "ZIT-058 empty forward reverse positions and stale scalar boundaries" {
    var model = try Document.init(a, "aé\r\n😀");
    defer model.deinit();
    var history = h.History.init(a, model.version, .{});
    defer history.deinit();
    try std.testing.expectEqual(@import("selection.zig").Direction.empty, history.selection.direction());
    try select(&history, &model, 1, 9);
    try std.testing.expectEqual(@import("selection.zig").Direction.forward, history.selection.direction());
    const forward = history.selection.range();
    try select(&history, &model, 9, 1);
    try std.testing.expectEqual(@import("selection.zig").Direction.reverse, history.selection.direction());
    try std.testing.expectEqual(forward, history.selection.range());
    const position = try Selection.fromPositions(&model, .{ .line = 1, .column = 4 }, .{ .line = 0, .column = 1 });
    try std.testing.expectEqual(history.selection, position);
    try std.testing.expectError(error.InvalidBoundary, Selection.init(&model, .{ .anchor = 2, .active = 3 }, 0));
    try std.testing.expectError(error.InvalidPosition, Selection.init(&model, .{ .anchor = 10, .active = 0 }, 0));
    const stale = history.selection;
    try edit(&history, &model, 0, 1, "x", .command);
    try std.testing.expectError(error.StaleSelection, history.select(&model, stale));
}

test "ZIT-058–061 multi-edit transaction transform exact undo redo metadata and selection" {
    var model = try Document.init(a, "\xef\xbb\xbfaé\r\nb\nlast");
    defer model.deinit();
    var history = h.History.init(a, model.version, .{});
    defer history.deinit();
    try select(&history, &model, model.len(), 3);
    const before = history.selection.endpoints();
    const metadata = model.metadata();
    _ = try history.commit(&model, .{ .version = 0, .edits = &.{ .{ .start = 8, .end = 9, .inserted = "😀" }, .{ .start = 3, .end = 4, .inserted = "A" }, .{ .start = 4, .end = 6, .inserted = "終" } }, .command = .{ .kind = .formatting, .id = "text.format" } });
    try expectBytes(&model, "\xef\xbb\xbfA終\r\n😀\nlast");
    const after = history.selection.endpoints();
    try std.testing.expectEqual(@as(usize, model.len()), after.anchor);
    try std.testing.expectEqual(@as(usize, 7), after.active);
    try std.testing.expectEqualStrings("text.format", history.current().?.command.id);
    try std.testing.expectEqual(h.Outcome.applied, try history.undo(&model));
    try expectBytes(&model, "\xef\xbb\xbfaé\r\nb\nlast");
    try std.testing.expectEqual(metadata, model.metadata());
    try std.testing.expectEqual(before, history.selection.endpoints());
    try std.testing.expectEqual(@as(u64, 2), model.version);
    try std.testing.expectEqual(h.Outcome.empty, try history.undo(&model));
    try std.testing.expectEqual(@as(u64, 2), model.version);
    try std.testing.expectEqual(h.Outcome.applied, try history.redo(&model));
    try expectBytes(&model, "\xef\xbb\xbfA終\r\n😀\nlast");
    try std.testing.expectEqual(after, history.selection.endpoints());
    try std.testing.expectEqual(h.Outcome.empty, try history.redo(&model));
    try history.selection.validate(&model);
}

test "ZIT-059 invalid after-selection and edits roll back entire state and redo" {
    var model = try Document.init(a, "é\r\n");
    defer model.deinit();
    var history = h.History.init(a, 0, .{});
    defer history.deinit();
    try edit(&history, &model, 0, 2, "😀", .command);
    _ = try history.undo(&model);
    const version = model.version;
    const selection = history.selection;
    const usage = history.usage;
    try std.testing.expectError(error.InvalidBoundary, history.commit(&model, .{ .version = version, .edits = &.{.{ .start = 0, .end = 2, .inserted = "😀" }}, .after = .{ .anchor = 1, .active = 4 } }));
    try std.testing.expectError(error.InvalidRange, history.commit(&model, .{ .version = version, .edits = &.{.{ .start = 0, .end = 99, .inserted = "" }} }));
    try std.testing.expectError(error.OverlappingEdits, history.commit(&model, .{ .version = version, .edits = &.{ .{ .start = 0, .end = 2, .inserted = "x" }, .{ .start = 0, .end = 0, .inserted = "y" } } }));
    try std.testing.expectError(error.InvalidUtf8, history.commit(&model, .{ .version = version, .edits = &.{.{ .start = 0, .end = 0, .inserted = "\xff" }} }));
    try std.testing.expectError(error.StaleSelection, history.commit(&model, .{ .version = 0, .edits = &.{} }));
    try expectBytes(&model, "é\r\n");
    try std.testing.expectEqual(version, model.version);
    try std.testing.expectEqual(selection, history.selection);
    try std.testing.expectEqual(usage, history.usage);
    try std.testing.expect(history.canRedo());
    try std.testing.expectEqual(h.Outcome.empty, try history.commit(&model, .{ .version = version, .edits = &.{} }));
    try std.testing.expect(history.canRedo());
    _ = try history.redo(&model);
    try expectBytes(&model, "😀\r\n");
}

test "ZIT-059 adjacent deletions and insertions normalize into reversible batches" {
    var model = try Document.init(a, "abcde");
    defer model.deinit();
    var history = h.History.init(a, 0, .{});
    defer history.deinit();
    _ = try history.commit(&model, .{ .version = 0, .edits = &.{ .{ .start = 0, .end = 1, .inserted = "" }, .{ .start = 1, .end = 2, .inserted = "" }, .{ .start = 2, .end = 2, .inserted = "X" }, .{ .start = 4, .end = 5, .inserted = "Z" } }, .after = .{ .anchor = 1, .active = 1 } });
    try expectBytes(&model, "XcdZ");
    _ = try history.undo(&model);
    try expectBytes(&model, "abcde");
    _ = try history.redo(&model);
    try expectBytes(&model, "XcdZ");
    try std.testing.expectEqual(@as(usize, 1), history.selection.active);
}

test "ZIT-061 new branches discard redo only after successful text commit" {
    var model = try Document.init(a, "");
    defer model.deinit();
    var history = h.History.init(a, 0, .{});
    defer history.deinit();
    try edit(&history, &model, 0, 0, "a", .command);
    try edit(&history, &model, 1, 1, "b", .command);
    _ = try history.undo(&model);
    try select(&history, &model, 0, 0);
    try std.testing.expect(history.canRedo());
    try edit(&history, &model, 0, 0, "c", .command);
    try std.testing.expect(!history.canRedo());
    try expectBytes(&model, "ca");
    _ = try history.undo(&model);
    try expectBytes(&model, "a");
    _ = try history.undo(&model);
    try expectBytes(&model, "");
}

test "ZIT-062 typing and both deletion directions coalesce without clocks" {
    var model = try Document.init(a, "");
    defer model.deinit();
    var history = h.History.init(a, 0, .{});
    defer history.deinit();
    try edit(&history, &model, 0, 0, "a", .typing);
    try edit(&history, &model, 1, 1, "é", .typing);
    try edit(&history, &model, 3, 3, "😀", .typing);
    try std.testing.expectEqual(@as(usize, 1), history.usage.entries);
    _ = try history.undo(&model);
    try expectBytes(&model, "");
    _ = try history.redo(&model);
    try expectBytes(&model, "aé😀");
    try edit(&history, &model, 3, 7, "", .backspace);
    try edit(&history, &model, 1, 3, "", .backspace);
    try edit(&history, &model, 0, 1, "", .backspace);
    try std.testing.expectEqual(@as(usize, 2), history.usage.entries);
    _ = try history.undo(&model);
    try expectBytes(&model, "aé😀");
    try std.testing.expectEqual(@as(usize, 7), history.selection.active);
    try select(&history, &model, 0, 0);
    try edit(&history, &model, 0, 1, "", .delete_forward);
    try edit(&history, &model, 0, 2, "", .delete_forward);
    try edit(&history, &model, 0, 4, "", .delete_forward);
    _ = try history.undo(&model);
    try expectBytes(&model, "aé😀");
    try std.testing.expectEqual(@as(usize, 0), history.selection.active);
}

test "ZIT-062 paste formatting cursor focus and explicit boundaries stay separate" {
    var model = try Document.init(a, "");
    defer model.deinit();
    var history = h.History.init(a, 0, .{});
    defer history.deinit();
    try edit(&history, &model, 0, 0, "a", .typing);
    history.boundary();
    try edit(&history, &model, 1, 1, "b", .typing);
    try select(&history, &model, 2, 2);
    try edit(&history, &model, 2, 2, "c", .typing);
    try edit(&history, &model, 3, 3, "paste", .paste);
    try edit(&history, &model, 8, 8, "!", .formatting);
    try edit(&history, &model, 9, 9, "\n", .typing);
    try edit(&history, &model, 10, 10, "d", .typing);
    try std.testing.expectEqual(@as(usize, 7), history.usage.entries);
    _ = try history.undo(&model);
    try expectBytes(&model, "abcpaste!\n");
    _ = try history.undo(&model);
    try expectBytes(&model, "abcpaste!");
}

test "ZIT-063 deterministic entry eviction preserves remaining undo and redo prefix" {
    var model = try Document.init(a, "");
    defer model.deinit();
    var history = h.History.init(a, 0, .{ .max_entries = 2 });
    defer history.deinit();
    try edit(&history, &model, 0, 0, "a", .command);
    try edit(&history, &model, 1, 1, "b", .command);
    try edit(&history, &model, 2, 2, "c", .command);
    try std.testing.expectEqual(@as(usize, 2), history.usage.entries);
    _ = try history.undo(&model);
    _ = try history.undo(&model);
    try expectBytes(&model, "a");
    try std.testing.expectEqual(h.Outcome.empty, try history.undo(&model));
    history.setLimits(.{ .max_entries = 1 });
    _ = try history.redo(&model);
    try expectBytes(&model, "ab");
    try std.testing.expectEqual(h.Outcome.empty, try history.redo(&model));
    history.clear();
    try std.testing.expectEqual(h.Usage{ .entries = 0, .bytes = 0 }, history.usage);
}

test "ZIT-063 byte limits and version exhaustion preserve text selection and stacks" {
    var model = try Document.init(a, "");
    defer model.deinit();
    var history = h.History.init(a, 0, .{});
    defer history.deinit();
    try edit(&history, &model, 0, 0, "a", .command);
    history.setLimits(.{ .max_bytes = history.usage.bytes });
    const large = try a.alloc(u8, history.usage.bytes);
    defer a.free(large);
    @memset(large, 'x');
    const version = model.version;
    try std.testing.expectError(error.HistoryLimitExceeded, history.commit(&model, .{ .version = version, .edits = &.{.{ .start = 1, .end = 1, .inserted = large }} }));
    try expectBytes(&model, "a");
    try std.testing.expectEqual(version, model.version);
    model.version = std.math.maxInt(u64);
    history.selection.version = model.version;
    try std.testing.expectError(error.Overflow, history.undo(&model));
    try std.testing.expect(history.canUndo());
    try std.testing.expect(!history.canRedo());
}

fn allocationTransactions(allocator: std.mem.Allocator) !void {
    var model = try Document.init(allocator, "é\r\n");
    defer model.deinit();
    var history = h.History.init(allocator, 0, .{});
    defer history.deinit();
    try select(&history, &model, 2, 2);
    _ = history.commit(&model, .{ .version = 0, .edits = &.{.{ .start = 2, .end = 2, .inserted = "a" }}, .command = .{ .kind = .typing } }) catch |err| {
        try expectBytes(&model, "é\r\n");
        try std.testing.expectEqual(@as(u64, 0), model.version);
        try std.testing.expectEqual(@as(usize, 0), history.usage.entries);
        return err;
    };
    const selection = history.selection;
    const usage = history.usage;
    _ = history.commit(&model, .{ .version = 1, .edits = &.{.{ .start = 3, .end = 3, .inserted = "😀" }}, .command = .{ .kind = .typing } }) catch |err| {
        try expectBytes(&model, "éa\r\n");
        try std.testing.expectEqual(selection, history.selection);
        try std.testing.expectEqual(usage, history.usage);
        return err;
    };
    _ = history.undo(&model) catch |err| {
        try expectBytes(&model, "éa😀\r\n");
        try std.testing.expect(history.canUndo());
        return err;
    };
    _ = history.redo(&model) catch |err| {
        try expectBytes(&model, "é\r\n");
        try std.testing.expect(history.canRedo());
        return err;
    };
    try expectBytes(&model, "éa😀\r\n");
    _ = try history.undo(&model);
    _ = history.commit(&model, .{ .version = model.version, .edits = &.{.{ .start = 2, .end = 2, .inserted = "branch" }} }) catch |err| {
        try expectBytes(&model, "é\r\n");
        try std.testing.expect(history.canRedo());
        return err;
    };
    try std.testing.expect(!history.canRedo());
}
test "ZIT-059–063 allocation failures are atomic for commit merge undo redo and branch" {
    try std.testing.checkAllAllocationFailures(a, allocationTransactions, .{});
}

test "ZIT-060 undo restores changed BOM line endings and final-newline metadata" {
    const original = "\xef\xbb\xbfaé\r\nb\nlast";
    var model = try Document.init(a, original);
    defer model.deinit();
    var history = h.History.init(a, 0, .{});
    defer history.deinit();
    const metadata = model.metadata();
    _ = try history.commit(&model, .{ .version = 0, .edits = &.{ .{ .start = 0, .end = 3, .inserted = "" }, .{ .start = 6, .end = 8, .inserted = "\n" }, .{ .start = model.len(), .end = model.len(), .inserted = "\n" } }, .command = .{ .kind = .formatting } });
    try std.testing.expect(!model.metadata().utf8_bom);
    try std.testing.expect(model.metadata().final_newline);
    try std.testing.expectEqual(@import("metadata.zig").Endings.lf, model.metadata().endings);
    const after_metadata = model.metadata();
    _ = try history.undo(&model);
    try expectBytes(&model, original);
    try std.testing.expectEqual(metadata, model.metadata());
    _ = try history.redo(&model);
    try std.testing.expectEqual(after_metadata, model.metadata());
}

test "ZIT-063 retained byte eviction and coalescence cap preserve remaining history" {
    var model = try Document.init(a, "");
    defer model.deinit();
    var history = h.History.init(a, 0, .{ .max_group_bytes = 1 });
    defer history.deinit();
    try edit(&history, &model, 0, 0, "a", .typing);
    const budget = history.usage.bytes;
    try edit(&history, &model, 1, 1, "b", .typing);
    try std.testing.expectEqual(@as(usize, 2), history.usage.entries);
    history.setLimits(.{ .max_bytes = budget, .max_group_bytes = 1 });
    try std.testing.expectEqual(@as(usize, 1), history.usage.entries);
    try edit(&history, &model, 2, 2, "c", .typing);
    try std.testing.expectEqual(@as(usize, 1), history.usage.entries);
    try std.testing.expectEqual(budget, history.usage.bytes);
    _ = try history.undo(&model);
    try expectBytes(&model, "ab");
    try std.testing.expectEqual(h.Outcome.empty, try history.undo(&model));
    _ = try history.redo(&model);
    try expectBytes(&model, "abc");
}

test "ZIT-060/063 owned inverse bytes survive storage compaction and history release" {
    var model = try Document.init(a, "é\r\n");
    defer model.deinit();
    var history = h.History.init(a, 0, .{});
    defer history.deinit();
    var original = try model.snapshot(a);
    defer original.deinit();
    const paste = try a.alloc(u8, 140 * 1024);
    defer a.free(paste);
    @memset(paste, 'x');
    try edit(&history, &model, 0, 0, paste, .paste);
    try edit(&history, &model, 0, paste.len, "", .command);
    try std.testing.expectEqual(@as(usize, 0), model.storage.added.items.len);
    _ = try history.undo(&model);
    try std.testing.expectEqual(paste.len + 4, model.len());
    _ = try history.undo(&model);
    try expectBytes(&model, original.bytes);
    _ = try history.redo(&model);
    _ = try history.redo(&model);
    history.clear();
    try expectBytes(&model, "é\r\n");
    try std.testing.expectEqualStrings("é\r\n", original.bytes);
    try std.testing.expectEqual(h.Usage{ .entries = 0, .bytes = 0 }, history.usage);
}
