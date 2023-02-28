const std = @import("std");
const Quadtree = @import("quadtree.zig").Quadtree;
const Particle = @import("particle.zig").Particle;

const GlNode = packed struct {
    center: @Vector(2, f32),
    radius: f32,
    total_mass: f32,
    weighted_sum: @Vector(2, f32),
};

var quadtree: Quadtree = undefined;

extern fn returnError(ptr: [*:0]const u8) void;

export const sizeOfParticle = @as(u32, @sizeOf(Particle));
export const sizeOfNode = @as(u32, @sizeOf(GlNode));

export fn init(scale: f32, big_g: f32, theta: f32) void {
    quadtree = Quadtree.init(std.heap.wasm_allocator, scale, big_g, theta);
}

export fn setParameters(big_g: f32, theta: f32) void {
    quadtree.big_g = big_g;
    quadtree.theta = theta;
}

export fn deinit() void {
    quadtree.deinit();
}

export fn insert(x: f32, y: f32, vx: f32, vy: f32, mass: f32) void {
    quadtree.insertParticle(Particle.new(.{ x, y }, .{ vx, vy }, mass)) catch |e| returnError(@errorName(e));
}

export fn step(dt: f32) void {
    quadtree.step(dt) catch |e| returnError(@errorName(e));
}

extern fn returnParticles(ptr: [*]Particle, len: usize) void;
export fn getParticles() void {
    returnParticles(quadtree.particles.items.ptr, quadtree.particles.items.len);
}

var nodes = std.ArrayList(GlNode).init(std.heap.wasm_allocator);
extern fn returnNodes(ptr: [*]GlNode, len: usize) void;
export fn getNodes() void {
    nodes.shrinkRetainingCapacity(0);
    if (quadtree.root) |root| appendNodes(root) catch |e| returnError(@errorName(e));
    returnNodes(nodes.items.ptr, nodes.items.len);
}

fn appendNodes(node: *Quadtree.Node) !void {
    try nodes.append(.{
        .center = node.center,
        .radius = node.radius,
        .total_mass = switch (node.data) {
            .leaf => |i| quadtree.particles.items[i].mass,
            .trunk => |data| data.total_mass,
        },
        .weighted_sum = switch (node.data) {
            .leaf => |i| quadtree.particles.items[i].position * @splat(2, quadtree.particles.items[i].mass),
            .trunk => |data| data.weighted_sum,
        },
    });
    if (node.data == .trunk) inline for (node.data.trunk.children) |child| {
        if (child) |child_node| try appendNodes(child_node);
    };
}
