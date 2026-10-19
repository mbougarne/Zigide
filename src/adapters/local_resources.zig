//! Local existing-resource resolver. The macOS fd path preserves filesystem case
//! and Unicode spelling and resolves symlinks without lexical '..' shortcuts.
const std = @import("std");
const ports = @import("ports");

pub const LocalResources = struct {
    io: std.Io,

    pub fn port(self: *LocalResources) ports.Resources {
        return .{ .context = self, .resolve = resolve };
    }
    fn resolve(raw: *anyopaque, allocator: std.mem.Allocator, base: []const u8, input: []const u8, kind: ports.ResourceKind) ports.ResourceError!ports.Resource {
        const self: *LocalResources = @ptrCast(@alignCast(raw));
        if (input.len == 0 or std.mem.indexOfScalar(u8, input, 0) != null or std.mem.indexOfScalar(u8, base, 0) != null) return error.InvalidPath;
        if (!std.fs.path.isAbsolute(input) and !std.fs.path.isAbsolute(base)) return error.InvalidPath;
        const path = if (std.fs.path.isAbsolute(input)) try allocator.dupe(u8, input) else try std.fs.path.join(allocator, &.{ base, input });
        defer allocator.free(path);
        var buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
        const length = switch (kind) {
            .folder => blk: {
                const dir = std.Io.Dir.openDirAbsolute(self.io, path, .{ .iterate = true }) catch |err| return translate(err);
                defer dir.close(self.io);
                break :blk dir.realPath(self.io, &buffer) catch |err| return translate(err);
            },
            .file => blk: {
                // Use the resolver's nonblocking path handle, so a FIFO/device
                // cannot block folder-open merely while establishing its identity.
                const anchor = std.Io.Dir.openDirAbsolute(self.io, "/", .{}) catch |err| return translate(err);
                defer anchor.close(self.io);
                const n = anchor.realPathFile(self.io, path, &buffer) catch |err| return translate(err);
                const canonical = buffer[0..n];
                const stat = std.Io.Dir.cwd().statFile(self.io, canonical, .{}) catch |err| return translate(err);
                if (stat.kind != .file) return error.NotFile;
                std.Io.Dir.cwd().access(self.io, canonical, .{ .read = true }) catch |err| return translate(err);
                break :blk n;
            },
        };
        return ports.Resource.initCanonical(allocator, buffer[0..length]);
    }
    fn translate(err: anyerror) ports.ResourceError {
        return switch (err) {
            error.FileNotFound => error.NotFound,
            error.AccessDenied, error.PermissionDenied => error.AccessDenied,
            error.NotDir => error.NotDirectory,
            error.IsDir => error.NotFile,
            error.BadPathName, error.NameTooLong, error.SymLinkLoop, error.InvalidWtf8 => error.InvalidPath,
            error.OutOfMemory => error.OutOfMemory,
            else => error.Unavailable,
        };
    }
};

test "ZIT-052 resolver aliases symlinks dot paths case and escapes" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const io = std.testing.io;
    const a = std.testing.allocator;
    try temp.dir.createDir(io, "Folder", .default_dir);
    try temp.dir.createDir(io, "outside", .default_dir);
    try temp.dir.createDir(io, "outside/nested", .default_dir);
    try temp.dir.writeFile(io, .{ .sub_path = "Folder/Mixed.zig", .data = "text" });
    try temp.dir.writeFile(io, .{ .sub_path = "Folder/é.zig", .data = "unicode" });
    try temp.dir.writeFile(io, .{ .sub_path = "outside/other.zig", .data = "outside" });
    try temp.dir.symLink(io, "Folder", "alias", .{ .is_directory = true });
    try temp.dir.symLink(io, "../outside", "Folder/escape", .{ .is_directory = true });
    try temp.dir.symLink(io, "missing", "dangling", .{});
    try temp.dir.symLink(io, "outside/nested", "nested-alias", .{ .is_directory = true });
    try temp.dir.symLink(io, "cycle", "cycle", .{});
    var base_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const base = base_buffer[0..try temp.dir.realPath(io, &base_buffer)];
    var adapter: LocalResources = .{ .io = io };
    const p = adapter.port();
    var root = try p.resolve(p.context, a, base, "Folder/./", .folder);
    defer root.deinit();
    var alias = try p.resolve(p.context, a, base, "alias", .folder);
    defer alias.deinit();
    try std.testing.expect(root.eql(alias));
    var file = try p.resolve(p.context, a, base, "alias/../Folder/Mixed.zig", .file);
    defer file.deinit();
    try std.testing.expect(root.contains(file));
    var escaped = try p.resolve(p.context, a, base, "Folder/escape", .folder);
    defer escaped.deinit();
    try std.testing.expect(!root.contains(escaped));
    var physical_parent = try p.resolve(p.context, a, base, "nested-alias/../other.zig", .file);
    defer physical_parent.deinit();
    try std.testing.expect(std.mem.endsWith(u8, physical_parent.path, "/outside/other.zig"));
    var unicode = try p.resolve(p.context, a, base, "Folder/é.zig", .file);
    defer unicode.deinit();
    if (p.resolve(p.context, a, base, "Folder/e\xcc\x81.zig", .file)) |value| {
        var equivalent = value;
        defer equivalent.deinit();
        try std.testing.expect(unicode.eql(equivalent));
    } else |err| try std.testing.expectEqual(error.NotFound, err);
    // A case-sensitive volume rejects the alternate spelling; a case-insensitive
    // volume must return the same identity. Never assume the host's volume type.
    if (p.resolve(p.context, a, base, "folder/mixed.ZIG", .file)) |value| {
        var folded = value;
        defer folded.deinit();
        try std.testing.expect(file.eql(folded));
    } else |err| try std.testing.expectEqual(error.NotFound, err);
    try std.testing.expectError(error.NotFound, p.resolve(p.context, a, base, "dangling", .file));
    try std.testing.expectError(error.InvalidPath, p.resolve(p.context, a, base, "cycle", .file));
    try std.testing.expectError(error.NotFile, p.resolve(p.context, a, base, "Folder", .file));
    try std.testing.expectError(error.NotDirectory, p.resolve(p.context, a, base, "Folder/Mixed.zig", .folder));
    try std.testing.expectError(error.InvalidPath, p.resolve(p.context, a, base, "a\x00b", .file));
}
