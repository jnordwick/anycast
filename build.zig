// build.zig - Fixed version
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a module for the library
    _ = b.addModule("anycast", .{
        .root_source_file = b.path("src/root.zig"),
    });

    // Test executable for development
    const test_exe = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);
}
