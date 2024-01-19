const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

tree_pipeline: *gpu.ComputePipeline,
tree_bind_group: *gpu.BindGroup,

bvh_pipeline: *gpu.ComputePipeline,
bvh_bind_group: *gpu.BindGroup,

pub fn init(particles: *gpu.Buffer, nodes: *gpu.Buffer) @This() {
    const shader = core.device.createShaderModuleWGSL("bvh.wgsl", @embedFile("bvh.wgsl"));
    defer shader.release();

    const tree_pipeline = core.device.createComputePipeline(&.{
        .label = "buildTree pipeline",
        .compute = .{
            .module = shader,
            .entry_point = "buildTree",
        },
    });
    const tree_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "buildTree bind group",
        .layout = tree_pipeline.getBindGroupLayout(0),
        .entries = &.{
            gpu.BindGroup.Entry.buffer(0, particles, 0, particles.getSize()),
            gpu.BindGroup.Entry.buffer(1, nodes, 0, nodes.getSize()),
        },
    }));

    const bvh_pipeline = core.device.createComputePipeline(&.{
        .label = "buildBvh pipeline",
        .compute = .{
            .module = shader,
            .entry_point = "buildBvh",
        },
    });
    const bvh_bind_group = core.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "buildBvh bind group",
        .layout = bvh_pipeline.getBindGroupLayout(0),
        .entries = &.{
            gpu.BindGroup.Entry.buffer(0, particles, 0, particles.getSize()),
            gpu.BindGroup.Entry.buffer(1, nodes, 0, nodes.getSize()),
        },
    }));

    return .{
        .tree_pipeline = tree_pipeline,
        .tree_bind_group = tree_bind_group,

        .bvh_pipeline = bvh_pipeline,
        .bvh_bind_group = bvh_bind_group,
    };
}

pub fn deinit(self: *@This()) void {
    self.bvh_bind_group.release();
    self.bvh_pipeline.release();

    self.tree_bind_group.release();
    self.tree_pipeline.release();
}

pub fn buildBvh(self: *@This(), pass: *gpu.ComputePassEncoder, particles: u32) void {
    pass.setPipeline(self.tree_pipeline);
    pass.setBindGroup(0, self.tree_bind_group, null);
    pass.dispatchWorkgroups(particles - 1, 1, 1);

    pass.setPipeline(self.bvh_pipeline);
    pass.setBindGroup(0, self.bvh_bind_group, null);
    pass.dispatchWorkgroups(particles, 1, 1);
}
