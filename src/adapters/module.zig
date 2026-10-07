//! Platform and protocol implementations of the application ports.

comptime {
    _ = @import("foundation");
    _ = @import("ports");
}

pub const DiscardLog = @import("discard_log.zig").DiscardLog;

pub const SystemClock = @import("clock.zig").SystemClock;

test {
    _ = @import("clock.zig");
}
