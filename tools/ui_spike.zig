//! Opt-in macOS candidate runner. The C ABI is confined to the spike adapter.
const std = @import("std");
const scenario = @import("ui_scenario");

extern fn zigide_ui_fixture_lines() usize;
extern fn zigide_ui_run(bytes: [*]const u8, len: usize, web: bool, probe: bool) c_int;

export fn zigide_ui_clipboard_sample() [*:0]const u8 {
    return scenario.clipboard_text.ptr;
}

export fn zigide_ui_build_mode() [*:0]const u8 {
    return @tagName(@import("builtin").mode);
}

export fn zigide_ui_search(bytes: [*]const u8, len: usize) usize {
    return scenario.search(bytes[0..len]);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var web = false;
    var probe = false;
    var input_fixture = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--web")) {
            web = true;
        } else if (std.mem.eql(u8, arg, "--probe")) {
            probe = true;
        } else if (std.mem.eql(u8, arg, "--input-fixture")) {
            input_fixture = true;
        } else return error.UnknownUiSpikeArgument;
    }
    if (probe and input_fixture) return error.ProbeRequiresLargeFixture;
    const bytes = try scenario.fixture(init.gpa, if (input_fixture) 32 else zigide_ui_fixture_lines());
    defer init.gpa.free(bytes);
    if (zigide_ui_run(bytes.ptr, bytes.len, web, probe) != 0) return error.UiProbeFailed;
}
