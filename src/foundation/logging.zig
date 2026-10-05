const clocks = @import("clock.zig");
const ids = @import("ids.zig");
const errors = @import("errors.zig");
const std = @import("std");

pub const Severity = enum { debug, info, warning, err };
pub const Subsystem = enum { foundation, application, workspace, commands, protocol };
pub const Name = enum { operation_started, operation_completed, operation_failed, operation_cancelled };

/// Closed, bounded schema: no free-form messages, paths, payloads, environment
/// dumps, prompts, or tokens. Adding fields requires an explicit privacy review.
pub const Event = struct {
    timestamp: clocks.WallTime,
    severity: Severity,
    subsystem: Subsystem,
    name: Name,
    correlation_id: ids.CorrelationId,
    failure: ?errors.Failure,
};

/// Borrowed synchronous sink; context outlives calls. A retaining sink copies
/// events and owns its own storage/cleanup. Implementations handle their own I/O.
pub const Sink = struct {
    context: *anyopaque,
    write: *const fn (*anyopaque, Event) error{Unavailable}!void,
};

/// Allocation-free, application-thread-only facade. Sink replacement is explicit.
/// Failed writes return false and never interrupt the caller's editing operation.
pub const Logger = struct {
    clock: clocks.Clock,
    sink: Sink,
    debug_enabled: bool = false,

    pub fn emit(self: Logger, severity: Severity, subsystem: Subsystem, name: Name, correlation_id: ids.CorrelationId, failure: ?errors.Failure) bool {
        if (severity == .debug and !self.debug_enabled) return true;
        self.sink.write(self.sink.context, .{
            .timestamp = self.clock.wall(),
            .severity = severity,
            .subsystem = subsystem,
            .name = name,
            .correlation_id = correlation_id,
            .failure = failure,
        }) catch return false;
        return true;
    }
};

test "structured events preserve metadata, support replacement, and contain sink failures" {
    const Capture = struct {
        event: ?Event = null,
        fn write(context: *anyopaque, event: Event) error{Unavailable}!void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.event = event;
        }
        fn fail(_: *anyopaque, _: Event) error{Unavailable}!void {
            return error.Unavailable;
        }
    };
    var clock: clocks.ManualClock = .{ .wall_time = .{ .ns = 123 } };
    var capture: Capture = .{};
    var logger: Logger = .{ .clock = clock.clock(), .sink = .{ .context = &capture, .write = Capture.write } };
    const correlation: ids.CorrelationId = @enumFromInt(42);
    try std.testing.expect(logger.emit(.debug, .foundation, .operation_started, correlation, null));
    try std.testing.expect(capture.event == null);
    const failure: errors.Failure = .{ .category = .not_found, .operation = .read_resource, .operation_id = @enumFromInt(5), .resource_id = @enumFromInt(6) };
    try std.testing.expect(logger.emit(.err, .workspace, .operation_failed, correlation, failure));
    try std.testing.expectEqualDeep(Event{ .timestamp = .{ .ns = 123 }, .severity = .err, .subsystem = .workspace, .name = .operation_failed, .correlation_id = correlation, .failure = failure }, capture.event.?);
    logger.sink.write = Capture.fail;
    try std.testing.expect(!logger.emit(.info, .application, .operation_completed, correlation, null));
    logger.sink.write = Capture.write;
    logger.debug_enabled = true;
    try std.testing.expect(logger.emit(.debug, .foundation, .operation_started, correlation, null));
    try std.testing.expectEqual(Severity.debug, capture.event.?.severity);
}
