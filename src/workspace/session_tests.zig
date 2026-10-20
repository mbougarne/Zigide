const std = @import("std");
const foundation = @import("foundation");
const types = @import("session.zig");
const Resource = @import("resource.zig").Resource;
const Session = types.Session;
const a = std.testing.allocator;

const Decisions = struct {
    values: []const types.Decision = &.{.discard},
    prompts: usize = 0,
    saves: usize = 0,
    fail_save: bool = false,
    session: ?*Session = null,
    reason: ?types.Reason = null,
    fn decide(raw: *anyopaque, prompt: types.Prompt) !types.Decision {
        const self: *Decisions = @ptrCast(@alignCast(raw));
        if (self.reason) |reason| try std.testing.expectEqual(reason, prompt.reason);
        if (self.session) |session| try std.testing.expectError(error.Busy, session.activate(null));
        const decision = self.values[@min(self.prompts, self.values.len - 1)];
        self.prompts += 1;
        return decision;
    }
    fn save(raw: *anyopaque, _: []const u8, snapshot: *const types.Snapshot) !void {
        const self: *Decisions = @ptrCast(@alignCast(raw));
        self.saves += 1;
        try std.testing.expect(snapshot.bytes.len != 0);
        if (self.fail_save) return error.SaveFailed;
    }
    fn policy(self: *Decisions) types.ClosePolicy {
        return .{ .context = self, .decide = decide, .save = save };
    }
};
fn cleanup(session: *Session) void {
    var decisions: Decisions = .{};
    session.closeWorkspace(.workspace_close, decisions.policy()) catch unreachable;
    session.deinit();
}
fn open(session: *Session, path: []const u8) !void {
    var root = try Resource.initCanonical(session.allocator, path);
    defer root.deinit();
    try session.openWorkspace(root, null);
}
fn document(session: *Session, path: []const u8, bytes: []const u8) !types.DocumentId {
    var resource = try Resource.initCanonical(session.allocator, path);
    defer resource.deinit();
    return session.openDocument(resource, bytes);
}
const Events = struct {
    active: usize = 0,
    dirty: usize = 0,
    destroyed: usize = 0,
    fn call(raw: *anyopaque, event: types.Change) void {
        const self: *Events = @ptrCast(@alignCast(raw));
        switch (event) {
            .active => self.active += 1,
            .dirty => self.dirty += 1,
            .selection => {},
        }
    }
    fn destroy(raw: *anyopaque, _: std.mem.Allocator) void {
        const self: *Events = @ptrCast(@alignCast(raw));
        self.destroyed += 1;
    }
    fn subscribe(self: *Events, session: *Session) !types.Changes.Subscription {
        return session.changes.subscribe(.{ .context = self, .call = call, .destroy = destroy });
    }
};

test "ZIT-053/054 one workspace deduplicates resources and closes scoped subscriptions" {
    var session = Session.init(a);
    defer cleanup(&session);
    try open(&session, "/work");
    var events: Events = .{};
    const old = try events.subscribe(&session);
    const first = try document(&session, "/work/one", "original");
    try session.edit(first, &.{.{ .start = 0, .end = 8, .inserted = "edited" }});
    try std.testing.expectEqual(first, try document(&session, "/work/one", "\xff"));
    try std.testing.expectEqual(@as(usize, 1), session.documents.items.len);
    const copy = try (try session.view(first)).model.copy(a);
    defer a.free(copy);
    try std.testing.expectEqualStrings("edited", copy);
    try std.testing.expectError(error.OutsideWorkspace, document(&session, "/workspace/other", ""));
    try std.testing.expectError(error.InvalidUtf8, document(&session, "/work/bad", "\xff"));
    var decisions: Decisions = .{};
    try session.closeWorkspace(.workspace_close, decisions.policy());
    try std.testing.expectEqual(@as(usize, 1), events.destroyed);
    try std.testing.expectEqual(@as(?types.DocumentId, null), session.active);
    try open(&session, "/work");
    var new_events: Events = .{};
    _ = try new_events.subscribe(&session);
    old.dispose();
    const reopened = try document(&session, "/work/one", "again");
    try std.testing.expect(first != reopened);
    try std.testing.expectEqual(@as(usize, 1), new_events.active);
    try session.closeWorkspace(.workspace_close, null);
}

test "ZIT-055 dirty follows edits inverse edits acknowledgements and external changes" {
    var session = Session.init(a);
    defer cleanup(&session);
    try open(&session, "/work");
    var events: Events = .{};
    const subscription = try events.subscribe(&session);
    defer subscription.dispose();
    const first = try document(&session, "/work/one", "é\r\n");
    const second = try document(&session, "/work/two", "two");
    try session.activate(second);
    try std.testing.expectEqual(@as(usize, 2), events.active);
    try session.activate(first);
    try session.activate(first);
    try std.testing.expectEqual(@as(usize, 3), events.active);
    try session.edit(first, &.{.{ .start = 0, .end = 2, .inserted = "😀" }});
    try std.testing.expect((try session.view(first)).dirty);
    try session.edit(first, &.{.{ .start = 0, .end = 4, .inserted = "é" }});
    try std.testing.expect(!(try session.view(first)).dirty);
    try std.testing.expectEqual(@as(u64, 2), (try session.view(first)).model.version);
    try session.edit(first, &.{.{ .start = 0, .end = 2, .inserted = "😀" }});
    var source: foundation.cancellation.Source = .{};
    const work = try session.beginWork(first, .save, source.token());
    var saved = try session.snapshot(first, a);
    defer saved.deinit();
    try std.testing.expect(try session.acknowledgeSave(work, &saved));
    try std.testing.expect(!(try session.view(first)).dirty);
    try session.externalChange(first);
    try std.testing.expect((try session.view(first)).dirty);
    try std.testing.expect((try session.view(first)).external_changed);
    try std.testing.expect(!try session.acknowledgeSave(work, &saved));
    const current = try session.beginWork(first, .save, source.token());
    try std.testing.expect(try session.acknowledgeSave(current, &saved));
    try std.testing.expect(!(try session.view(first)).dirty);
    try session.closeDocument(first, null);
    try std.testing.expectEqual(second, session.active.?);
    try std.testing.expectEqual(@as(usize, 4), events.active);
    try std.testing.expectEqual(@as(usize, 6), events.dirty);
}

test "ZIT-056 cancel preserves all state before saves for close switch and shutdown" {
    for ([_]types.Reason{ .document_close, .workspace_close, .workspace_switch, .shutdown }) |reason| {
        var session = Session.init(a);
        defer cleanup(&session);
        try open(&session, "/work");
        const one = try document(&session, "/work/one", "one");
        const two = try document(&session, "/work/two", "two");
        try session.edit(one, &.{.{ .start = 0, .end = 0, .inserted = "x" }});
        try session.edit(two, &.{.{ .start = 0, .end = 0, .inserted = "y" }});
        var decisions: Decisions = .{ .values = if (reason == .document_close) &.{.cancel} else &.{ .save, .cancel }, .session = &session, .reason = reason };
        const generation = session.generation;
        var replacement = try Resource.initCanonical(a, "/next");
        defer replacement.deinit();
        switch (reason) {
            .document_close => try std.testing.expectError(error.Cancelled, session.closeDocument(one, decisions.policy())),
            .workspace_switch => try std.testing.expectError(error.Cancelled, session.openWorkspace(replacement, decisions.policy())),
            else => try std.testing.expectError(error.Cancelled, session.closeWorkspace(reason, decisions.policy())),
        }
        try std.testing.expectEqual(@as(usize, 0), decisions.saves);
        try std.testing.expectEqual(generation, session.generation);
        try std.testing.expectEqualStrings("/work", session.root.?.path);
        try std.testing.expectEqual(@as(usize, 2), session.documents.items.len);
        try std.testing.expectEqual(two, session.active.?);
        try std.testing.expect((try session.view(one)).dirty and (try session.view(two)).dirty);
    }
}

test "ZIT-056 save failure and missing policy retain documents discard is explicit" {
    var session = Session.init(a);
    defer cleanup(&session);
    try open(&session, "/work");
    const id = try document(&session, "/work/one", "text");
    try session.edit(id, &.{.{ .start = 0, .end = 0, .inserted = "x" }});
    try std.testing.expectError(error.DecisionRequired, session.closeDocument(id, null));
    var decisions: Decisions = .{ .values = &.{.save}, .fail_save = true };
    try std.testing.expectError(error.SaveFailed, session.closeWorkspace(.shutdown, decisions.policy()));
    try std.testing.expect((try session.view(id)).dirty);
    var missing = decisions.policy();
    missing.save = null;
    try std.testing.expectError(error.SaveUnavailable, session.closeDocument(id, missing));
    decisions.fail_save = false;
    try session.closeWorkspace(.shutdown, decisions.policy());
    try std.testing.expect(session.root == null);
    try std.testing.expectError(error.DocumentClosed, session.view(id));
}

test "ZIT-057 stale closed reopened switched cancelled reordered and replayed results" {
    var session = Session.init(a);
    defer cleanup(&session);
    try open(&session, "/work");
    const id = try document(&session, "/work/one", "text");
    var source: foundation.cancellation.Source = .{};
    const old = try session.beginWork(id, .analyze, source.token());
    const current = try session.beginWork(id, .analyze, source.token());
    const edits: []const types.Edit = &.{.{ .start = 0, .end = 4, .inserted = "new" }};
    try std.testing.expect(!try session.applyResult(.{ .work = old, .outcome = .{ .success = edits } }));
    try std.testing.expect(try session.applyResult(.{ .work = current, .outcome = .{ .success = edits } }));
    try std.testing.expect(!try session.applyResult(.{ .work = current, .outcome = .{ .success = edits } }));
    const before_edit = try session.beginWork(id, .analyze, source.token());
    const before_save = try session.beginWork(id, .save, source.token());
    var saved = try session.snapshot(id, a);
    defer saved.deinit();
    try session.edit(id, &.{.{ .start = 0, .end = 3, .inserted = "text" }});
    try std.testing.expect(!try session.applyResult(.{ .work = before_edit, .outcome = .{ .failure = error.WorkerFailed } }));
    try std.testing.expect(!try session.acknowledgeSave(before_save, &saved));
    const before_external = try session.beginWork(id, .analyze, source.token());
    try session.externalChange(id);
    try std.testing.expect(!try session.complete(before_external));
    const closing = try session.beginWork(id, .analyze, source.token());
    var decisions: Decisions = .{};
    try session.closeDocument(id, decisions.policy());
    const reopened = try document(&session, "/work/one", "text");
    try std.testing.expect(id != reopened);
    try std.testing.expect(!try session.complete(closing));
    const cancelled = try session.beginWork(reopened, .analyze, source.token());
    _ = source.cancel();
    try std.testing.expect(!try session.applyResult(.{ .work = cancelled, .outcome = .{ .success = edits } }));
    try std.testing.expectError(error.Cancelled, session.beginWork(reopened, .analyze, source.token()));
    var fresh: foundation.cancellation.Source = .{};
    const discovery = try session.beginWork(null, .discover, fresh.token());
    const prior_workspace = try session.beginWork(reopened, .load, fresh.token());
    var next = try Resource.initCanonical(a, "/next");
    defer next.deinit();
    try session.openWorkspace(next, null);
    try std.testing.expect(!try session.complete(discovery));
    try std.testing.expect(!try session.applyResult(.{ .work = prior_workspace, .outcome = .{ .success = edits } }));
    try open(&session, "/work");
    const latest = try document(&session, "/work/one", "text");
    const accepted = try session.beginWork(latest, .analyze, fresh.token());
    try std.testing.expectError(error.WorkerFailed, session.applyResult(.{ .work = accepted, .outcome = .{ .failure = error.WorkerFailed } }));
    try std.testing.expect(!try session.complete(accepted));
    try std.testing.expect(!(try session.view(latest)).dirty);
}

fn allocationLifecycle(allocator: std.mem.Allocator) !void {
    var session = Session.init(allocator);
    defer cleanup(&session);
    try open(&session, "/work");
    const one = try document(&session, "/work/one", "é\r\n");
    try session.edit(one, &.{.{ .start = 0, .end = 2, .inserted = "changed" }});
    var decisions: Decisions = .{ .values = &.{.save} };
    var next = try Resource.initCanonical(allocator, "/next");
    defer next.deinit();
    session.openWorkspace(next, decisions.policy()) catch |err| {
        try std.testing.expectEqualStrings("/work", session.root.?.path);
        try std.testing.expectEqual(one, session.active.?);
        try std.testing.expect((try session.view(one)).dirty);
        try std.testing.expectEqual(@as(usize, 0), decisions.saves);
        return err;
    };
    try std.testing.expectEqualStrings("/next", session.root.?.path);
    try std.testing.expectEqual(@as(usize, 1), decisions.saves);
}
test "ZIT-053–056 allocation failures preserve ownership and pending close state" {
    try std.testing.checkAllAllocationFailures(a, allocationLifecycle, .{});
}

test "ZIT-055 dirty comparison crosses UTF-8 chunk boundaries without normalizing bytes" {
    var session = Session.init(a);
    defer cleanup(&session);
    try open(&session, "/work");
    const bytes = try a.alloc(u8, 8200);
    defer a.free(bytes);
    @memset(bytes, 'a');
    @memcpy(bytes[4095..4099], "😀");
    @memcpy(bytes[8190..8192], "\r\n");
    const id = try document(&session, "/work/one", bytes);
    try session.edit(id, &.{.{ .start = 4095, .end = 4099, .inserted = "abcd" }});
    try std.testing.expect((try session.view(id)).dirty);
    try session.edit(id, &.{.{ .start = 4095, .end = 4099, .inserted = "😀" }});
    try std.testing.expect(!(try session.view(id)).dirty);
    try session.edit(id, &.{.{ .start = 8199, .end = 8200, .inserted = "z" }});
    try std.testing.expect((try session.view(id)).dirty);
}

test "ZIT-057 session ownership and worker stamp tampering cannot consume current work" {
    var first = Session.init(a);
    defer cleanup(&first);
    var second = Session.init(a);
    defer cleanup(&second);
    try open(&first, "/work");
    try open(&second, "/work");
    const one = try document(&first, "/work/one", "text");
    const two = try document(&second, "/work/one", "text");
    var source: foundation.cancellation.Source = .{};
    const initial = try first.beginWork(one, .analyze, source.token());
    const other = try second.beginWork(two, .analyze, source.token());
    try std.testing.expect(!try second.complete(initial));
    var tampered = initial;
    tampered.version += 1;
    try std.testing.expect(!try first.complete(tampered));
    try std.testing.expect(try first.complete(initial));
    try std.testing.expect(try second.complete(other));
}

test "ZIT-056 earlier successful saves remain acknowledged if a later save fails" {
    var session = Session.init(a);
    defer cleanup(&session);
    try open(&session, "/work");
    const one = try document(&session, "/work/one", "one");
    const two = try document(&session, "/work/two", "two");
    try session.edit(one, &.{.{ .start = 0, .end = 0, .inserted = "x" }});
    try session.edit(two, &.{.{ .start = 0, .end = 0, .inserted = "y" }});
    const SaveSecondFailure = struct {
        calls: usize = 0,
        fn decide(_: *anyopaque, _: types.Prompt) !types.Decision {
            return .save;
        }
        fn save(raw: *anyopaque, _: []const u8, _: *const types.Snapshot) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            if (self.calls == 2) return error.SaveFailed;
        }
    };
    var fail: SaveSecondFailure = .{};
    try std.testing.expectError(error.SaveFailed, session.closeWorkspace(.shutdown, .{ .context = &fail, .decide = SaveSecondFailure.decide, .save = SaveSecondFailure.save }));
    try std.testing.expect(!(try session.view(one)).dirty);
    try std.testing.expect((try session.view(two)).dirty);
    try std.testing.expectEqual(@as(usize, 2), session.documents.items.len);
    try std.testing.expectEqual(two, session.active.?);
}

test "ZIT-058–062 workspace undo dirty save stale results and focus boundaries" {
    var session = Session.init(a);
    defer cleanup(&session);
    try open(&session, "/work");
    const one = try document(&session, "/work/one", "");
    const two = try document(&session, "/work/two", "other");
    try session.activate(one);
    try session.transaction(one, .{ .version = 0, .edits = &.{.{ .start = 0, .end = 0, .inserted = "a" }}, .command = .{ .kind = .typing } });
    try session.transaction(one, .{ .version = 1, .edits = &.{.{ .start = 1, .end = 1, .inserted = "é" }}, .command = .{ .kind = .typing } });
    try session.activate(two);
    try session.activate(one);
    try session.transaction(one, .{ .version = 2, .edits = &.{.{ .start = 3, .end = 3, .inserted = "😀" }}, .command = .{ .kind = .typing } });
    var source: foundation.cancellation.Source = .{};
    const work = try session.beginWork(one, .analyze, source.token());
    _ = try session.undo(one);
    var before = try session.snapshot(one, a);
    defer before.deinit();
    try std.testing.expectEqualStrings("aé", before.bytes);
    _ = try session.undo(one);
    try std.testing.expect(!(try session.view(one)).dirty);
    try std.testing.expect((try session.view(one)).can_redo);
    try std.testing.expect(!try session.complete(work));
    _ = try session.redo(one);
    try std.testing.expect((try session.view(one)).dirty);
    var saved = try session.snapshot(one, a);
    defer saved.deinit();
    const save = try session.beginWork(one, .save, source.token());
    try std.testing.expect(try session.acknowledgeSave(save, &saved));
    try session.transaction(one, .{ .version = saved.version, .edits = &.{.{ .start = 3, .end = 3, .inserted = "!" }}, .command = .{ .kind = .typing } });
    _ = try session.undo(one);
    try std.testing.expect(!(try session.view(one)).dirty);
    try std.testing.expectEqual(@as(usize, 3), (try session.view(one)).selection.active);
    try session.closeDocument(one, null);
    const reopened = try document(&session, "/work/one", "aé");
    try std.testing.expect(!(try session.view(reopened)).can_undo);
    try std.testing.expect(!(try session.view(reopened)).can_redo);
}
