const std = @import("std");
const core = @import("mach-core");
const Particles = @import("Particles.zig");
const Nodes = @import("Nodes.zig");
const Controls = @import("Controls.zig");
const Sorter = @import("Sorter.zig");
const BvhBuilder = @import("BvhBuilder.zig");
const gpu = core.gpu;

const PARTICLES = 10;

pub const App = @This();

controls: Controls,
particles: Particles,
nodes: Nodes,

sorter: Sorter,
bvh_builder: BvhBuilder,

physics_pipeline: *gpu.ComputePipeline,
physics_bind_group: *gpu.BindGroup,

pub fn init(app: *App) !void {
    try core.init(.{});

    var rng = std.rand.DefaultPrng.init(2);
    const random = rng.random();

    const controls = Controls.init();
    const particles = Particles.init(controls.buffer, PARTICLES);
    const nodes = Nodes.init(controls.buffer, PARTICLES - 1);

    const initial_particles = try core.allocator.alloc(Particles.Particle, PARTICLES);
    defer core.allocator.free(initial_particles);
    for (initial_particles) |*p| p.* = Particles.Particle.new(
        random.float(f32) * 1.5 - 0.75,
        random.float(f32) * 1.5 - 0.75,
        0.0,
        0.0,
        0.001,
    );
    core.queue.writeBuffer(particles.buffer, 0, initial_particles[0..]);

    const initial_nodes = try core.allocator.alloc(Nodes.Node, PARTICLES - 1);
    defer core.allocator.free(initial_nodes);
    @memset(initial_nodes, Nodes.Node.init());
    core.queue.writeBuffer(nodes.buffer, 0, initial_nodes[0..]);

    const compute_module = core.device.createShaderModuleWGSL("compute.wgsl", @embedFile("compute.wgsl"));
    defer compute_module.release();

    const physics_pipeline = core.device.createComputePipeline(&.{
        .label = "physics pipeline",
        .compute = .{
            .module = compute_module,
            .entry_point = "physics",
        },
    });
    const physics_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "physics bind group",
        .layout = physics_pipeline.getBindGroupLayout(0),
        .entries = &.{
            gpu.BindGroup.Entry.buffer(0, particles.buffer, 0, particles.buffer.getSize()),
        },
    }));

    app.* = .{
        .controls = controls,
        .particles = particles,
        .nodes = nodes,

        .sorter = Sorter.init(particles.buffer),
        .bvh_builder = BvhBuilder.init(particles.buffer, nodes.buffer),

        .physics_pipeline = physics_pipeline,
        .physics_bind_group = physics_bind_group,
    };

    core.setFrameRateLimit(60);
}

pub fn deinit(app: *App) void {
    app.physics_bind_group.release();
    app.physics_pipeline.release();

    app.bvh_builder.deinit();
    app.sorter.deinit();

    app.nodes.deinit();
    app.particles.deinit();
    app.controls.deinit();

    core.deinit();
}

pub fn update(app: *App) !bool {
    var iter = core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .close => return true,
            .framebuffer_resize => |e| app.controls.updateWindowScale(.{ @floatFromInt(e.width), @floatFromInt(e.height) }),
            .mouse_scroll => |e| app.controls.zoom(e.yoffset),
            .mouse_press => |e| if (e.button == .left) app.controls.beginTranslation(.{ @floatCast(e.pos.x), @floatCast(e.pos.y) }),
            .mouse_motion => |e| app.controls.translate(.{ @floatCast(e.pos.x), @floatCast(e.pos.y) }),
            .mouse_release => |e| if (e.button == .left) app.controls.endTranslation(),
            else => {},
        }
    }

    app.sorter.sort(PARTICLES);

    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;

    const encoder = core.device.createCommandEncoder(null);

    const compute_pass = encoder.beginComputePass(null);

    app.bvh_builder.buildBvh(compute_pass, PARTICLES);

    compute_pass.setPipeline(app.physics_pipeline);
    compute_pass.setBindGroup(0, app.physics_bind_group, null);
    compute_pass.dispatchWorkgroups(PARTICLES, 1, 1);

    compute_pass.end();
    compute_pass.release();

    const render_pass = encoder.beginRenderPass(&gpu.RenderPassDescriptor.init(.{
        .label = "render pass",
        .color_attachments = &.{gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            .clear_value = std.mem.zeroes(gpu.Color),
            .load_op = .clear,
            .store_op = .store,
        }},
    }));

    app.nodes.render(render_pass, PARTICLES - 1);
    app.particles.render(render_pass, PARTICLES);

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
