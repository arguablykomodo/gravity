const std = @import("std");
const Quadtree = @import("quadtree.zig").Quadtree;
const Particle = @import("particle.zig").Particle;
const Coord = @import("quadtree.zig").Coord;

var quadtree: Quadtree = undefined;

extern fn returnError(ptr: [*:0]const u8) void;

export const sizeOfParticle = @as(u32, @sizeOf(Particle));
export const sizeOfNode = @as(u32, @sizeOf(Coord));

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
    quadtree.insert(Particle.new(.{ x, y }, .{ vx, vy }, mass)) catch |e| returnError(@errorName(e));
}

export fn step(dt: f32) void {
    quadtree.step(dt) catch |e| returnError(@errorName(e));
}

extern fn returnParticles(ptr: [*]Particle, len: usize) void;
export fn getParticles() void {
    returnParticles(quadtree.particles.items.ptr, quadtree.particles.items.len);
}

extern fn returnNodes(ptr: [*]Coord, len: usize) void;
export fn getNodes() void {
    const keys = quadtree.nodes.keys();
    returnNodes(keys.ptr, keys.len);
}
