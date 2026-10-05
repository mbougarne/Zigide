const std = @import("std");

/// Caller-owned atomic cancellation state, with no heap resources. Keep at a
/// stable address and join all observers before ending its lifetime. Cancellation
/// does not join workers or make their result safe to apply; owners handle both.
pub const Source = struct {
    cancelled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn token(self: *const Source) Token {
        return .{ .source = self };
    }

    /// Safe across threads and idempotent. Returns true only on the first signal.
    pub fn cancel(self: *Source) bool {
        return !self.cancelled.swap(true, .release);
    }
};

/// Copyable borrowed observation handle. The source must outlive all token users.
pub const Token = struct {
    source: *const Source,

    pub fn isCancelled(self: Token) bool {
        return self.source.cancelled.load(.acquire);
    }

    pub fn check(self: Token) error{Cancelled}!void {
        if (self.isCancelled()) return error.Cancelled;
    }
};

test "cancellation is shared, idempotent and observable before or after token creation" {
    var source: Source = .{};
    const token = source.token();
    try token.check();
    try std.testing.expect(source.cancel());
    try std.testing.expect(!source.cancel());
    try std.testing.expect(token.isCancelled());
    try std.testing.expectError(error.Cancelled, source.token().check());
}
