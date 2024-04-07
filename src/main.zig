const std = @import("std");
const core = @import("mach").core;
const Particles = @import("Particles.zig");
const Nodes = @import("Nodes.zig");
const Controls = @import("Controls.zig");
const Sorter = @import("Sorter.zig");
const BvhBuilder = @import("BvhBuilder.zig");
const Physics = @import("Physics.zig");
const gpu = @import("mach").gpu;

const PARTICLES = 32768;

pub const App = @This();

controls: Controls,
particles: Particles,
nodes: Nodes,
sorter: Sorter,
bvh_builder: BvhBuilder,
physics: Physics,

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
        random.floatNorm(f32) * 10.0,
        random.floatNorm(f32) * 10.0,
        0.0,
        0.0,
        0.001,
    );
    core.queue.writeBuffer(particles.buffer, 0, initial_particles[0..]);

    const initial_nodes = try core.allocator.alloc(Nodes.Node, PARTICLES - 1);
    defer core.allocator.free(initial_nodes);
    @memset(initial_nodes, Nodes.Node.init());
    core.queue.writeBuffer(nodes.buffer, 0, initial_nodes[0..]);

    app.* = .{
        .controls = controls,
        .particles = particles,
        .nodes = nodes,
        .sorter = Sorter.init(particles.buffer),
        .bvh_builder = BvhBuilder.init(particles.buffer, nodes.buffer),
        .physics = Physics.init(PARTICLES, particles.buffer),
    };

    core.setFrameRateLimit(60);
}

pub fn deinit(app: *App) void {
    app.physics.deinit();
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

    if (app.physics.pending()) return false;

    app.sorter.sort(PARTICLES);

    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;

    const encoder = core.device.createCommandEncoder(null);

    const compute_pass = encoder.beginComputePass(null);

    app.bvh_builder.buildBvh(compute_pass, PARTICLES);

    compute_pass.end();
    compute_pass.release();

    app.physics.copy(encoder, app.particles.buffer, app.nodes.buffer);

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

    app.physics.step();

    core.swap_chain.present();
    back_buffer_view.release();

    return false;
}
