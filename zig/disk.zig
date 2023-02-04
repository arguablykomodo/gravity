const std = @import("std");
const consts = @import("consts.zig");
const utils = @import("utils.zig");
const Quadtree = @import("quadtree.zig").Quadtree;
const Particle = @import("particle.zig").Particle;

pub fn disk(quadtree: *Quadtree, seed: u64) !void {
    var random = std.rand.DefaultPrng.init(seed);
    const rng = random.random();
    var i: usize = 0;
    while (i < consts.INITIAL_PARTICLES) : (i += 1) {
        const position = @Vector(2, f32){
            @max(@min(rng.floatNorm(f32) * consts.DISK_SD, consts.QUADTREE_LIMITS), -consts.QUADTREE_LIMITS),
            @max(@min(rng.floatNorm(f32) * consts.DISK_SD, consts.QUADTREE_LIMITS), -consts.QUADTREE_LIMITS),
        };
        const r = utils.length(position);
        const direction = std.math.atan2(f32, position[1], position[0]) + std.math.pi / 2.0;
        try quadtree.insert(Particle.new(
            position,
            @Vector(2, f32){ @cos(direction), @sin(direction) } * @splat(2, r * consts.ANGULAR_VELOCITY),
            1.0,
        ));
    }
}
