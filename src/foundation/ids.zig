//! Process-local identifiers. Persisted or wire IDs require a separate contract.
const std = @import("std");

pub const OperationId = enum(u64) { _ };
pub const CorrelationId = enum(u64) { _ };
pub const ResourceId = enum(u64) { _ };

/// Caller-owned, allocation-free sequence. Inject one instance per ID domain;
/// seeds make tests deterministic. Application-thread only, never wraps/reuses IDs.
pub fn Generator(comptime Id: type) type {
    return struct {
        next_value: ?u64 = 1,
        const Self = @This();

        pub fn next(self: *Self) error{IdExhausted}!Id {
            const value = self.next_value orelse return error.IdExhausted;
            self.next_value = if (value == std.math.maxInt(u64)) null else value + 1;
            return @enumFromInt(value);
        }
    };
}

test "ID domains are distinct and generators are deterministic and bounded" {
    try std.testing.expect(OperationId != CorrelationId);
    try std.testing.expect(OperationId != ResourceId);
    var first: Generator(OperationId) = .{};
    var second: Generator(OperationId) = .{};
    try std.testing.expectEqual(try first.next(), try second.next());
    try std.testing.expectEqual(@as(u64, 2), @intFromEnum(try first.next()));
    var last: Generator(CorrelationId) = .{ .next_value = std.math.maxInt(u64) };
    try std.testing.expectEqual(std.math.maxInt(u64), @intFromEnum(try last.next()));
    try std.testing.expectError(error.IdExhausted, last.next());
    try std.testing.expectError(error.IdExhausted, last.next());
}
