//! Read-only prerequisite inspection. Exit 2 means blocked or unrun, never qualified.
const std = @import("std");
const builtin = @import("builtin");
const suite = @import("editor_suite");

const adr_path = "docs/architecture/decisions/0004-ui-toolkit-selection.md";
const report_path = ".zig-cache/dependable-editor-preflight.json";
const Inspection = struct {
    dependencies: [suite.dependencies.len]suite.Status,
    owners: [suite.checks.len]suite.Status,
    adr_accepted: bool,
};

fn read(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
}

fn inspect(io: std.Io, allocator: std.mem.Allocator) !Inspection {
    const epic = try read(io, allocator, "tickets/dependable-editor.md");
    defer allocator.free(epic);
    try suite.validateDependencies(epic);
    var result: Inspection = undefined;
    for (suite.dependencies, &result.dependencies) |dependency, *status| {
        const content = try read(io, allocator, dependency.file);
        defer allocator.free(content);
        status.* = try suite.ticketStatus(content, dependency.id);
    }
    for (suite.checks, &result.owners) |check, *status| {
        const content = try read(io, allocator, check.owner.file);
        defer allocator.free(content);
        status.* = try suite.ticketStatus(content, check.owner.id);
    }
    const adr = try read(io, allocator, adr_path);
    defer allocator.free(adr);
    result.adr_accepted = try suite.adrAccepted(adr);
    return result;
}

fn command(init: std.process.Init, argv: []const []const u8) ![]const u8 {
    const allocator = init.arena.allocator();
    const result = try std.process.run(allocator, init.io, .{ .argv = argv, .stdout_limit = .limited(64 * 1024), .stderr_limit = .limited(4096) });
    if (result.term != .exited or result.term.exited != 0) {
        std.debug.print("Provenance command failed: {s}; {s}\n", .{ argv[0], result.stderr });
        return error.ProvenanceCommandFailed;
    }
    return std.mem.trim(u8, result.stdout, "\r\n ");
}

fn digest(bytes: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}

const Fixture = struct { file: []const u8, bytes: usize, sha256: [64]u8 };
fn fixture(comptime module_name: []const u8, file: []const u8) Fixture {
    const bytes = @embedFile(module_name);
    return .{ .file = file, .bytes = bytes.len, .sha256 = digest(bytes) };
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const inspection = try inspect(init.io, allocator);
    const supported = builtin.os.tag == .macos and builtin.cpu.arch == .aarch64;
    const state = suite.journeyState(&inspection.dependencies, inspection.adr_accepted, supported);
    const revision = try command(init, &.{ "git", "rev-parse", "HEAD" });
    const changes = try command(init, &.{ "git", "status", "--porcelain=v1", "--untracked-files=normal" });
    const executable = try std.process.executablePathAlloc(init.io, allocator);
    const executable_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, executable, allocator, .limited(128 * 1024 * 1024));
    const Dependency = struct { ticket: []const u8, status: suite.Status, file: []const u8 };
    var dependencies: [suite.dependencies.len]Dependency = undefined;
    for (suite.dependencies, inspection.dependencies, &dependencies) |dependency, status, *row| {
        row.* = .{ .ticket = dependency.id, .status = status, .file = dependency.file };
    }
    const Case = struct { check: suite.Check, owner_status: suite.Status, result: []const u8 = "unrun" };
    var cases: [suite.checks.len]Case = undefined;
    for (suite.checks, inspection.owners, &cases) |check, status, *row| row.* = .{ .check = check, .owner_status = status };
    const hardware = if (builtin.os.tag == .macos) try command(init, &.{ "/usr/sbin/sysctl", "-n", "hw.model" }) else "unsupported";
    const os_version = if (builtin.os.tag == .macos) try command(init, &.{ "/usr/bin/sw_vers", "-productVersion" }) else "unsupported";
    const os_build = if (builtin.os.tag == .macos) try command(init, &.{ "/usr/bin/sw_vers", "-buildVersion" }) else "unsupported";
    const report = try std.json.Stringify.valueAlloc(allocator, .{
        .schema_version = 1,
        .kind = "dependable-editor-readiness-only",
        .journey_status = state,
        .journey_executed = false,
        .milestone_qualified = false,
        .voiceover = "unrun",
        .physical_ime = "unrun",
        .timestamp_unix_ns = std.Io.Clock.real.now(init.io).nanoseconds,
        .source_revision = revision,
        .working_tree_dirty = changes.len != 0,
        .preflight_executable_sha256 = digest(executable_bytes),
        .environment = .{ .zig = builtin.zig_version_string, .optimize = @tagName(builtin.mode), .os = @tagName(builtin.os.tag), .arch = @tagName(builtin.cpu.arch), .hardware = hardware, .os_version = os_version, .os_build = os_build, .supported_target = supported },
        .adr = .{ .file = adr_path, .accepted = inspection.adr_accepted },
        .dependencies = dependencies,
        .cases = cases,
        .fixtures = [_]Fixture{
            fixture("journey_main", "tests/dependable_editor/fixtures/main.zig"),
            fixture("journey_message", "tests/dependable_editor/fixtures/message.zig"),
        },
    }, .{ .whitespace = .indent_2 });
    const terminated = try std.mem.concat(allocator, u8, &.{ report, "\n" });
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = report_path, .data = terminated });
    std.debug.print("ZIT-043 {s}: readiness inspection only; journey executed=false; milestone qualified=false\nReport: {s}\n", .{ @tagName(state), report_path });
    for (dependencies) |dependency| {
        if (dependency.status != .Done) std.debug.print("  {s}: {s} ({s})\n", .{ dependency.ticket, @tagName(dependency.status), dependency.file });
    }
    if (!inspection.adr_accepted) std.debug.print("  ADR-0004: not accepted; production view blocked\n", .{});
    if (!supported) std.debug.print("  Target: requires macOS arm64\n", .{});
    std.process.exit(2);
}

test "all exit owners and declared dependencies resolve against current repository tickets" {
    _ = try inspect(std.testing.io, std.testing.allocator);
}

test "maintained journey fixture includes Unicode without implicit normalization" {
    const source = @embedFile("journey_message");
    try std.testing.expect(std.unicode.utf8ValidateSlice(source));
    try std.testing.expect(std.mem.indexOf(u8, source, "café 😀 日本語 العربية") != null);
    try std.testing.expect(std.mem.indexOf(u8, source, "\\u{301}") != null);
    try std.testing.expectEqual(@as(usize, 64), digest(source).len);
}
