//! Foundational identifiers, clocks, cancellation, events, errors, logging, and lifetimes.
pub const ids = @import("ids.zig");
pub const clock = @import("clock.zig");
pub const cancellation = @import("cancellation.zig");
pub const events = @import("events.zig");
pub const errors = @import("errors.zig");
pub const logging = @import("logging.zig");

test {
    _ = ids;
    _ = clock;
    _ = cancellation;
    _ = events;
    _ = errors;
    _ = logging;
    _ = @import("lifetime_tests.zig");
}
