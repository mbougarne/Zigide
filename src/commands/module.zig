//! UI-independent command registration and lookup.
pub const Registry = @import("registry.zig").Registry;
pub const Handler = @import("registry.zig").Handler;

test {
    _ = @import("registry.zig");
}
