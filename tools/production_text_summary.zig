//! Summarize production benchmark CSV in Zig; nearest-rank p95.
const std = @import("std");
const workloads = @import("text_workloads.zig");
const Sample = struct { ns: u64, current: usize, peak: usize };
const Group = struct { key: []const u8, samples: std.ArrayList(Sample) = .empty };

fn percentileIndex(count: usize, percent: usize) usize {
    return (count * percent + 99) / 100 - 1;
}
fn less(_: void, a: Sample, b: Sample) bool {
    return a.ns < b.ns;
}
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 3 and args.len != 4) return error.ExpectedInputCsvAndOutputCsv;
    const check = args.len == 4 and std.mem.eql(u8, args[3], "--check-budgets");
    if (args.len == 4 and !check) return error.UnknownOption;
    const data = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(16 * 1024 * 1024));
    var groups: std.ArrayList(Group) = .empty;
    var lines = std.mem.tokenizeScalar(u8, data, '\n');
    const header = lines.next() orelse return error.MissingHeader;
    if (!std.mem.eql(u8, header, "fixture,bytes,model,operation,iteration,ns,current_requested_bytes,peak_requested_bytes")) return error.InvalidHeader;
    while (lines.next()) |line| {
        var fields = std.mem.splitScalar(u8, line, ',');
        const fixture = fields.next() orelse return error.MissingField;
        const size = fields.next() orelse return error.MissingField;
        const model = fields.next() orelse return error.MissingField;
        const operation = fields.next() orelse return error.MissingField;
        _ = fields.next() orelse return error.MissingField;
        const ns = try std.fmt.parseInt(u64, fields.next() orelse return error.MissingField, 10);
        const current = try std.fmt.parseInt(usize, fields.next() orelse return error.MissingField, 10);
        const peak = try std.fmt.parseInt(usize, fields.next() orelse return error.MissingField, 10);
        if (fields.next() != null) return error.ExtraField;
        const key = try std.fmt.allocPrint(allocator, "{s},{s},{s},{s}", .{ fixture, size, model, operation });
        var found: ?usize = null;
        for (groups.items, 0..) |group, i| if (std.mem.eql(u8, key, group.key)) {
            found = i;
            break;
        };
        if (found == null) {
            found = groups.items.len;
            try groups.append(allocator, .{ .key = key });
        }
        try groups.items[found.?].samples.append(allocator, .{ .ns = ns, .current = current, .peak = peak });
    }
    var output: std.ArrayList(u8) = .empty;
    try output.appendSlice(allocator, "fixture,bytes,model,operation,samples,median_ns,p95_ns,max_ns,max_current_requested_bytes,max_peak_requested_bytes\n");
    var failures: usize = 0;
    if (check and groups.items.len != 85) return error.IncompleteProductionEvidence;
    for (groups.items) |*group| {
        const samples = group.samples.items;
        std.mem.sort(Sample, samples, {}, less);
        var current: usize = 0;
        var peak: usize = 0;
        for (samples) |sample| {
            current = @max(current, sample.current);
            peak = @max(peak, sample.peak);
        }
        if (check) {
            var fields = std.mem.splitScalar(u8, group.key, ',');
            const fixture = fields.next().?;
            const size = try std.fmt.parseInt(usize, fields.next().?, 10);
            if (!std.mem.eql(u8, fields.next().?, "production-piece-table")) return error.ExpectedProductionModel;
            const operation = fields.next().?;
            try validateGroup(fixture, size, operation, samples.len);
            const limit = latencyLimit(operation);
            if (samples[percentileIndex(samples.len, 95)].ns > limit or peak > size * 8 + 512 * 1024) {
                failures += 1;
                std.debug.print("BUDGET MISS {s}: p95={d}ns limit={d}ns peak={d}B memory limit={d}B\n", .{ group.key, samples[percentileIndex(samples.len, 95)].ns, limit, peak, size * 8 + 512 * 1024 });
            }
        }
        const row = try std.fmt.allocPrint(allocator, "{s},{d},{d},{d},{d},{d},{d}\n", .{ group.key, samples.len, samples[percentileIndex(samples.len, 50)].ns, samples[percentileIndex(samples.len, 95)].ns, samples[samples.len - 1].ns, current, peak });
        try output.appendSlice(allocator, row);
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[2], .data = output.items });
    if (failures > 0) return error.TextBudgetExceeded;
    std.debug.print("Summarized {d} fixture/operation groups to {s}\n", .{ groups.items.len, args[2] });
}
fn validateGroup(fixture_name: []const u8, size: usize, operation: []const u8, count: usize) !void {
    var known = false;
    for (workloads.fixtures) |fixture| {
        if (std.mem.eql(u8, fixture_name, fixture.name) and size == fixture.size / fixture.pattern.len * fixture.pattern.len) known = true;
    }
    if (!known) return error.UnknownFixture;
    const expected: usize = if (std.meta.stringToEnum(workloads.Operation, operation) != null)
        workloads.samples
    else if (std.mem.eql(u8, operation, "sustained-replace"))
        workloads.edits
    else if (std.mem.eql(u8, operation, "fragmented-offset-to-position") or std.mem.eql(u8, operation, "fragmented-position-to-offset"))
        workloads.samples
    else if (std.mem.eql(u8, operation, "churn-insert") or std.mem.eql(u8, operation, "churn-delete"))
        64
    else if (std.mem.eql(u8, operation, "memory-open") or std.mem.eql(u8, operation, "memory-sustained") or std.mem.eql(u8, operation, "memory-churn") or std.mem.eql(u8, operation, "memory-four-snapshots"))
        1
    else
        return error.UnknownOperation;
    if (count != expected) return error.IncompleteProductionEvidence;
}
fn latencyLimit(operation: []const u8) u64 {
    if (std.mem.startsWith(u8, operation, "memory-")) return 0;
    if (std.mem.indexOf(u8, operation, "position") != null or std.mem.eql(u8, operation, "position_to_offset")) return 10_000;
    if (std.mem.eql(u8, operation, "open")) return 50_000_000;
    if (std.mem.eql(u8, operation, "snapshot")) return 10_000_000;
    return 16_000_000;
}
test "nearest rank median and p95 preserve small sample extremes" {
    try std.testing.expectEqual(@as(usize, 0), percentileIndex(1, 95));
    try std.testing.expectEqual(@as(usize, 15), percentileIndex(31, 50));
    try std.testing.expectEqual(@as(usize, 29), percentileIndex(31, 95));
    try std.testing.expectEqual(@as(usize, 972), percentileIndex(1024, 95));
}

test "budget validation rejects missing samples and substituted fixtures or operations" {
    try std.testing.expectError(error.IncompleteProductionEvidence, validateGroup("small", 4096, "open", 30));
    try std.testing.expectError(error.UnknownFixture, validateGroup("small", 4000, "open", 31));
    try std.testing.expectError(error.UnknownOperation, validateGroup("small", 4096, "unmeasured", 31));
}
