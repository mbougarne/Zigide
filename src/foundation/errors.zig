//! Safe metadata alongside ordinary Zig error unions. Boundary code maps its
//! concrete error to a category; it must not copy raw payloads/paths into context.
const ids = @import("ids.zig");
const std = @import("std");

pub const Category = enum { cancelled, invalid_input, not_found, permission_denied, unavailable, out_of_memory, internal };
pub const Operation = enum { read_resource, write_resource, execute_command, background_work };

/// Allocation-free, copyable context. Resource IDs refer to application-owned
/// identities, never paths, URIs, prompts, document contents or credentials.
pub const Failure = struct {
    category: Category,
    operation: Operation,
    operation_id: ids.OperationId,
    resource_id: ?ids.ResourceId = null,

    /// Fixed text is safe for UI and logs; details stay in the owning service.
    pub fn message(self: Failure) []const u8 {
        return switch (self.category) {
            .cancelled => "Operation cancelled.",
            .invalid_input => "Invalid input.",
            .not_found => "Resource not found.",
            .permission_denied => "Permission denied.",
            .unavailable => "Service unavailable.",
            .out_of_memory => "Not enough memory.",
            .internal => "Operation failed.",
        };
    }
};

test "boundary failures retain safe context alongside Zig errors" {
    const Boundary = struct {
        fn read(failure: *?Failure, operation_id: ids.OperationId, resource_id: ids.ResourceId) error{AccessDenied}!void {
            failure.* = .{ .category = .permission_denied, .operation = .read_resource, .operation_id = operation_id, .resource_id = resource_id };
            return error.AccessDenied;
        }
    };
    var failure: ?Failure = null;
    try std.testing.expectError(error.AccessDenied, Boundary.read(&failure, @enumFromInt(7), @enumFromInt(9)));
    try std.testing.expectEqual(@as(ids.OperationId, @enumFromInt(7)), failure.?.operation_id);
    try std.testing.expectEqual(@as(?ids.ResourceId, @enumFromInt(9)), failure.?.resource_id);
    try std.testing.expectEqualStrings("Permission denied.", failure.?.message());
}
