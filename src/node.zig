const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

pub const Node = struct {
    min_corner: @Vector(2, f32),
    max_corner: @Vector(2, f32),
    center_of_mass: @Vector(2, f32),
    total_mass: f32,
    left_leaf: i32,
    left_node: i32,
    right_leaf: i32,
    right_node: i32,
    parent: u32,
    times_visited: u32,

    pub fn init() Node {
        return .{
            .min_corner = .{ 0.0, 0.0 },
            .max_corner = .{ 0.0, 0.0 },
            .center_of_mass = .{ 0.0, 0.0 },
            .total_mass = 0.0,
            .left_leaf = -1,
            .left_node = -1,
            .right_leaf = -1,
            .right_node = -1,
            .parent = 0,
            .times_visited = 0,
        };
    }

    pub fn pipeline() *gpu.RenderPipeline {
        const shader_module = core.device.createShaderModuleWGSL("node.wgsl", @embedFile("node.wgsl"));
        defer shader_module.release();
        return core.device.createRenderPipeline(&.{
            .label = "node render pipeline",
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
