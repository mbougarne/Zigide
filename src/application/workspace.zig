//! Resource resolution sits outside the domain. File bytes arrive from the
//! existing file service seam; opening a folder never executes workspace code.
const std = @import("std");
const workspace = @import("workspace");
const ports = @import("ports");

pub const Failure = struct { operation: enum { open_workspace, open_document }, cause: anyerror };
pub const Workspace = struct {
    session: workspace.Session,
    resources: ports.Resources,
    last_failure: ?Failure = null,

    pub fn init(allocator: std.mem.Allocator, resources: ports.Resources) Workspace {
        return .{ .session = workspace.Session.init(allocator), .resources = resources };
    }
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
