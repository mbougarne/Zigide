const foundation = @import("foundation");

/// Explicit opt-out for the headless executable until log persistence is added.
/// No allocation or I/O. The adapter must outlive its borrowed sink interface.
pub const DiscardLog = struct {
    pub fn sink(self: *DiscardLog) foundation.logging.Sink {
        return .{ .context = self, .write = discard };
    }

    fn discard(_: *anyopaque, _: foundation.logging.Event) error{Unavailable}!void {}
};
