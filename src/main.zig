const std = @import("std");
const core = @import("mach-core");
const Particle = @import("particle.zig").Particle;
const Node = @import("node.zig").Node;
const gpu = core.gpu;

const PARTICLES = 1000;

pub const App = @This();

particles: []Particle,
particle_buffer: *gpu.Buffer,
particle_pipeline: *gpu.RenderPipeline,

nodes: []Node,
node_buffer: *gpu.Buffer,
node_pipeline: *gpu.RenderPipeline,

compute_pipeline: *gpu.ComputePipeline,
compute_bind_group: *gpu.BindGroup,

pub fn init(app: *App) !void {
    try core.init(.{});

    var rng = std.rand.DefaultPrng.init(0);
    const random = rng.random();

    const particles = try core.allocator.alloc(Particle, PARTICLES);
    for (particles) |*p| {
        p.position = .{ random.floatNorm(f32), random.floatNorm(f32) };
        p.velocity = .{ 0.0, 0.0 };
        p.acceleration = .{ 0.0, 0.0 };
        p.mass = 0.001;
    }
    const particle_buffer = core.device.createBuffer(&.{
        .usage = .{ .storage = true, .vertex = true, .copy_dst = true },
        .size = @sizeOf(Particle) * particles.len,
    });
    core.queue.writeBuffer(particle_buffer, 0, particles[0..]);

    const nodes = try core.allocator.alloc(Node, PARTICLES - 1);
    for (nodes) |*n| {
        n.min_corner = .{ -random.floatExp(f32), -random.floatExp(f32) };
        n.max_corner = .{ random.floatExp(f32), random.floatExp(f32) };
    }
    const node_buffer = core.device.createBuffer(&.{
        .usage = .{ .storage = true, .vertex = true, .copy_dst = true },
        .size = @sizeOf(Node) * nodes.len,
    });
    core.queue.writeBuffer(node_buffer, 0, nodes[0..]);

    const compute_module = core.device.createShaderModuleWGSL("compute.wgsl", @embedFile("compute.wgsl"));
    defer compute_module.release();

    const compute_pipeline = core.device.createComputePipeline(&.{ .compute = .{
        .module = compute_module,
        .entry_point = "compute",
    } });

    const compute_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = compute_pipeline.getBindGroupLayout(0),
        .entries = &.{gpu.BindGroup.Entry.buffer(0, particle_buffer, 0, @sizeOf(Particle) * particles.len)},
    }));

    app.* = .{
        .particles = particles,
        .particle_buffer = particle_buffer,
        .particle_pipeline = Particle.pipeline(),

        .nodes = nodes,
        .node_buffer = node_buffer,
        .node_pipeline = Node.pipeline(),

        .compute_pipeline = compute_pipeline,
        .compute_bind_group = compute_bind_group,
    };
}

pub fn deinit(app: *App) void {
    app.compute_bind_group.release();
    app.compute_pipeline.release();

    app.node_pipeline.release();
    app.node_buffer.release();
    core.allocator.free(app.nodes);

    app.particle_pipeline.release();
    app.particle_buffer.release();
    core.allocator.free(app.particles);

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

    render_pass.setPipeline(app.node_pipeline);
    render_pass.setVertexBuffer(0, app.node_buffer, 0, gpu.whole_size);
    render_pass.draw(5, @intCast(app.nodes.len), 0, 0);

    render_pass.setPipeline(app.particle_pipeline);
    render_pass.setVertexBuffer(0, app.particle_buffer, 0, gpu.whole_size);
    render_pass.draw(4, @intCast(app.particles.len), 0, 0);

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
