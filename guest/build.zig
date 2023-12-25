const std = @import("std");
const CrossTarget = std.zig.CrossTarget;
const Target = std.Target;
const Feature = std.Target.Cpu.Feature;

pub fn build(b: *std.build.Builder) void {
    const features = Target.riscv.Feature;
    var disabled_features = Feature.Set.empty;
    var enabled_features = Feature.Set.empty;

    // disable all CPU extensions
    disabled_features.addFeature(@intFromEnum(features.a));
    disabled_features.addFeature(@intFromEnum(features.c));
    disabled_features.addFeature(@intFromEnum(features.d));
    disabled_features.addFeature(@intFromEnum(features.e));
    disabled_features.addFeature(@intFromEnum(features.f));
    // except multiply
    enabled_features.addFeature(@intFromEnum(features.m));

    const target = CrossTarget{
        .cpu_arch = Target.Cpu.Arch.riscv32,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 },
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_features,
    };

    var exe_options = std.build.ExecutableOptions{
        .name = "factors",
        .root_source_file = .{ .path = "src/main.zig" },
    };
    const exe = b.addExecutable(exe_options);
    // exe.setBuildMode(std.build.Mode.ReleaseSmall);
    exe.setLinkerScriptPath(.{ .path = "linker.ld" });
    exe.strip = true;
    // _ = exe.installRaw("factors.bin", .{});
    exe.target = target;
    b.installArtifact(exe);
}
