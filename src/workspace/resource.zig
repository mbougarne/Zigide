//! Owned physical, absolute paths supplied by a filesystem resolver.
const std = @import("std");

pub const Resource = struct {
    allocator: std.mem.Allocator,
    path: []const u8,

    /// Only resolvers may establish filesystem equivalence. This checks the
    /// canonical representation; it does not resolve links or fold case.
    pub fn initCanonical(allocator: std.mem.Allocator, path: []const u8) !Resource {
        if (path.len == 0 or path[0] != '/' or std.mem.indexOfScalar(u8, path, 0) != null) return error.InvalidPath;
        if (path.len > 1) {
            var parts = std.mem.splitScalar(u8, path[1..], '/');
            while (parts.next()) |part| {
                if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return error.InvalidPath;
            }
        }
        return .{ .allocator = allocator, .path = try allocator.dupe(u8, path) };
    }
    pub fn clone(self: Resource, allocator: std.mem.Allocator) !Resource {
        return initCanonical(allocator, self.path);
    }
    pub fn deinit(self: *Resource) void {
        self.allocator.free(self.path);
        self.* = undefined;
    }
    pub fn eql(self: Resource, other: Resource) bool {
        return std.mem.eql(u8, self.path, other.path);
    }
    pub fn contains(self: Resource, other: Resource) bool {
        if (self.eql(other)) return true;
        if (std.mem.eql(u8, self.path, "/")) return true;
        return other.path.len > self.path.len and std.mem.startsWith(u8, other.path, self.path) and other.path[self.path.len] == '/';
    }
};

test "ZIT-052 canonical representation and component boundaries" {
    const a = std.testing.allocator;
    var root = try Resource.initCanonical(a, "/work");
    defer root.deinit();
    var inside = try Resource.initCanonical(a, "/work/é.zig");
    defer inside.deinit();
    var sibling = try Resource.initCanonical(a, "/workspace/file");
    defer sibling.deinit();
    var different_case = try Resource.initCanonical(a, "/Work");
    defer different_case.deinit();
    try std.testing.expect(root.contains(inside));
    try std.testing.expect(root.contains(root));
    try std.testing.expect(!root.contains(sibling));
    try std.testing.expect(!root.eql(different_case));
    for ([_][]const u8{ "", "relative", "/work/", "/work//file", "/work/../file", "/./work", "/x\x00y" }) |path|
        try std.testing.expectError(error.InvalidPath, Resource.initCanonical(a, path));
}
