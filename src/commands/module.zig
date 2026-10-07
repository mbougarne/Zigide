//! UI-independent typed command dispatch and registration ownership.
pub const Registry = @import("registry.zig").Registry;
pub const Handler = @import("registry.zig").Handler;
pub const Registration = @import("registry.zig").Registration;
pub const Arguments = @import("registry.zig").Arguments;
pub const DispatchError = @import("registry.zig").DispatchError;

test {
    _ = @import("registry.zig");
    _ = @import("dispatch_tests.zig");
}
