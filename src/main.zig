const std = @import("std");
const core = @import("mach-core");
const Particle = @import("particle.zig").Particle;
const Node = @import("node.zig").Node;
const Controls = @import("Controls.zig");
const gpu = core.gpu;

const PARTICLES = 10;

pub const App = @This();

controls: Controls,

particles: []Particle,
particle_buffer: *gpu.Buffer,
particle_pipeline: *gpu.RenderPipeline,
particle_bind_group: *gpu.BindGroup,

nodes: []Node,
node_buffer: *gpu.Buffer,
node_pipeline: *gpu.RenderPipeline,
node_bind_group: *gpu.BindGroup,

sort_uniform_buffer: *gpu.Buffer,
sort_pipeline: *gpu.ComputePipeline,
sort_bind_group: *gpu.BindGroup,

build_tree_pipeline: *gpu.ComputePipeline,
build_tree_bind_group: *gpu.BindGroup,

build_bvh_pipeline: *gpu.ComputePipeline,
build_bvh_bind_group: *gpu.BindGroup,

physics_pipeline: *gpu.ComputePipeline,
physics_bind_group: *gpu.BindGroup,

const SortUniforms = struct {
    group_width: u32,
    group_height: u32,
    step: u32,
};

pub fn init(app: *App) !void {
    try core.init(.{});

    var rng = std.rand.DefaultPrng.init(2);
    const random = rng.random();

    const controls = Controls.init();

    const particles = try core.allocator.alloc(Particle, PARTICLES);
    for (particles) |*p| p.* = Particle.new(
        random.float(f32) * 1.5 - 0.75,
        random.float(f32) * 1.5 - 0.75,
        0.0,
        0.0,
        0.001,
    );
    const particle_buffer = core.device.createBuffer(&.{
        .label = "particle buffer",
        .usage = .{ .storage = true, .vertex = true, .copy_dst = true },
        .size = @sizeOf(Particle) * particles.len,
    });
    core.queue.writeBuffer(particle_buffer, 0, particles[0..]);
    const particle_pipeline = Particle.pipeline();
    const particle_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "particle bind group",
        .layout = particle_pipeline.getBindGroupLayout(0),
        .entries = &.{gpu.BindGroup.Entry.buffer(0, controls.buffer, 0, @sizeOf(Controls.Uniforms))},
    }));

    const nodes = try core.allocator.alloc(Node, particles.len - 1);
    @memset(nodes, Node.init());
    const node_buffer = core.device.createBuffer(&.{
        .label = "node buffer",
        .usage = .{ .storage = true, .vertex = true, .copy_dst = true },
        .size = @sizeOf(Node) * nodes.len,
    });
    core.queue.writeBuffer(node_buffer, 0, nodes[0..]);
    const node_pipeline = Node.pipeline();
    const node_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "node bind group",
        .layout = node_pipeline.getBindGroupLayout(0),
        .entries = &.{gpu.BindGroup.Entry.buffer(0, controls.buffer, 0, @sizeOf(Controls.Uniforms))},
    }));

    const compute_module = core.device.createShaderModuleWGSL("compute.wgsl", @embedFile("compute.wgsl"));
    defer compute_module.release();

    const sort_uniform_buffer = core.device.createBuffer(&.{
        .label = "sort uniform buffer",
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(SortUniforms),
    });
    const sort_pipeline = core.device.createComputePipeline(&.{
        .label = "sort pipeline",
        .compute = .{
            .module = compute_module,
            .entry_point = "sort",
        },
    });
    const sort_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "sort bind group",
        .layout = sort_pipeline.getBindGroupLayout(0),
        .entries = &.{
            gpu.BindGroup.Entry.buffer(0, particle_buffer, 0, @sizeOf(Particle) * particles.len),
            gpu.BindGroup.Entry.buffer(2, sort_uniform_buffer, 0, @sizeOf(SortUniforms)),
        },
    }));

    const build_tree_pipeline = core.device.createComputePipeline(&.{
        .label = "buildTree pipeline",
        .compute = .{
            .module = compute_module,
            .entry_point = "buildTree",
        },
    });
    const build_tree_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "buildTree bind group",
        .layout = build_tree_pipeline.getBindGroupLayout(0),
        .entries = &.{
            gpu.BindGroup.Entry.buffer(0, particle_buffer, 0, @sizeOf(Particle) * particles.len),
            gpu.BindGroup.Entry.buffer(1, node_buffer, 0, @sizeOf(Node) * nodes.len),
        },
    }));

    const build_bvh_pipeline = core.device.createComputePipeline(&.{
        .label = "buildBvh pipeline",
        .compute = .{
            .module = compute_module,
            .entry_point = "buildBvh",
        },
    });
    const build_bvh_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "buildBvh bind group",
        .layout = build_bvh_pipeline.getBindGroupLayout(0),
        .entries = &.{
            gpu.BindGroup.Entry.buffer(0, particle_buffer, 0, @sizeOf(Particle) * particles.len),
            gpu.BindGroup.Entry.buffer(1, node_buffer, 0, @sizeOf(Node) * nodes.len),
        },
    }));

    const physics_pipeline = core.device.createComputePipeline(&.{
        .label = "physics pipeline",
        .compute = .{
            .module = compute_module,
            .entry_point = "physics",
        },
    });
    const physics_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "physics bind group",
        .layout = physics_pipeline.getBindGroupLayout(0),
        .entries = &.{
            gpu.BindGroup.Entry.buffer(0, particle_buffer, 0, @sizeOf(Particle) * particles.len),
        },
    }));

    app.* = .{
        .controls = controls,

        .particles = particles,
        .particle_buffer = particle_buffer,
        .particle_pipeline = particle_pipeline,
        .particle_bind_group = particle_bind_group,

        .nodes = nodes,
        .node_buffer = node_buffer,
        .node_pipeline = node_pipeline,
        .node_bind_group = node_bind_group,

        .sort_uniform_buffer = sort_uniform_buffer,
        .sort_pipeline = sort_pipeline,
        .sort_bind_group = sort_bind_group,

        .build_tree_pipeline = build_tree_pipeline,
        .build_tree_bind_group = build_tree_bind_group,

        .build_bvh_pipeline = build_bvh_pipeline,
        .build_bvh_bind_group = build_bvh_bind_group,

        .physics_pipeline = physics_pipeline,
        .physics_bind_group = physics_bind_group,
    };

    core.setFrameRateLimit(60);
}

pub fn deinit(app: *App) void {
    app.physics_bind_group.release();
    app.physics_pipeline.release();

    app.build_bvh_bind_group.release();
    app.build_bvh_pipeline.release();

    app.build_tree_bind_group.release();
    app.build_tree_pipeline.release();

    app.sort_bind_group.release();
    app.sort_pipeline.release();
    app.sort_uniform_buffer.release();

    app.node_bind_group.release();
    app.node_pipeline.release();
    app.node_buffer.release();
    core.allocator.free(app.nodes);

    app.particle_bind_group.release();
    app.particle_pipeline.release();
    app.particle_buffer.release();
    core.allocator.free(app.particles);

    app.controls.deinit();

    core.deinit();
}

pub fn update(app: *App) !bool {
    var iter = core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .close => return true,
            .framebuffer_resize => |e| app.controls.updateWindowScale(.{ @floatFromInt(e.width), @floatFromInt(e.height) }),
            .mouse_scroll => |e| app.controls.zoom(e.yoffset),
            .mouse_press => |e| if (e.button == .left) app.controls.beginTranslation(.{ @floatCast(e.pos.x), @floatCast(e.pos.y) }),
            .mouse_motion => |e| app.controls.translate(.{ @floatCast(e.pos.x), @floatCast(e.pos.y) }),
            .mouse_release => |e| if (e.button == .left) app.controls.endTranslation(),
            else => {},
        }
    }

    const numStages = std.math.log2_int(u32, std.math.ceilPowerOfTwoAssert(u32, @intCast(app.particles.len)));
    for (0..numStages) |stageIndex| {
        for (0..(stageIndex + 1)) |stepIndex| {
            // Calculate some pattern stuff
            const groupWidth = @as(u32, 1) << @intCast(stageIndex - stepIndex);
            const groupHeight = 2 * groupWidth - 1;
            // Run the sorting step on the GPU
            const runs = std.math.ceilPowerOfTwoAssert(u32, @intCast(app.particles.len)) / 2;
            core.queue.writeBuffer(app.sort_uniform_buffer, 0, &[1]SortUniforms{.{
                .group_width = groupWidth,
                .group_height = groupHeight,
                .step = @intCast(stepIndex),
            }});
            const encoder = core.device.createCommandEncoder(null);
            const compute_pass = encoder.beginComputePass(null);
            compute_pass.setPipeline(app.sort_pipeline);
            compute_pass.setBindGroup(0, app.sort_bind_group, null);
            compute_pass.dispatchWorkgroups(runs, 1, 1);
            compute_pass.end();
            compute_pass.release();
            var command = encoder.finish(null);
            encoder.release();
            core.queue.submit(&[_]*gpu.CommandBuffer{command});
            command.release();
        }
    }

    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;

    const encoder = core.device.createCommandEncoder(null);

    const compute_pass = encoder.beginComputePass(null);

    compute_pass.setPipeline(app.build_tree_pipeline);
    compute_pass.setBindGroup(0, app.build_tree_bind_group, null);
    compute_pass.dispatchWorkgroups(@intCast(app.nodes.len), 1, 1);

    compute_pass.setPipeline(app.build_bvh_pipeline);
    compute_pass.setBindGroup(0, app.build_bvh_bind_group, null);
    compute_pass.dispatchWorkgroups(@intCast(app.particles.len), 1, 1);

    compute_pass.setPipeline(app.physics_pipeline);
    compute_pass.setBindGroup(0, app.physics_bind_group, null);
    compute_pass.dispatchWorkgroups(@intCast(app.particles.len), 1, 1);

    compute_pass.end();
    compute_pass.release();

    const render_pass = encoder.beginRenderPass(&gpu.RenderPassDescriptor.init(.{
        .label = "render pass",
        .color_attachments = &.{gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            .clear_value = std.mem.zeroes(gpu.Color),
            .load_op = .clear,
            .store_op = .store,
        }},
    }));

    render_pass.setPipeline(app.node_pipeline);
    render_pass.setBindGroup(0, app.node_bind_group, null);
    render_pass.setVertexBuffer(0, app.node_buffer, 0, gpu.whole_size);
    render_pass.draw(5, @intCast(app.nodes.len), 0, 0);

    render_pass.setPipeline(app.particle_pipeline);
    render_pass.setBindGroup(0, app.particle_bind_group, null);
    render_pass.setVertexBuffer(0, app.particle_buffer, 0, gpu.whole_size);
    render_pass.draw(4, @intCast(app.particles.len), 0, 0);

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
