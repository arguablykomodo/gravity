const std = @import("std");
const core = @import("mach-core");
const math = @import("mach").math;
const gpu = core.gpu;

pub const Particle = packed struct {
    position: @Vector(2, f32),
    velocity: @Vector(2, f32),
    acceleration: @Vector(2, f32),
    mass: f32,
    parent: u32,

    pub fn new(
        position_x: f32,
        position_y: f32,
        velocity_x: f32,
        velocity_y: f32,
        mass: f32,
    ) Particle {
        return .{
            .position = .{ position_x, position_y },
            .velocity = .{ velocity_x, velocity_y },
            .acceleration = .{ 0.0, 0.0 },
            .mass = mass,
            .parent = 0,
        };
    }

    pub fn pipeline() *gpu.RenderPipeline {
        const shader_module = core.device.createShaderModuleWGSL("particle.wgsl", @embedFile("particle.wgsl"));
        defer shader_module.release();
        return core.device.createRenderPipeline(&.{
            .label = "particle render pipeline",
            .vertex = gpu.VertexState.init(.{
                .module = shader_module,
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
    }
};
