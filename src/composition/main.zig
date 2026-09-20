//! Executable composition root. Product services are wired by later milestone tickets.

pub fn main() void {
    _ = @import("application");
    _ = @import("adapters");
    _ = @import("ui");
}
