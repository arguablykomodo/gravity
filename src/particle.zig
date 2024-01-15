const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

pub const Particle = extern struct {
    position: @Vector(2, f32),
    velocity: @Vector(2, f32),
    acceleration: @Vector(2, f32),
    mass: f32,
    parent: u32,

    pub const Pipeline = struct {
        alloc: std.mem.Allocator,
        particles: []Particle,
        buffer: *gpu.Buffer,
        pipeline: *gpu.RenderPipeline,

        pub fn init(alloc: std.mem.Allocator, count: usize) !Pipeline {
            const particles = try alloc.alloc(Particle, count);
            var rng = std.rand.DefaultPrng.init(0);
            const random = rng.random();
            for (particles) |*p| {
                p.position = .{ random.floatNorm(f32), random.floatNorm(f32) };
                p.velocity = .{ 0.0, 0.0 };
                p.acceleration = .{ 0.0, 0.0 };
                p.mass = 0.001;
            }

            const buffer = core.device.createBuffer(&.{
                .usage = .{ .storage = true, .vertex = true, .copy_dst = true },
                .size = @sizeOf(Particle) * particles.len,
            });
            core.queue.writeBuffer(buffer, 0, particles[0..]);

            const shader_module = core.device.createShaderModuleWGSL("particle.wgsl", @embedFile("particle.wgsl"));
            defer shader_module.release();

            const pipeline = core.device.createRenderPipeline(&.{
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

            return Pipeline{
                .alloc = alloc,
                .particles = particles,
                .buffer = buffer,
                .pipeline = pipeline,
            };
        }

        pub fn deinit(self: Pipeline) void {
            self.pipeline.release();
            self.buffer.release();
            self.alloc.free(self.particles);
        }

        pub fn bindGroup(self: Pipeline, binding: u32) gpu.BindGroup.Entry {
            return gpu.BindGroup.Entry.buffer(binding, self.buffer, 0, @sizeOf(Particle) * self.particles.len);
        }

        pub fn render(self: Pipeline, pass: *gpu.RenderPassEncoder) void {
            pass.setPipeline(self.pipeline);
            pass.setVertexBuffer(0, self.buffer, 0, gpu.whole_size);
            pass.draw(4, @intCast(self.particles.len), 0, 0);
        }
    };
};
