//! Platform and protocol implementations of the application ports.

comptime {
    _ = @import("foundation");
    _ = @import("ports");
}

pub const DiscardLog = @import("discard_log.zig").DiscardLog;

pub const SystemClock = @import("clock.zig").SystemClock;

pub const framing = @import("protocol/framing.zig");
pub const transport = @import("protocol/transport.zig");
pub const rpc = @import("protocol/rpc.zig");

test {
    _ = framing;
    _ = rpc;
    _ = transport;
    _ = @import("clock.zig");
}
