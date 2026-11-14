const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("lizp", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "lizp",
        .root_module = mod,
    });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    run.addPassthruArgs();

    const run_step = b.step("run", "Run the Lisp REPL");
    run_step.dependOn(&run.step);

    const check_exe = b.addExecutable(.{
        .name = "lizp",
        .root_module = mod,
    });

    const check_step = b.step("check", "Check if project compiles");
    check_step.dependOn(&check_exe.step);

    const test_step = b.step("test", "Run tests");
    const src_paths = [_][]const u8{
        "src/forms.zig",
        "src/Gardener.zig",
        "src/lisp.zig",
        "src/printer.zig",
        "src/reader.zig",
    };
    for (src_paths) |path| {
        const test_mod = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
        });

        const test_exe = b.addTest(.{ .root_module = test_mod });
        test_exe.name = b.fmt("{s}-test", .{std.fs.path.stem(path)});

        const test_run = b.addRunArtifact(test_exe);

        test_step.dependOn(&test_run.step);
    }
}
