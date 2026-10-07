//! Borrowed, application-facing contracts. No platform or UI imports.
const std = @import("std");
const foundation = @import("foundation");

pub const Error = error{ NotFound, AccessDenied, Unavailable, OutOfMemory, Cancelled, Pending, DeadlineExceeded, InvalidRequest, Busy };
pub const Request = struct {
    cancellation: foundation.cancellation.Token,
    deadline: foundation.clock.MonotonicTime,

    pub fn check(self: Request, clock: foundation.clock.Clock) Error!void {
        try self.cancellation.check();
        if (clock.monotonic().ns >= self.deadline.ns) return error.DeadlineExceeded;
    }
};

/// File and storage services use separate instances of this byte-oriented port.
/// Reads transfer an allocation to the caller; writes copy bytes before return.
/// Pending has no side effects and may be retried with the same request.
pub const BlobStore = struct {
    context: *anyopaque,
    read: *const fn (*anyopaque, std.mem.Allocator, []const u8, Request) Error![]u8,
    write: *const fn (*anyopaque, []const u8, []const u8, Request) Error!void,
};

pub const ProcessId = enum(u64) { _ };
pub const Process = struct {
    context: *anyopaque,
    start: *const fn (*anyopaque, []const []const u8, Request) Error!ProcessId,
    poll: *const fn (*anyopaque, ProcessId, Request) Error!?u8,
    terminate: *const fn (*anyopaque, ProcessId) Error!void,
};

/// Queued callbacks borrow their context until run or discarded by their owner.
/// Adapters marshal work to the application thread. Cancellation suppresses it.
pub const Task = struct {
    context: *anyopaque,
    run: *const fn (*anyopaque) void,
    cancellation: foundation.cancellation.Token,
};
pub const Scheduler = struct {
    context: *anyopaque,
    post: *const fn (*anyopaque, Task) Error!void,
};
