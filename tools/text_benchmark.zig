//! Opt-in synthetic storage benchmark. CSV retains every timed sample and memory checkpoints.
const std = @import("std");
const text = @import("text");
const Meter = @import("text_memory.zig").Meter;
const workloads = @import("text_workloads.zig");
const samples = workloads.samples;
const edits = workloads.edits;
const Fixture = workloads.Fixture;
const fixtures = workloads.fixtures;
const Operation = workloads.Operation;
fn now(io: std.Io) i96 {
    return std.Io.Clock.awake.now(io).nanoseconds;
}
fn row(csv: *std.ArrayList(u8), allocator: std.mem.Allocator, fixture: Fixture, model: []const u8, operation: []const u8, iteration: usize, ns: i96, current: usize, peak: usize) !void {
    const line = try std.fmt.allocPrint(allocator, "{s},{d},{s},{s},{d},{d},{d},{d}\n", .{ fixture.name, fixture.size, model, operation, iteration, ns, current, peak });
    defer allocator.free(line);
    try csv.appendSlice(allocator, line);
}
fn snapshotBytes(comptime Model: type, model: *const Model, allocator: std.mem.Allocator) ![]u8 {
    return if (Model == text.Document) model.copy(allocator) else model.snapshot(allocator);
}
fn benchmark(comptime Model: type, init: std.process.Init, csv: *std.ArrayList(u8), fixture: Fixture, bytes: []const u8) !void {
    const label = if (Model == text.Reference) "reference" else if (Model == text.Document) "production-piece-table" else "piece-table";
    const middle = (bytes.len / fixture.pattern.len / 2) * fixture.pattern.len;
    for (std.enums.values(Operation)) |operation| {
        if (operation == .batch and Model != text.Document) continue;
        // One unrecorded warmup, then 31 individual observations; no timed I/O.
        for (0..samples + 1) |iteration| {
            var meter: Meter = .{ .backing = init.gpa };
            defer if (meter.current != 0) @panic("benchmark allocator did not return to zero");
            const allocator = meter.allocator();
            const open_start = now(init.io);
            var model = try Model.init(allocator, bytes);
            defer model.deinit();
            var elapsed: i96 = undefined;
            if (operation == .open) {
                elapsed = now(init.io) - open_start;
            } else {
                const pos = try model.position(middle);
                const start = now(init.io);
                switch (operation) {
                    .open => unreachable,
                    .batch => if (Model == text.Document) try model.apply(&.{ .{ .start = middle, .end = middle + 1, .inserted = "y" }, .{ .start = 0, .end = 1, .inserted = "z" } }) else unreachable,
                    .insert => try model.edit(.{ .start = middle, .end = middle, .inserted = "x\r\n" }),
                    .delete => try model.edit(.{ .start = middle, .end = middle + fixture.pattern.len, .inserted = "" }),
                    .replace => try model.edit(.{ .start = middle, .end = middle + 1, .inserted = "x" }),
                    .snapshot => {
                        if (Model == text.Document) {
                            var snapshot = try model.snapshot(allocator);
                            elapsed = now(init.io) - start;
                            std.mem.doNotOptimizeAway(std.hash.Wyhash.hash(0, snapshot.bytes));
                            snapshot.deinit();
                        } else {
                            const copy = try model.snapshot(allocator);
                            elapsed = now(init.io) - start;
                            std.mem.doNotOptimizeAway(std.hash.Wyhash.hash(0, copy));
                            allocator.free(copy);
                        }
                    },
                    .offset_to_position => std.mem.doNotOptimizeAway(try model.position(middle)),
                    .position_to_offset => std.mem.doNotOptimizeAway(try model.offset(pos)),
                }
                if (operation != .snapshot) elapsed = now(init.io) - start;
            }
            if (iteration > 0) try row(csv, init.gpa, fixture, label, @tagName(operation), iteration - 1, elapsed, meter.current, meter.peak);
        }
    }
    var meter: Meter = .{ .backing = init.gpa };
    var model = try Model.init(meter.allocator(), bytes);
    defer {
        model.deinit();
        if (meter.current != 0) @panic("benchmark allocator did not return to zero");
    }
    try row(csv, init.gpa, fixture, label, "memory-open", 0, 0, meter.current, meter.peak);
    var oracle = try text.Reference.init(init.gpa, bytes);
    defer oracle.deinit();
    var random = std.Random.DefaultPrng.init(0x027033);
    const units = bytes.len / fixture.pattern.len;
    for (0..edits) |iteration| {
        // Alternate far ends and uniformly scattered replacements; fixed-size edits
        // keep known UTF-8 boundaries while splitting descriptors throughout text.
        const unit = switch (iteration % 3) {
            0 => iteration / 3 % units,
            1 => units - 1 - iteration / 3 % units,
            else => random.random().uintLessThan(usize, units),
        };
        const at = unit * fixture.pattern.len;
        const edit: text.Edit = .{ .start = at, .end = at + 1, .inserted = "x" };
        const start = now(init.io);
        try model.edit(edit);
        const elapsed = now(init.io) - start;
        try row(csv, init.gpa, fixture, label, "sustained-replace", iteration, elapsed, meter.current, meter.peak);
        try oracle.edit(edit);
    }
    const final = try snapshotBytes(Model, &model, init.gpa);
    defer init.gpa.free(final);
    if (!std.mem.eql(u8, final, oracle.bytes)) return error.BenchmarkContentMismatch;
    // Lookup after fragmentation, rather than only on a one-piece document.
    const pos = try model.position(middle);
    for (0..samples) |iteration| {
        const start = now(init.io);
        std.mem.doNotOptimizeAway(try model.position(middle));
        const forward = now(init.io) - start;
        try row(csv, init.gpa, fixture, label, "fragmented-offset-to-position", iteration, forward, meter.current, meter.peak);
        const inverse_start = now(init.io);
        std.mem.doNotOptimizeAway(try model.offset(pos));
        const inverse = now(init.io) - inverse_start;
        try row(csv, init.gpa, fixture, label, "fragmented-position-to-offset", iteration, inverse, meter.current, meter.peak);
    }
    try row(csv, init.gpa, fixture, label, "memory-sustained", edits, 0, meter.current, meter.peak);
    // Bounded paste/delete churn exposes add-buffer history retained after deletion.
    var paste: [4096]u8 = undefined;
    @memset(&paste, 'z');
    for (0..64) |iteration| {
        const start = now(init.io);
        try model.edit(.{ .start = middle, .end = middle, .inserted = &paste });
        const inserted = now(init.io) - start;
        try row(csv, init.gpa, fixture, label, "churn-insert", iteration, inserted, meter.current, meter.peak);
        const delete_start = now(init.io);
        try model.edit(.{ .start = middle, .end = middle + paste.len, .inserted = "" });
        const deleted = now(init.io) - delete_start;
        try row(csv, init.gpa, fixture, label, "churn-delete", iteration, deleted, meter.current, meter.peak);
    }
    const after_churn = try snapshotBytes(Model, &model, init.gpa);
    defer init.gpa.free(after_churn);
    if (!std.mem.eql(u8, after_churn, oracle.bytes)) return error.BenchmarkChurnMismatch;
    try row(csv, init.gpa, fixture, label, "memory-churn", 64, 0, meter.current, meter.peak);
    if (Model == text.Document) {
        var snapshots: [4]text.Snapshot = undefined;
        var retained: usize = 0;
        defer for (snapshots[0..retained]) |*snapshot| snapshot.deinit();
        for (&snapshots) |*snapshot| {
            snapshot.* = try model.snapshot(meter.allocator());
            retained += 1;
            if (!std.mem.eql(u8, snapshot.bytes, oracle.bytes)) return error.BenchmarkSnapshotMismatch;
        }
        try row(csv, init.gpa, fixture, label, "memory-four-snapshots", 4, 0, meter.current, meter.peak);
    }
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const production = args.len > 1 and std.mem.eql(u8, args[1], "production");
    const path_index: usize = if (production) 2 else 1;
    if (args.len > path_index + 1) return error.ExpectedOptionalCsvPath;
    const path = if (args.len > path_index) args[path_index] else if (production) ".zig-cache/production-text.csv" else ".zig-cache/text-benchmark.csv";
    var csv: std.ArrayList(u8) = .empty;
    defer csv.deinit(init.gpa);
    try csv.appendSlice(init.gpa, "fixture,bytes,model,operation,iteration,ns,current_requested_bytes,peak_requested_bytes\n");
    for (fixtures) |fixture| {
        const size = fixture.size / fixture.pattern.len * fixture.pattern.len;
        const bytes = try init.gpa.alloc(u8, size);
        defer init.gpa.free(bytes);
        for (0..size / fixture.pattern.len) |i| @memcpy(bytes[i * fixture.pattern.len ..][0..fixture.pattern.len], fixture.pattern);
        var actual = fixture;
        actual.size = size;
        if (production) {
            try benchmark(text.Document, init, &csv, actual, bytes);
        } else {
            try benchmark(text.Reference, init, &csv, actual, bytes);
            try benchmark(text.PieceTable, init, &csv, actual, bytes);
        }
        std.debug.print("benchmarked {s}: {d} bytes; {d} samples/operation, {d} sustained edits/model\n", .{ fixture.name, size, samples, edits });
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.items });
    std.debug.print("CSV: {s}; Zig {s}; {s}; {s}-{s}\n", .{ path, @import("builtin").zig_version_string, @tagName(@import("builtin").mode), @tagName(@import("builtin").cpu.arch), @tagName(@import("builtin").os.tag) });
}

test {
    _ = @import("text_memory.zig");
}
