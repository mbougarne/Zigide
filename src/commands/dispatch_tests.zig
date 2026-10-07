const std = @import("std");
const command = @import("registry.zig");
const Source = @import("foundation").cancellation.Source;

const Fixture = struct {
    calls: usize = 0,
    enabled: bool = true,
    fail: bool = false,
    handle: ?command.Registration = null,
    source: Source = .{},
    cancel_on_enable: bool = false,
    close_on_validate: bool = false,

    fn handler(self: *Fixture) command.Handler {
        return .{ .context = self, .argument_kind = .integer, .validate = validate, .enabled = isEnabled, .call = run };
    }
    fn validate(raw: *anyopaque, args: command.Arguments) bool {
        const self: *Fixture = @ptrCast(@alignCast(raw));
        if (self.handle) |handle| {
            std.testing.expectError(error.CommandInUse, handle.dispose()) catch unreachable;
            if (self.close_on_validate) handle.registry.close();
        }
        return args.integer > 0;
    }
    fn isEnabled(raw: *anyopaque) bool {
        const self: *Fixture = @ptrCast(@alignCast(raw));
        if (self.cancel_on_enable) _ = self.source.cancel();
        return self.enabled;
    }
    fn run(raw: *anyopaque, args: command.Arguments, _: command.Token) !void {
        const self: *Fixture = @ptrCast(@alignCast(raw));
        self.calls += @intCast(args.integer);
        if (self.handle) |handle| {
            try std.testing.expectError(error.CommandInUse, handle.dispose());
            var buffer: [64]u8 = undefined;
            for (0..100) |index| {
                _ = try handle.registry.register(try std.fmt.bufPrint(&buffer, "test.growth{d}", .{index}), self.handler());
            }
        }
        if (self.fail) return error.ExpectedFailure;
    }
};

test "dispatch distinguishes missing invalid disabled cancelled and handler failure" {
    var registry = command.Registry.init(std.testing.allocator);
    defer registry.deinit();
    var fixture: Fixture = .{};
    _ = try registry.register("test.run", fixture.handler());
    const token = fixture.source.token();
    try std.testing.expectError(error.UnknownCommand, registry.dispatch("test.missing", .none, token));
    try std.testing.expectError(error.InvalidArguments, registry.dispatch("test.run", .{ .text = "1" }, token));
    try std.testing.expectError(error.InvalidArguments, registry.dispatch("test.run", .{ .integer = 0 }, token));
    fixture.enabled = false;
    try std.testing.expectError(error.DisabledCommand, registry.dispatch("test.run", .{ .integer = 1 }, token));
    try std.testing.expectEqual(@as(usize, 0), fixture.calls);
    fixture.enabled = true;
    try registry.dispatch("test.run", .{ .integer = 2 }, token);
    fixture.fail = true;
    try std.testing.expectError(error.HandlerFailed, registry.dispatch("test.run", .{ .integer = 1 }, token));
    _ = fixture.source.cancel();
    try std.testing.expectError(error.Cancelled, registry.dispatch("test.run", .{ .integer = 1 }, token));
    try std.testing.expectEqual(@as(usize, 3), fixture.calls);
}

test "callback lifetime pin covers validation dispatch and map growth" {
    var registry = command.Registry.init(std.testing.allocator);
    defer registry.deinit();
    var fixture: Fixture = .{};
    const handle = try registry.register("test.run", fixture.handler());
    fixture.handle = handle;
    try handle.dispatch(.{ .integer = 1 }, fixture.source.token());
    try handle.dispose();
    try handle.dispose();
    fixture.handle = null;
    const replacement = try registry.register("test.run", fixture.handler());
    try handle.dispose();
    try std.testing.expectError(error.UnknownCommand, handle.dispatch(.{ .integer = 1 }, fixture.source.token()));
    try replacement.dispatch(.{ .integer = 1 }, fixture.source.token());
    try std.testing.expectEqual(@as(usize, 2), fixture.calls);
    try std.testing.expectEqual(@as(usize, 101), registry.entries.count());
}

test "cancellation and shutdown from preconditions prevent handler invocation" {
    var registry = command.Registry.init(std.testing.allocator);
    defer registry.deinit();
    var fixture: Fixture = .{ .cancel_on_enable = true };
    const handle = try registry.register("test.run", fixture.handler());
    try std.testing.expectError(error.Cancelled, handle.dispatch(.{ .integer = 1 }, fixture.source.token()));
    fixture.source = .{};
    fixture.cancel_on_enable = false;
    fixture.close_on_validate = true;
    fixture.handle = handle;
    try std.testing.expectError(error.ShuttingDown, handle.dispatch(.{ .integer = 1 }, fixture.source.token()));
    try std.testing.expectError(error.ShuttingDown, registry.register("test.late", fixture.handler()));
    try std.testing.expectEqual(@as(usize, 0), fixture.calls);
    try handle.dispose();
}

test "disposed heap contexts are never reached by retained handles" {
    var registry = command.Registry.init(std.testing.allocator);
    defer registry.deinit();
    var source: Source = .{};
    const fixture = try std.testing.allocator.create(Fixture);
    fixture.* = .{};
    const handle = registry.register("test.owned", fixture.handler()) catch |err| {
        std.testing.allocator.destroy(fixture);
        return err;
    };
    try handle.dispose();
    std.testing.allocator.destroy(fixture);
    try std.testing.expectError(error.UnknownCommand, handle.dispatch(.{ .integer = 1 }, source.token()));
}

test "handler cancellation is classified and dispatch pins are always released" {
    const Cancel = struct {
        fn run(raw: *anyopaque, _: command.Arguments, token: command.Token) !void {
            const source: *Source = @ptrCast(@alignCast(raw));
            _ = source.cancel();
            try token.check();
        }
    };
    var registry = command.Registry.init(std.testing.allocator);
    defer registry.deinit();
    var source: Source = .{};
    const handle = try registry.register("test.cancel", .{ .context = &source, .call = Cancel.run });
    try std.testing.expectError(error.Cancelled, handle.dispatch(.none, source.token()));
    try std.testing.expectEqual(@as(usize, 0), registry.active_dispatches);
    try handle.dispose();
}
