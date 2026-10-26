//! macOS/POSIX local persistence. No user file is opened for truncation.
const std = @import("std");
const ports = @import("ports");
const builtin = @import("builtin");
// System copyfile.h: COPYFILE_METADATA = ACL | STAT | XATTR.
extern "c" fn fcopyfile(c_int, c_int, ?*anyopaque, u32) c_int;

pub const Stage = enum { read, destination, compare, create, write, sync, permissions, rename, committed_metadata };
pub const Failure = struct { stage: Stage, cause: anyerror, committed: bool = false };
/// Optional deterministic checkpoint used by disposable fault fixtures. Errors
/// go through the same cleanup and application transaction as real OS failures.
pub const Checkpoint = struct {
    context: *anyopaque,
    call: *const fn (*anyopaque, Stage) anyerror!void,
};
pub const LocalFiles = struct {
    io: std.Io,
    max_bytes: usize = 16 * 1024 * 1024,
    checkpoint: ?Checkpoint = null,
    last_failure: ?Failure = null,
    stage: Stage = .read,
    committed: bool = false,

    pub fn port(self: *LocalFiles) ports.SafeFiles {
        return .{ .context = self, .read = read, .destination = destination, .save = save };
    }
    fn at(self: *LocalFiles, stage: Stage) !void {
        self.stage = stage;
        if (self.checkpoint) |point| try point.call(point.context, stage);
    }
    fn fail(self: *LocalFiles, err: anyerror) void {
        self.last_failure = .{ .stage = self.stage, .cause = err, .committed = self.committed };
    }
    fn stamp(stat: std.Io.File.Stat) ports.FileStamp {
        return .{ .inode = @intCast(stat.inode), .size = stat.size, .mtime = stat.mtime.nanoseconds, .ctime = stat.ctime.nanoseconds, .mode = @intCast(stat.permissions.toMode()) };
    }
    fn regular(stat: std.Io.File.Stat) !void {
        if (stat.kind != .file) return error.NotFile;
    }
    fn read(raw: *anyopaque, allocator: std.mem.Allocator, path: []const u8) !ports.FileData {
        const self: *LocalFiles = @ptrCast(@alignCast(raw));
        self.last_failure = null;
        self.committed = false;
        errdefer |err| self.fail(err);
        try self.at(.read);
        // NONBLOCK prevents a raced-in FIFO from hanging admission. NOFOLLOW
        // rejects a replaced symlink; existing aliases are resolved upstream.
        const fd = try std.posix.openat(std.posix.AT.FDCWD, path, .{ .ACCMODE = .RDONLY, .NONBLOCK = true, .NOFOLLOW = true, .CLOEXEC = true }, 0);
        const file: std.Io.File = .{ .handle = fd, .flags = .{ .nonblocking = true } };
        defer file.close(self.io);
        const before = try file.stat(self.io);
        try regular(before);
        if (before.size > self.max_bytes) return error.FileTooLarge;
        var bytes: std.ArrayList(u8) = .empty;
        defer bytes.deinit(allocator);
        var buffer: [4096]u8 = undefined;
        while (true) {
            // Read one byte beyond the limit without allocating it.
            const remaining = self.max_bytes - bytes.items.len;
            const n = try file.readPositional(self.io, &.{buffer[0..@min(buffer.len, remaining +| 1)]}, bytes.items.len);
            if (n == 0) break;
            if (n > remaining) return error.FileTooLarge;
            try bytes.appendSlice(allocator, buffer[0..n]);
        }
        const after = try file.stat(self.io);
        if (!stamp(before).eql(stamp(after)) or bytes.items.len != after.size) return error.ExternalChange;
        const named = try std.Io.Dir.cwd().statFile(self.io, path, .{ .follow_symlinks = false });
        if (!stamp(after).eql(stamp(named))) return error.ExternalChange;
        if (!std.unicode.utf8ValidateSlice(bytes.items)) return error.InvalidUtf8;
        return .{ .allocator = allocator, .bytes = try bytes.toOwnedSlice(allocator), .stamp = stamp(after) };
    }
    fn destination(raw: *anyopaque, allocator: std.mem.Allocator, base: []const u8, input: []const u8) !ports.Resource {
        const self: *LocalFiles = @ptrCast(@alignCast(raw));
        self.last_failure = null;
        self.committed = false;
        errdefer |err| self.fail(err);
        try self.at(.destination);
        if (input.len == 0 or std.mem.indexOfScalar(u8, input, 0) != null) return error.InvalidPath;
        const joined = if (std.fs.path.isAbsolute(input)) try allocator.dupe(u8, input) else try std.fs.path.join(allocator, &.{ base, input });
        defer allocator.free(joined);
        const leaf = std.fs.path.basename(joined);
        if (leaf.len == 0 or std.mem.eql(u8, leaf, ".") or std.mem.eql(u8, leaf, "..") or joined[joined.len - 1] == '/') return error.InvalidPath;
        const parent = try std.Io.Dir.openDirAbsolute(self.io, std.fs.path.dirname(joined) orelse return error.InvalidPath, .{});
        defer parent.close(self.io);
        var buffer: [std.Io.Dir.max_path_bytes]u8 = undefined;
        const n = try parent.realPath(self.io, &buffer);
        const canonical = try std.fs.path.join(allocator, &.{ buffer[0..n], leaf });
        defer allocator.free(canonical);
        return ports.Resource.initCanonical(allocator, canonical);
    }
    fn compare(self: *LocalFiles, dir: std.Io.Dir, leaf: []const u8, expected: ?ports.FileStamp) !?std.Io.File.Stat {
        const current = dir.statFile(self.io, leaf, .{ .follow_symlinks = false }) catch |err| switch (err) {
            error.FileNotFound => {
                if (expected != null) return error.ExternalChange;
                return null;
            },
            else => return err,
        };
        if (expected == null) return error.DestinationExists;
        try regular(current);
        if (!expected.?.eql(stamp(current))) return error.ExternalChange;
        if (current.permissions.readOnly()) return error.AccessDenied;
        if (current.nlink != 1) return error.HardLinkedFile;
        return current;
    }
    fn save(raw: *anyopaque, path: []const u8, bytes: []const u8, expected: ?ports.FileStamp) !ports.FileStamp {
        const self: *LocalFiles = @ptrCast(@alignCast(raw));
        self.last_failure = null;
        self.committed = false;
        errdefer |err| self.fail(err);
        try self.at(.compare);
        if (bytes.len > self.max_bytes) return error.FileTooLarge;
        if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidUtf8;
        const dir = try std.Io.Dir.openDirAbsolute(self.io, std.fs.path.dirname(path) orelse return error.InvalidPath, .{});
        defer dir.close(self.io);
        const leaf = std.fs.path.basename(path);
        const original = try self.compare(dir, leaf, expected);
        // Require write access as well as parent rename access; never use atomic
        // replacement to bypass a read-only destination's access policy.
        if (original != null) try dir.access(self.io, leaf, .{ .write = true });
        try self.at(.create);
        var random: [16]u8 = undefined;
        self.io.random(&random);
        const name = ".zigide-save-" ++ std.fmt.bytesToHex(random, .lower);
        const temp = try dir.createFile(self.io, name, .{ .exclusive = true, .permissions = .fromMode(0o600) });
        defer temp.close(self.io);
        defer dir.deleteFile(self.io, name) catch |err| {
            if (err != error.FileNotFound) self.last_failure = .{ .stage = .create, .cause = err, .committed = self.committed };
        };
        // Bounded chunks let tests fail after a real partial temp write.
        var offset: usize = 0;
        while (offset < bytes.len) {
            try self.at(.write);
            const end = @min(bytes.len, offset + 4096);
            try temp.writePositionalAll(self.io, bytes[offset..end], offset);
            offset = end;
        }
        try self.at(.permissions);
        if (original) |value| {
            if (builtin.os.tag != .macos) return error.MetadataCopyUnsupported;
            const source_fd = try std.posix.openat(dir.handle, leaf, .{ .ACCMODE = .RDONLY, .NONBLOCK = true, .NOFOLLOW = true, .CLOEXEC = true }, 0);
            const source: std.Io.File = .{ .handle = source_fd, .flags = .{ .nonblocking = true } };
            defer source.close(self.io);
            if (!stamp(value).eql(stamp(try source.stat(self.io)))) return error.ExternalChange;
            // Copy security/stat/xattrs (including resource forks) onto the
            // replacement before commit; never silently discard macOS metadata.
            const rc = fcopyfile(source_fd, temp.handle, null, 0b111);
            if (rc != 0) return error.MetadataCopyFailed;
            try temp.setPermissions(self.io, .fromMode(value.permissions.toMode() & 0o777));
        }
        try self.at(.sync);
        try temp.sync(self.io);
        try self.at(.rename);
        // Compare again after preparing the complete replacement. This narrows,
        // but cannot eliminate, the external-writer race before rename.
        _ = try self.compare(dir, leaf, expected);
        if (expected == null) try dir.renamePreserve(name, dir, leaf, self.io) else try dir.rename(name, dir, leaf, self.io);
        self.committed = true;
        try self.at(.committed_metadata);
        return stamp(try temp.stat(self.io));
    }
};
