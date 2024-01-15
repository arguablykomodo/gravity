const std = @import("std");
const core = @import("mach-core");
const Particle = @import("particle.zig").Particle;
const gpu = core.gpu;

const PARTICLES = 1000;

pub const App = @This();

particle_pipeline: Particle.Pipeline,

compute_pipeline: *gpu.ComputePipeline,
compute_bind_group: *gpu.BindGroup,

pub fn init(app: *App) !void {
    try core.init(.{});

    const particle_pipeline = try Particle.Pipeline.init(core.allocator, PARTICLES);

    const compute_module = core.device.createShaderModuleWGSL("compute.wgsl", @embedFile("compute.wgsl"));
    defer compute_module.release();

    const compute_pipeline = core.device.createComputePipeline(&.{ .compute = .{
        .module = compute_module,
        .entry_point = "compute",
    } });

    const compute_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = compute_pipeline.getBindGroupLayout(0),
        .entries = &.{particle_pipeline.bindGroup(0)},
    }));

    app.* = .{
        .particle_pipeline = particle_pipeline,

        .compute_pipeline = compute_pipeline,
        .compute_bind_group = compute_bind_group,
    };
}

pub fn deinit(app: *App) void {
    app.compute_bind_group.release();
    app.compute_pipeline.release();
    app.particle_pipeline.deinit();
    core.deinit();
}

pub fn update(app: *App) !bool {
    var iter = core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .close => return true,
            else => {},
        }
    }

    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;

    const encoder = core.device.createCommandEncoder(null);

    const compute_pass = encoder.beginComputePass(null);
    compute_pass.setPipeline(app.compute_pipeline);
    compute_pass.setBindGroup(0, app.compute_bind_group, null);
    compute_pass.dispatchWorkgroups(PARTICLES, 1, 1);
    compute_pass.end();
    compute_pass.release();

    const render_pass = encoder.beginRenderPass(&gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            .clear_value = std.mem.zeroes(gpu.Color),
            .load_op = .clear,
            .store_op = .store,
        }},
    }));
    app.particle_pipeline.render(render_pass);
    render_pass.end();
    render_pass.release();

    var command = encoder.finish(null);
    encoder.release();

    core.queue.submit(&[_]*gpu.CommandBuffer{command});
    command.release();
    core.swap_chain.present();
    back_buffer_view.release();

    return false;
}
