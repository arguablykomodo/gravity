const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

pub const Node = extern struct {
    min_corner: @Vector(2, f32),
    max_corner: @Vector(2, f32),
    parent: u32,
    left: u32,
    left_is_leaf: bool,
    right: u32,
    right_is_leaf: bool,
    center_of_mass: @Vector(2, f32),
    total_mass: f32,
    times_visited: std.atomic.Value(u32),

    pub fn pipeline() *gpu.RenderPipeline {
        const shader_module = core.device.createShaderModuleWGSL("node.wgsl", @embedFile("node.wgsl"));
        defer shader_module.release();
        return core.device.createRenderPipeline(&.{
            .vertex = gpu.VertexState.init(.{
                .module = shader_module,
                .entry_point = "vertex",
                .buffers = &.{gpu.VertexBufferLayout.init(.{
                    .array_stride = @sizeOf(Node),
                    .step_mode = .instance,
                    .attributes = &.{
                        .{ .shader_location = 0, .offset = 0, .format = .float32x2 },
                        .{ .shader_location = 1, .offset = 2 * @sizeOf(f32), .format = .float32x2 },
                    },
                })},
            }),
            .primitive = .{ .topology = .line_strip },
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
