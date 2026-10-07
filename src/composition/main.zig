//! Executable composition root: selects adapters and owns their lifetimes.
const std = @import("std");
const application = @import("application");
const adapters = @import("adapters");

pub fn main(init: std.process.Init) !void {
    const clock: adapters.SystemClock = .{ .io = init.io };
    var log: adapters.DiscardLog = .{};
    var context = application.Context.init(init.gpa, .{
        .clock = clock.clock(),
        .log_sink = log.sink(),
    });
    defer context.deinit();
    try context.start(&.{});
    try context.shutdown(.{ .ns = clock.clock().monotonic().ns + std.time.ns_per_s });
}
