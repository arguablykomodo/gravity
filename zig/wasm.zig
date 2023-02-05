const std = @import("std");
const Quadtree = @import("quadtree.zig").Quadtree;
const Particle = @import("particle.zig").Particle;
const Coord = @import("quadtree.zig").Coord;

var quadtree: Quadtree = undefined;

extern fn returnError(ptr: [*:0]const u8) void;
extern fn returnOk(
    particles_ptr: [*]Particle,
    particles_len: usize,
    nodes_ptr: [*]Coord,
    nodes_len: usize,
) void;

export fn sizeOfParticle() usize {
    return @sizeOf(Particle);
}

export fn sizeOfNode() usize {
    return @sizeOf(Coord);
}

export fn init(scale: f32, gravitational_constant: f32, theta: f32) void {
    quadtree = Quadtree.init(std.heap.wasm_allocator, scale, gravitational_constant, theta);
}

export fn deinit() void {
    quadtree.deinit();
}

export fn insert(x: f32, y: f32, vx: f32, vy: f32, mass: f32) void {
    quadtree.insert(Particle.new(.{ x, y }, .{ vx, vy }, mass)) catch |e| returnError(@errorName(e));
}

export fn step(dt: f32) void {
    quadtree.step(dt) catch |e| returnError(@errorName(e));
    const keys = quadtree.nodes.keys();
    returnOk(quadtree.particles.items.ptr, quadtree.particles.items.len, keys.ptr, keys.len);
}
