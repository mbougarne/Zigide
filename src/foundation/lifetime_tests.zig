const std = @import("std");
const Event = @import("events.zig").Event(u32);
const cancellation = @import("cancellation.zig");

const Context = struct {
    total: *u32,
    destroyed: *usize,
    own: ?Event.Subscription = null,
    other: ?Event.Subscription = null,
    emitter: ?*Event = null,
    nested: bool = false,
    add_once: bool = false,
    added: ?Event.Subscription = null,

    fn call(raw: *anyopaque, value: u32) void {
        const self: *Context = @ptrCast(@alignCast(raw));
        self.total.* += value;
        if (self.other) |other| other.dispose();
        if (self.own) |own| own.dispose();
        if (self.add_once) {
            self.add_once = false;
            self.added = self.emitter.?.subscribe(.{ .context = self, .call = addedCall, .destroy = noDestroy }) catch unreachable;
        }
        if (self.nested) {
            self.nested = false;
            self.emitter.?.dispatch(value + 1);
        }
        // This access after self-disposal/nested dispatch catches premature frees.
        self.total.* += 10;
    }

    fn addedCall(raw: *anyopaque, value: u32) void {
        const self: *Context = @ptrCast(@alignCast(raw));
        self.total.* += value * 100;
    }

    fn noDestroy(_: *anyopaque, _: std.mem.Allocator) void {}

    fn destroy(raw: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *Context = @ptrCast(@alignCast(raw));
        self.destroyed.* += 1;
        allocator.destroy(self);
    }
};

fn subscribe(emitter: *Event, total: *u32, destroyed: *usize) !struct { handle: Event.Subscription, context: *Context } {
    const context = try emitter.allocator.create(Context);
    errdefer emitter.allocator.destroy(context);
    context.* = .{ .total = total, .destroyed = destroyed };
    const handle = try emitter.subscribe(.{ .context = context, .call = Context.call, .destroy = Context.destroy });
    return .{ .handle = handle, .context = context };
}

test "dispatch order and removal before a callback's turn" {
    var emitter = Event.init(std.testing.allocator);
    defer emitter.deinit();
    var total: u32 = 0;
    var destroyed: usize = 0;
    const first = try subscribe(&emitter, &total, &destroyed);
    const second = try subscribe(&emitter, &total, &destroyed);
    first.context.other = second.handle;
    emitter.dispatch(1);
    try std.testing.expectEqual(@as(u32, 11), total);
    try std.testing.expectEqual(@as(usize, 1), destroyed);
    second.handle.dispose();
    first.handle.dispose();
    first.handle.dispose();
    try std.testing.expectEqual(@as(usize, 2), destroyed);
    emitter.dispatch(100);
    try std.testing.expectEqual(@as(u32, 11), total);
}

test "self-disposal defers destruction until nested and outer callbacks return" {
    var emitter = Event.init(std.testing.allocator);
    defer emitter.deinit();
    var total: u32 = 0;
    var destroyed: usize = 0;
    const first = try subscribe(&emitter, &total, &destroyed);
    const second = try subscribe(&emitter, &total, &destroyed);
    first.context.own = first.handle;
    first.context.emitter = &emitter;
    first.context.nested = true;
    emitter.dispatch(1);
    try std.testing.expectEqual(@as(u32, 34), total);
    try std.testing.expectEqual(@as(usize, 1), destroyed);
    second.handle.dispose();
    try std.testing.expectEqual(@as(usize, 2), destroyed);
}

test "new subscriptions wait until the next dispatch and disposed IDs never alias" {
    var emitter = Event.init(std.testing.allocator);
    defer emitter.deinit();
    var total: u32 = 0;
    var destroyed: usize = 0;
    const first = try subscribe(&emitter, &total, &destroyed);
    first.context.emitter = &emitter;
    first.context.add_once = true;
    emitter.dispatch(1);
    try std.testing.expectEqual(@as(u32, 11), total);
    emitter.dispatch(1);
    try std.testing.expectEqual(@as(u32, 122), total);
    first.context.added.?.dispose();
    first.handle.dispose();
    const next = try subscribe(&emitter, &total, &destroyed);
    first.handle.dispose();
    emitter.dispatch(1);
    try std.testing.expectEqual(@as(u32, 133), total);
    next.handle.dispose();
}

fn allocationPaths(allocator: std.mem.Allocator) !void {
    var emitter = Event.init(allocator);
    defer emitter.deinit();
    var total: u32 = 0;
    var destroyed: usize = 0;
    const first = try subscribe(&emitter, &total, &destroyed);
    _ = try subscribe(&emitter, &total, &destroyed);
    emitter.dispatch(1);
    first.handle.dispose();
    first.handle.dispose();
    try std.testing.expectEqual(@as(usize, 1), destroyed);
    // Remaining subscription is released by emitter deinit (abandonment).
}

test "all event allocation failures release nodes and caller-owned contexts" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationPaths, .{});
}

test "ID exhaustion preserves caller ownership and existing subscriptions" {
    var emitter = Event.init(std.testing.allocator);
    defer emitter.deinit();
    var total: u32 = 0;
    var destroyed: usize = 0;
    emitter.next_id = std.math.maxInt(u64);
    const last = try subscribe(&emitter, &total, &destroyed);
    try std.testing.expectError(error.IdExhausted, subscribe(&emitter, &total, &destroyed));
    emitter.dispatch(1);
    try std.testing.expectEqual(@as(u32, 11), total);
    last.handle.dispose();
    try std.testing.expectEqual(@as(usize, 1), destroyed);
}

const Outcome = enum { success, failure, cancellation, abandonment };
fn request(allocator: std.mem.Allocator, outcome: Outcome) !void {
    var source: cancellation.Source = .{};
    var emitter = Event.init(allocator);
    defer emitter.deinit();
    var total: u32 = 0;
    var destroyed: usize = 0;
    const subscription = try subscribe(&emitter, &total, &destroyed);
    defer subscription.handle.dispose();
    const buffer = try allocator.alloc(u8, 32);
    defer allocator.free(buffer);
    const token = source.token();
    switch (outcome) {
        .success => emitter.dispatch(1),
        .failure => return error.RequestFailed,
        .cancellation => {
            _ = source.cancel();
            try token.check();
        },
        .abandonment => {
            _ = source.cancel();
            return;
        },
    }
}

fn requestPaths(allocator: std.mem.Allocator) !void {
    try request(allocator, .success);
    request(allocator, .failure) catch |err| switch (err) {
        error.RequestFailed => {},
        else => return err,
    };
    request(allocator, .cancellation) catch |err| switch (err) {
        error.Cancelled => {},
        else => return err,
    };
    try request(allocator, .abandonment);
}

test "request resources are released on success failure cancellation abandonment and OOM" {
    try std.testing.expectError(error.RequestFailed, request(std.testing.allocator, .failure));
    try std.testing.expectError(error.Cancelled, request(std.testing.allocator, .cancellation));
    try std.testing.checkAllAllocationFailures(std.testing.allocator, requestPaths, .{});
}

test "worker signals cancellation across threads and is joined before cleanup" {
    const Worker = struct {
        fn run(source: *cancellation.Source) void {
            _ = source.cancel();
            _ = source.cancel();
        }
    };
    var source: cancellation.Source = .{};
    const token = source.token();
    try token.check();
    const thread = try std.Thread.spawn(.{}, Worker.run, .{&source});
    thread.join();
    try std.testing.expectError(error.Cancelled, token.check());
}

test "emitter cleanup destroys every remaining context exactly once" {
    var emitter = Event.init(std.testing.allocator);
    var total: u32 = 0;
    var destroyed: usize = 0;
    const first = try subscribe(&emitter, &total, &destroyed);
    _ = try subscribe(&emitter, &total, &destroyed);
    first.handle.dispose();
    first.handle.dispose();
    emitter.deinit();
    try std.testing.expectEqual(@as(usize, 2), destroyed);
}
