const std = @import("std");
const foundation = @import("foundation");
const commands = @import("commands");
const ports = @import("ports");

/// Optional ports are absent capabilities, never implicit platform adapters.
/// Services requiring them must receive an explicit implementation at composition.
pub const ExternalPorts = struct {
    clock: foundation.clock.Clock,
    log_sink: foundation.logging.Sink,
    files: ?ports.BlobStore = null,
    storage: ?ports.BlobStore = null,
    process: ?ports.Process = null,
    ui: ?ports.Scheduler = null,
};

pub const Phase = enum { persist, cancel, stop, flush };
pub const State = enum { constructed, starting, running, stopping, stopped };
pub const LifecycleError = error{ Busy, Stopped, StartupFailed, ShutdownFailed, DeadlineExceeded };

/// Borrowed service and context, in dependency order (dependencies first).
/// shutdown must respect the absolute monotonic deadline and force cleanup when
/// it expires; release is nonblocking and called once even after hook errors.
/// A failed start must leave its partial resources safe for shutdown/release.
pub const Service = struct {
    context: *anyopaque,
    start: *const fn (*anyopaque) anyerror!void,
    shutdown: *const fn (*anyopaque, Phase, foundation.clock.MonotonicTime) anyerror!void,
    release: *const fn (*anyopaque) void,
};

/// Application-thread owner. Reentrant shutdown closes admission immediately,
/// but returns Busy until dispatch/start callbacks unwind; retry before deinit.
pub const Context = struct {
    commands: commands.Registry,
    logger: foundation.logging.Logger,
    external: ExternalPorts,
    state: State = .constructed,
    services: []const Service = &.{},
    started: usize = 0,
    in_lifecycle: bool = false,
    deadline: ?foundation.clock.MonotonicTime = null,
    shutdown_error: ?LifecycleError = null,
    cause: ?anyerror = null,

    pub fn init(allocator: std.mem.Allocator, external: ExternalPorts) Context {
        var registry = commands.Registry.init(allocator);
        registry.accepting = false;
        return .{ .commands = registry, .logger = .{ .clock = external.clock, .sink = external.log_sink }, .external = external };
    }

    pub fn start(self: *Context, services: []const Service) LifecycleError!void {
        switch (self.state) {
            .running => return,
            .starting => return error.Busy,
            .stopping, .stopped => return error.Stopped,
            .constructed => {},
        }
        self.state = .starting;
        self.services = services;
        self.in_lifecycle = true;
        for (services) |service| {
            self.started += 1;
            service.start(service.context) catch |err| {
                self.cause = err;
                self.in_lifecycle = false;
                self.shutdown(self.external.clock.monotonic()) catch {};
                return error.StartupFailed;
            };
            if (self.state == .stopping) {
                self.in_lifecycle = false;
                self.shutdown(self.deadline.?) catch {};
                return error.Stopped;
            }
        }
        self.in_lifecycle = false;
        self.state = .running;
        self.commands.accepting = true;
    }

    /// The first deadline is retained across Busy retries. All phases run even
    /// after an error; subsequent calls return the saved outcome without repeats.
    pub fn shutdown(self: *Context, deadline: foundation.clock.MonotonicTime) LifecycleError!void {
        if (self.state == .stopped) {
            if (self.shutdown_error) |err| return err;
            return;
        }
        self.commands.close();
        self.state = .stopping;
        if (self.deadline == null) self.deadline = deadline;
        if (self.in_lifecycle or self.commands.active_dispatches != 0) return error.Busy;
        self.in_lifecycle = true;
        defer self.in_lifecycle = false;
        for ([_]Phase{ .persist, .cancel, .stop, .flush }) |phase| {
            for (0..self.started) |index| {
                const service_index = if (phase == .stop) self.started - index - 1 else index;
                const service = self.services[service_index];
                service.shutdown(service.context, phase, self.deadline.?) catch |err| {
                    if (self.cause == null) self.cause = err;
                    if (self.shutdown_error == null) self.shutdown_error = if (err == error.DeadlineExceeded) error.DeadlineExceeded else error.ShutdownFailed;
                };
            }
        }
        if (self.external.clock.monotonic().ns > self.deadline.?.ns and self.shutdown_error == null)
            self.shutdown_error = error.DeadlineExceeded;
        var remaining = self.started;
        while (remaining > 0) {
            remaining -= 1;
            const service = self.services[remaining];
            service.release(service.context);
        }
        self.started = 0;
        self.state = .stopped;
        if (self.shutdown_error) |err| return err;
    }

    /// Call only after successful completion of shutdown (including its terminal
    /// error outcome), or on a never-started context. Never from a callback.
    pub fn deinit(self: *Context) void {
        std.debug.assert(self.state == .constructed or self.state == .stopped);
        self.commands.deinit();
        self.* = undefined;
    }
};
