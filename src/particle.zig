const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

pub const Particle = extern struct {
    position: @Vector(2, f32),
    velocity: @Vector(2, f32),
    acceleration: @Vector(2, f32),
    mass: f32,
    parent: u32,

    pub fn pipeline() *gpu.RenderPipeline {
        const shader_module = core.device.createShaderModuleWGSL("particle.wgsl", @embedFile("particle.wgsl"));
        defer shader_module.release();
        return core.device.createRenderPipeline(&.{
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
