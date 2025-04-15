const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // create module for percentgraph lib
    const percentgraph = b.addModule("percentgraph", .{
        .root_source_file = b.path("percentgraph/src/percentgraphServer.zig"),
    });

    const cpu_exe = b.addExecutable(.{
        .name = "cpupercentServer",
        .root_source_file = b.path("src/cpupercentServer.zig"),
        .target = target,
        .optimize = optimize,
    });
    cpu_exe.root_module.addImport("percentgraph", percentgraph);
    //const percentgraph_server_pkg = std.build.Pkg{ .name = "percentgraph", .source = .{ .path = "percentgraph/src/percentgraphServer.zig" } };
    //cpu_exe.addPackage(percentgraph_server_pkg);
    b.installArtifact(cpu_exe);

    const network_exe = b.addExecutable(.{
        .name = "networkServer",
        .root_source_file = b.path("src/networkServer.zig"),
        .target = target,
        .optimize = optimize,
    });
    network_exe.root_module.addImport("percentgraph", percentgraph);
    //network_exe.addPackage(percentgraph_server_pkg);
    b.installArtifact(network_exe);

    const cpu_run_cmd = b.addRunArtifact(cpu_exe);
    cpu_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        cpu_run_cmd.addArgs(args);
    }

    const network_run_cmd = b.addRunArtifact(network_exe);
    network_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        network_run_cmd.addArgs(args);
    }

    const cpu_run_step = b.step("run-cpu", "Run the cpu percent server");
    cpu_run_step.dependOn(&cpu_run_cmd.step);

    const network_run_step = b.step("run-net", "Run the network percent server");
    network_run_step.dependOn(&network_run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_source_file = b.path("src/cpupercentServer.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
