const std = @import("std");

test "executable exits cleanly in an isolated workspace" {
    var workspace = std.testing.tmpDir(.{ .iterate = true });
    defer workspace.cleanup();

    const project_root = try std.process.currentPathAlloc(std.testing.io, std.testing.allocator);
    defer std.testing.allocator.free(project_root);
    const executable_path = try std.fs.path.join(std.testing.allocator, &.{
        project_root,
        @import("build_options").zigide_executable,
    });
    defer std.testing.allocator.free(executable_path);

    var environment = std.process.Environ.Map.init(std.testing.allocator);
    defer environment.deinit();

    const result = std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = &.{executable_path},
        .cwd = .{ .dir = workspace.dir },
        .environ_map = &environment,
        .stdout_limit = .limited(1024),
        .stderr_limit = .limited(1024),
    }) catch |err| {
        std.debug.print("unable to launch Zigide integration fixture: {s}\n", .{@errorName(err)});
        return err;
    };
    defer std.testing.allocator.free(result.stdout);
    defer std.testing.allocator.free(result.stderr);

    try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, result.term);
    try std.testing.expectEqualStrings("", result.stdout);
    try std.testing.expectEqualStrings("", result.stderr);

    var entries = workspace.dir.iterate();
    try std.testing.expect((try entries.next(std.testing.io)) == null);
}
