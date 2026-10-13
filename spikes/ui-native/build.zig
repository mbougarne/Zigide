//! Isolated toolkit dependency graph; product checks do not fetch UI dependencies.
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dvui = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .sdl3,
        .accesskit = .static,
        .freetype = false,
        .tvg = false,
        .@"tiny-file-dialogs" = false,
        .@"tree-sitter" = false,
    });
    const module = b.createModule(.{
        .root_source_file = b.path("../../src/ui/spike/dvui.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Static AccessKit exposes Objective-C/AppKit references that a dynamic SDL
    // library does not make available to the final executable's link step.
    module.linkFramework("Cocoa", .{});
    module.linkSystemLibrary("objc", .{});
    module.addImport("dvui", dvui.module("dvui_sdl3"));
    module.addImport("ui_scenario", b.createModule(.{
        .root_source_file = b.path("../../src/ui/spike/scenario.zig"),
        .target = target,
        .optimize = optimize,
    }));
    const executable = b.addExecutable(.{ .name = "ui-native", .root_module = module });
    b.installArtifact(executable);
}
