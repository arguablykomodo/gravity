const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const wasm = b.addStaticLibrary(.{
        .name = "gravity",
        .root_source_file = .{ .path = "zig/wasm.zig" },
        .target = std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable,
        .optimize = optimize,
    });
    wasm.export_symbol_names = &.{ "sizeOfParticle", "sizeOfNode", "quadtreeLimits", "init", "step" };
    wasm.linkage = .dynamic;

    const install_wasm = b.addInstallArtifact(wasm);
    install_wasm.dest_dir = std.build.InstallDir.prefix;
    b.getInstallStep().dependOn(&install_wasm.step);

    const static_step = b.addInstallDirectory(.{
        .source_dir = "static",
        .install_dir = std.build.InstallDir.prefix,
        .install_subdir = "",
    });
    b.getInstallStep().dependOn(&static_step.step);

    const deno_step = b.addSystemCommand(&.{ "deno", "bundle", "--quiet", "ts/main.ts", b.pathJoin(&.{ b.install_prefix, "main.js" }) });
    b.getInstallStep().dependOn(&deno_step.step);

    const zig_tests = b.addTest(.{
        .root_source_file = .{ .path = "zig/test.zig" },
        .optimize = optimize,
    });
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&zig_tests.step);
}
