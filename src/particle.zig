const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

pub const Particle = extern struct {
    position: @Vector(2, f32),
    velocity: @Vector(2, f32),
    acceleration: @Vector(2, f32),
    mass: f32,

    pub const layout = gpu.VertexBufferLayout.init(.{
        .array_stride = @sizeOf(Particle),
        .step_mode = .instance,
        .attributes = &.{
            .{ .shader_location = 0, .offset = 0, .format = .float32x2 },
            .{ .shader_location = 1, .offset = 2 * @sizeOf(f32), .format = .float32x2 },
            .{ .shader_location = 2, .offset = 4 * @sizeOf(f32), .format = .float32x2 },
            .{ .shader_location = 3, .offset = 6 * @sizeOf(f32), .format = .float32 },
        },
    });
};
