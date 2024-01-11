const std = @import("std");
const core = @import("mach-core");
const Particle = @import("particle.zig").Particle;
const gpu = core.gpu;

const PARTICLES = 1000;

pub const App = @This();

timer: core.Timer,
pipeline: *gpu.RenderPipeline,
particles: [PARTICLES]Particle,
particle_buffer: *gpu.Buffer,

pub fn init(app: *App) !void {
    try core.init(.{});

    const shader_module = core.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
    defer shader_module.release();

    const pipeline = core.device.createRenderPipeline(&.{
        .vertex = gpu.VertexState.init(.{
            .module = shader_module,
            .entry_point = "vertex",
            .buffers = &.{Particle.layout},
        }),
        .primitive = .{
            .topology = .triangle_strip,
        },
        .fragment = &gpu.FragmentState.init(.{
            .module = shader_module,
            .entry_point = "fragment",
            .targets = &.{.{
                .format = core.descriptor.format,
                .blend = &.{
                    .color = .{ .dst_factor = .one_minus_src_alpha },
                    .alpha = .{ .dst_factor = .one_minus_src_alpha },
                },
            }},
        }),
    });

    var particles: [PARTICLES]Particle = undefined;
    var rng = std.rand.DefaultPrng.init(0);
    const random = rng.random();
    for (&particles) |*p| {
        p.position = .{ random.floatNorm(f32), random.floatNorm(f32) };
        p.velocity = .{ random.floatNorm(f32), random.floatNorm(f32) };
        p.acceleration = .{ random.floatNorm(f32), random.floatNorm(f32) };
        p.mass = random.floatExp(f32) / 100.0;
    }

    const particle_buffer = core.device.createBuffer(&.{
        .usage = .{ .vertex = true, .copy_dst = true },
        .size = PARTICLES * @sizeOf(Particle),
    });
    core.queue.writeBuffer(particle_buffer, 0, particles[0..]);

    app.* = .{
        .timer = try core.Timer.start(),
        .pipeline = pipeline,
        .particles = particles,
        .particle_buffer = particle_buffer,
    };
}

pub fn deinit(app: *App) void {
    defer core.deinit();
    app.particle_buffer.release();
    app.pipeline.release();
}

pub fn update(app: *App) !bool {
    const dt = app.timer.read();
    app.timer.reset();

    var iter = core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .close => return true,
            else => {},
        }
    }

    const queue = core.queue;
    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;

    for (&app.particles) |*p| {
        p.velocity[0] += p.acceleration[0] * dt;
        p.velocity[1] += p.acceleration[1] * dt;
        p.position[0] += p.velocity[0] * dt;
        p.position[1] += p.velocity[1] * dt;
    }
    queue.writeBuffer(app.particle_buffer, 0, app.particles[0..]);

    const encoder = core.device.createCommandEncoder(null);
    const render_pass_info = gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            .clear_value = std.mem.zeroes(gpu.Color),
            .load_op = .clear,
            .store_op = .store,
        }},
    });
    const pass = encoder.beginRenderPass(&render_pass_info);
    pass.setPipeline(app.pipeline);
    pass.setVertexBuffer(0, app.particle_buffer, 0, gpu.whole_size);
    pass.draw(4, PARTICLES, 0, 0);
    pass.end();
    pass.release();

    var command = encoder.finish(null);
    encoder.release();

    queue.submit(&[_]*gpu.CommandBuffer{command});
    command.release();
    core.swap_chain.present();
    back_buffer_view.release();

    return false;
}
