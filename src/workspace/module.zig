//! Toolkit-independent resource, workspace and document lifecycle.
pub const Resource = @import("resource.zig").Resource;
test {
    _ = @import("resource.zig");
}

pub const lifecycle = @import("session.zig");
pub const Session = lifecycle.Session;
pub const Edit = lifecycle.Edit;
pub const Snapshot = lifecycle.Snapshot;
pub const DocumentId = lifecycle.DocumentId;
pub const ClosePolicy = lifecycle.ClosePolicy;
test {
    _ = lifecycle;
    _ = @import("session_tests.zig");
}
