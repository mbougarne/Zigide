//! macOS/POSIX spike: argv-only child launch, concurrent stderr drain, bounded lifetime.
const std = @import("std");
const framing = @import("framing.zig");

pub const Session = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    child: *std.process.Child,
    decoder: framing.Decoder,
    buffer: [4096]u8 = undefined,
    start: usize = 0,
    end: usize = 0,

    pub fn send(self: *Session, payload: []const u8) !void {
        const input = self.child.stdin orelse return error.StdinClosed;
        const frame = try framing.encode(self.allocator, payload, self.decoder.limits);
        defer self.allocator.free(frame);
        try input.writeStreamingAll(self.io, frame);
    }

    pub fn closeInput(self: *Session) void {
        if (self.child.stdin) |file| file.close(self.io);
        self.child.stdin = null;
    }

    /// Each returned payload belongs to the caller; null is clean stdout EOF.
    pub fn receive(self: *Session) !?[]u8 {
        while (true) {
            if (self.start < self.end) {
                const chunk = try self.decoder.feed(self.buffer[self.start..self.end]);
                self.start += chunk.consumed;
                if (chunk.payload) |payload| return payload;
            }
            self.start = 0;
            self.end = self.child.stdout.?.readStreaming(self.io, &.{&self.buffer}) catch |err| switch (err) {
                error.EndOfStream => 0,
                else => return err,
            };
            if (self.end == 0) {
                try self.decoder.finish();
                return null;
            }
        }
    }
};

pub const Result = struct {
    term: std.process.Child.Term,
    stderr_bytes: usize,
    /// Bounded prefix, even if the server writes unlimited diagnostics.
    stderr_prefix: [4096]u8,
    stderr_prefix_len: usize,
};
pub const Diagnostics = struct { bytes: usize = 0, prefix: [4096]u8 = @splat(0), len: usize = 0 };
pub const Options = struct {
    diagnostics: ?*Diagnostics = null,
    argv: []const []const u8,
    cwd: std.process.Child.Cwd = .inherit,
    environ_map: ?*const std.process.Environ.Map = null,
    timeout: std.Io.Duration = .fromSeconds(10),
    limits: framing.Limits = .{},
};
pub const Conversation = *const fn (*Session, *anyopaque) anyerror!void;
const Event = union(enum) { conversation: anyerror!void, stderr: anyerror!void, timer: std.Io.Cancelable!void, exit: anyerror!std.process.Child.Term };

/// Conversation owns stdin/stdout. Stderr always drains concurrently. All tasks
/// are joined before pipes close, and every return reaps the owned child.
pub fn run(allocator: std.mem.Allocator, io: std.Io, options: Options, context: *anyopaque, conversation: Conversation) !Result {
    var child = try std.process.spawn(io, .{
        .argv = options.argv,
        .cwd = options.cwd,
        .environ_map = options.environ_map,
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .pipe,
    });
    defer if (child.id != null) {
        terminate(&child, io) catch |err| std.debug.print("protocol child cleanup failed: {s}\n", .{@errorName(err)});
    };
    var session: Session = .{ .io = io, .allocator = allocator, .child = &child, .decoder = framing.Decoder.init(allocator, options.limits) };
    defer session.decoder.deinit();
    var result: Result = .{ .term = undefined, .stderr_bytes = 0, .stderr_prefix = @splat(0), .stderr_prefix_len = 0 };
    defer if (options.diagnostics) |diagnostics| {
        diagnostics.* = .{ .bytes = result.stderr_bytes, .prefix = result.stderr_prefix, .len = result.stderr_prefix_len };
    };
    var events: [4]Event = undefined;
    var select = std.Io.Select(Event).init(io, &events);
    defer select.cancelDiscard();
    try select.concurrent(.timer, std.Io.sleep, .{ io, options.timeout, .awake });
    try select.concurrent(.stderr, drainStderr, .{ io, child.stderr.?, &result });
    try select.concurrent(.conversation, converse, .{ &session, context, conversation });
    var completed: usize = 0;
    while (true) {
        const event = try select.await();
        switch (event) {
            .timer => |outcome| {
                try outcome;
                select.cancelDiscard();
                if (child.id != null) try terminate(&child, io);
                return error.DeadlineExceeded;
            },
            .conversation, .stderr => |outcome| {
                outcome catch |err| {
                    select.cancelDiscard();
                    try terminate(&child, io);
                    return err;
                };
                completed += 1;
                if (completed == 2) try select.concurrent(.exit, waitExit, .{ &child, io });
            },
            .exit => |outcome| {
                result.term = try outcome;
                return result;
            },
        }
    }
}

fn converse(session: *Session, context: *anyopaque, conversation: Conversation) !void {
    try conversation(session, context);
    session.closeInput();
    // Continue draining output after the dialogue so a child cannot block on exit.
    while (try session.receive()) |payload| session.allocator.free(payload);
}

fn drainStderr(io: std.Io, file: std.Io.File, result: *Result) !void {
    var buffer: [8192]u8 = undefined;
    while (true) {
        const count = file.readStreaming(io, &.{&buffer}) catch |err| switch (err) {
            error.EndOfStream => 0,
            else => return err,
        };
        if (count == 0) return;
        result.stderr_bytes +|= count;
        const keep = @min(count, result.stderr_prefix.len - result.stderr_prefix_len);
        @memcpy(result.stderr_prefix[result.stderr_prefix_len..][0..keep], buffer[0..keep]);
        result.stderr_prefix_len += keep;
    }
}

/// Unlike Child.kill's best-effort cleanup, the explicit termination path reports
/// signal and reap failures. Limited to the first-release POSIX target.
pub fn terminate(child: *std.process.Child, io: std.Io) !void {
    return terminateWith(child, io, std.posix.kill);
}

fn terminateWith(child: *std.process.Child, io: std.Io, signal: *const fn (std.posix.pid_t, std.posix.SIG) std.posix.KillError!void) !void {
    const protection = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(protection);
    const id = child.id orelse return error.AlreadyExited;
    signal(id, .KILL) catch |err| switch (err) {
        error.ProcessNotFound => {}, // Reap an already-exited child as well.
        else => return err,
    };
    _ = try child.wait(io);
}

test "termination failure and repeated termination are observable" {
    const Denied = struct {
        fn signal(_: std.posix.pid_t, _: std.posix.SIG) std.posix.KillError!void {
            return error.PermissionDenied;
        }
    };
    var child: std.process.Child = undefined;
    child.id = 123;
    try std.testing.expectError(error.PermissionDenied, terminateWith(&child, std.testing.io, Denied.signal));
    child.id = null;
    try std.testing.expectError(error.AlreadyExited, terminate(&child, std.testing.io));
}

// Zig 0.16 Child.wait closes handles even when cancelled. Polling retains child
// ownership until a successful reap, so a deadline after pipe EOF can still kill it.
fn waitExit(child: *std.process.Child, io: std.Io) !std.process.Child.Term {
    while (true) {
        var status: c_int = 0;
        const result = std.posix.system.waitpid(child.id.?, &status, std.posix.W.NOHANG);
        if (result > 0) {
            child.id = null;
            if (child.stdin) |file| file.close(io);
            if (child.stdout) |file| file.close(io);
            if (child.stderr) |file| file.close(io);
            child.stdin = null;
            child.stdout = null;
            child.stderr = null;
            const value: u32 = @bitCast(status);
            if (std.posix.W.IFEXITED(value)) return .{ .exited = std.posix.W.EXITSTATUS(value) };
            if (std.posix.W.IFSIGNALED(value)) return .{ .signal = std.posix.W.TERMSIG(value) };
            return .{ .unknown = value };
        }
        if (result < 0) switch (std.posix.errno(result)) {
            .INTR => {},
            else => |err| return std.posix.unexpectedErrno(err),
        };
        try std.Io.sleep(io, .fromMilliseconds(2), .awake);
    }
}
