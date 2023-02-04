const std = @import("std");
const consts = @import("consts.zig");
const disk = @import("disk.zig").disk;
const Quadtree = @import("quadtree.zig").Quadtree;
const Particle = @import("particle.zig").Particle;
const Coord = @import("quadtree.zig").Coord;

var quadtree: Quadtree = undefined;

extern fn returnError(ptr: [*:0]const u8) void;
extern fn returnOk(
    particlesPtr: [*]Particle,
    particlesLen: usize,
    nodesPtr: [*]Coord,
    nodesLen: usize,
) void;

export fn sizeOfParticle() usize {
    return @sizeOf(Particle);
}

export fn sizeOfNode() usize {
    return @sizeOf(Coord);
}

export fn quadtreeLimits() f32 {
    return consts.QUADTREE_LIMITS;
}

export fn init(seed: u64) void {
    quadtree = Quadtree.init(std.heap.wasm_allocator);
    if (disk(&quadtree, seed)) |_| {} else |e| returnError(@errorName(e));
}

export fn deinit() void {
    quadtree.deinit();
}

export fn step(dt: f32) void {
    if (quadtree.step(dt)) |_| {
        const keys = quadtree.nodes.keys();
        returnOk(quadtree.particles.items.ptr, quadtree.particles.items.len, keys.ptr, keys.len);
    } else |e| returnError(@errorName(e));
}
