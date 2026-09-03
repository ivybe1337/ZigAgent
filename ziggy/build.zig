const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "ziggy",
        .root_module = root_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run Ziggy");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const check_exe = b.addExecutable(.{
        .name = "ziggy-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .Debug,
        }),
    });

    const check_step = b.step("check", "Build-check Ziggy");
    check_step.dependOn(&check_exe.step);

    // Cross-Platform Windows Executable Step
    const win_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
    });
    const win_exe = b.addExecutable(.{
        .name = "ziggy-windows-x86_64.exe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = win_target,
            .optimize = optimize,
        }),
    });
    const win_install = b.addInstallArtifact(win_exe, .{});
    const win_step = b.step("windows", "Build standalone Windows x86_64 binary");
    win_step.dependOn(&win_install.step);
}
