//! Explicit opt-in real-server validation; never substitutes a mock for ZLS.
const std = @import("std");
const adapters = @import("adapters");
const foundation = @import("foundation");
const options = @import("spike_options");
const rpc = adapters.rpc;
const transport = adapters.transport;

const Fixture = struct {
    root_uri: []const u8,
    source: foundation.cancellation.Source = .{},
    pending: rpc.Correlator = .{},

    fn exchange(session: *transport.Session, raw: *anyopaque) !void {
        const self: *Fixture = @ptrCast(@alignCast(raw));
        const clock: adapters.SystemClock = .{ .io = session.io };
        defer self.pending.disconnect();
        const initialize_id = try self.pending.begin(.{ .cancellation = self.source.token(), .deadline = .{ .ns = clock.clock().monotonic().ns + 10 * std.time.ns_per_s } }, clock.clock());
        const initialize = try std.json.Stringify.valueAlloc(session.allocator, .{
            .jsonrpc = "2.0",
            .id = @intFromEnum(initialize_id),
            .method = "initialize",
            .params = .{ .processId = null, .rootUri = self.root_uri, .capabilities = struct {}{}, .clientInfo = .{ .name = "zigide-zls-spike", .version = "0.0.0" } },
        }, .{});
        defer session.allocator.free(initialize);
        try session.send(initialize);
        try self.response(session, initialize_id, clock.clock(), true);
        try session.send("{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}");
        const shutdown_id = try self.pending.begin(.{ .cancellation = self.source.token(), .deadline = .{ .ns = clock.clock().monotonic().ns + 10 * std.time.ns_per_s } }, clock.clock());
        const shutdown = try std.json.Stringify.valueAlloc(session.allocator, .{ .jsonrpc = "2.0", .id = @intFromEnum(shutdown_id), .method = "shutdown", .params = null }, .{});
        defer session.allocator.free(shutdown);
        try session.send(shutdown);
        try self.response(session, shutdown_id, clock.clock(), false);
        try session.send("{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}");
        if (self.pending.count() != 0) return error.PendingRequestsAtExit;
    }

    fn response(self: *Fixture, session: *transport.Session, expected: rpc.Id, clock: foundation.clock.Clock, initialize: bool) !void {
        while (try session.receive()) |payload| {
            defer session.allocator.free(payload);
            var message = try rpc.decode(session.allocator, payload, session.decoder.limits.payload);
            defer message.deinit();
            switch (message.kind) {
                .notification => continue,
                .request => return error.UnexpectedServerRequest,
                .result, .remote_error => {},
            }
            if (message.id() != expected) return error.UnexpectedResponseId;
            if (self.pending.complete(message, clock) != .result) return error.RequestFailed;
            const result = message.parsed.value.object.get("result").?;
            if (initialize) {
                if (result != .object) return error.InvalidInitializeResult;
                const capabilities = result.object.get("capabilities") orelse return error.MissingCapabilities;
                if (capabilities != .object) return error.InvalidCapabilities;
            } else if (result != .null) return error.InvalidShutdownResult;
            return;
        }
        return error.ServerClosedBeforeResponse;
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    const version = try std.process.run(allocator, io, .{ .argv = &.{ options.zls, "--version" }, .stdout_limit = .limited(4096), .stderr_limit = .limited(4096) });
    defer allocator.free(version.stdout);
    defer allocator.free(version.stderr);
    if (version.term != .exited or version.term.exited != 0) return error.VersionProbeFailed;
    const zls_version = std.mem.trim(u8, version.stdout, "\r\n ");
    if (!std.mem.eql(u8, zls_version, "0.16.0")) return error.UnsupportedZlsVersion;

    var random: [16]u8 = undefined;
    io.random(&random);
    const dirname = try std.fmt.allocPrint(allocator, ".zig-cache/zls-spike-{s}", .{std.fmt.bytesToHex(random, .lower)});
    defer allocator.free(dirname);
    const cwd = std.Io.Dir.cwd();
    var workspace = try cwd.createDirPathOpen(io, dirname, .{});
    defer workspace.close(io);
    var success = false;
    defer if (success) {
        cwd.deleteTree(io, dirname) catch |err| std.debug.print("workspace cleanup failed: {s}\n", .{@errorName(err)});
    };
    try workspace.writeFile(io, .{ .sub_path = "main.zig", .data = "pub fn main() void {}\n" });
    try workspace.writeFile(io, .{ .sub_path = "build.zig", .data = "const std = @import(\"std\");\npub fn build(b: *std.Build) void {\n const exe = b.addExecutable(.{ .name = \"fixture\", .root_module = b.createModule(.{ .root_source_file = b.path(\"main.zig\"), .target = b.graph.host }) });\n b.installArtifact(exe);\n}\n" });
    const config = try std.json.Stringify.valueAlloc(allocator, .{ .zig_exe_path = options.zig }, .{});
    defer allocator.free(config);
    try workspace.writeFile(io, .{ .sub_path = "zls.json", .data = config });
    const root = try cwd.realPathFileAlloc(io, dirname, allocator);
    defer allocator.free(root);
    const uri: std.Uri = .{ .scheme = "file", .host = .{ .raw = "" }, .path = .{ .raw = root } };
    const root_uri = try std.fmt.allocPrint(allocator, "{f}", .{uri});
    defer allocator.free(root_uri);
    var fixture: Fixture = .{ .root_uri = root_uri };
    var diagnostics: transport.Diagnostics = .{};
    const result = transport.run(allocator, io, .{ .argv = &.{ options.zls, "--config-path", "zls.json", "--log-file", "zls.log", "--enable-stderr-logs" }, .cwd = .{ .dir = workspace }, .timeout = .fromSeconds(15), .diagnostics = &diagnostics }, &fixture, Fixture.exchange) catch |err| {
        std.debug.print("ZLS stderr ({d} bytes): {s}\nRetained workspace: {s}\n", .{ diagnostics.bytes, diagnostics.prefix[0..diagnostics.len], root });
        return err;
    };
    success = true;
    if (result.term != .exited or result.term.exited != 0) return error.UncleanServerExit;
    std.debug.print("ZLS spike PASS: Zig {s}; ZLS {s}; initialize/initialized/shutdown/exit; exit 0; pending 0; stderr {d} bytes\n", .{ @import("builtin").zig_version_string, zls_version, result.stderr_bytes });
    std.debug.print("Workspace: temporary {s} (main.zig, build.zig, zls.json; removed after run)\nCommand: {s} --config-path zls.json --log-file zls.log --enable-stderr-logs\nZig executable: {s}\n", .{ root, options.zls, options.zig });
}
