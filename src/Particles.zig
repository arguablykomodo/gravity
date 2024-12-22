const std = @import("std");
const core = @import("mach").core;
const math = @import("mach").math;
const gpu = @import("mach").gpu;

buffer: *gpu.Buffer,
pipeline: *gpu.RenderPipeline,
bind_group: *gpu.BindGroup,

pub const Particle = packed struct {
    position: @Vector(2, f32),
    velocity: @Vector(2, f32),
    acceleration: @Vector(2, f32),
    mass: f32,
    parent: u32,

    pub fn new(position_x: f32, position_y: f32, velocity_x: f32, velocity_y: f32, mass: f32) Particle {
        return .{
            .position = .{ position_x, position_y },
            .velocity = .{ velocity_x, velocity_y },
            .acceleration = .{ 0.0, 0.0 },
            .mass = mass,
            .parent = 0,
        };
    }
};

pub fn init(controls: *gpu.Buffer, max_particles: u32) @This() {
    const shader = core.device.createShaderModuleWGSL("particle.wgsl", @embedFile("shaders/particle.wgsl"));
    defer shader.release();

    const buffer = core.device.createBuffer(&.{
        .label = "particle buffer",
        .usage = .{ .storage = true, .vertex = true, .copy_src = true, .copy_dst = true },
        .size = @sizeOf(Particle) * max_particles,
    });
    const pipeline = core.device.createRenderPipeline(&.{
        .label = "particle render pipeline",
        .vertex = gpu.VertexState.init(.{
            .module = shader,
            .entry_point = "vertex",
            .buffers = &.{gpu.VertexBufferLayout.init(.{
                .array_stride = @sizeOf(Particle),
                .step_mode = .instance,
                .attributes = &.{
                    .{ .shader_location = 0, .offset = 0, .format = .float32x2 },
                    .{ .shader_location = 1, .offset = 2 * @sizeOf(f32), .format = .float32x2 },
                    .{ .shader_location = 2, .offset = 4 * @sizeOf(f32), .format = .float32x2 },
                    .{ .shader_location = 3, .offset = 6 * @sizeOf(f32), .format = .float32 },
                },
            })},
        }),
        .primitive = .{ .topology = .triangle_strip },
        .fragment = &gpu.FragmentState.init(.{
            .module = shader,
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
    const bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "particle bind group",
        .layout = pipeline.getBindGroupLayout(0),
        .entries = &.{gpu.BindGroup.Entry.buffer(0, controls, 0, controls.getSize())},
    }));

    return .{
        .buffer = buffer,
        .pipeline = pipeline,
        .bind_group = bind_group,
    };
}

pub fn deinit(self: *@This()) void {
    self.bind_group.release();
    self.pipeline.release();
    self.buffer.release();
}

pub fn render(self: *@This(), pass: *gpu.RenderPassEncoder, particles: u32) void {
    pass.setPipeline(self.pipeline);
    pass.setBindGroup(0, self.bind_group, null);
    pass.setVertexBuffer(0, self.buffer, 0, gpu.whole_size);
    pass.draw(4, particles, 0, 0);
}
