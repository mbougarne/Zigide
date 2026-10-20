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
        .paths = &.{ "build.zig", "build.zig.zon", "src", "tests", "tools", "spikes/ui-native/build.zig", "spikes/ui-native/build.zig.zon" },
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

    // Imported modules compile lazily; run their test roots explicitly so the
    // public-module smoke test cannot silently omit behavioral tests.
    const foundation_tests = b.addTest(.{ .root_module = modules.get("foundation").? });
    const run_foundation_tests = b.addRunArtifact(foundation_tests);
    const adapter_tests = b.addTest(.{ .root_module = modules.get("adapters").? });
    const run_adapter_tests = b.addRunArtifact(adapter_tests);

    const text_tests = b.addTest(.{ .root_module = modules.get("text").? });
    const run_text_tests = b.addRunArtifact(text_tests);

    const equivalence_module = b.createModule(.{ .root_source_file = b.path("tests/text_equivalence.zig"), .target = target, .optimize = optimize });
    equivalence_module.addImport("text", modules.get("text").?);
    const equivalence_tests = b.addTest(.{ .root_module = equivalence_module });
    const run_equivalence = b.addRunArtifact(equivalence_tests);
    const text_test_step = b.step("text-test", "Run text correctness, seeded differential tests and fuzz corpus replay");
    text_test_step.dependOn(&run_text_tests.step);
    text_test_step.dependOn(&run_equivalence.step);

    const history_module = b.createModule(.{ .root_source_file = b.path("tests/edit_history.zig"), .target = target, .optimize = optimize });
    history_module.addImport("text", modules.get("text").?);
    const history_tests = b.addTest(.{ .root_module = history_module });
    const history_test_step = b.step("history-test", "Run selection, transaction, undo/redo and seeded history tests");
    history_test_step.dependOn(&run_text_tests.step);
    history_test_step.dependOn(&b.addRunArtifact(history_tests).step);
    text_test_step.dependOn(history_test_step);

    const production_module = b.createModule(.{ .root_source_file = b.path("tests/production_text.zig"), .target = target, .optimize = optimize });
    production_module.addImport("text", modules.get("text").?);
    const production_tests = b.addTest(.{ .root_module = production_module });
    const run_production_tests = b.addRunArtifact(production_tests);
    const production_step = b.step("production-text-test", "Run production batch, snapshot, metadata and seeded oracle tests");
    production_step.dependOn(&run_text_tests.step);
    production_step.dependOn(&run_production_tests.step);
    text_test_step.dependOn(production_step);

    const workspace_tests = b.addTest(.{ .root_module = modules.get("workspace").? });
    const run_workspace_tests = b.addRunArtifact(workspace_tests);
    const workspace_test_step = b.step("workspace-test", "Run resource, document and workspace lifecycle tests");
    workspace_test_step.dependOn(&run_workspace_tests.step);
    workspace_test_step.dependOn(&run_adapter_tests.step);

    const command_tests = b.addTest(.{ .root_module = modules.get("commands").? });
    const run_command_tests = b.addRunArtifact(command_tests);

    const protocol_child_module = b.createModule(.{ .root_source_file = b.path("tests/fixtures/protocol_child.zig"), .target = target, .optimize = optimize });
    protocol_child_module.addImport("adapters", modules.get("adapters").?);
    const protocol_child = b.addExecutable(.{ .name = "protocol-child", .root_module = protocol_child_module });
    const integration_options = b.addOptions();
    integration_options.addOptionPath("protocol_child", protocol_child.getEmittedBin());
    integration_options.addOptionPath("zigide_executable", zigide.getEmittedBin());
    const integration_module = b.createModule(.{
        .root_source_file = b.path("tests/integration.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_module.addImport("adapters", modules.get("adapters").?);
    integration_module.addOptions("build_options", integration_options);
    integration_module.addImport("application", modules.get("application").?);
    integration_module.addImport("foundation", modules.get("foundation").?);
    integration_module.addImport("commands", modules.get("commands").?);
    integration_module.addImport("ports", modules.get("ports").?);
    integration_module.addImport("workspace", modules.get("workspace").?);
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

    const mixed_ids_root = b.createModule(.{
        .root_source_file = b.path("tests/fixtures/mixed_foundation_ids.zig"),
        .target = target,
        .optimize = optimize,
    });
    mixed_ids_root.addImport("foundation", modules.get("foundation").?);
    const mixed_ids = b.addTest(.{
        .name = "mixed-foundation-ids-fixture",
        .root_module = mixed_ids_root,
    });
    mixed_ids.expect_errors = .{ .contains = "expected type 'ids.CorrelationId', found 'ids.OperationId'" };

    const unit_test_step = b.step("unit-test", "Run product unit tests");
    unit_test_step.dependOn(&run_unit_tests.step);
    unit_test_step.dependOn(&mixed_ids.step);
    unit_test_step.dependOn(&run_foundation_tests.step);
    unit_test_step.dependOn(&run_adapter_tests.step);
    unit_test_step.dependOn(&run_command_tests.step);
    unit_test_step.dependOn(workspace_test_step);
    unit_test_step.dependOn(text_test_step);

    const integration_test_step = b.step("integration-test", "Run product integration tests");
    integration_test_step.dependOn(&run_integration_tests.step);

    const test_step = b.step("test", "Run repository, unit, integration, and module-boundary tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_integration_tests.step);
    test_step.dependOn(&forbidden_import.step);
    test_step.dependOn(&mixed_ids.step);
    test_step.dependOn(&run_foundation_tests.step);
    test_step.dependOn(&run_adapter_tests.step);
    test_step.dependOn(&run_command_tests.step);
    test_step.dependOn(workspace_test_step);
    test_step.dependOn(text_test_step);

    const check_step = b.step("check", "Run repository checks: unit tests, hygiene, Markdown links, trace ledger, zig fmt");
    check_step.dependOn(test_step);
    check_step.dependOn(&fmt_check.step);
    check_step.dependOn(&run_check.step);

    const editor_suite = b.createModule(.{ .root_source_file = b.path("tests/dependable_editor/suite.zig"), .target = target, .optimize = optimize });
    const editor_contract_tests = b.addTest(.{ .root_module = editor_suite });
    const editor_preflight_module = b.createModule(.{ .root_source_file = b.path("tools/dependable_editor.zig"), .target = target, .optimize = optimize });
    editor_preflight_module.addImport("editor_suite", editor_suite);
    editor_preflight_module.addAnonymousImport("journey_main", .{ .root_source_file = b.path("tests/dependable_editor/fixtures/main.zig") });
    editor_preflight_module.addAnonymousImport("journey_message", .{ .root_source_file = b.path("tests/dependable_editor/fixtures/message.zig") });
    const editor_preflight_tests = b.addTest(.{ .root_module = editor_preflight_module });
    const run_editor_preflight_tests = b.addRunArtifact(editor_preflight_tests);
    run_editor_preflight_tests.setCwd(b.path("."));
    const journey_fixture = b.addExecutable(.{ .name = "editing-journey-fixture", .root_module = b.createModule(.{ .root_source_file = b.path("tests/dependable_editor/fixtures/main.zig"), .target = target, .optimize = optimize }) });
    const editor_test_step = b.step("dependable-editor-test", "Validate exit contract, prerequisite parsing and maintained Zig project fixture (does not qualify the journey)");
    editor_test_step.dependOn(&b.addRunArtifact(editor_contract_tests).step);
    editor_test_step.dependOn(&run_editor_preflight_tests.step);
    editor_test_step.dependOn(&journey_fixture.step);
    test_step.dependOn(editor_test_step);
    const editor_preflight = b.addExecutable(.{ .name = "dependable-editor-preflight", .root_module = editor_preflight_module });
    const run_editor_preflight = b.addRunArtifact(editor_preflight);
    run_editor_preflight.setCwd(b.path("."));
    b.step("dependable-editor-preflight", "Report journey blockers to ignored JSON; exits 2 for blocked/unrun acceptance").dependOn(&run_editor_preflight.step);

    const spike_options = b.addOptions();
    spike_options.addOption([]const u8, "zls", b.option([]const u8, "zls", "Absolute path to ZLS 0.16.0 for the opt-in live fixture") orelse "zls");
    spike_options.addOption([]const u8, "zig", b.graph.zig_exe);
    const spike_module = b.createModule(.{ .root_source_file = b.path("tools/zls_spike.zig"), .target = target, .optimize = optimize });
    spike_module.addImport("adapters", modules.get("adapters").?);
    spike_module.addImport("foundation", modules.get("foundation").?);
    spike_module.addOptions("spike_options", spike_options);
    const spike = b.addExecutable(.{ .name = "zls-spike", .root_module = spike_module });
    const run_spike = b.addRunArtifact(spike);
    run_spike.setCwd(b.path("."));
    b.step("zls-spike", "Validate initialize/shutdown against real ZLS 0.16.0 (requires -Dzls=/absolute/path)").dependOn(&run_spike.step);

    const benchmark_module = b.createModule(.{ .root_source_file = b.path("tools/text_benchmark.zig"), .target = target, .optimize = optimize });
    benchmark_module.addImport("text", modules.get("text").?);
    const benchmark_tests = b.addTest(.{ .root_module = benchmark_module });
    const run_benchmark_tests = b.addRunArtifact(benchmark_tests);
    test_step.dependOn(&run_benchmark_tests.step);
    const text_benchmark = b.addExecutable(.{ .name = "text-benchmark", .root_module = benchmark_module });
    const run_benchmark = b.addRunArtifact(text_benchmark);
    run_benchmark.setCwd(b.path("."));
    if (b.args) |args| run_benchmark.addArgs(args);
    b.step("text-benchmark", "Measure storage candidates and retain raw CSV (use -Doptimize=ReleaseFast)").dependOn(&run_benchmark.step);
    const summary_module = b.createModule(.{ .root_source_file = b.path("tools/production_text_summary.zig"), .target = target, .optimize = optimize });
    const summary_tests = b.addTest(.{ .root_module = summary_module });
    test_step.dependOn(&b.addRunArtifact(summary_tests).step);
    const summary_exe = b.addExecutable(.{ .name = "production-text-summary", .root_module = summary_module });
    const run_summary = b.addRunArtifact(summary_exe);
    run_summary.setCwd(b.path("."));
    if (b.args) |args| run_summary.addArgs(args);
    b.step("production-text-summary", "Summarize raw text CSV using nearest-rank median and p95").dependOn(&run_summary.step);
    const run_production_benchmark = b.addRunArtifact(text_benchmark);
    run_production_benchmark.setCwd(b.path("."));
    run_production_benchmark.addArg("production");
    if (b.args) |args| run_production_benchmark.addArgs(args);
    b.step("production-text-benchmark", "Measure production text using approved spike workloads (use ReleaseFast)").dependOn(&run_production_benchmark.step);

    const ui_scenario = b.createModule(.{ .root_source_file = b.path("src/ui/spike/scenario.zig"), .target = target, .optimize = optimize });
    const ui_tests = b.addTest(.{ .root_module = ui_scenario });
    const run_ui_tests = b.addRunArtifact(ui_tests);
    test_step.dependOn(&run_ui_tests.step);
    b.step("ui-test", "Run toolkit-independent shared scenario and scoring tests").dependOn(&run_ui_tests.step);

    if (target.result.os.tag == .macos) {
        // The platform bridge is a separate opt-in spike, never a domain import.
        const bridge = b.addSystemCommand(&.{ "xcrun", "clang", "-fobjc-arc", "-O2", "-Wall", "-Wextra", "-Werror", "-c" });
        bridge.addFileArg(b.path("src/ui/spike/macos.m"));
        bridge.addArg("-o");
        const object = bridge.addOutputFileArg("ui-spike.o");
        const ui_module = b.createModule(.{ .root_source_file = b.path("tools/ui_spike.zig"), .target = target, .optimize = optimize, .link_libc = true });
        ui_module.addImport("ui_scenario", ui_scenario);
        ui_module.addObjectFile(object);
        ui_module.linkFramework("AppKit", .{});
        ui_module.linkFramework("WebKit", .{});
        const ui_spike = b.addExecutable(.{ .name = "ui-spike", .root_module = ui_module });
        const install_ui = b.addInstallArtifact(ui_spike, .{});
        b.step("ui-spike", "Build the AppKit/WKWebView spike executable (bundle with tools/ui_spike.py)").dependOn(&install_ui.step);
    }

    const hooks_cmd = b.addSystemCommand(&.{ "git", "config", "core.hooksPath", ".githooks" });
    const hooks_step = b.step("hooks", "Point git at .githooks so pre-commit runs the repository checks");
    hooks_step.dependOn(&hooks_cmd.step);
}
