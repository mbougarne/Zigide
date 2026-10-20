//! Zero-based UTF-8 byte endpoints, versioned independently of input devices.
const semantics = @import("semantics.zig");
const Document = @import("document.zig").Document;

pub const Endpoints = struct { anchor: usize, active: usize };
pub const Direction = enum { empty, forward, reverse };
pub const Selection = struct {
    anchor: usize = 0,
    active: usize = 0,
    version: u64 = 0,

    pub fn init(model: anytype, values: Endpoints, version: u64) !Selection {
        _ = try model.position(values.anchor);
        _ = try model.position(values.active);
        return .{ .anchor = values.anchor, .active = values.active, .version = version };
    }
    pub fn fromPositions(model: *const Document, anchor: semantics.Position, active: semantics.Position) !Selection {
        return init(model, .{ .anchor = try model.offset(anchor), .active = try model.offset(active) }, model.version);
    }
    pub fn validate(self: Selection, model: *const Document) !void {
        if (self.version != model.version) return error.StaleSelection;
        _ = try model.position(self.anchor);
        _ = try model.position(self.active);
    }
    pub fn direction(self: Selection) Direction {
        return if (self.anchor == self.active) .empty else if (self.anchor < self.active) .forward else .reverse;
    }
    pub fn range(self: Selection) semantics.Range {
        return semantics.Range.normalized(self.anchor, self.active);
    }
    pub fn endpoints(self: Selection) Endpoints {
        return .{ .anchor = self.anchor, .active = self.active };
    }
    pub fn eql(self: Selection, other: Selection) bool {
        return self.anchor == other.anchor and self.active == other.active and self.version == other.version;
    }
    /// Edits are normalized, disjoint, in original coordinates. Both endpoints
    /// have right affinity: an insertion/replacement at an endpoint moves it to
    /// the inserted text's end; an endpoint inside removed text collapses there.
    pub fn transformed(self: Selection, edits: []const semantics.Edit, version: u64) Selection {
        return .{ .anchor = transform(self.anchor, edits), .active = transform(self.active, edits), .version = version };
    }
    fn transform(at: usize, edits: []const semantics.Edit) usize {
        var removed: usize = 0;
        var inserted: usize = 0;
        for (edits) |edit| {
            if (at < edit.start) break;
            if (at <= edit.end) return edit.start - removed + inserted + edit.inserted.len;
            removed += edit.end - edit.start;
            inserted += edit.inserted.len;
        }
        return at - removed + inserted;
    }
};
