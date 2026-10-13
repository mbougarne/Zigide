//! Shared, deterministic UI-spike contract. No toolkit types enter product modules.
const std = @import("std");

pub const line = "const café = \"日本語 😀 é\"; // needle\n";
pub const line_count = 100_000;
pub const clipboard_text = "café 😀\n日本語\né\n";
pub const width = 1100;
pub const height = 760;
pub const explorer_width = 220;
pub const panel_height = 140;

pub const Criterion = enum { input, accessibility, performance, packaging, zig_ownership, maintenance };

pub const weights = [_]u8{ 35, 25, 15, 10, 10, 5 };

pub const Observation = enum { unverified, failed, partial, passed };

pub const Assessment = struct {
    observations: [weights.len]Observation,

    pub fn score(self: Assessment) u16 {
        var result: u16 = 0;
        for (self.observations, weights) |observation, weight| {
            result += @as(u16, weight) * switch (observation) {
                .unverified, .failed => @as(u16, 0),
                .partial => @as(u16, 1),
                .passed => @as(u16, 2),
            };
        }
        return result;
    }

    pub fn productionEligible(self: Assessment) bool {
        return self.observations[@intFromEnum(Criterion.input)] == .passed and
            self.observations[@intFromEnum(Criterion.accessibility)] == .passed;
    }
};

pub const Result = struct {
    version: u64,
    matches: usize,
    cancelled: bool = false,

    pub fn applies(self: Result, current_version: u64) bool {
        return !self.cancelled and self.version == current_version;
    }
};

pub fn fixture(allocator: std.mem.Allocator, lines: usize) ![]u8 {
    const size = try std.math.mul(usize, lines, line.len);
    const bytes = try allocator.alloc(u8, size);
    for (0..lines) |index| @memcpy(bytes[index * line.len ..][0..line.len], line);
    return bytes;
}

pub fn search(bytes: []const u8) usize {
    var matches: usize = 0;
    var offset: usize = 0;
    while (std.mem.indexOfPos(u8, bytes, offset, "needle")) |index| {
        matches += 1;
        offset = index + "needle".len;
    }
    return matches;
}

test "same large Unicode fixture and background result for every candidate" {
    const bytes = try fixture(std.testing.allocator, line_count);
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(std.unicode.utf8ValidateSlice(bytes));
    try std.testing.expectEqual(line_count, search(bytes));
    try std.testing.expectEqual(line_count * line.len, bytes.len);
    try std.testing.expect(std.mem.endsWith(u8, bytes, "\n"));
    try std.testing.expectError(error.Overflow, fixture(std.testing.allocator, std.math.maxInt(usize)));
}

test "input and accessibility dominate weights and gate production" {
    var assessment: Assessment = .{ .observations = @splat(.passed) };
    try std.testing.expectEqual(@as(u16, 200), assessment.score());
    try std.testing.expect(weights[0] + weights[1] > 50);
    try std.testing.expect(assessment.productionEligible());
    assessment.observations[0] = .unverified;
    try std.testing.expect(!assessment.productionEligible());
    assessment.observations[0] = .passed;
    assessment.observations[1] = .partial;
    try std.testing.expect(!assessment.productionEligible());
}

test "stale and cancelled background results cannot apply" {
    try std.testing.expect((Result{ .version = 7, .matches = 2 }).applies(7));
    try std.testing.expect(!(Result{ .version = 7, .matches = 2 }).applies(8));
    try std.testing.expect(!(Result{ .version = 7, .matches = 2, .cancelled = true }).applies(7));
}
