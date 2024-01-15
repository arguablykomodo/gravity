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

    pub const Pipeline = struct {
        alloc: std.mem.Allocator,
        nodes: []Node,
        buffer: *gpu.Buffer,
        pipeline: *gpu.RenderPipeline,

        pub fn init(alloc: std.mem.Allocator, count: usize) !Pipeline {
            const nodes = try alloc.alloc(Node, count);
            var rng = std.rand.DefaultPrng.init(1);
            const random = rng.random();
            for (nodes) |*n| {
                n.min_corner = .{ -random.floatExp(f32), -random.floatExp(f32) };
                n.max_corner = .{ random.floatExp(f32), random.floatExp(f32) };
            }

            const buffer = core.device.createBuffer(&.{
                .usage = .{ .storage = true, .vertex = true, .copy_dst = true },
                .size = @sizeOf(Node) * nodes.len,
            });
            core.queue.writeBuffer(buffer, 0, nodes[0..]);

            const shader_module = core.device.createShaderModuleWGSL("node.wgsl", @embedFile("node.wgsl"));
            defer shader_module.release();

            const pipeline = core.device.createRenderPipeline(&.{
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
                .primitive = .{
                    .topology = .line_strip,
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

            return Pipeline{
                .alloc = alloc,
                .nodes = nodes,
                .buffer = buffer,
                .pipeline = pipeline,
            };
        }

        pub fn deinit(self: Pipeline) void {
            self.pipeline.release();
            self.buffer.release();
            self.alloc.free(self.nodes);
        }

        pub fn bindGroup(self: Pipeline, binding: u32) gpu.BindGroup.Entry {
            return gpu.BindGroup.Entry.buffer(binding, self.buffer, 0, @sizeOf(Node) * self.nodes.len);
        }

        pub fn render(self: Pipeline, pass: *gpu.RenderPassEncoder) void {
            pass.setPipeline(self.pipeline);
            pass.setVertexBuffer(0, self.buffer, 0, gpu.whole_size);
            pass.draw(5, @intCast(self.nodes.len), 0, 0);
        }
    };
};
