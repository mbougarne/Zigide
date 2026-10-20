//! Independent contiguous-string oracle, retaining full states only in tests.
const std = @import("std");
const text = @import("text");
const a = std.testing.allocator;
const Endpoints = text.SelectionEndpoints;
const State = struct {
    before: []u8,
    after: []u8,
    before_selection: Endpoints,
    after_selection: Endpoints,
    fn deinit(self: State) void {
        a.free(self.before);
        a.free(self.after);
    }
};
fn boundary(bytes: []const u8, random: std.Random) usize {
    var at = random.intRangeAtMost(usize, 0, bytes.len);
    while (at < bytes.len and bytes[at] & 0xc0 == 0x80) at -= 1;
    return at;
}
fn transformed(at: usize, edit: text.Edit) usize {
    if (at < edit.start) return at;
    if (at <= edit.end) return edit.start + edit.inserted.len;
    return at - (edit.end - edit.start) + edit.inserted.len;
}
fn verify(model: *const text.Document, history: *const text.History, expected: []const u8, selection: Endpoints) !void {
    const bytes = try model.copy(a);
    defer a.free(bytes);
    try std.testing.expectEqualStrings(expected, bytes);
    try std.testing.expectEqual(selection, history.selection.endpoints());
    try history.selection.validate(model);
    var reference = try text.Reference.init(a, expected);
    defer reference.deinit();
    for (0..expected.len + 1) |at| {
        if (at < expected.len and expected[at] & 0xc0 == 0x80) continue;
        try std.testing.expectEqual(try reference.position(at), try model.position(at));
    }
}

test "ZIT-063 seeded edit undo redo branch round trips match independent states" {
    const initial = "aé\r\n😀\n";
    for (0..16) |seed| {
        var prng = std.Random.DefaultPrng.init(0x5a4954058063 + seed);
        const random = prng.random();
        var model = try text.Document.init(a, initial);
        defer model.deinit();
        var history = text.History.init(a, 0, .{});
        defer history.deinit();
        var reference = try text.Reference.init(a, initial);
        defer reference.deinit();
        var states: std.ArrayList(State) = .empty;
        defer {
            for (states.items) |state| state.deinit();
            states.deinit(a);
        }
        var cursor: usize = 0;
        var selection: Endpoints = .{ .anchor = 0, .active = 0 };
        for (0..256) |step| {
            errdefer std.debug.print("history seed={x} step={d}\n", .{ 0x5a4954058063 + seed, step });
            const action = random.intRangeLessThan(u8, 0, 10);
            if (action < 6) {
                selection = .{ .anchor = boundary(reference.bytes, random), .active = boundary(reference.bytes, random) };
                try history.select(&model, try text.Selection.init(&model, selection, model.version));
                const first = boundary(reference.bytes, random);
                const last = boundary(reference.bytes, random);
                const range = text.Range.normalized(first, last);
                const choices = [_][]const u8{ "x", "é", "😀", "\r\n", "\n", "終", "\xef\xbb\xbf", "" };
                const inserted = choices[random.intRangeLessThan(usize, 0, choices.len)];
                const edit: text.Edit = .{ .start = range.start, .end = range.end, .inserted = inserted };
                const before = try a.dupe(u8, reference.bytes);
                errdefer a.free(before);
                const before_selection = selection;
                try reference.edit(edit);
                const changed = edit.start != edit.end or edit.inserted.len != 0;
                const explicit = random.boolean();
                const after: Endpoints = if (explicit)
                    .{ .anchor = boundary(reference.bytes, random), .active = boundary(reference.bytes, random) }
                else
                    .{ .anchor = transformed(selection.anchor, edit), .active = transformed(selection.active, edit) };
                const outcome = try history.commit(&model, .{ .version = model.version, .edits = &.{edit}, .after = if (explicit) after else null, .command = .{ .kind = .command, .id = "oracle.edit" } });
                selection = after;
                if (changed) {
                    try std.testing.expectEqual(text.HistoryOutcome.applied, outcome);
                    while (states.items.len > cursor) states.pop().?.deinit();
                    const after_bytes = try a.dupe(u8, reference.bytes);
                    errdefer a.free(after_bytes);
                    try states.append(a, .{ .before = before, .after = after_bytes, .before_selection = before_selection, .after_selection = after });
                    cursor += 1;
                } else {
                    a.free(before);
                    try std.testing.expectEqual(text.HistoryOutcome.empty, outcome);
                }
            } else if (action < 8) {
                const outcome = try history.undo(&model);
                if (cursor == 0) {
                    try std.testing.expectEqual(text.HistoryOutcome.empty, outcome);
                } else {
                    cursor -= 1;
                    try reference.edit(.{ .start = 0, .end = reference.len(), .inserted = states.items[cursor].before });
                    selection = states.items[cursor].before_selection;
                }
            } else {
                const outcome = try history.redo(&model);
                if (cursor == states.items.len) {
                    try std.testing.expectEqual(text.HistoryOutcome.empty, outcome);
                } else {
                    try reference.edit(.{ .start = 0, .end = reference.len(), .inserted = states.items[cursor].after });
                    selection = states.items[cursor].after_selection;
                    cursor += 1;
                }
            }
            try verify(&model, &history, reference.bytes, selection);
            try std.testing.expectEqual(cursor != 0, history.canUndo());
            try std.testing.expectEqual(cursor < states.items.len, history.canRedo());
            try std.testing.expect(history.usage.bytes <= history.limits.max_bytes);
        }
        while (history.canUndo()) _ = try history.undo(&model);
        const restored = try model.copy(a);
        defer a.free(restored);
        try std.testing.expectEqualStrings(initial, restored);
        while (history.canRedo()) _ = try history.redo(&model);
        if (states.items.len > 0) try verify(&model, &history, states.items[states.items.len - 1].after, states.items[states.items.len - 1].after_selection);
        history.clear();
        try std.testing.expectEqual(@as(usize, 0), history.usage.bytes);
    }
}
