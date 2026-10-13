//! Native Zig candidate: pinned DVUI + SDL3 + static AccessKit, isolated from the core.
const std = @import("std");
const dvui = @import("dvui");
const scenario = @import("ui_scenario");

pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{ .logFn = dvui.App.logFn };
pub const dvui_app: dvui.App = .{
    .config = .{ .startFn = &startOptions },
    .initFn = initialize,
    .frameFn = frame,
    .deinitFn = deinitialize,
};

fn startOptions() dvui.App.StartOptions {
    const init = dvui.App.main_init.?;
    const args = init.minimal.args.toSlice(init.arena.allocator()) catch @panic("OOM");
    var hidden = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--probe")) hidden = true;
    }
    return .{
        .size = .{ .w = scenario.width, .h = scenario.height },
        .min_size = .{ .w = 640, .h = 480 },
        .title = "Zigide UI spike · DVUI",
        .org = "zigide-spike",
        .persist_window_geometry = false,
        .hidden = hidden,
    };
}

const Search = struct {
    bytes: []const u8,
    done: std.atomic.Value(bool) = .init(false),
    matches: usize = 0,

    fn run(self: *Search) void {
        self.matches = scenario.search(self.bytes);
        self.done.store(true, .release);
    }
};

var content: std.ArrayList(u8) = .empty;
var worker: Search = undefined;
var thread: ?std.Thread = null;
var version: u64 = 0;
var source_version: u64 = 0;
var matches: ?usize = null;
var started: i96 = 0;
var search_started: i96 = 0;
var ready_at: i96 = 0;
var frames: usize = 0;
var probe = false;
var frame_max_ms: f64 = 0;
var last_frame: i96 = 0;
var scroll_ms: f64 = 0;

fn clock() i96 {
    return std.Io.Clock.awake.now(dvui.App.main_init.?.io).nanoseconds;
}

fn milliseconds(ns: i96) f64 {
    return @as(f64, @floatFromInt(ns)) / 1_000_000.0;
}

fn emit(comptime format: []const u8, args: anytype) void {
    std.debug.print(format ++ "\n", args);
}

fn initialize(win: *dvui.Window) !void {
    started = clock();
    const args = try dvui.App.main_init.?.minimal.args.toSlice(win.gpa);
    defer win.gpa.free(args);
    var input_fixture = std.mem.indexOf(u8, args[0], "-input.app/") != null;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--probe")) {
            probe = true;
        } else if (std.mem.eql(u8, arg, "--input-fixture")) {
            input_fixture = true;
        } else return error.UnknownUiSpikeArgument;
    }
    if (probe and input_fixture) return error.ProbeRequiresLargeFixture;
    const bytes = try scenario.fixture(win.gpa, if (input_fixture) 32 else scenario.line_count);
    content = .fromOwnedSlice(bytes);
    // Retain an immutable snapshot until the worker has joined.
    worker = .{ .bytes = try win.gpa.dupe(u8, bytes) };
    search_started = clock();
    thread = try std.Thread.spawn(.{}, Search.run, .{&worker});
}

fn deinitialize(win: *dvui.Window) void {
    if (thread) |owned| owned.join();
    win.gpa.free(worker.bytes);
    content.deinit(win.gpa);
}

fn frame() !dvui.App.Result {
    const win = dvui.currentWindow();
    const timestamp = clock();
    if (last_frame != 0) frame_max_ms = @max(frame_max_ms, milliseconds(timestamp - last_frame));
    last_frame = timestamp;
    frames += 1;
    if (worker.done.load(.acquire) and matches == null and source_version == version) {
        matches = worker.matches;
        emit("{{\"event\":\"background_result\",\"matches\":{d},\"delivery_ms\":{d}}}", .{ worker.matches, milliseconds(clock() - search_started) });
    }
    {
        const size = dvui.windowRect();
        var explorer = dvui.box(@src(), .{ .dir = .vertical }, .{
            .rect = .{ .x = 0, .y = 0, .w = scenario.explorer_width, .h = size.h },
            .padding = .all(18),
            .label = .{ .text = "Explorer" },
            .role = .group,
        });
        defer explorer.deinit();
        dvui.labelNoFmt(@src(), "Explorer", .{}, .{});
        if (dvui.button(@src(), "fixture.zig", .{}, .{ .tab_index = 0 })) {
            dvui.focusWidget(dvui.dataGet(null, win.data().id, "editor-id", dvui.Id), null, null);
        }
        if (dvui.button(@src(), "Search needle", .{}, .{ .tab_index = 1 })) {
            // Same immutable-fixture search as system candidates. Joining only occurs after completion.
            if (worker.done.load(.acquire)) {
                if (thread) |owned| owned.join();
                thread = null;
                worker.done.store(false, .release);
                source_version = version;
                matches = null;
                search_started = clock();
                thread = try std.Thread.spawn(.{}, Search.run, .{&worker});
            }
        }
    }
    {
        const size = dvui.windowRect();
        const editor = dvui.textEntry(@src(), .{
            .text = .{ .array_list = .{ .backing = &content, .allocator = win.gpa, .limit = 16 * 1024 * 1024 } },
            .multiline = true,
            .break_lines = false,
            .cache_layout = true,
        }, .{
            .rect = .{ .x = scenario.explorer_width, .y = 0, .w = size.w - scenario.explorer_width, .h = size.h - scenario.panel_height },
            .font = .theme(.mono),
            .label = .{ .text = "Zig source editor" },
            .tab_index = 2,
        });
        defer editor.deinit();
        dvui.dataSet(null, win.data().id, "editor-id", editor.data().id);
        if (frames == 1) dvui.focusWidget(editor.data().id, null, null);
        if (editor.text_changed and frames > 1) version += 1;
        // Forced scroll offsets exercise the same large fixture. This is not a physical frame benchmark.
        if (probe and frames > 3 and frames <= 123) {
            const before = clock();
            editor.scroll.si.viewport.y = if (frames % 2 == 0) @max(0, editor.scroll.si.virtual_size.h - editor.scroll.si.viewport.h) else 0;
            scroll_ms += milliseconds(clock() - before);
        }
    }
    {
        const size = dvui.windowRect();
        var panel = dvui.box(@src(), .{ .dir = .vertical }, .{
            .rect = .{ .x = scenario.explorer_width, .y = size.h - scenario.panel_height, .w = size.w - scenario.explorer_width, .h = scenario.panel_height },
            .padding = .all(16),
            .label = .{ .text = "Search results" },
            .role = .group,
        });
        defer panel.deinit();
        dvui.labelNoFmt(@src(), "Search results", .{}, .{});
        if (matches) |count| {
            dvui.label(@src(), "{d} matches · version {d}", .{ count, source_version }, .{});
        } else dvui.labelNoFmt(@src(), "Waiting for background search", .{}, .{});
    }
    if (frames == 3) {
        ready_at = clock();
        emit("{{\"event\":\"ready\",\"candidate\":\"dvui\",\"startup_ms\":{d},\"fixture_bytes\":{d},\"scale\":{d},\"build_mode\":\"{s}\",\"offscreen\":{}}}", .{ milliseconds(ready_at - started), worker.bytes.len, win.content_scale, @tagName(@import("builtin").mode), probe });
    }
    if (probe) {
        dvui.refresh(null, @src(), null);
        if (frames > 123 and clock() - ready_at > 1_000_000_000) {
            if (matches != scenario.line_count) return error.BackgroundSearchMismatch;
            emit("{{\"event\":\"metrics\",\"passed\":true,\"frame_count\":{d},\"frame_max_ms\":{d},\"scroll_offset_ms\":{d},\"input_verified\":false,\"voiceover_verified\":false}}", .{ frames, frame_max_ms, scroll_ms });
            return .close;
        }
    }
    return .ok;
}
