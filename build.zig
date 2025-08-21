const std = @import("std");

fn watchDir(b: *std.Build, step: *std.Build.Step.Run, dir: []const u8) !void {
    var ts_dir = try std.fs.openDirAbsolute(b.pathFromRoot(dir), .{ .iterate = true });
    defer ts_dir.close();
    var walker = try ts_dir.walk(b.allocator);
    defer walker.deinit();
    while (walker.next() catch unreachable) |entry| {
        const entry_path = b.pathJoin(&.{ dir, entry.path });
        if (entry.kind == .directory) try watchDir(b, step, entry_path)
        else step.addFileInput(b.path(entry_path));
    }
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const cpu_features = std.Target.wasm.featureSet(&.{
        .multivalue,
        .relaxed_simd,
        .simd128,
    });
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .cpu_features_add = cpu_features,
    });
    const native_target = b.standardTargetOptions(.{});

    const build_wasm = b.addExecutable(.{
        .name = "gravity",
        .root_module = b.createModule(.{
            .root_source_file = b.path("zig/wasm.zig"),
            .target = wasm_target,
            .optimize = optimize,
        }),
    });
    build_wasm.entry = .disabled;
    build_wasm.rdynamic = true;
    const install_wasm = b.addInstallArtifact(build_wasm, .{ .dest_dir = .{ .override = .prefix } });
    b.getInstallStep().dependOn(&install_wasm.step);

    const run_bundle = b.addSystemCommand(&.{ "bun", "build" });
    if (optimize == .Debug) run_bundle.addArg("--sourcemap") else run_bundle.addArg("--minify");
    run_bundle.addFileArg(b.path("web/index.html"));
    run_bundle.addArg("--outdir");
    const bundle_dir = run_bundle.addOutputDirectoryArg("bun_bundle");
    watchDir(b, run_bundle, "web") catch unreachable;
    const install_bundle = b.addInstallDirectory(.{
        .source_dir = bundle_dir,
        .install_dir = .prefix,
        .install_subdir = "",
    });
    b.getInstallStep().dependOn(&install_bundle.step);

    const build_tests = b.addTest(.{
        .use_llvm = true, // Self-hosted has some miscompilations involving SIMD
        .root_module = b.createModule(.{
            .root_source_file = b.path("zig/test.zig"),
            .target = native_target,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(build_tests);
    b.step("test", "Run tests").dependOn(&run_tests.step);

    const build_bench = b.addExecutable(.{
        .name = "bench",
        .use_llvm = true, // Self-hosted has some miscompilations involving SIMD
        .root_module = b.createModule(.{
            .root_source_file = b.path("zig/bench.zig"),
            .target = native_target,
            .optimize = optimize,
        }),
    });
    const install_bench = b.addInstallArtifact(build_bench, .{});
    b.step("bench", "Build benchmark").dependOn(&install_bench.step);
}
