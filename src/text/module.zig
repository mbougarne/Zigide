//! Storage-independent text contracts and the Milestone 0 storage candidates.
pub const Position = @import("semantics.zig").Position;
pub const Edit = @import("semantics.zig").Edit;
pub const Reference = @import("reference.zig").Reference;
pub const PieceTable = @import("piece_table.zig").PieceTable;
test {
    _ = @import("model_tests.zig");
}
