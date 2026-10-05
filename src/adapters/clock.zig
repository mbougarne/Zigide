const std = @import("std");
const foundation = @import("foundation");

/// Borrows the process I/O runtime. Both runtime and adapter must outlive the
/// clock interface. No allocation or adapter-specific deinitialization is needed.
pub const SystemClock = struct {
    io: std.Io,

    pub fn clock(self: *const SystemClock) foundation.clock.Clock {
        return .{ .context = self, .wall_fn = wall, .monotonic_fn = monotonic };
    }

    fn wall(context: *const anyopaque) foundation.clock.WallTime {
        const self: *const SystemClock = @ptrCast(@alignCast(context));
        return .{ .ns = std.Io.Clock.real.now(self.io).nanoseconds };
    }

    fn monotonic(context: *const anyopaque) foundation.clock.MonotonicTime {
        const self: *const SystemClock = @ptrCast(@alignCast(context));
        return .{ .ns = std.Io.Clock.awake.now(self.io).nanoseconds };
    }
};

test "production clock provides wall and nondecreasing monotonic time" {
    const adapter: SystemClock = .{ .io = std.testing.io };
    const clock = adapter.clock();
    try std.testing.expect(clock.wall().ns > 0);
    const before = clock.monotonic();
    try std.testing.expect(clock.monotonic().ns >= before.ns);
}
