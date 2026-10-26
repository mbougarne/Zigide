//! Application-thread owner. All callbacks are synchronous; mutation during a
//! callback returns Busy. Owning structs and the event emitter stay at stable addresses.
const std = @import("std");
const foundation = @import("foundation");
const text = @import("text");
const FileStamp = @import("file_stamp.zig").FileStamp;
const Resource = @import("resource.zig").Resource;

pub const DocumentId = enum(u64) { _ };
pub const Reason = enum { document_close, workspace_close, workspace_switch, shutdown };
pub const Decision = enum { save, discard, cancel };
pub const Prompt = struct { document: DocumentId, resource: []const u8, reason: Reason, external_changed: bool };
pub const ClosePolicy = struct {
    context: *anyopaque,
    decide: *const fn (*anyopaque, Prompt) anyerror!Decision,
    /// Success acknowledges this exact immutable snapshot persisted safely.
    /// An unresolved external change must be checked by the save adapter.
    save: ?*const fn (*anyopaque, []const u8, *const text.Snapshot) anyerror!void = null,
};
pub const Change = union(enum) {
    active: struct { previous: ?DocumentId, current: ?DocumentId },
    dirty: struct { document: DocumentId, dirty: bool },
    selection: struct { document: DocumentId, selection: text.Selection },
};
pub const Changes = foundation.events.Event(Change);
pub const WorkKind = enum { load, analyze, save, discover };
pub const Work = struct {
    owner: *const Session,
    operation: foundation.ids.OperationId,
    generation: u64,
    document: ?DocumentId,
    version: u64,
    revision: u64,
    kind: WorkKind,
    cancellation: foundation.cancellation.Token,
};
pub fn Result(comptime Payload: type) type {
    return struct { work: Work, outcome: union(enum) { success: Payload, failure: anyerror } };
}
pub const Edit = text.Edit;
pub const Snapshot = text.Snapshot;

const Document = struct {
    id: DocumentId,
    resource: Resource,
    model: text.Document,
    history: text.History,
    saved: text.Snapshot,
    base_stamp: ?FileStamp = null,
    external_changed: bool = false,
    revision: u64 = 0,
    dirty: bool = false,

    fn deinit(self: *Document, allocator: std.mem.Allocator) void {
        self.saved.deinit();
        self.history.deinit();
        self.model.deinit();
        self.resource.deinit();
        allocator.destroy(self);
    }
    fn differs(self: *const Document) bool {
        if (self.external_changed or self.model.len() != self.saved.bytes.len) return true;
        if (self.model.version == self.saved.version) return false;
        var buffer: [4096]u8 = undefined;
        var offset: usize = 0;
        // Align chunk edges to saved UTF-8 boundaries for the public read API.
        while (offset < self.saved.bytes.len) {
            var end = @min(offset + buffer.len, self.saved.bytes.len);
            while (end < self.saved.bytes.len and self.saved.bytes[end] & 0xc0 == 0x80) : (end -= 1) {}
            // Current text can have different scalar boundaries at the same byte
            // offset. A boundary failure itself proves content differs.
            self.model.read(.{ .start = offset, .end = end }, buffer[0 .. end - offset]) catch return true;
            if (!std.mem.eql(u8, buffer[0 .. end - offset], self.saved.bytes[offset..end])) return true;
            offset = end;
        }
        return false;
    }
};

pub const View = struct {
    id: DocumentId,
    resource: []const u8,
    model: *const text.Document,
    dirty: bool,
    external_changed: bool,
    selection: text.Selection,
    can_undo: bool,
    can_redo: bool,
};

pub const Session = struct {
    allocator: std.mem.Allocator,
    root: ?Resource = null,
    generation: u64 = 0,
    documents: std.ArrayList(*Document) = .empty,
    active: ?DocumentId = null,
    changes: Changes,
    document_ids: foundation.ids.Generator(DocumentId) = .{},
    operation_ids: foundation.ids.Generator(foundation.ids.OperationId) = .{},
    pending: std.ArrayList(Work) = .empty,
    busy: bool = false,
    history_limits: text.HistoryLimits = .{},

    pub fn init(allocator: std.mem.Allocator) Session {
        return .{ .allocator = allocator, .changes = Changes.init(allocator) };
    }
    /// First close through the decision contract; deinit is never a discard decision.
    pub fn deinit(self: *Session) void {
        std.debug.assert(!self.busy and self.root == null and self.documents.items.len == 0);
        self.documents.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.changes.deinit();
        self.* = undefined;
    }
    fn enter(self: *Session) !void {
        if (self.busy) return error.Busy;
        self.busy = true;
    }
    fn find(self: *const Session, id: DocumentId) ?*Document {
        for (self.documents.items) |doc| if (doc.id == id) return doc;
        return null;
    }
    pub fn view(self: *const Session, id: DocumentId) !View {
        const doc = self.find(id) orelse return error.DocumentClosed;
        return .{ .id = id, .resource = doc.resource.path, .model = &doc.model, .dirty = doc.dirty, .external_changed = doc.external_changed, .selection = doc.history.selection, .can_undo = doc.history.canUndo(), .can_redo = doc.history.canRedo() };
    }
    pub fn lookup(self: *const Session, resource: Resource) ?DocumentId {
        for (self.documents.items) |doc| if (doc.resource.eql(resource)) return doc.id;
        return null;
    }
    fn setActive(self: *Session, id: ?DocumentId) void {
        if (self.active == id) return;
        const previous = self.active;
        if (previous) |value| if (self.find(value)) |doc| doc.history.boundary();
        if (id) |value| if (self.find(value)) |doc| doc.history.boundary();
        self.active = id;
        self.changes.dispatch(.{ .active = .{ .previous = previous, .current = id } });
    }
    pub fn activate(self: *Session, id: ?DocumentId) !void {
        try self.enter();
        defer self.busy = false;
        if (id) |value| if (self.find(value) == null) return error.DocumentClosed;
        self.setActive(id);
    }
    pub fn openDocument(self: *Session, resource: Resource, bytes: []const u8) !DocumentId {
        try self.enter();
        defer self.busy = false;
        const root = self.root orelse return error.WorkspaceClosed;
        if (!root.contains(resource) or root.eql(resource)) return error.OutsideWorkspace;
        if (self.lookup(resource)) |id| {
            self.setActive(id);
            return id;
        }
        const doc = try self.allocator.create(Document);
        errdefer self.allocator.destroy(doc);
        var owned = try resource.clone(self.allocator);
        errdefer owned.deinit();
        var model = try text.Document.init(self.allocator, bytes);
        errdefer model.deinit();
        var saved = try model.snapshot(self.allocator);
        errdefer saved.deinit();
        try self.documents.ensureUnusedCapacity(self.allocator, 1);
        const id = try self.document_ids.next();
        doc.* = .{ .id = id, .resource = owned, .model = model, .history = text.History.init(self.allocator, model.version, self.history_limits), .saved = saved };
        self.documents.appendAssumeCapacity(doc);
        self.setActive(id);
        return id;
    }
    fn refreshDirty(self: *Session, doc: *Document) void {
        const dirty = doc.differs();
        if (dirty == doc.dirty) return;
        doc.dirty = dirty;
        self.changes.dispatch(.{ .dirty = .{ .document = doc.id, .dirty = dirty } });
    }
    fn apply(self: *Session, doc: *Document, edits: []const text.Edit) !void {
        try self.transact(doc, .{ .version = doc.model.version, .edits = edits });
    }
    fn transact(self: *Session, doc: *Document, request: text.EditTransaction) !void {
        const revision = try std.math.add(u64, doc.revision, 1);
        const previous = doc.model.version;
        const selection = doc.history.selection;
        _ = try doc.history.commit(&doc.model, request);
        if (previous != doc.model.version) doc.revision = revision;
        self.refreshDirty(doc);
        if (!selection.eql(doc.history.selection)) self.changes.dispatch(.{ .selection = .{ .document = doc.id, .selection = doc.history.selection } });
    }
    /// Ordinary commands share transactions with typed input and background edits.
    pub fn edit(self: *Session, id: DocumentId, edits: []const text.Edit) !void {
        try self.enter();
        defer self.busy = false;
        try self.apply(self.find(id) orelse return error.DocumentClosed, edits);
    }
    pub fn transaction(self: *Session, id: DocumentId, request: text.EditTransaction) !void {
        try self.enter();
        defer self.busy = false;
        try self.transact(self.find(id) orelse return error.DocumentClosed, request);
    }
    pub fn select(self: *Session, id: DocumentId, selection: text.Selection) !void {
        try self.enter();
        defer self.busy = false;
        const doc = self.find(id) orelse return error.DocumentClosed;
        const previous = doc.history.selection;
        try doc.history.select(&doc.model, selection);
        if (!previous.eql(selection)) self.changes.dispatch(.{ .selection = .{ .document = id, .selection = selection } });
    }
    pub fn historyBoundary(self: *Session, id: DocumentId) !void {
        try self.enter();
        defer self.busy = false;
        (self.find(id) orelse return error.DocumentClosed).history.boundary();
    }
    pub fn setHistoryLimits(self: *Session, id: DocumentId, limits: text.HistoryLimits) !void {
        try self.enter();
        defer self.busy = false;
        (self.find(id) orelse return error.DocumentClosed).history.setLimits(limits);
    }
    fn replay(self: *Session, id: DocumentId, redo_value: bool) !text.HistoryOutcome {
        try self.enter();
        defer self.busy = false;
        const doc = self.find(id) orelse return error.DocumentClosed;
        const revision = try std.math.add(u64, doc.revision, 1);
        const outcome = if (redo_value) try doc.history.redo(&doc.model) else try doc.history.undo(&doc.model);
        if (outcome == .applied) {
            doc.revision = revision;
            self.refreshDirty(doc);
            self.changes.dispatch(.{ .selection = .{ .document = id, .selection = doc.history.selection } });
        }
        return outcome;
    }
    pub fn undo(self: *Session, id: DocumentId) !text.HistoryOutcome {
        return self.replay(id, false);
    }
    pub fn redo(self: *Session, id: DocumentId) !text.HistoryOutcome {
        return self.replay(id, true);
    }
    pub fn snapshot(self: *const Session, id: DocumentId, allocator: std.mem.Allocator) !text.Snapshot {
        return (self.find(id) orelse return error.DocumentClosed).model.snapshot(allocator);
    }
    /// The acknowledgement must describe current bytes/version. A late save
    /// never clears later edits or an external-change notification.
    pub fn acknowledgeSave(self: *Session, work: Work, saved: *const text.Snapshot) !bool {
        try self.enter();
        defer self.busy = false;
        if (!self.accept(work)) return false;
        const doc = self.find(work.document orelse return error.InvalidOperation) orelse return false;
        if (work.kind != .save or saved.version != doc.model.version) return error.InvalidOperation;
        var replacement = try doc.model.snapshot(self.allocator);
        errdefer replacement.deinit();
        if (!std.mem.eql(u8, saved.bytes, replacement.bytes)) return error.InvalidOperation;
        doc.saved.deinit();
        doc.saved = replacement;
        doc.external_changed = false;
        doc.history.boundary();
        self.refreshDirty(doc);
        return true;
    }
    pub fn baseStamp(self: *const Session, id: DocumentId) !?FileStamp {
        return (self.find(id) orelse return error.DocumentClosed).base_stamp;
    }
    pub fn setBaseStamp(self: *Session, id: DocumentId, stamp: FileStamp) !void {
        try self.enter();
        defer self.busy = false;
        (self.find(id) orelse return error.DocumentClosed).base_stamp = stamp;
    }
    /// Prepare allocations and admission before writing. Callback borrows this
    /// locked session; success commits without any further fallible operations.
    pub fn persist(self: *Session, id: DocumentId, target: Resource, context: *anyopaque, write: *const fn (*anyopaque, []const u8, []const u8, ?FileStamp) anyerror!FileStamp) anyerror!void {
        try self.enter();
        defer self.busy = false;
        const doc = self.find(id) orelse return error.DocumentClosed;
        const root = self.root orelse return error.WorkspaceClosed;
        if (!root.contains(target) or root.eql(target)) return error.OutsideWorkspace;
        if (self.lookup(target)) |other| if (other != id) return error.DestinationOpen;
        const revision = try std.math.add(u64, doc.revision, 1);
        var resource = try target.clone(self.allocator);
        errdefer resource.deinit();
        var saved = try doc.model.snapshot(self.allocator);
        errdefer saved.deinit();
        const stamp = try write(context, resource.path, saved.bytes, if (doc.resource.eql(target)) doc.base_stamp else null);
        doc.resource.deinit();
        doc.resource = resource;
        doc.saved.deinit();
        doc.saved = saved;
        doc.base_stamp = stamp;
        doc.external_changed = false;
        doc.revision = revision;
        doc.history.boundary();
        self.refreshDirty(doc);
    }
    /// Dirty reload needs an independent explicit discard decision. All
    /// preparation happens before replacing model, history and saved baseline.
    pub fn reload(self: *Session, id: DocumentId, bytes: []const u8, stamp: FileStamp, discard_dirty: bool) !void {
        try self.enter();
        defer self.busy = false;
        const doc = self.find(id) orelse return error.DocumentClosed;
        if (doc.dirty and !discard_dirty) return error.DiscardDecisionRequired;
        const revision = try std.math.add(u64, doc.revision, 1);
        var model = try text.Document.init(self.allocator, bytes);
        errdefer model.deinit();
        var saved = try model.snapshot(self.allocator);
        errdefer saved.deinit();
        doc.model.deinit();
        doc.saved.deinit();
        doc.history.deinit();
        doc.model = model;
        doc.saved = saved;
        doc.history = text.History.init(self.allocator, model.version, self.history_limits);
        doc.base_stamp = stamp;
        doc.external_changed = false;
        doc.revision = revision;
        self.refreshDirty(doc);
        self.changes.dispatch(.{ .selection = .{ .document = id, .selection = doc.history.selection } });
    }
    pub fn externalChange(self: *Session, id: DocumentId) !void {
        try self.enter();
        defer self.busy = false;
        const doc = self.find(id) orelse return error.DocumentClosed;
        doc.revision = try std.math.add(u64, doc.revision, 1);
        doc.external_changed = true;
        doc.history.boundary();
        self.refreshDirty(doc);
    }
    pub fn openWorkspace(self: *Session, resource: Resource, policy: ?ClosePolicy) !void {
        try self.enter();
        defer self.busy = false;
        if (self.root) |root| if (root.eql(resource)) return;
        const generation = try std.math.add(u64, self.generation, 1);
        var replacement = try resource.clone(self.allocator);
        errdefer replacement.deinit();
        try self.decide(null, .workspace_switch, policy);
        self.clearWorkspace();
        self.root = replacement;
        self.generation = generation;
    }
    pub fn closeWorkspace(self: *Session, reason: Reason, policy: ?ClosePolicy) !void {
        try self.enter();
        defer self.busy = false;
        if (reason != .workspace_close and reason != .shutdown) return error.InvalidOperation;
        if (self.root == null) return;
        const generation = try std.math.add(u64, self.generation, 1);
        try self.decide(null, reason, policy);
        self.clearWorkspace();
        self.generation = generation;
    }
    pub fn closeDocument(self: *Session, id: DocumentId, policy: ?ClosePolicy) !void {
        try self.enter();
        defer self.busy = false;
        _ = self.find(id) orelse return error.DocumentClosed;
        try self.decide(id, .document_close, policy);
        for (self.documents.items, 0..) |doc, index| {
            if (doc.id != id) continue;
            _ = self.documents.orderedRemove(index);
            if (self.active == id) self.setActive(if (self.documents.items.len == 0) null else self.documents.items[@min(index, self.documents.items.len - 1)].id);
            self.removeWork(id);
            doc.deinit(self.allocator);
            return;
        }
        unreachable;
    }
    fn decide(self: *Session, only: ?DocumentId, reason: Reason, policy: ?ClosePolicy) !void {
        const Choice = struct { doc: *Document, saved: ?text.Snapshot = null };
        var choices: std.ArrayList(Choice) = .empty;
        defer {
            for (choices.items) |*choice| if (choice.saved) |*saved| saved.deinit();
            choices.deinit(self.allocator);
        }
        // Collect every decision before any persistence or removal. Discard-only
        // teardown needs no allocation, even after an allocation failure.
        for (self.documents.items) |doc| {
            if ((only != null and doc.id != only.?) or !doc.dirty) continue;
            const p = policy orelse return error.DecisionRequired;
            const decision = try p.decide(p.context, .{ .document = doc.id, .resource = doc.resource.path, .reason = reason, .external_changed = doc.external_changed });
            if (decision == .cancel) return error.Cancelled;
            if (decision == .save) try choices.append(self.allocator, .{ .doc = doc });
        }
        // Prepare all snapshots before the first write; no allocation can fail
        // between an acknowledged save and its dirty-state update.
        for (choices.items) |*choice| {
            if (policy.?.save == null) return error.SaveUnavailable;
            choice.saved = try choice.doc.model.snapshot(self.allocator);
        }
        for (choices.items) |*choice| if (choice.saved) |*saved| {
            const p = policy.?;
            try p.save.?(p.context, choice.doc.resource.path, saved);
            choice.doc.saved.deinit();
            choice.doc.saved = saved.*;
            choice.saved = null;
            choice.doc.external_changed = false;
            choice.doc.history.boundary();
            self.refreshDirty(choice.doc);
        };
    }
    fn clearWorkspace(self: *Session) void {
        self.setActive(null);
        for (self.documents.items) |doc| doc.deinit(self.allocator);
        self.documents.clearRetainingCapacity();
        self.pending.clearRetainingCapacity();
        if (self.root) |*root| root.deinit();
        self.root = null;
        // Old handles remain harmless when a new workspace subscribes.
        const next_id = self.changes.next_id;
        self.changes.deinit();
        self.changes = Changes.init(self.allocator);
        self.changes.next_id = next_id;
    }
    fn removeWork(self: *Session, id: DocumentId) void {
        var i: usize = 0;
        while (i < self.pending.items.len) {
            if (self.pending.items[i].document == id) _ = self.pending.orderedRemove(i) else i += 1;
        }
    }
    pub fn beginWork(self: *Session, id: ?DocumentId, kind: WorkKind, cancellation: foundation.cancellation.Token) !Work {
        try self.enter();
        defer self.busy = false;
        try cancellation.check();
        if (self.root == null) return error.WorkspaceClosed;
        const doc = if (id) |value| self.find(value) orelse return error.DocumentClosed else null;
        try self.pending.ensureUnusedCapacity(self.allocator, 1);
        const work: Work = .{ .owner = self, .operation = try self.operation_ids.next(), .generation = self.generation, .document = id, .version = if (doc) |value| value.model.version else self.generation, .revision = if (doc) |value| value.revision else self.generation, .kind = kind, .cancellation = cancellation };
        var i: usize = 0;
        while (i < self.pending.items.len) {
            const old = self.pending.items[i];
            if (old.document == id and old.kind == kind) _ = self.pending.orderedRemove(i) else i += 1;
        }
        self.pending.appendAssumeCapacity(work);
        return work;
    }
    /// Removes the tracked operation on completion, including cancellation or
    /// staleness. The stored stamp is authoritative; never trust worker fields.
    fn accept(self: *Session, result: Work) bool {
        if (result.owner != self) return false;
        for (self.pending.items, 0..) |work, index| {
            if (work.operation != result.operation) continue;
            if (work.document != result.document or work.generation != result.generation or work.version != result.version or work.revision != result.revision or work.kind != result.kind) return false;
            _ = self.pending.orderedRemove(index);
            if (work.cancellation.isCancelled() or self.root == null or self.generation != work.generation) return false;
            if (work.document) |id| return if (self.find(id)) |doc| doc.model.version == work.version and doc.revision == work.revision else false;
            return true;
        }
        return false;
    }
    /// For read-only workspace payloads. Consumers apply accepted payloads on
    /// this same application thread; each completion is accepted at most once.
    pub fn complete(self: *Session, work: Work) !bool {
        try self.enter();
        defer self.busy = false;
        return self.accept(work);
    }
    /// Guard and mutation share one admission check; stale successes and errors
    /// cannot change document state. Workers receive snapshots, never this owner.
    pub fn applyResult(self: *Session, result: Result([]const text.Edit)) !bool {
        try self.enter();
        defer self.busy = false;
        if (!self.accept(result.work)) return false;
        const id = result.work.document orelse return error.InvalidOperation;
        const doc = self.find(id) orelse return false;
        switch (result.outcome) {
            .success => |edits| try self.apply(doc, edits),
            .failure => |err| return err,
        }
        return true;
    }
};
