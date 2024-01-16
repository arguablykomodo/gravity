const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

pub const Particle = packed struct {
    position_x: f32,
    position_y: f32,
    velocity_x: f32,
    velocity_y: f32,
    acceleration_x: f32,
    acceleration_y: f32,
    mass: f32,
    parent: u32,
    morton: u64,

    fn interleave(input: u32) u64 {
        var word: u64 = input;
        word = (word ^ (word << 16)) & 0x0000ffff0000ffff;
        word = (word ^ (word << 8)) & 0x00ff00ff00ff00ff;
        word = (word ^ (word << 4)) & 0x0f0f0f0f0f0f0f0f;
        word = (word ^ (word << 2)) & 0x3333333333333333;
        word = (word ^ (word << 1)) & 0x5555555555555555;
        return word;
    }

    pub fn new(
        position_x: f32,
        position_y: f32,
        velocity_x: f32,
        velocity_y: f32,
        mass: f32,
    ) Particle {
        return .{
            .position_x = position_x,
            .position_y = position_y,
            .velocity_x = velocity_x,
            .velocity_y = velocity_y,
            .acceleration_x = 0.0,
            .acceleration_y = 0.0,
            .mass = mass,
            .parent = 0,
            .morton = interleave(@bitCast(position_x)) | (interleave(@bitCast(position_y)) << 1),
        };
    }

    pub fn lessThan(_: void, lhs: Particle, rhs: Particle) bool {
        return lhs.morton < rhs.morton;
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
