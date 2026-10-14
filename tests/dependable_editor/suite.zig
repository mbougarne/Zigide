//! Exit contract and prerequisite checks, not an implementation of the editor journey.
const std = @import("std");

pub const Outcome = enum { shell, editing, settings, recovery, input, crash_safety, large_file, sustained_edit };
pub const Layer = enum { domain, integration, crash, ui, accessibility, performance };
pub const Blocker = enum { functional, data_loss, accessibility, critical_latency };
pub const Ref = struct { id: []const u8, file: []const u8 };
pub const Check = struct {
    id: []const u8,
    outcome: Outcome,
    layer: Layer,
    owner: Ref,
    blocker: Blocker,
    completion: []const u8,
};

pub const dependencies = [_]Ref{
    .{ .id = "ZIT-051", .file = "tickets/production-text-model.md" },
    .{ .id = "ZIT-057", .file = "tickets/document-and-workspace-lifecycle.md" },
    .{ .id = "ZIT-063", .file = "tickets/selection-undo-and-redo.md" },
    .{ .id = "ZIT-070", .file = "tickets/safe-file-io.md" },
    .{ .id = "ZIT-076", .file = "tickets/configuration-and-keybindings.md" },
    .{ .id = "ZIT-083", .file = "tickets/crash-recovery.md" },
    .{ .id = "ZIT-089", .file = "tickets/macos-application-shell.md" },
    .{ .id = "ZIT-099", .file = "tickets/editor-input-rendering-and-accessibility.md" },
    .{ .id = "ZIT-106", .file = "tickets/explorer-command-palette-and-status.md" },
};

pub const checks = [_]Check{
    .{ .id = "shell", .outcome = .shell, .layer = .ui, .owner = dependencies[6], .blocker = .functional, .completion = "Launch, resize, reopen and terminate the production bundle; explorer/editor/palette/status remain available." },
    .{ .id = "navigation", .outcome = .shell, .layer = .accessibility, .owner = dependencies[8], .blocker = .accessibility, .completion = "Complete explorer, documents, palette and status navigation using keyboard and observed VoiceOver; preserve focus." },
    .{ .id = "text", .outcome = .editing, .layer = .domain, .owner = .{ .id = "ZIT-050", .file = "tickets/production-text-model.md" }, .blocker = .data_loss, .completion = "Production edits, snapshots, positions and encoding metadata match the oracle, including allocation failure." },
    .{ .id = "documents", .outcome = .editing, .layer = .integration, .owner = dependencies[1], .blocker = .data_loss, .completion = "Open two resources once, track active/dirty state, cancel close and reject stale results after close/reopen." },
    .{ .id = "history", .outcome = .editing, .layer = .domain, .owner = dependencies[2], .blocker = .data_loss, .completion = "Undo/redo restores exact bytes and selections across files, branching and bounded-history eviction." },
    .{ .id = "files", .outcome = .editing, .layer = .integration, .owner = dependencies[3], .blocker = .data_loss, .completion = "Open, save and Save As preserve bytes, identity and permissions; disk divergence requires an explicit decision." },
    .{ .id = "save-crash", .outcome = .crash_safety, .layer = .crash, .owner = dependencies[3], .blocker = .data_loss, .completion = "Terminate only the fixture child at write/sync/rename boundaries; disk contains a complete old or new file and dirty data remains recoverable." },
    .{ .id = "settings", .outcome = .settings, .layer = .integration, .owner = dependencies[4], .blocker = .data_loss, .completion = "Inspect effective scopes, change settings/keybindings, reject invalid siblings and stale reloads without overwriting user input." },
    .{ .id = "settings-crash", .outcome = .settings, .layer = .crash, .owner = .{ .id = "ZIT-075", .file = "tickets/configuration-and-keybindings.md" }, .blocker = .data_loss, .completion = "Interrupt atomic settings/keybinding persistence; reopen the last complete valid file." },
    .{ .id = "recovery", .outcome = .recovery, .layer = .crash, .owner = dependencies[5], .blocker = .data_loss, .completion = "Recover edits covered by snapshot cadence; isolate corrupt siblings; cancel divergence without changing newer disk content; clean only resolved snapshots." },
    .{ .id = "input", .outcome = .input, .layer = .ui, .owner = dependencies[7], .blocker = .functional, .completion = "Observe keyboard, mouse, private clipboard, Unicode/RTL, physical IME update/commit/cancel, fallback and display scaling on the target Mac." },
    .{ .id = "editor-accessibility", .outcome = .input, .layer = .accessibility, .owner = dependencies[7], .blocker = .accessibility, .completion = "Observe VoiceOver text, selection, focus, commands and actionable errors without trapping navigation or blocking input." },
    .{ .id = "large-file", .outcome = .large_file, .layer = .performance, .owner = dependencies[0], .blocker = .critical_latency, .completion = "Define approved numeric open/lookup/memory budgets before measuring production storage on the 4 MiB and long-line fixtures; retain all samples." },
    .{ .id = "sustained-edit", .outcome = .sustained_edit, .layer = .performance, .owner = dependencies[0], .blocker = .critical_latency, .completion = "Measure 1024 scattered production edits plus paste/delete churn against approved p95 and memory budgets; verify final bytes against the oracle." },
    .{ .id = "input-latency", .outcome = .input, .layer = .performance, .owner = dependencies[7], .blocker = .critical_latency, .completion = "Measure visible typing, scrolling and background delivery against approved UI budgets; offscreen probes cannot qualify visible latency." },
};

pub const Status = enum { Planned, Ready, @"In Progress", Blocked, Done, Cancelled, Superseded };

pub fn ticketSection(content: []const u8, id: []const u8) ![]const u8 {
    var result: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "## ")) continue;
        const heading = line[3..];
        if (heading.len <= id.len or !std.mem.eql(u8, heading[0..id.len], id) or heading[id.len] != ':') continue;
        if (result != null) return error.DuplicateTicket;
        const start = lines.index orelse content.len;
        const end = if (std.mem.startsWith(u8, content[start..], "## ")) start else if (std.mem.indexOfPos(u8, content, start, "\n## ")) |n| n else content.len;
        result = content[start..end];
    }
    return result orelse error.MissingTicket;
}

pub fn ticketStatus(content: []const u8, id: []const u8) !Status {
    const section = try ticketSection(content, id);
    var result: ?Status = null;
    var lines = std.mem.splitScalar(u8, section, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        const prefix = "- **Status:** ";
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        if (result != null) return error.DuplicateStatus;
        result = std.meta.stringToEnum(Status, line[prefix.len..]) orelse return error.InvalidStatus;
    }
    return result orelse error.MissingStatus;
}

pub fn adrAccepted(content: []const u8) !bool {
    var result: ?bool = null;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        const prefix = "* Status: ";
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        if (result != null) return error.DuplicateStatus;
        const status = line[prefix.len..];
        if (std.mem.eql(u8, status, "Accepted")) {
            result = true;
        } else if (std.mem.eql(u8, status, "Proposed") or std.mem.eql(u8, status, "Superseded")) {
            result = false;
        } else return error.InvalidStatus;
    }
    return result orelse error.MissingStatus;
}

pub fn validateDependencies(content: []const u8) !void {
    const section = try ticketSection(content, "ZIT-043");
    var lines = std.mem.splitScalar(u8, section, '\n');
    var found = false;
    while (lines.next()) |raw| {
        const prefix = "- **Dependencies:** ";
        if (!std.mem.startsWith(u8, raw, prefix)) continue;
        if (found) return error.DuplicateDependencies;
        found = true;
        var ids = std.mem.splitSequence(u8, std.mem.trimEnd(u8, raw[prefix.len..], "\r"), ", ");
        for (dependencies) |dependency| {
            if (!std.mem.eql(u8, ids.next() orelse return error.DependencyDrift, dependency.id)) return error.DependencyDrift;
        }
        if (ids.next() != null) return error.DependencyDrift;
    }
    if (!found) return error.MissingDependencies;
}

pub const JourneyState = enum { blocked, unrun };

pub fn journeyState(statuses: []const Status, accepted_adr: bool, target_supported: bool) JourneyState {
    if (statuses.len != dependencies.len or !accepted_adr or !target_supported) return .blocked;
    for (statuses) |status| if (status != .Done) return .blocked;
    // Readiness alone is never acceptance evidence.
    return .unrun;
}

test "exit contract covers every roadmap outcome, evidence layer and blocking class with unique checks" {
    inline for (.{ Outcome, Layer, Blocker }) |T| {
        for (std.enums.values(T)) |value| {
            var found = false;
            for (checks) |check| {
                const actual = if (T == Outcome) check.outcome else if (T == Layer) check.layer else check.blocker;
                if (actual == value) found = true;
            }
            try std.testing.expect(found);
        }
    }
    for (checks, 0..) |check, i| {
        try std.testing.expect(check.completion.len > 0);
        for (checks[0..i]) |previous| try std.testing.expect(!std.mem.eql(u8, check.id, previous.id));
    }
}

test "ticket status is scoped, exact and fail closed" {
    try std.testing.expectEqual(.Planned, try ticketStatus("## ZIT-051: Target\n- **Status:** Planned\nDone in description\n## ZIT-052: Other\n- **Status:** Done\n", "ZIT-051"));
    try std.testing.expectEqual(.Done, try ticketStatus("## ZIT-051: Target\r\n- **Status:** Done\r\n", "ZIT-051"));
    try std.testing.expectError(error.MissingTicket, ticketStatus("## ZIT-0510: Wrong\n- **Status:** Done\n", "ZIT-051"));
    try std.testing.expectError(error.MissingStatus, ticketStatus("## ZIT-051: Target\n## ZIT-052: Other\n- **Status:** Done\n", "ZIT-051"));
    try std.testing.expectError(error.InvalidStatus, ticketStatus("## ZIT-051: Target\n- **Status:** Done-ish\n", "ZIT-051"));
    try std.testing.expectError(error.DuplicateStatus, ticketStatus("## ZIT-051: Target\n- **Status:** Done\n- **Status:** Done\n", "ZIT-051"));
    try std.testing.expectError(error.DuplicateTicket, ticketStatus("## ZIT-051: First\n- **Status:** Done\n## ZIT-051: Second\n- **Status:** Done\n", "ZIT-051"));
}

test "readiness never passes the journey and every unresolved dependency blocks" {
    var statuses = [_]Status{.Done} ** dependencies.len;
    try std.testing.expectEqual(.unrun, journeyState(&statuses, true, true));
    for (&statuses) |*status| {
        for (std.enums.values(Status)) |value| {
            status.* = value;
            const expected: JourneyState = if (value == .Done) .unrun else .blocked;
            try std.testing.expectEqual(expected, journeyState(&statuses, true, true));
        }
        status.* = .Done;
    }
    try std.testing.expectEqual(.blocked, journeyState(&statuses, false, true));
    try std.testing.expectEqual(.blocked, journeyState(&statuses, true, false));
    try std.testing.expectEqual(.blocked, journeyState(statuses[0..1], true, true));
}

test "ADR decision status is exact and unique" {
    try std.testing.expect(try adrAccepted("* Status: Accepted\n"));
    try std.testing.expect(!try adrAccepted("* Status: Proposed\nAccepted in commentary\n"));
    try std.testing.expect(!try adrAccepted("* Status: Superseded\n"));
    try std.testing.expectError(error.MissingStatus, adrAccepted("Accepted\n"));
    try std.testing.expectError(error.InvalidStatus, adrAccepted("* Status: Accepted-ish\n"));
    try std.testing.expectError(error.DuplicateStatus, adrAccepted("* Status: Proposed\n* Status: Accepted\n"));
}

test "declared journey dependencies cannot drift from the gate" {
    const valid = "## ZIT-043: Journey\n- **Dependencies:** ZIT-051, ZIT-057, ZIT-063, ZIT-070, ZIT-076, ZIT-083, ZIT-089, ZIT-099, ZIT-106\n";
    try validateDependencies(valid);
    try std.testing.expectError(error.MissingDependencies, validateDependencies("## ZIT-043: Journey\n"));
    try std.testing.expectError(error.DependencyDrift, validateDependencies(valid[0 .. valid.len - 10]));
    try std.testing.expectError(error.DuplicateDependencies, validateDependencies(valid ++ "- **Dependencies:** ZIT-051\n"));
    try std.testing.expectError(error.DependencyDrift, validateDependencies("## ZIT-043: Journey\n- **Dependencies:** ZIT-051, ZIT-057, ZIT-063, ZIT-070, ZIT-076, ZIT-083, ZIT-089, ZIT-099, ZIT-106, ZIT-107\n"));
}
