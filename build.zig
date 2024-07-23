const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // MOdules
    const httpz = b.dependency("httpz", .{});
    const sqlite = b.dependency("sqlite", .{});

    // tests
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.linkLibC();
    exe_unit_tests.root_module.addImport("httpz", httpz.module("httpz"));
    exe_unit_tests.root_module.addImport("sqlite", sqlite.module("sqlite"));

    b.installArtifact(exe_unit_tests);
    const test_cmd = b.addRunArtifact(exe_unit_tests);
    //test_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        test_cmd.addArgs(args);
    }
    const test_step = b.step("test", "Test the app");
    test_step.dependOn(&test_cmd.step);

    // exe
    const exe = b.addExecutable(.{
        .name = "httpo",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.root_module.addImport("httpz", httpz.module("httpz"));
    exe.root_module.addImport("sqlite", sqlite.module("sqlite"));

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.step.dependOn(&test_cmd.step);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
