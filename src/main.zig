const std = @import("std");
const core = @import("mach-core");
const Particle = @import("particle.zig").Particle;
const gpu = core.gpu;

const PARTICLES = 10000;

pub const App = @This();

allocator: std.heap.GeneralPurposeAllocator(.{}),
timer: core.Timer,
particles: []Particle,
particle_buffer: *gpu.Buffer,
render_pipeline: *gpu.RenderPipeline,
compute_pipeline: *gpu.ComputePipeline,
compute_uniforms_buffer: *gpu.Buffer,
compute_bind_group: *gpu.BindGroup,

const ComputeUniforms = struct {
    dt: f32,
};

pub fn init(app: *App) !void {
    try core.init(.{});

    var allocator = std.heap.GeneralPurposeAllocator(.{}){};

    var particles = try allocator.allocator().alloc(Particle, PARTICLES);
    var rng = std.rand.DefaultPrng.init(0);
    const random = rng.random();
    for (particles) |*p| {
        p.position = .{ random.floatNorm(f32), random.floatNorm(f32) };
        p.velocity = .{ 0.0, 0.0 };
        p.acceleration = .{ 0.0, 0.0 };
        p.mass = 0.001;
    }

    const particle_buffer = core.device.createBuffer(&.{
        .usage = .{ .storage = true, .vertex = true, .copy_dst = true },
        .size = PARTICLES * @sizeOf(Particle),
    });
    core.queue.writeBuffer(particle_buffer, 0, particles[0..]);

    const compute_uniforms_buffer = core.device.createBuffer(&.{
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(ComputeUniforms),
    });

    const render_module = core.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
    defer render_module.release();

    const render_pipeline = core.device.createRenderPipeline(&.{
        .vertex = gpu.VertexState.init(.{
            .module = render_module,
            .entry_point = "vertex",
            .buffers = &.{Particle.layout},
        }),
        .primitive = .{
            .topology = .triangle_strip,
        },
        .fragment = &gpu.FragmentState.init(.{
            .module = render_module,
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

    const compute_module = core.device.createShaderModuleWGSL("compute.wgsl", @embedFile("compute.wgsl"));
    defer compute_module.release();

    const compute_pipeline = core.device.createComputePipeline(&.{ .compute = .{
        .module = compute_module,
        .entry_point = "compute",
    } });

    const compute_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = compute_pipeline.getBindGroupLayout(0),
        .entries = &.{
            gpu.BindGroup.Entry.buffer(0, particle_buffer, 0, @sizeOf(Particle) * PARTICLES),
            gpu.BindGroup.Entry.buffer(1, compute_uniforms_buffer, 0, @sizeOf(ComputeUniforms)),
        },
    }));

    app.* = .{
        .allocator = allocator,
        .timer = try core.Timer.start(),
        .particles = particles,
        .particle_buffer = particle_buffer,
        .render_pipeline = render_pipeline,
        .compute_pipeline = compute_pipeline,
        .compute_uniforms_buffer = compute_uniforms_buffer,
        .compute_bind_group = compute_bind_group,
    };
}

pub fn deinit(app: *App) void {
    app.particle_buffer.release();
    app.render_pipeline.release();
    app.compute_bind_group.release();
    app.compute_uniforms_buffer.release();
    app.compute_pipeline.release();
    app.allocator.allocator().free(app.particles);
    core.deinit();
}

pub fn update(app: *App) !bool {
    const dt = app.timer.read();
    app.timer.reset();
    core.queue.writeBuffer(app.compute_uniforms_buffer, 0, &[1]ComputeUniforms{ComputeUniforms{ .dt = dt }});

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
    render_pass.setPipeline(app.render_pipeline);
    render_pass.setVertexBuffer(0, app.particle_buffer, 0, gpu.whole_size);
    render_pass.draw(4, PARTICLES, 0, 0);
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
