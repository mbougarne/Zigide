//! Production domain text model and retained independent spike oracles.
pub const Position = @import("semantics.zig").Position;
pub const Range = @import("semantics.zig").Range;
pub const comparePositions = @import("semantics.zig").comparePositions;
pub const Document = @import("document.zig").Document;
pub const Snapshot = @import("document.zig").Snapshot;
pub const Metadata = @import("metadata.zig").Metadata;
pub const Endings = @import("metadata.zig").Endings;
pub const Edit = @import("semantics.zig").Edit;
pub const Reference = @import("reference.zig").Reference;
pub const PieceTable = @import("piece_table.zig").PieceTable;
pub const Selection = @import("selection.zig").Selection;
pub const SelectionEndpoints = @import("selection.zig").Endpoints;
pub const History = @import("history.zig").History;
pub const HistoryLimits = @import("history.zig").Limits;
pub const EditTransaction = @import("history.zig").Request;
pub const EditCommand = @import("history.zig").Command;
pub const HistoryOutcome = @import("history.zig").Outcome;
test {
    _ = @import("model_tests.zig");
    _ = @import("storage.zig");
    _ = @import("semantics.zig");
    _ = @import("document.zig");
    _ = @import("history_tests.zig");
}
