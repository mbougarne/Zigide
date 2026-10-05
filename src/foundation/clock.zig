const std = @import("std");

/// Unix epoch nanoseconds; may jump backwards. Use only for timestamps.
pub const WallTime = struct { ns: i96 };
/// Nanoseconds from an unspecified origin; use only for elapsed time/deadlines.
pub const MonotonicTime = struct { ns: i96 };

/// Borrowed interface: context must outlive every call. No allocation or cleanup.
pub const Clock = struct {
    context: *const anyopaque,
    wall_fn: *const fn (*const anyopaque) WallTime,
    monotonic_fn: *const fn (*const anyopaque) MonotonicTime,

    pub fn wall(self: Clock) WallTime {
        return self.wall_fn(self.context);
    }

    pub fn monotonic(self: Clock) MonotonicTime {
        return self.monotonic_fn(self.context);
    }
};

/// Caller-owned test time. Set wall time independently to model clock corrections.
/// Keep at a stable address while its interface is borrowed; application-thread only.
pub const ManualClock = struct {
    wall_time: WallTime = .{ .ns = 0 },
    monotonic_time: MonotonicTime = .{ .ns = 0 },

    pub fn clock(self: *const ManualClock) Clock {
        return .{ .context = self, .wall_fn = readWall, .monotonic_fn = readMonotonic };
    }

    pub fn advance(self: *ManualClock, ns: u64) error{TimeOverflow}!void {
        const wall_ns = std.math.add(i96, self.wall_time.ns, ns) catch return error.TimeOverflow;
        const monotonic_ns = std.math.add(i96, self.monotonic_time.ns, ns) catch return error.TimeOverflow;
        self.wall_time.ns = wall_ns;
        self.monotonic_time.ns = monotonic_ns;
    }

    fn readWall(context: *const anyopaque) WallTime {
        const self: *const ManualClock = @ptrCast(@alignCast(context));
        return self.wall_time;
    }

    fn readMonotonic(context: *const anyopaque) MonotonicTime {
        const self: *const ManualClock = @ptrCast(@alignCast(context));
        return self.monotonic_time;
    }
};

test "manual time is deterministic and wall corrections do not change deadlines" {
    var time: ManualClock = .{};
    const clock = time.clock();
    try time.advance(42);
    time.wall_time.ns = -100;
    try std.testing.expectEqual(@as(i96, -100), clock.wall().ns);
    try std.testing.expectEqual(@as(i96, 42), clock.monotonic().ns);
    time.monotonic_time.ns = std.math.maxInt(i96);
    try std.testing.expectError(error.TimeOverflow, time.advance(1));
    try std.testing.expectEqual(@as(i96, -100), clock.wall().ns);
}
