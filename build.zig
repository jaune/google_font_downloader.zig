const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const google_font_downloader = b.addModule("root", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("./src/root.zig"),
    });

    {
        const exe = b.addExecutable(.{
            .name = "google_font_downloader",
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("./src/main.zig"),
        });

        exe.subsystem = .Console;

        exe.root_module.addImport("google_font_downloader", google_font_downloader);

        b.installArtifact(exe);

        const run_step = b.step("run_dl_inter", "run google_font_downloader inter");
        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());

        run_cmd.addArg("Inter");
        run_cmd.addArg("./out/Inter");

        run_step.dependOn(&run_cmd.step);
    }
}
