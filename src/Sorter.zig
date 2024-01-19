const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

uniform_buffer: *gpu.Buffer,
pipeline: *gpu.ComputePipeline,
bind_group: *gpu.BindGroup,

pub const Uniforms = struct {
    width: u32,
    height: u32,
    step: u32,
};

pub fn init(particles: *gpu.Buffer) @This() {
    const shader = core.device.createShaderModuleWGSL("sort.wgsl", @embedFile("sort.wgsl"));
    defer shader.release();

    const uniform_buffer = core.device.createBuffer(&.{
        .label = "sort uniform buffer",
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(Uniforms),
    });
    const pipeline = core.device.createComputePipeline(&.{
        .label = "sort pipeline",
        .compute = .{
            .module = shader,
            .entry_point = "sort",
        },
    });
    const bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "sort bind group",
        .layout = pipeline.getBindGroupLayout(0),
        .entries = &.{
            gpu.BindGroup.Entry.buffer(0, particles, 0, particles.getSize()),
            gpu.BindGroup.Entry.buffer(1, uniform_buffer, 0, @sizeOf(Uniforms)),
        },
    }));

    return .{
        .uniform_buffer = uniform_buffer,
        .pipeline = pipeline,
        .bind_group = bind_group,
    };
}

pub fn deinit(self: *@This()) void {
    self.bind_group.release();
    self.pipeline.release();
    self.uniform_buffer.release();
}

pub fn sort(self: *@This(), particles: u32) void {
    const stages = std.math.log2_int(u32, std.math.ceilPowerOfTwoAssert(u32, particles));
    for (0..stages) |stage| {
        for (0..(stage + 1)) |step| {
            const width = @as(u32, 1) << @intCast(stage - step);
            const height = 2 * width - 1;
            core.queue.writeBuffer(self.uniform_buffer, 0, &[1]Uniforms{.{
                .width = width,
                .height = height,
                .step = @intCast(step),
            }});

            const encoder = core.device.createCommandEncoder(null);
            defer encoder.release();

            const compute_pass = encoder.beginComputePass(null);
            defer compute_pass.release();
            compute_pass.setPipeline(self.pipeline);
            compute_pass.setBindGroup(0, self.bind_group, null);
            compute_pass.dispatchWorkgroups(std.math.ceilPowerOfTwoAssert(u32, particles) / 2, 1, 1);
            compute_pass.end();

            var command = encoder.finish(null);
            defer command.release();
            core.queue.submit(&[_]*gpu.CommandBuffer{command});
        }
    }
}
