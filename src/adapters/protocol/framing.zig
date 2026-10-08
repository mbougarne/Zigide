//! Bounded Content-Length framing. A decoder owns at most one partial frame.
const std = @import("std");

pub const Limits = struct { header: usize = 8192, payload: usize = 1024 * 1024 };
pub const Error = error{ HeaderTooLarge, PayloadTooLarge, MalformedHeader, MissingLength, DuplicateLength, InvalidLength, TruncatedHeader, TruncatedBody, DecoderFailed } || std.mem.Allocator.Error;
pub const Chunk = struct { consumed: usize, payload: ?[]u8 = null };

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    limits: Limits,
    header: std.ArrayList(u8) = .empty,
    body: ?[]u8 = null,
    used: usize = 0,
    failed: bool = false,

    pub fn init(allocator: std.mem.Allocator, limits: Limits) Decoder {
        return .{ .allocator = allocator, .limits = limits };
    }

    pub fn deinit(self: *Decoder) void {
        self.header.deinit(self.allocator);
        if (self.body) |body| self.allocator.free(body);
        self.* = undefined;
    }

    /// Returns one owned payload and its consumed byte count. Re-feed the remainder.
    /// On error discard the connection; framing cannot safely resynchronize.
    pub fn feed(self: *Decoder, bytes: []const u8) Error!Chunk {
        if (self.failed) return error.DecoderFailed;
        errdefer self.failed = true;
        var offset: usize = 0;
        while (offset < bytes.len) {
            if (self.body == null) {
                if (self.header.items.len >= self.limits.header) return error.HeaderTooLarge;
                // Cap geometric growth at the configured header limit.
                if (self.header.items.len == self.header.capacity)
                    try self.header.ensureTotalCapacityPrecise(self.allocator, @min(self.limits.header, @max(64, self.header.capacity *| 2)));
                self.header.appendAssumeCapacity(bytes[offset]);
                offset += 1;
                if (!std.mem.endsWith(u8, self.header.items, "\r\n\r\n")) continue;
                const length = try parseHeader(self.header.items, self.limits.payload);
                self.body = try self.allocator.alloc(u8, length);
                self.header.clearRetainingCapacity();
                if (length == 0) return self.take(offset);
            }
            const body = self.body.?;
            const count = @min(body.len - self.used, bytes.len - offset);
            @memcpy(body[self.used..][0..count], bytes[offset..][0..count]);
            self.used += count;
            offset += count;
            if (self.used == body.len) return self.take(offset);
        }
        return .{ .consumed = offset };
    }

    fn take(self: *Decoder, consumed: usize) Chunk {
        const body = self.body.?;
        self.body = null;
        self.used = 0;
        return .{ .consumed = consumed, .payload = body };
    }

    pub fn finish(self: *Decoder) Error!void {
        if (self.failed) return error.DecoderFailed;
        errdefer self.failed = true;
        if (self.body != null) return error.TruncatedBody;
        if (self.header.items.len != 0) return error.TruncatedHeader;
    }
};

fn parseHeader(header: []const u8, max_payload: usize) Error!usize {
    var length: ?usize = null;
    var lines = std.mem.splitSequence(u8, header[0 .. header.len - 4], "\r\n");
    while (lines.next()) |line| {
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse return error.MalformedHeader;
        const name = line[0..colon];
        if (name.len == 0) return error.MalformedHeader;
        for (name) |c| if (!std.ascii.isAlphanumeric(c) and c != '-') return error.MalformedHeader;
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        for (value) |c| if ((c < 32 and c != '\t') or c > 126) return error.MalformedHeader;
        if (!std.ascii.eqlIgnoreCase(name, "Content-Length")) continue;
        if (length != null) return error.DuplicateLength;
        if (value.len == 0) return error.InvalidLength;
        for (value) |c| if (!std.ascii.isDigit(c)) return error.InvalidLength;
        const parsed = std.fmt.parseInt(usize, value, 10) catch return error.InvalidLength;
        if (parsed > max_payload) return error.PayloadTooLarge;
        length = parsed;
    }
    return length orelse error.MissingLength;
}

/// Payload length counts UTF-8 bytes, not characters. Caller owns the frame.
pub fn encode(allocator: std.mem.Allocator, payload: []const u8, limits: Limits) ![]u8 {
    if (payload.len > limits.payload) return error.PayloadTooLarge;
    var buffer: [64]u8 = undefined;
    const header = try std.fmt.bufPrint(&buffer, "Content-Length: {d}\r\n\r\n", .{payload.len});
    if (header.len > limits.header) return error.HeaderTooLarge;
    return std.mem.concat(allocator, u8, &.{ header, payload });
}

test "every split round trips UTF-8, supported headers and combined frames" {
    const a = std.testing.allocator;
    const wire = "Content-Type: application/vscode-jsonrpc; charset=utf-8\r\ncontent-length: 4\r\n\r\n\"é\"Content-Length: 0\r\n\r\n";
    for (0..wire.len + 1) |split| {
        var decoder = Decoder.init(a, .{});
        defer decoder.deinit();
        var frames: usize = 0;
        for ([_][]const u8{ wire[0..split], wire[split..] }) |chunk| {
            var remaining = chunk;
            while (remaining.len > 0) {
                const result = try decoder.feed(remaining);
                remaining = remaining[result.consumed..];
                if (result.payload) |payload| {
                    defer a.free(payload);
                    try std.testing.expectEqualStrings(if (frames == 0) "\"é\"" else "", payload);
                    frames += 1;
                }
            }
        }
        try decoder.finish();
        try std.testing.expectEqual(@as(usize, 2), frames);
    }
    const encoded = try encode(a, "\"é\"", .{});
    defer a.free(encoded);
    try std.testing.expectEqualStrings("Content-Length: 4\r\n\r\n\"é\"", encoded);
}

test "invalid lengths, headers, truncation and limits are contextual and sticky" {
    const cases = .{
        .{ "Content-Length: -1\r\n\r\n", error.InvalidLength },
        .{ "Content-Length: 1x\r\n\r\n", error.InvalidLength },
        .{ "Content-Length: 9999999999999999999999999\r\n\r\n", error.InvalidLength },
        .{ "Content-Length: 4\r\nContent-Length: 4\r\n\r\n", error.DuplicateLength },
        .{ "X-Test: yes\r\n\r\n", error.MissingLength },
        .{ "Content Length: 4\r\n\r\n", error.MalformedHeader },
        .{ "Content-Length: 5\r\n\r\n", error.PayloadTooLarge },
    };
    inline for (cases) |case| {
        var decoder = Decoder.init(std.testing.allocator, .{ .payload = 4 });
        defer decoder.deinit();
        try std.testing.expectError(case[1], decoder.feed(case[0]));
        try std.testing.expect(decoder.body == null);
        try std.testing.expectError(error.DecoderFailed, decoder.feed(""));
    }
    var header = Decoder.init(std.testing.allocator, .{ .header = 4 });
    defer header.deinit();
    try std.testing.expectError(error.HeaderTooLarge, header.feed("abcde"));
    var partial = Decoder.init(std.testing.allocator, .{});
    defer partial.deinit();
    _ = try partial.feed("Content-Length: 4\r\n\r\nabc");
    try std.testing.expectError(error.TruncatedBody, partial.finish());
    var truncated = Decoder.init(std.testing.allocator, .{});
    defer truncated.deinit();
    _ = try truncated.feed("Content-");
    try std.testing.expectError(error.TruncatedHeader, truncated.finish());
    try std.testing.expectError(error.PayloadTooLarge, encode(std.testing.allocator, "12345", .{ .payload = 4 }));
}
