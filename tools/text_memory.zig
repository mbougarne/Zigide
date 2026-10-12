//! Requested-byte accounting around the benchmark allocator; excludes allocator metadata/RSS.
const std = @import("std");
pub const Meter = struct {
    backing: std.mem.Allocator,
    current: usize = 0,
    peak: usize = 0,
    pub fn allocator(self: *Meter) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn change(self: *Meter, old: usize, new: usize) void {
        self.current = self.current - old + new;
        self.peak = @max(self.peak, self.current);
    }
    fn alloc(raw: *anyopaque, length: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Meter = @ptrCast(@alignCast(raw));
        const result = self.backing.rawAlloc(length, alignment, ret) orelse return null;
        self.change(0, length);
        return result;
    }
    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, length: usize, ret: usize) bool {
        const self: *Meter = @ptrCast(@alignCast(raw));
        if (!self.backing.rawResize(bytes, alignment, length, ret)) return false;
        self.change(bytes.len, length);
        return true;
    }
    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, length: usize, ret: usize) ?[*]u8 {
        const self: *Meter = @ptrCast(@alignCast(raw));
        const result = self.backing.rawRemap(bytes, alignment, length, ret) orelse return null;
        self.change(bytes.len, length);
        return result;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Meter = @ptrCast(@alignCast(raw));
        self.backing.rawFree(bytes, alignment, ret);
        self.change(bytes.len, 0);
    }
};

test "memory meter observes requested bytes and temporary peak" {
    var meter: Meter = .{ .backing = std.testing.allocator };
    const allocator = meter.allocator();
    const one = try allocator.alloc(u8, 100);
    const two = try allocator.alloc(u8, 200);
    try std.testing.expectEqual(@as(usize, 300), meter.current);
    try std.testing.expectEqual(@as(usize, 300), meter.peak);
    allocator.free(one);
    allocator.free(two);
    try std.testing.expectEqual(@as(usize, 0), meter.current);
}
