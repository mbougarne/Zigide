//! Resource resolution sits outside the domain. File bytes arrive from the
//! existing file service seam; opening a folder never executes workspace code.
const std = @import("std");
const workspace = @import("workspace");
const ports = @import("ports");

pub const Failure = struct { operation: enum { open_workspace, open_document, save, reload }, cause: anyerror };
pub const Workspace = struct {
    session: workspace.Session,
    resources: ports.Resources,
    files: ?ports.SafeFiles = null,
    last_failure: ?Failure = null,

    pub fn init(allocator: std.mem.Allocator, resources: ports.Resources) Workspace {
        return .{ .session = workspace.Session.init(allocator), .resources = resources };
    }
    pub const Resolution = enum { reload, inspect, overwrite, cancel };
    pub fn openFile(self: *Workspace, path: []const u8) !workspace.DocumentId {
        self.last_failure = null;
        errdefer |err| {
            self.last_failure = .{ .operation = .open_document, .cause = err };
        }
        const files = self.files orelse return error.FileServiceUnavailable;
        const root = self.session.root orelse return error.WorkspaceClosed;
        var resource = try self.resources.resolve(self.resources.context, self.session.allocator, root.path, path, .file);
        defer resource.deinit();
        if (self.session.lookup(resource)) |id| {
            try self.session.activate(id);
            return id;
        }
        var data = try files.read(files.context, self.session.allocator, resource.path);
        defer data.deinit();
        const id = try self.session.openDocument(resource, data.bytes);
        try self.session.setBaseStamp(id, data.stamp);
        return id;
    }
    pub fn saveFile(self: *Workspace, id: workspace.DocumentId, save_as: ?[]const u8) anyerror!void {
        self.last_failure = null;
        errdefer |err| {
            self.last_failure = .{ .operation = .save, .cause = err };
        }
        const files = self.files orelse return error.FileServiceUnavailable;
        const view = try self.session.view(id);
        const root = self.session.root orelse return error.WorkspaceClosed;
        var target = if (save_as) |path| try files.destination(files.context, self.session.allocator, root.path, path) else try ports.Resource.initCanonical(self.session.allocator, view.resource);
        defer target.deinit();
        // Save As is create-only even when an alias names the source.
        if (save_as != null and std.mem.eql(u8, target.path, view.resource)) return error.DestinationExists;
        self.session.persist(id, target, files.context, files.save) catch |err| {
            if (err == error.ExternalChange) try self.session.externalChange(id);
            return @as(anyerror!void, err);
        };
    }
    /// inspect returns owned disk bytes without changing either side. A dirty
    /// reload requires a separate discard confirmation supplied by the caller.
    pub fn resolveExternal(self: *Workspace, id: workspace.DocumentId, decision: Resolution, discard_dirty: bool) !?ports.FileData {
        if (decision == .cancel) return null;
        self.last_failure = null;
        errdefer |err| {
            self.last_failure = .{ .operation = .reload, .cause = err };
        }
        const files = self.files orelse return error.FileServiceUnavailable;
        const view = try self.session.view(id);
        var disk = try files.read(files.context, self.session.allocator, view.resource);
        if (decision == .inspect) return disk;
        defer disk.deinit();
        if (decision == .reload) {
            try self.session.reload(id, disk.bytes, disk.stamp, discard_dirty);
        } else {
            // Overwrite consent is scoped to this observed disk revision. A
            // later external write still conflicts during the save transaction.
            var context = Overwrite{ .files = files, .expected = disk.stamp };
            var target = try ports.Resource.initCanonical(self.session.allocator, view.resource);
            defer target.deinit();
            try self.session.persist(id, target, &context, Overwrite.write);
        }
        return null;
    }
    const Overwrite = struct {
        files: ports.SafeFiles,
        expected: ports.FileStamp,
        fn write(raw: *anyopaque, path: []const u8, bytes: []const u8, _: ?ports.FileStamp) !ports.FileStamp {
            const self: *Overwrite = @ptrCast(@alignCast(raw));
            return self.files.save(self.files.context, path, bytes, self.expected);
        }
    };
    pub fn deinit(self: *Workspace) void {
        self.session.deinit();
        self.* = undefined;
    }
    pub fn close(self: *Workspace, policy: ?workspace.ClosePolicy) !void {
        try self.session.closeWorkspace(.workspace_close, policy);
    }
    /// Complete this admission step before Context.shutdown closes commands.
    /// Cancellation leaves the application and session available for editing.
    pub fn prepareShutdown(self: *Workspace, policy: ?workspace.ClosePolicy) !void {
        try self.session.closeWorkspace(.shutdown, policy);
    }
    pub fn open(self: *Workspace, base: []const u8, path: []const u8, policy: ?workspace.ClosePolicy) !void {
        self.last_failure = null;
        var resource = self.resources.resolve(self.resources.context, self.session.allocator, base, path, .folder) catch |err| {
            self.last_failure = .{ .operation = .open_workspace, .cause = err };
            return err;
        };
        defer resource.deinit();
        self.session.openWorkspace(resource, policy) catch |err| {
            self.last_failure = .{ .operation = .open_workspace, .cause = err };
            return err;
        };
    }
    pub fn openDocument(self: *Workspace, path: []const u8, bytes: []const u8) !workspace.DocumentId {
        self.last_failure = null;
        const root = self.session.root orelse return error.WorkspaceClosed;
        var resource = self.resources.resolve(self.resources.context, self.session.allocator, root.path, path, .file) catch |err| {
            self.last_failure = .{ .operation = .open_document, .cause = err };
            return err;
        };
        defer resource.deinit();
        return self.session.openDocument(resource, bytes) catch |err| {
            self.last_failure = .{ .operation = .open_document, .cause = err };
            return err;
        };
    }
};
