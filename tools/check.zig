//! Repository checker for Zigide.
//!
//! Enforces the rules documented in AGENTIC_RULES.md and agents/README.md:
//! text hygiene (no trailing whitespace, final newline, no merge markers),
//! local Markdown links that resolve, and a consistent append-only trace
//! ledger in agents/history.json with one record per prompt and no orphan
//! record files. Run through `zig build check`.

const std = @import("std");

const max_file_bytes = 16 * 1024 * 1024;

const skip_dirs = [_][]const u8{ ".git", ".zig-cache", "zig-out", ".claude" };
const text_extensions = [_][]const u8{ ".md", ".json", ".zig", ".zon", ".yml", ".yaml" };
const text_basenames = [_][]const u8{ "LICENSE", ".gitignore", "pre-commit" };

var failures: usize = 0;

fn fail(comptime fmt: []const u8, args: anytype) void {
    failures += 1;
    std.debug.print("FAIL: " ++ fmt ++ "\n", args);
}

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var threaded: std.Io.Threaded = .init(arena, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var referenced_records = std.ArrayList([]const u8).empty;

    try walkTree(io, arena, ".");
    try checkTraceLedger(io, arena, &referenced_records);
    try checkOrphanRecords(io, arena, "agents/conversations", referenced_records.items);
    try checkOrphanRecords(io, arena, "agents/researches", referenced_records.items);

    if (failures != 0) {
        std.debug.print("{d} check failure(s)\n", .{failures});
        std.process.exit(1);
    }
    std.debug.print("all repository checks passed\n", .{});
}

fn isTextFile(basename: []const u8) bool {
    for (text_basenames) |name| {
        if (std.mem.eql(u8, basename, name)) return true;
    }
    const ext = std.fs.path.extension(basename);
    for (text_extensions) |candidate| {
        if (std.mem.eql(u8, ext, candidate)) return true;
    }
    return false;
}

fn walkTree(io: std.Io, arena: std.mem.Allocator, dir_path: []const u8) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        const child = try std.fs.path.join(arena, &.{ dir_path, entry.name });
        switch (entry.kind) {
            .directory => {
                var skip = false;
                for (skip_dirs) |name| {
                    if (std.mem.eql(u8, entry.name, name)) skip = true;
                }
                if (!skip) try walkTree(io, arena, child);
            },
            .file => {
                if (isTextFile(entry.name)) try checkFile(io, arena, child);
            },
            else => {},
        }
    }
}

fn checkFile(io: std.Io, arena: std.mem.Allocator, path: []const u8) !void {
    const content = std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(max_file_bytes)) catch |err| {
        fail("{s}: unreadable ({s})", .{ path, @errorName(err) });
        return;
    };
    checkHygiene(path, content);
    if (std.mem.endsWith(u8, path, ".md")) try checkLinks(io, arena, path, content);
}

fn checkHygiene(path: []const u8, content: []const u8) void {
    if (content.len == 0 or content[content.len - 1] != '\n') {
        fail("{s}: missing final newline", .{path});
    }
    var line_no: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        line_no += 1;
        if (line.len > 0 and (line[line.len - 1] == ' ' or line[line.len - 1] == '\t')) {
            fail("{s}:{d}: trailing whitespace", .{ path, line_no });
        }
        if (std.mem.startsWith(u8, line, "<<<<<<< ") or
            std.mem.startsWith(u8, line, ">>>>>>> ") or
            std.mem.eql(u8, line, "======="))
        {
            fail("{s}:{d}: merge conflict marker", .{ path, line_no });
        }
    }
}

fn checkLinks(io: std.Io, arena: std.mem.Allocator, path: []const u8, content: []const u8) !void {
    var search_from: usize = 0;
    while (std.mem.indexOfPos(u8, content, search_from, "](")) |idx| {
        const start = idx + 2;
        const end = std.mem.indexOfScalarPos(u8, content, start, ')') orelse break;
        search_from = end + 1;

        var link = content[start..end];
        if (std.mem.indexOfScalar(u8, link, '#')) |hash| link = link[0..hash];
        if (link.len == 0) continue;
        if (std.mem.startsWith(u8, link, "http://") or
            std.mem.startsWith(u8, link, "https://") or
            std.mem.startsWith(u8, link, "mailto:")) continue;

        const dir = std.fs.path.dirname(path) orelse ".";
        const target = try std.fs.path.join(arena, &.{ dir, link });
        std.Io.Dir.cwd().access(io, target, .{}) catch {
            fail("{s}: broken link -> {s}", .{ path, link });
        };
    }
}

fn checkTraceLedger(io: std.Io, arena: std.mem.Allocator, referenced: *std.ArrayList([]const u8)) !void {
    const ledger_path = "agents/history.json";
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, ledger_path, arena, .limited(max_file_bytes)) catch |err| {
        fail("{s}: unreadable ({s})", .{ ledger_path, @errorName(err) });
        return;
    };
    const parsed = std.json.parseFromSlice(std.json.Value, arena, bytes, .{}) catch |err| {
        fail("{s}: invalid JSON ({s})", .{ ledger_path, @errorName(err) });
        return;
    };
    const root = switch (parsed.value) {
        .object => |obj| obj,
        else => {
            fail("{s}: root must be an object", .{ledger_path});
            return;
        },
    };

    checkIntField(ledger_path, root, "schemaVersion", 1);
    checkStringField(ledger_path, root, "project", "zigide");

    const entries = root.get("entries") orelse {
        fail("{s}: missing entries", .{ledger_path});
        return;
    };
    const list = switch (entries) {
        .array => |array| array,
        else => {
            fail("{s}: entries must be an array", .{ledger_path});
            return;
        },
    };

    var seen_ids = std.ArrayList([]const u8).empty;
    for (list.items, 0..) |item, index| {
        const entry = switch (item) {
            .object => |obj| obj,
            else => {
                fail("{s}: entry {d} must be an object", .{ ledger_path, index });
                continue;
            },
        };
        try checkEntry(io, arena, ledger_path, index, entry, &seen_ids, referenced);
    }
}

fn checkEntry(
    io: std.Io,
    arena: std.mem.Allocator,
    ledger_path: []const u8,
    index: usize,
    entry: std.json.ObjectMap,
    seen_ids: *std.ArrayList([]const u8),
    referenced: *std.ArrayList([]const u8),
) !void {
    const id = getString(entry, "id") orelse {
        fail("{s}: entry {d}: missing id", .{ ledger_path, index });
        return;
    };
    if (!isUuidV4(id)) fail("{s}: entry {d}: id is not a lowercase v4 UUID: {s}", .{ ledger_path, index, id });
    for (seen_ids.items) |existing| {
        if (std.mem.eql(u8, existing, id)) fail("{s}: duplicate entry id {s}", .{ ledger_path, id });
    }
    try seen_ids.append(arena, id);

    if (getString(entry, "timestamp")) |timestamp| {
        if (!isUtcTimestamp(timestamp)) fail("{s}: entry {s}: bad timestamp {s}", .{ ledger_path, id, timestamp });
    } else fail("{s}: entry {s}: missing timestamp", .{ ledger_path, id });

    for ([_][]const u8{ "kind", "summary" }) |field| {
        const value = getString(entry, field) orelse "";
        if (value.len == 0) fail("{s}: entry {s}: missing or empty {s}", .{ ledger_path, id, field });
    }
    for ([_][]const u8{ "intentTags", "artifacts", "decisions", "verification" }) |field| {
        checkStringArray(ledger_path, id, entry, field);
    }

    if (entry.get("publication")) |publication| {
        const object = switch (publication) {
            .object => |obj| obj,
            else => {
                fail("{s}: entry {s}: publication must be an object", .{ ledger_path, id });
                return;
            },
        };
        for ([_][]const u8{ "committed", "pushed" }) |field| {
            const value = object.get(field) orelse {
                fail("{s}: entry {s}: publication missing {s}", .{ ledger_path, id, field });
                continue;
            };
            if (value != .bool) fail("{s}: entry {s}: publication.{s} must be a boolean", .{ ledger_path, id, field });
        }
    } else fail("{s}: entry {s}: missing publication", .{ ledger_path, id });

    if (getString(entry, "conversation")) |conversation| {
        try checkRecordPath(io, arena, ledger_path, id, conversation, "conversations/", referenced);
    } else fail("{s}: entry {s}: missing conversation", .{ ledger_path, id });

    if (entry.get("research")) |research| {
        switch (research) {
            .null => {},
            .string => |value| try checkRecordPath(io, arena, ledger_path, id, value, "researches/", referenced),
            else => fail("{s}: entry {s}: research must be a string or null", .{ ledger_path, id }),
        }
    } else fail("{s}: entry {s}: missing research", .{ ledger_path, id });
}

fn checkRecordPath(
    io: std.Io,
    arena: std.mem.Allocator,
    ledger_path: []const u8,
    id: []const u8,
    record: []const u8,
    expected_prefix: []const u8,
    referenced: *std.ArrayList([]const u8),
) !void {
    if (!std.mem.startsWith(u8, record, expected_prefix) or !std.mem.endsWith(u8, record, ".md")) {
        fail("{s}: entry {s}: record path must be {s}*.md: {s}", .{ ledger_path, id, expected_prefix, record });
    }
    if (std.mem.indexOf(u8, record, id) == null) {
        fail("{s}: entry {s}: record filename does not contain the entry id: {s}", .{ ledger_path, id, record });
    }
    const full = try std.fs.path.join(arena, &.{ "agents", record });
    for (referenced.items) |existing| {
        if (std.mem.eql(u8, existing, full)) {
            fail("{s}: record referenced by more than one entry: {s}", .{ ledger_path, record });
        }
    }
    std.Io.Dir.cwd().access(io, full, .{}) catch {
        fail("{s}: entry {s}: record file missing: {s}", .{ ledger_path, id, record });
    };
    try referenced.append(arena, full);
}

fn checkOrphanRecords(io: std.Io, arena: std.mem.Allocator, dir_path: []const u8, referenced: []const []const u8) !void {
    var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch return;
    defer dir.close(io);
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".md")) continue;
        const full = try std.fs.path.join(arena, &.{ dir_path, entry.name });
        var found = false;
        for (referenced) |candidate| {
            if (std.mem.eql(u8, candidate, full)) found = true;
        }
        if (!found) fail("{s}: orphan record not referenced by agents/history.json", .{full});
    }
}

fn getString(object: std.json.ObjectMap, field: []const u8) ?[]const u8 {
    const value = object.get(field) orelse return null;
    return switch (value) {
        .string => |string| string,
        else => null,
    };
}

fn checkIntField(path: []const u8, object: std.json.ObjectMap, field: []const u8, expected: i64) void {
    const value = object.get(field) orelse {
        fail("{s}: missing {s}", .{ path, field });
        return;
    };
    switch (value) {
        .integer => |integer| if (integer != expected) fail("{s}: {s} must be {d}", .{ path, field, expected }),
        else => fail("{s}: {s} must be an integer", .{ path, field }),
    }
}

fn checkStringField(path: []const u8, object: std.json.ObjectMap, field: []const u8, expected: []const u8) void {
    const value = getString(object, field) orelse {
        fail("{s}: missing string {s}", .{ path, field });
        return;
    };
    if (!std.mem.eql(u8, value, expected)) fail("{s}: {s} must be \"{s}\"", .{ path, field, expected });
}

fn checkStringArray(path: []const u8, id: []const u8, object: std.json.ObjectMap, field: []const u8) void {
    const value = object.get(field) orelse {
        fail("{s}: entry {s}: missing {s}", .{ path, id, field });
        return;
    };
    const list = switch (value) {
        .array => |array| array,
        else => {
            fail("{s}: entry {s}: {s} must be an array", .{ path, id, field });
            return;
        },
    };
    for (list.items) |item| {
        switch (item) {
            .string => |string| if (string.len == 0) fail("{s}: entry {s}: {s} contains an empty string", .{ path, id, field }),
            else => fail("{s}: entry {s}: {s} must contain only strings", .{ path, id, field }),
        }
    }
}

fn isUuidV4(id: []const u8) bool {
    if (id.len != 36) return false;
    for (id, 0..) |char, index| {
        switch (index) {
            8, 13, 18, 23 => if (char != '-') return false,
            14 => if (char != '4') return false,
            19 => switch (char) {
                '8', '9', 'a', 'b' => {},
                else => return false,
            },
            else => switch (char) {
                '0'...'9', 'a'...'f' => {},
                else => return false,
            },
        }
    }
    return true;
}

fn isUtcTimestamp(value: []const u8) bool {
    // Shape: YYYY-MM-DDTHH:MM:SSZ
    if (value.len != 20) return false;
    for (value, 0..) |char, index| {
        switch (index) {
            4, 7 => if (char != '-') return false,
            10 => if (char != 'T') return false,
            13, 16 => if (char != ':') return false,
            19 => if (char != 'Z') return false,
            else => if (char < '0' or char > '9') return false,
        }
    }
    return true;
}

test "isUuidV4 accespt valid values and rejects invalid ones" {
    // Valid 36
    try std.testing.expect(isUuidV4("ed834826-aab2-414a-b06b-e26301cb9aa0"));
    // Invalid 35 and 37
    try std.testing.expect(!isUuidV4("ed834826-aab2-414a-b06b-e26301cb9aa"));
    try std.testing.expect(!isUuidV4("ed834826-aab2-414a-b06b-e26301cb9aa01"));
    // Uppercase not allowed
    try std.testing.expect(!isUuidV4("ED834826-AAB2-414A-B06B-E26301CB9AA0"));
}
