//! Owned reversible batches. One application-thread history per mutable document.
const std = @import("std");
const Document = @import("document.zig").Document;
const Edit = @import("semantics.zig").Edit;
const selections = @import("selection.zig");
pub const Selection = selections.Selection;
pub const Endpoints = selections.Endpoints;

pub const Kind = enum { typing, backspace, delete_forward, paste, formatting, command, external };
pub const Command = struct { kind: Kind = .command, id: []const u8 = "edit" };
pub const Limits = struct { max_entries: usize = 1024, max_bytes: usize = 8 * 1024 * 1024, max_group_bytes: usize = 64 * 1024 };
pub const Request = struct { version: u64, edits: []const Edit, after: ?Endpoints = null, command: Command = .{} };
pub const Outcome = enum { applied, empty };
pub const Usage = struct { entries: usize, bytes: usize };
pub const Info = struct { before: Endpoints, after: Endpoints, command: Command };

const Entry = struct {
    previous: ?*Entry = null,
    next: ?*Entry = null,
    forward: []Edit,
    inverse: []Edit,
    before: Endpoints,
    after: Endpoints,
    command: Command,
    bytes: usize,

    fn destroy(self: *Entry, allocator: std.mem.Allocator) void {
        for (self.forward) |edit| allocator.free(edit.inserted);
        for (self.inverse) |edit| allocator.free(edit.inserted);
        allocator.free(self.forward);
        allocator.free(self.inverse);
        allocator.free(self.command.id);
        allocator.destroy(self);
    }
    fn less(_: void, left: Edit, right: Edit) bool {
        return left.start < right.start;
    }
    fn cost(edits: usize, payload: usize, command_bytes: usize) !usize {
        return std.math.add(usize, try std.math.add(usize, @sizeOf(Entry), try std.math.mul(usize, edits, 2 * @sizeOf(Edit))), try std.math.add(usize, payload, command_bytes));
    }
    fn allocate(allocator: std.mem.Allocator, count: usize, bytes: usize, command: Command, before: Endpoints, after: Endpoints) !*Entry {
        const self = try allocator.create(Entry);
        errdefer allocator.destroy(self);
        const forward = try allocator.alloc(Edit, count);
        errdefer allocator.free(forward);
        const inverse = try allocator.alloc(Edit, count);
        errdefer allocator.free(inverse);
        const id = try allocator.dupe(u8, command.id);
        self.* = .{ .forward = forward, .inverse = inverse, .before = before, .after = after, .command = .{ .kind = command.kind, .id = id }, .bytes = bytes };
        for (forward) |*edit| edit.* = .{ .start = 0, .end = 0, .inserted = &.{} };
        for (inverse) |*edit| edit.* = .{ .start = 0, .end = 0, .inserted = &.{} };
        return self;
    }
    /// Canonicalize adjacent edits so inverse insertions never share a start.
    fn capture(allocator: std.mem.Allocator, model: *const Document, request: Request, before: Endpoints, limits: Limits) !?*Entry {
        const sorted = try allocator.dupe(Edit, request.edits);
        defer allocator.free(sorted);
        std.mem.sort(Edit, sorted, {}, less);
        var count: usize = 0;
        var payload: usize = 0;
        var previous_end: ?usize = null;
        for (sorted, 0..) |edit, index| {
            if (edit.start > edit.end or edit.end > model.len()) return error.InvalidRange;
            _ = try model.position(edit.start);
            _ = try model.position(edit.end);
            if (!std.unicode.utf8ValidateSlice(edit.inserted)) return error.InvalidUtf8;
            if (index > 0 and (edit.start < sorted[index - 1].end or edit.start == sorted[index - 1].start)) return error.OverlappingEdits;
            if (edit.start == edit.end and edit.inserted.len == 0) continue;
            if (previous_end == null or previous_end.? != edit.start) count += 1;
            previous_end = edit.end;
            payload = try std.math.add(usize, payload, try std.math.add(usize, edit.end - edit.start, edit.inserted.len));
        }
        if (count == 0) return null;
        const bytes = try cost(count, payload, request.command.id.len);
        if (limits.max_entries == 0 or bytes > limits.max_bytes) return error.HistoryLimitExceeded;
        const result = try allocate(allocator, count, bytes, request.command, before, before);
        errdefer result.destroy(allocator);
        var at: usize = 0;
        var group: usize = 0;
        var removed: usize = 0;
        var inserted: usize = 0;
        while (at < sorted.len) {
            if (sorted[at].start == sorted[at].end and sorted[at].inserted.len == 0) {
                at += 1;
                continue;
            }
            const start = sorted[at].start;
            var end = sorted[at].end;
            var size = sorted[at].inserted.len;
            const first = at;
            at += 1;
            while (at < sorted.len and sorted[at].start == end) : (at += 1) {
                end = sorted[at].end;
                size = try std.math.add(usize, size, sorted[at].inserted.len);
            }
            const added = try allocator.alloc(u8, size);
            result.forward[group] = .{ .start = start, .end = end, .inserted = added };
            var offset: usize = 0;
            for (sorted[first..at]) |edit| {
                @memcpy(added[offset..][0..edit.inserted.len], edit.inserted);
                offset += edit.inserted.len;
            }
            const inverse_start = start - removed + inserted;
            const original = try allocator.alloc(u8, end - start);
            result.inverse[group] = .{ .start = inverse_start, .end = inverse_start + size, .inserted = original };
            try model.read(.{ .start = start, .end = end }, original);
            removed += end - start;
            inserted += size;
            group += 1;
        }
        std.debug.assert(group == count);
        return result;
    }
    fn canMerge(old: *const Entry, current: *const Entry) bool {
        if (old.forward.len != 1 or current.forward.len != 1 or old.command.kind != current.command.kind or !std.mem.eql(u8, old.command.id, current.command.id)) return false;
        if (old.before.anchor != old.before.active or old.after.anchor != old.after.active or current.before.anchor != current.before.active or current.after.anchor != current.after.active) return false;
        if (!std.meta.eql(old.after, current.before)) return false;
        const left = old.forward[0];
        const right = current.forward[0];
        return switch (old.command.kind) {
            .typing => left.start == left.end and right.start == right.end and right.start == left.start + left.inserted.len and old.before.active == left.start and current.before.active == right.start and current.after.active == right.start + right.inserted.len and std.mem.indexOfAny(u8, left.inserted, "\r\n") == null and std.mem.indexOfAny(u8, right.inserted, "\r\n") == null,
            .backspace => left.inserted.len == 0 and right.inserted.len == 0 and left.end == old.before.active and left.start == old.after.active and right.end == left.start and right.start == current.after.active,
            .delete_forward => left.inserted.len == 0 and right.inserted.len == 0 and left.start == old.before.active and right.start == left.start and current.before.active == right.start and current.after.active == right.start,
            else => false,
        };
    }
    fn merge(allocator: std.mem.Allocator, old: *const Entry, current: *const Entry, limits: Limits) !?*Entry {
        const bytes = try std.math.add(usize, old.bytes, current.bytes - @sizeOf(Entry) - 2 * @sizeOf(Edit) - current.command.id.len);
        if (bytes > limits.max_bytes or bytes > limits.max_group_bytes) return null;
        const result = try allocate(allocator, 1, bytes, current.command, old.before, current.after);
        errdefer result.destroy(allocator);
        const left = old.forward[0];
        const right = current.forward[0];
        if (current.command.kind == .typing) {
            result.forward[0] = .{ .start = left.start, .end = left.end, .inserted = try std.mem.concat(allocator, u8, &.{ left.inserted, right.inserted }) };
            result.inverse[0] = .{ .start = left.start, .end = left.start + result.forward[0].inserted.len, .inserted = try allocator.dupe(u8, old.inverse[0].inserted) };
        } else {
            const original = if (current.command.kind == .backspace)
                try std.mem.concat(allocator, u8, &.{ current.inverse[0].inserted, old.inverse[0].inserted })
            else
                try std.mem.concat(allocator, u8, &.{ old.inverse[0].inserted, current.inverse[0].inserted });
            const start = if (current.command.kind == .backspace) right.start else left.start;
            result.inverse[0] = .{ .start = start, .end = start, .inserted = original };
            result.forward[0] = .{ .start = start, .end = start + original.len, .inserted = try allocator.alloc(u8, 0) };
        }
        return result;
    }
};

pub const History = struct {
    allocator: std.mem.Allocator,
    limits: Limits,
    selection: Selection,
    first: ?*Entry = null,
    last: ?*Entry = null,
    cursor: ?*Entry = null,
    usage: Usage = .{ .entries = 0, .bytes = 0 },
    grouping: bool = false,

    pub fn init(allocator: std.mem.Allocator, version: u64, limits: Limits) History {
        return .{ .allocator = allocator, .limits = limits, .selection = .{ .version = version } };
    }
    pub fn deinit(self: *History) void {
        self.clear();
        self.* = undefined;
    }
    pub fn clear(self: *History) void {
        while (self.last) |entry| self.remove(entry);
        self.grouping = false;
    }
    pub fn boundary(self: *History) void {
        self.grouping = false;
    }
    pub fn select(self: *History, model: *const Document, selection: Selection) !void {
        try self.selection.validate(model);
        try selection.validate(model);
        self.selection = selection;
        self.boundary();
    }
    pub fn canUndo(self: *const History) bool {
        return self.cursor != null;
    }
    pub fn canRedo(self: *const History) bool {
        return if (self.cursor) |entry| entry.next != null else self.first != null;
    }
    pub fn current(self: *const History) ?Info {
        const entry = self.cursor orelse return null;
        return .{ .before = entry.before, .after = entry.after, .command = entry.command };
    }
    fn remove(self: *History, entry: *Entry) void {
        if (entry.previous) |previous| previous.next = entry.next else self.first = entry.next;
        if (entry.next) |next| next.previous = entry.previous else self.last = entry.previous;
        if (self.cursor == entry) self.cursor = entry.previous;
        self.usage.entries -= 1;
        self.usage.bytes -= entry.bytes;
        entry.destroy(self.allocator);
    }
    pub fn setLimits(self: *History, limits: Limits) void {
        self.limits = limits;
        self.boundary();
        self.evict();
    }
    fn evict(self: *History) void {
        while (self.usage.entries > self.limits.max_entries or self.usage.bytes > self.limits.max_bytes) {
            // Drop oldest applied history first, then the newest redo suffix.
            self.remove(if (self.cursor != null) self.first.? else self.last.?);
        }
    }
    pub fn commit(self: *History, model: *Document, request: Request) !Outcome {
        try self.selection.validate(model);
        if (request.version != model.version) return error.StaleSelection;
        const entry = (try Entry.capture(self.allocator, model, request, self.selection.endpoints(), self.limits)) orelse {
            if (request.after) |after| {
                self.selection = try Selection.init(model, after, model.version);
                self.boundary();
            }
            return .empty;
        };
        var owned: ?*Entry = entry;
        defer if (owned) |value| value.destroy(self.allocator);
        var prepared = (try model.prepare(entry.forward)).?;
        errdefer prepared.deinit();
        const next = if (request.after) |after|
            try Selection.init(&prepared, after, prepared.version)
        else
            self.selection.transformed(entry.forward, prepared.version);
        _ = try prepared.position(next.anchor);
        _ = try prepared.position(next.active);
        entry.after = next.endpoints();
        var merged: ?*Entry = null;
        errdefer if (merged) |value| value.destroy(self.allocator);
        if (self.grouping and self.cursor != null and self.cursor == self.last and Entry.canMerge(self.cursor.?, entry))
            merged = try Entry.merge(self.allocator, self.cursor.?, entry, self.limits);
        const retained = merged orelse entry;
        prepared.commit();
        if (merged == null) owned = null;
        while (self.last != self.cursor) self.remove(self.last.?);
        if (merged != null) self.remove(self.cursor.?);
        retained.previous = self.last;
        if (self.last) |last| last.next = retained else self.first = retained;
        self.last = retained;
        self.cursor = retained;
        self.usage.entries += 1;
        self.usage.bytes += retained.bytes;
        self.selection = next;
        self.grouping = true;
        self.evict();
        return .applied;
    }
    fn replay(self: *History, model: *Document, redo_value: bool) !Outcome {
        try self.selection.validate(model);
        const entry = (if (redo_value) (if (self.cursor) |current_entry| current_entry.next else self.first) else self.cursor) orelse {
            self.boundary();
            return .empty;
        };
        var prepared = (try model.prepare(if (redo_value) entry.forward else entry.inverse)).?;
        errdefer prepared.deinit();
        const selection = try Selection.init(&prepared, if (redo_value) entry.after else entry.before, prepared.version);
        prepared.commit();
        self.selection = selection;
        self.cursor = if (redo_value) entry else entry.previous;
        self.boundary();
        return .applied;
    }
    pub fn undo(self: *History, model: *Document) !Outcome {
        return self.replay(model, false);
    }
    pub fn redo(self: *History, model: *Document) !Outcome {
        return self.replay(model, true);
    }
};
