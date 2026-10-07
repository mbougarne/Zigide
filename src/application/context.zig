const std = @import("std");
const foundation = @import("foundation");
const commands = @import("commands");

/// Every external dependency currently used by application services is required
/// explicitly. Port implementations are chosen by the executable or test root.
pub const ExternalPorts = struct {
    clock: foundation.clock.Clock,
    log_sink: foundation.logging.Sink,
};

/// Owns the command registry; borrows external port contexts and handler contexts.
/// Dependencies must outlive this context and any resolved handlers. Keep it at
/// a stable address once borrowed by services; use on the application thread only.
pub const Context = struct {
    commands: commands.Registry,
    logger: foundation.logging.Logger,

    pub fn init(allocator: std.mem.Allocator, external: ExternalPorts) Context {
        return .{
            .commands = commands.Registry.init(allocator),
            .logger = .{ .clock = external.clock, .sink = external.log_sink },
        };
    }

    /// Releases registry storage, never borrowed dependencies. Lifecycle ordering
    /// and idempotent shutdown are separate work; call exactly once after use.
    pub fn deinit(self: *Context) void {
        self.commands.deinit();
        self.* = undefined;
    }
};
