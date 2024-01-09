const std = @import("std");

fn walkDir(b: *std.Build, dir: []const u8) ![]const []const u8 {
    var files = std.ArrayList([]const u8).init(b.allocator);
    errdefer files.deinit();
    var ts_dir = try std.fs.openDirAbsolute(b.pathFromRoot(dir), .{ .iterate = true });
    defer ts_dir.close();
    var walker = try ts_dir.walk(b.allocator);
    defer walker.deinit();
    while (walker.next() catch unreachable) |entry| {
        try files.append(try b.allocator.dupe(u8, b.pathJoin(&.{ dir, entry.path })));
    }
    return try files.toOwnedSlice();
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const build_wasm = b.addExecutable(.{
        .name = "gravity",
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .optimize = optimize,
        .root_source_file = .{ .path = "zig/wasm.zig" },
    });
    build_wasm.entry = .disabled;
    build_wasm.rdynamic = true;
    const install_wasm = b.addInstallArtifact(build_wasm, .{ .dest_dir = .{ .override = .prefix } });
    b.getInstallStep().dependOn(&install_wasm.step);

    const install_static = b.addInstallDirectory(.{
        .source_dir = .{ .path = "static" },
        .install_dir = .prefix,
        .install_subdir = "",
    });
    b.getInstallStep().dependOn(&install_static.step);

    const run_bundle = b.addSystemCommand(&.{ "bun", "build" });
    if (optimize == .Debug) run_bundle.addArg("--sourcemap") else run_bundle.addArg("--minify");
    run_bundle.addFileArg(.{ .path = "ts/main.ts" });
    run_bundle.extra_file_dependencies = walkDir(b, "ts") catch unreachable;
    const bundled = run_bundle.captureStdOut();
    const install_bundle = b.addInstallFile(bundled, "main.js");
    b.getInstallStep().dependOn(&install_bundle.step);

    const build_tests = b.addTest(.{
        .root_source_file = .{ .path = "zig/test.zig" },
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(build_tests);
    b.step("test", "Run tests").dependOn(&run_tests.step);

    const build_bench = b.addExecutable(.{
        .name = "bench",
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi }),
        .optimize = optimize,
        .root_source_file = .{ .path = "zig/bench.zig" },
    });
    const install_bench = b.addInstallArtifact(build_bench, .{});
    b.step("bench", "Build benchmark").dependOn(&install_bench.step);
}
