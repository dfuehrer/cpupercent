const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const cpu_exe = b.addExecutable("cpupercentServer", "src/cpupercentServer.zig");
    //const percentgraph = b.addModule("percentgraph", .{ .source_file = .{ .path = "percentgraph/src/percentgraphServer.zig" } });
    //cpu_exe.addLibraryPath("percentgraph", percentgraph);
    //cpu_exe.addPackagePath("percentgraph", "percentgraph/src/percentgraphServer.zig");
    const percentgraph_server_pkg = std.build.Pkg{ .name = "percentgraph", .source = .{ .path = "percentgraph/src/percentgraphServer.zig" } };
    cpu_exe.addPackage(percentgraph_server_pkg);
    //cpu_exe.addIncludePath("percentgraph/src/");
    cpu_exe.setTarget(target);
    cpu_exe.setBuildMode(mode);

    const network_exe = b.addExecutable("networkServer", "src/networkServer.zig");
    network_exe.addPackage(percentgraph_server_pkg);
    network_exe.setTarget(target);
    network_exe.setBuildMode(mode);
    network_exe.install();
    network_exe.install();

    const cpu_run_cmd = cpu_exe.run();
    cpu_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        cpu_run_cmd.addArgs(args);
    }

    const network_run_cmd = network_exe.run();
    network_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        network_run_cmd.addArgs(args);
    }

    const cpu_run_step = b.step("run-cpu", "Run the cpu percent server");
    cpu_run_step.dependOn(&cpu_run_cmd.step);

    const network_run_step = b.step("run-net", "Run the network percent server");
    network_run_step.dependOn(&network_run_cmd.step);

    const exe_tests = b.addTest("src/cpupercentServer.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
