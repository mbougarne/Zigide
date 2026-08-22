const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const check_exe = b.addExecutable(.{
        .name = "zigide-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/check.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const fmt_check = b.addFmt(.{
        .paths = &.{ "build.zig", "build.zig.zon", "tools" },
        .check = true,
    });

    const run_check = b.addRunArtifact(check_exe);
    // The checker resolves repository paths relative to its working directory.
    run_check.setCwd(b.path("."));

    const check_step = b.step("check", "Run repository checks: hygiene, Markdown links, trace ledger, zig fmt");
    check_step.dependOn(&fmt_check.step);
    check_step.dependOn(&run_check.step);

    const hooks_cmd = b.addSystemCommand(&.{ "git", "config", "core.hooksPath", ".githooks" });
    const hooks_step = b.step("hooks", "Point git at .githooks so pre-commit runs the repository checks");
    hooks_step.dependOn(&hooks_cmd.step);
}
