const std = @import("std");
const adapters = @import("adapters");
const application = @import("application");
const workspace = @import("workspace");
const ports = @import("ports");
const a = std.testing.allocator;
const io = std.testing.io;
const expect = std.testing.expect;
const equal = std.testing.expectEqualStrings;

const Fixture = struct {
    temp: std.testing.TmpDir,
    root: []u8,
    resources: adapters.LocalResources = .{ .io = io },
    files: adapters.LocalFiles = .{ .io = io },
    app: application.Workspace = undefined,
    fn init(self: *Fixture) !void {
        self.resources = .{ .io = io };
        self.files = .{ .io = io };
        self.temp = std.testing.tmpDir(.{ .iterate = true });
        errdefer self.temp.cleanup();
        var buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
        self.root = try a.dupe(u8, buffer[0..try self.temp.dir.realPath(io, &buffer)]);
        errdefer a.free(self.root);
        self.app = application.Workspace.init(a, self.resources.port());
        self.app.files = self.files.port();
        try self.app.open(self.root, self.root, null);
    }
    fn deinit(self: *Fixture) void {
        self.app.close(.{ .context = self, .decide = discard }) catch unreachable;
        self.app.deinit();
        a.free(self.root);
        self.temp.cleanup();
    }
    fn discard(_: *anyopaque, _: workspace.lifecycle.Prompt) !workspace.lifecycle.Decision {
        return .discard;
    }
    fn put(self: *Fixture, name: []const u8, bytes: []const u8) !void {
        try self.temp.dir.writeFile(io, .{ .sub_path = name, .data = bytes });
    }
    fn disk(self: *Fixture, name: []const u8, bytes: []const u8) !void {
        const actual = try self.temp.dir.readFileAlloc(io, name, a, .limited(32768));
        defer a.free(actual);
        try equal(bytes, actual);
    }
    fn memory(self: *Fixture, id: workspace.DocumentId, bytes: []const u8, dirty: bool) !void {
        var snapshot = try self.app.session.snapshot(id, a);
        defer snapshot.deinit();
        try equal(bytes, snapshot.bytes);
        try std.testing.expectEqual(dirty, (try self.app.session.view(id)).dirty);
    }
    fn noTemps(self: *Fixture) !void {
        var iterator = self.temp.dir.iterate();
        while (try iterator.next(io)) |entry| try expect(!std.mem.startsWith(u8, entry.name, ".zigide-save-"));
    }
};
const Fault = struct {
    stage: adapters.FileStage,
    hits: usize = 0,
    fail_at: usize = 1,
    cause: anyerror = error.InjectedFailure,
    fn call(raw: *anyopaque, stage: adapters.FileStage) !void {
        const self: *Fault = @ptrCast(@alignCast(raw));
        if (stage != self.stage) return;
        self.hits += 1;
        if (self.hits == self.fail_at) return self.cause;
    }
    fn install(self: *Fault, files: *adapters.LocalFiles) void {
        files.checkpoint = .{ .context = self, .call = call };
    }
};

test "ZIT-064/065 bounded missing nonregular permission invalid bytes and no editable admission" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try std.testing.expectError(error.NotFound, f.app.openFile("missing"));
    try f.temp.dir.createDir(io, "folder", .default_dir);
    try std.testing.expectError(error.NotFile, f.app.openFile("folder"));
    try f.put("big", "12345");
    f.files.max_bytes = 4;
    try std.testing.expectError(error.FileTooLarge, f.app.openFile("big"));
    f.files.max_bytes = 16 * 1024 * 1024;
    try f.put("bad", "a\xffb");
    try std.testing.expectError(error.InvalidUtf8, f.app.openFile("bad"));
    try f.disk("bad", "a\xffb");
    try expect(f.app.session.documents.items.len == 0);
    try f.put("denied", "valid");
    const file = try f.temp.dir.openFile(io, "denied", .{});
    defer file.close(io);
    try file.setPermissions(io, .fromMode(0));
    defer file.setPermissions(io, .fromMode(0o600)) catch unreachable;
    try std.testing.expectError(error.AccessDenied, f.app.openFile("denied"));
    try expect(f.app.session.documents.items.len == 0);
    // Adapter independently distinguishes a nonregular file without blocking.
    const folder = try std.fs.path.join(a, &.{ f.root, "folder" });
    defer a.free(folder);
    try std.testing.expectError(error.NotFile, f.files.port().read(&f.files, a, folder));
}

test "ZIT-066/070 partial write sync permission rename failures retain original dirty bytes and recover" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.put("file", "original");
    const id = try f.app.openFile("file");
    const bytes = try a.alloc(u8, 9000);
    defer a.free(bytes);
    @memset(bytes, 'x');
    try f.app.session.edit(id, &.{.{ .start = 0, .end = 8, .inserted = bytes }});
    for ([_]adapters.FileStage{ .create, .write, .permissions, .sync, .rename }) |stage| {
        var fault = Fault{ .stage = stage, .fail_at = if (stage == .write) 2 else 1 };
        fault.install(&f.files);
        try std.testing.expectError(error.InjectedFailure, f.app.saveFile(id, null));
        try f.disk("file", "original");
        try f.memory(id, bytes, true);
        try std.testing.expectEqual(stage, f.files.last_failure.?.stage);
        try expect(!f.files.last_failure.?.committed);
        try f.noTemps();
    }
    f.files.checkpoint = null;
    try f.app.saveFile(id, null);
    try f.disk("file", bytes);
    try f.memory(id, bytes, false);
    // A second save must accept the post-rename metadata baseline.
    try f.app.saveFile(id, null);
    try f.noTemps();
}

test "ZIT-067 Save As collision failure identity and permissions transaction" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.put("source", "base");
    try f.put("collision", "other");
    const id = try f.app.openFile("source");
    const original = try a.dupe(u8, (try f.app.session.view(id)).resource);
    defer a.free(original);
    try f.app.session.edit(id, &.{.{ .start = 4, .end = 4, .inserted = "!" }});
    try std.testing.expectError(error.DestinationExists, f.app.saveFile(id, "collision"));
    var fault = Fault{ .stage = .create, .cause = error.AccessDenied };
    fault.install(&f.files);
    try std.testing.expectError(error.AccessDenied, f.app.saveFile(id, "new"));
    try equal(original, (try f.app.session.view(id)).resource);
    try f.memory(id, "base!", true);
    try f.disk("source", "base");
    try f.disk("collision", "other");
    f.files.checkpoint = null;
    try f.app.saveFile(id, "new");
    try expect(std.mem.endsWith(u8, (try f.app.session.view(id)).resource, "/new"));
    try f.memory(id, "base!", false);
    try f.disk("source", "base");
    try f.disk("new", "base!");
    const stat = try f.temp.dir.statFile(io, "new", .{});
    try std.testing.expectEqual(@as(u32, 0o600), @as(u32, @intCast(stat.permissions.toMode())) & 0o777);
    const file = try f.temp.dir.openFile(io, "new", .{});
    defer file.close(io);
    try file.setPermissions(io, .fromMode(0o640));
    // A permission change is itself external divergence until explicitly accepted.
    try std.testing.expectError(error.ExternalChange, f.app.saveFile(id, null));
    _ = try f.app.resolveExternal(id, .overwrite, false);
    const saved_stat = try f.temp.dir.statFile(io, "new", .{});
    try std.testing.expectEqual(@as(u32, 0o640), @as(u32, @intCast(saved_stat.permissions.toMode())) & 0o777);
    try file.setPermissions(io, .fromMode(0o600)); // old inode only; fixture cleanup owns both.
}

test "ZIT-068/069 disk edit replacement deletion cancel inspect reload and overwrite decisions" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.put("file", "base");
    const id = try f.app.openFile("file");
    try f.app.session.edit(id, &.{.{ .start = 4, .end = 4, .inserted = "!" }});
    try f.put("file", "disk");
    try std.testing.expectError(error.ExternalChange, f.app.saveFile(id, null));
    _ = try f.app.resolveExternal(id, .cancel, false);
    try f.disk("file", "disk");
    try f.memory(id, "base!", true);
    var inspected = (try f.app.resolveExternal(id, .inspect, false)).?;
    defer inspected.deinit();
    try equal("disk", inspected.bytes);
    try f.memory(id, "base!", true);
    try std.testing.expectError(error.DiscardDecisionRequired, f.app.resolveExternal(id, .reload, false));
    try f.memory(id, "base!", true);
    _ = try f.app.resolveExternal(id, .reload, true);
    try f.memory(id, "disk", false);
    try f.app.session.edit(id, &.{.{ .start = 4, .end = 4, .inserted = "!" }});
    try f.put("replacement", "disk");
    try f.temp.dir.rename("replacement", f.temp.dir, "file", io);
    try std.testing.expectError(error.ExternalChange, f.app.saveFile(id, null));
    _ = try f.app.resolveExternal(id, .overwrite, false);
    try f.disk("file", "disk!");
    try f.memory(id, "disk!", false);
    try f.app.session.edit(id, &.{.{ .start = 5, .end = 5, .inserted = "?" }});
    try f.temp.dir.deleteFile(io, "file");
    try std.testing.expectError(error.ExternalChange, f.app.saveFile(id, null));
    try f.memory(id, "disk!?", true);
    try f.app.saveFile(id, "recovered");
    try f.disk("recovered", "disk!?");
    try f.memory(id, "disk!?", false);
}

test "ZIT-065/070 exact BOM LF CRLF CR mixed and no-final-newline save round trips" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    for ([_][]const u8{ "", "\xef\xbb\xbftext", "a\nb\n", "a\r\nb\r\n", "a\rb\r", "a\r\nb\nc\r", "no final newline", "é العربية\n" }, 0..) |bytes, i| {
        var name_buffer: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buffer, "file{d}", .{i});
        try f.put(name, bytes);
        const id = try f.app.openFile(name);
        try f.app.saveFile(id, null);
        try f.disk(name, bytes);
        try f.memory(id, bytes, false);
    }
}

test "ZIT-066/070 post-commit metadata failure reports committed outcome keeps edits and recovers" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.put("file", "base");
    const id = try f.app.openFile("file");
    try f.app.session.edit(id, &.{.{ .start = 4, .end = 4, .inserted = "!" }});
    var fault = Fault{ .stage = .committed_metadata };
    fault.install(&f.files);
    try std.testing.expectError(error.InjectedFailure, f.app.saveFile(id, null));
    try expect(f.files.last_failure.?.committed);
    try f.disk("file", "base!");
    try f.memory(id, "base!", true);
    f.files.checkpoint = null;
    try std.testing.expectError(error.ExternalChange, f.app.saveFile(id, null));
    _ = try f.app.resolveExternal(id, .overwrite, false);
    try f.memory(id, "base!", false);
    try f.noTemps();
}

const RacingWriter = struct {
    fixture: *Fixture,
    create_only: bool = false,
    fn call(raw: *anyopaque, stage: adapters.FileStage) !void {
        const self: *RacingWriter = @ptrCast(@alignCast(raw));
        if (stage == .rename) try self.fixture.put(if (self.create_only) "new" else "file", "raced");
    }
};
test "ZIT-067/068 concurrent destination creation and edit during save preparation preserve both sides" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.put("file", "base");
    const id = try f.app.openFile("file");
    try f.app.session.edit(id, &.{.{ .start = 4, .end = 4, .inserted = "!" }});
    var writer = RacingWriter{ .fixture = &f };
    f.files.checkpoint = .{ .context = &writer, .call = RacingWriter.call };
    try std.testing.expectError(error.ExternalChange, f.app.saveFile(id, null));
    try f.disk("file", "raced");
    try f.memory(id, "base!", true);
    try f.noTemps();
    writer.create_only = true;
    try std.testing.expectError(error.DestinationExists, f.app.saveFile(id, "new"));
    try f.disk("new", "raced");
    try f.memory(id, "base!", true);
    try f.noTemps();
}

test "ZIT-067/070 real read-only destination symlink collision and failed reload preserve state" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.put("file", "base");
    const file = try f.temp.dir.openFile(io, "file", .{});
    defer file.close(io);
    try file.setPermissions(io, .fromMode(0o400));
    const id = try f.app.openFile("file");
    try f.app.session.edit(id, &.{.{ .start = 4, .end = 4, .inserted = "!" }});
    try std.testing.expectError(error.AccessDenied, f.app.saveFile(id, null));
    try f.disk("file", "base");
    try f.memory(id, "base!", true);
    try f.temp.dir.symLink(io, "file", "alias", .{});
    try std.testing.expectError(error.DestinationExists, f.app.saveFile(id, "alias"));
    try file.setPermissions(io, .fromMode(0o600));
    try f.put("file", "\xff");
    try std.testing.expectError(error.InvalidUtf8, f.app.resolveExternal(id, .reload, true));
    try f.memory(id, "base!", true);
    try f.disk("file", "\xff");
    try f.app.saveFile(id, "recovery");
    try f.disk("recovery", "base!");
    try f.disk("file", "\xff");
}

extern "c" fn fsetxattr(c_int, [*:0]const u8, [*]const u8, usize, u32, c_int) c_int;
extern "c" fn fgetxattr(c_int, [*:0]const u8, [*]u8, usize, u32, c_int) isize;
test "ZIT-067 macOS replacement preserves extended attributes and resource-fork bytes" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.put("file", "base");
    const source = try f.temp.dir.openFile(io, "file", .{});
    defer source.close(io);
    try expect(fsetxattr(source.handle, "org.zigide.fixture", "metadata", 8, 0, 0) == 0);
    try expect(fsetxattr(source.handle, "com.apple.ResourceFork", "fork", 4, 0, 0) == 0);
    const id = try f.app.openFile("file");
    try f.app.session.edit(id, &.{.{ .start = 4, .end = 4, .inserted = "!" }});
    try f.app.saveFile(id, null);
    try f.disk("file", "base!");
    const replacement = try f.temp.dir.openFile(io, "file", .{});
    defer replacement.close(io);
    var buffer: [32]u8 = undefined;
    const n = fgetxattr(replacement.handle, "org.zigide.fixture", &buffer, buffer.len, 0, 0);
    try expect(n == 8);
    try equal("metadata", buffer[0..8]);
    const fork_n = fgetxattr(replacement.handle, "com.apple.ResourceFork", &buffer, buffer.len, 0, 0);
    try expect(fork_n == 4);
    try equal("fork", buffer[0..4]);
}
