const std = @import("std");

const ModuleSpec = struct {
    name: []const u8,
    root: []const u8,
    imports: []const []const u8 = &.{},
};

const product_modules = [_]ModuleSpec{
    .{ .name = "foundation", .root = "src/foundation/module.zig" },
    .{ .name = "text", .root = "src/text/module.zig", .imports = &.{"foundation"} },
    .{ .name = "workspace", .root = "src/workspace/module.zig", .imports = &.{ "foundation", "text" } },
    .{ .name = "commands", .root = "src/commands/module.zig", .imports = &.{"foundation"} },
    .{ .name = "ports", .root = "src/ports/module.zig", .imports = &.{ "foundation", "text", "workspace" } },
    .{ .name = "application", .root = "src/application/module.zig", .imports = &.{ "foundation", "workspace", "commands", "ports" } },
    .{ .name = "adapters", .root = "src/adapters/module.zig", .imports = &.{ "foundation", "ports" } },
    .{ .name = "ui", .root = "src/ui/module.zig", .imports = &.{ "application", "ports" } },
    .{ .name = "composition", .root = "src/composition/main.zig", .imports = &.{ "application", "adapters", "ui" } },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var modules = std.StringHashMap(*std.Build.Module).init(b.allocator);
    for (product_modules) |spec| {
        const module = b.createModule(.{
            .root_source_file = b.path(spec.root),
            .target = target,
            .optimize = optimize,
        });
        modules.put(spec.name, module) catch @panic("OOM");
    }
    for (product_modules) |spec| {
        const module = modules.get(spec.name).?;
        for (spec.imports) |import_name| {
            module.addImport(import_name, modules.get(import_name).?);
        }
    }

    const zigide = b.addExecutable(.{
        .name = "zigide",
        .root_module = modules.get("composition").?,
    });
    b.installArtifact(zigide);

    const run_zigide = b.addRunArtifact(zigide);
    const run_step = b.step("run", "Run the Zigide executable");
    run_step.dependOn(&run_zigide.step);

    const check_exe = b.addExecutable(.{
        .name = "zigide-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/check.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const fmt_check = b.addFmt(.{
        .paths = &.{ "build.zig", "build.zig.zon", "src", "tests", "tools" },
        .check = true,
    });

    const run_check = b.addRunArtifact(check_exe);
    // The checker resolves repository paths relative to its working directory.
    run_check.setCwd(b.path("."));

    const check_tests = b.addTest(.{
        .root_module = check_exe.root_module,
    });
    const run_tests = b.addRunArtifact(check_tests);

    const unit_module = b.createModule(.{
        .root_source_file = b.path("tests/unit.zig"),
        .target = target,
        .optimize = optimize,
    });
    for (product_modules) |spec| {
        unit_module.addImport(spec.name, modules.get(spec.name).?);
    }
    const unit_tests = b.addTest(.{ .root_module = unit_module });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const integration_options = b.addOptions();
    integration_options.addOptionPath("zigide_executable", zigide.getEmittedBin());
    const integration_module = b.createModule(.{
        .root_source_file = b.path("tests/integration.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_module.addOptions("build_options", integration_options);
    const integration_tests = b.addTest(.{ .root_module = integration_module });
    const run_integration_tests = b.addRunArtifact(integration_tests);
    run_integration_tests.setCwd(b.path("."));
    run_integration_tests.step.dependOn(&zigide.step);

    const foundation_spec = for (product_modules) |spec| {
        if (std.mem.eql(u8, spec.name, "foundation")) break spec;
    } else unreachable;
    const forbidden_import_root = b.createModule(.{
        .root_source_file = b.path("tests/fixtures/forbidden_domain_ui_import.zig"),
        .target = target,
        .optimize = optimize,
    });
    for (foundation_spec.imports) |import_name| {
        forbidden_import_root.addImport(import_name, modules.get(import_name).?);
    }
    const forbidden_import = b.addTest(.{
        .name = "forbidden-import-fixture",
        .root_module = forbidden_import_root,
    });
    forbidden_import.expect_errors = .{ .contains = "error: no module named 'ui' available within module 'root'" };

    const unit_test_step = b.step("unit-test", "Run product unit tests");
    unit_test_step.dependOn(&run_unit_tests.step);

    const integration_test_step = b.step("integration-test", "Run product integration tests");
    integration_test_step.dependOn(&run_integration_tests.step);

    const test_step = b.step("test", "Run repository, unit, integration, and module-boundary tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_integration_tests.step);
    test_step.dependOn(&forbidden_import.step);

    const check_step = b.step("check", "Run repository checks: unit tests, hygiene, Markdown links, trace ledger, zig fmt");
    check_step.dependOn(test_step);
    check_step.dependOn(&fmt_check.step);
    check_step.dependOn(&run_check.step);

    const hooks_cmd = b.addSystemCommand(&.{ "git", "config", "core.hooksPath", ".githooks" });
    const hooks_step = b.step("hooks", "Point git at .githooks so pre-commit runs the repository checks");
    hooks_step.dependOn(&hooks_cmd.step);
}
