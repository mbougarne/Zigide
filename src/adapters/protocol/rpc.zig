//! JSON-RPC prototype: bounded numeric outgoing IDs and borrowed request lifetimes.
const std = @import("std");
const foundation = @import("foundation");
const ports = @import("ports");
pub const Id = foundation.ids.CorrelationId;
pub const Kind = enum { request, notification, result, remote_error };
pub const Message = struct {
    parsed: std.json.Parsed(std.json.Value),
    kind: Kind,

    pub fn deinit(self: *Message) void {
        self.parsed.deinit();
    }
    pub fn id(self: Message) ?Id {
        const value = self.parsed.value.object.get("id") orelse return null;
        if (value != .integer or value.integer <= 0) return null;
        return @enumFromInt(@as(u64, @intCast(value.integer)));
    }
};

pub fn decode(allocator: std.mem.Allocator, payload: []const u8, limit: usize) !Message {
    if (payload.len > limit) return error.PayloadTooLarge;
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, payload, .{ .allocate = .alloc_always, .duplicate_field_behavior = .@"error" }) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return error.InvalidMessage,
    };
    errdefer parsed.deinit();
    if (parsed.value != .object) return error.InvalidMessage;
    const object = parsed.value.object;
    const version = object.get("jsonrpc") orelse return error.InvalidMessage;
    if (version != .string or !std.mem.eql(u8, version.string, "2.0")) return error.InvalidMessage;
    const id = object.get("id");
    if (id) |value| switch (value) {
        .integer, .string, .null => {},
        else => return error.InvalidMessage,
    };
    const result = object.get("result");
    const remote_error = object.get("error");
    const kind: Kind = if (object.get("method")) |method| blk: {
        if (method != .string or result != null or remote_error != null) return error.InvalidMessage;
        if (object.get("params")) |params| {
            if (params != .object and params != .array) return error.InvalidMessage;
        }
        break :blk if (id != null) .request else .notification;
    } else blk: {
        if (id == null or (result == null) == (remote_error == null)) return error.InvalidMessage;
        if (remote_error) |value| {
            if (value != .object) return error.InvalidMessage;
            const code = value.object.get("code") orelse return error.InvalidMessage;
            const message = value.object.get("message") orelse return error.InvalidMessage;
            if (code != .integer or message != .string) return error.InvalidMessage;
        }
        break :blk if (remote_error != null) .remote_error else .result;
    };
    return .{ .parsed = parsed, .kind = kind };
}

pub const Outcome = enum { result, remote_error, cancelled, timed_out, ignored };
pub const Completion = struct { id: Id, outcome: Outcome };
pub const Correlator = struct {
    const Pending = struct { id: Id, request: ports.Request };
    pending: [64]?Pending = @splat(null),
    ids: foundation.ids.Generator(Id) = .{},

    pub fn begin(self: *Correlator, request: ports.Request, clock: foundation.clock.Clock) !Id {
        try request.check(clock);
        for (&self.pending) |*slot| {
            if (slot.* != null) continue;
            const id = try self.ids.next();
            // JSON integer IDs must survive common peers' IEEE-754 representations.
            if (@intFromEnum(id) > 9007199254740991) return error.IdExhausted;
            slot.* = .{ .id = id, .request = request };
            return id;
        }
        return error.TooManyPendingRequests;
    }

    pub fn complete(self: *Correlator, message: Message, clock: foundation.clock.Clock) Outcome {
        if (message.kind != .result and message.kind != .remote_error) return .ignored;
        const id = message.id() orelse return .ignored;
        for (&self.pending) |*slot| {
            const pending = slot.* orelse continue;
            if (pending.id != id) continue;
            slot.* = null;
            return terminal(pending.request, clock) orelse if (message.kind == .result) .result else .remote_error;
        }
        return .ignored;
    }

    /// Drain cancellations/deadlines before dispatch; send cancelPayload for each.
    pub fn poll(self: *Correlator, clock: foundation.clock.Clock) ?Completion {
        for (&self.pending) |*slot| {
            const pending = slot.* orelse continue;
            if (terminal(pending.request, clock)) |outcome| {
                slot.* = null;
                return .{ .id = pending.id, .outcome = outcome };
            }
        }
        return null;
    }

    pub fn abandon(self: *Correlator, id: Id) void {
        for (&self.pending) |*slot| if (slot.*) |pending| {
            if (pending.id == id) slot.* = null;
        };
    }

    /// Transport failure/shutdown releases all borrowed tokens. IDs are never reused.
    pub fn disconnect(self: *Correlator) void {
        self.pending = @splat(null);
    }

    pub fn count(self: *const Correlator) usize {
        var total: usize = 0;
        for (self.pending) |slot| if (slot != null) {
            total += 1;
        };
        return total;
    }

    fn terminal(request: ports.Request, clock: foundation.clock.Clock) ?Outcome {
        if (request.cancellation.isCancelled()) return .cancelled;
        if (clock.monotonic().ns >= request.deadline.ns) return .timed_out;
        return null;
    }
};

pub fn cancelPayload(allocator: std.mem.Allocator, id: Id) ![]u8 {
    return std.json.Stringify.valueAlloc(allocator, .{ .jsonrpc = "2.0", .method = "$/cancelRequest", .params = .{ .id = @intFromEnum(id) } }, .{});
}

test "responses cannot resurrect completed, cancelled, expired or unknown requests" {
    var clock: foundation.clock.ManualClock = .{};
    var source: foundation.cancellation.Source = .{};
    var correlator: Correlator = .{};
    const request: ports.Request = .{ .cancellation = source.token(), .deadline = .{ .ns = 10 } };
    const first = try correlator.begin(request, clock.clock());
    var result = try decode(std.testing.allocator, "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}", 1024);
    defer result.deinit();
    try std.testing.expectEqual(Outcome.result, correlator.complete(result, clock.clock()));
    try std.testing.expectEqual(Outcome.ignored, correlator.complete(result, clock.clock()));
    try std.testing.expectEqual(@as(usize, 0), correlator.count());
    const second = try correlator.begin(request, clock.clock());
    try std.testing.expect(second != first);
    _ = source.cancel();
    try std.testing.expectEqual(Outcome.cancelled, correlator.poll(clock.clock()).?.outcome);
    source = .{};
    _ = try correlator.begin(request, clock.clock());
    try clock.advance(10);
    try std.testing.expectEqual(Outcome.timed_out, correlator.poll(clock.clock()).?.outcome);
    try std.testing.expectEqual(@as(usize, 0), correlator.count());
    const payload = try cancelPayload(std.testing.allocator, second);
    defer std.testing.allocator.free(payload);
    var cancel = try decode(std.testing.allocator, payload, 1024);
    defer cancel.deinit();
    try std.testing.expectEqual(Kind.notification, cancel.kind);
}

test "JSON-RPC validates kinds and errors before touching bounded pending state" {
    const a = std.testing.allocator;
    const invalid = [_][]const u8{
        "[]",                                                                            "{}",                                                   "{\"jsonrpc\":\"1.0\",\"method\":\"x\"}",
        "{\"jsonrpc\":\"2.0\",\"method\":1}",                                            "{\"jsonrpc\":\"2.0\",\"id\":true,\"result\":null}",    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":0,\"error\":{}}",
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":\"bad\",\"message\":\"x\"}}", "{\"jsonrpc\":\"2.0\",\"id\":1,\"id\":2,\"result\":0}", "{\"jsonrpc\":\"2.0\",\"method\":\"x\",\"params\":4}",
    };
    for (invalid) |payload| try std.testing.expectError(error.InvalidMessage, decode(a, payload, 1024));
    var request = try decode(a, "{\"jsonrpc\":\"2.0\",\"id\":\"peer-id\",\"method\":\"work\",\"params\":[]}", 1024);
    defer request.deinit();
    try std.testing.expectEqual(Kind.request, request.kind);
    var clock: foundation.clock.ManualClock = .{};
    var source: foundation.cancellation.Source = .{};
    var correlator: Correlator = .{};
    defer correlator.disconnect();
    const pending: ports.Request = .{ .cancellation = source.token(), .deadline = .{ .ns = 100 } };
    for (0..64) |_| _ = try correlator.begin(pending, clock.clock());
    try std.testing.expectError(error.TooManyPendingRequests, correlator.begin(pending, clock.clock()));
    var unknown = try decode(a, "{\"jsonrpc\":\"2.0\",\"id\":99,\"result\":0}", 1024);
    defer unknown.deinit();
    try std.testing.expectEqual(Outcome.ignored, correlator.complete(unknown, clock.clock()));
    try std.testing.expectEqual(Outcome.ignored, correlator.complete(request, clock.clock()));
    try std.testing.expectEqual(@as(usize, 64), correlator.count());
    var remote_error = try decode(a, "{\"jsonrpc\":\"2.0\",\"id\":2,\"error\":{\"code\":-32601,\"message\":\"unknown method\"}}", 1024);
    defer remote_error.deinit();
    try std.testing.expectEqual(Outcome.remote_error, correlator.complete(remote_error, clock.clock()));
    var late = try decode(a, "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":0}", 1024);
    defer late.deinit();
    _ = source.cancel();
    try std.testing.expectEqual(Outcome.cancelled, correlator.complete(late, clock.clock()));
    try std.testing.expectEqual(Outcome.ignored, correlator.complete(late, clock.clock()));
    correlator.disconnect();
    try std.testing.expectEqual(@as(usize, 0), correlator.count());
    source = .{};
    const id = try correlator.begin(pending, clock.clock());
    correlator.abandon(id);
    try std.testing.expectEqual(@as(usize, 0), correlator.count());
    const expired_id = try correlator.begin(pending, clock.clock());
    const payload = try std.fmt.allocPrint(a, "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"result\":0}}", .{@intFromEnum(expired_id)});
    defer a.free(payload);
    var expired = try decode(a, payload, 1024);
    defer expired.deinit();
    try clock.advance(100);
    try std.testing.expectEqual(Outcome.timed_out, correlator.complete(expired, clock.clock()));
    try std.testing.expectEqual(Outcome.ignored, correlator.complete(expired, clock.clock()));
    try std.testing.expectEqual(@as(usize, 0), correlator.count());
}
