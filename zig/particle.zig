const std = @import("std");
const consts = @import("consts.zig");
const utils = @import("utils.zig");
const Coord = @import("quadtree.zig").Coord;
const Quadtree = @import("quadtree.zig").Quadtree;

/// Represents an idealized point particle, subject to Newton's law of motion.
pub const Particle = struct {
    position: @Vector(2, f32),
    velocity: @Vector(2, f32),
    acceleration: @Vector(2, f32),
    mass: f32,
    node: Coord,

    /// Creates a new `Particle`. The `node` property must be set afterwards by
    /// a matching `Quadtree.insert` call.
    pub fn new(position: @Vector(2, f32), velocity: @Vector(2, f32), mass: f32) Particle {
        return .{
            .position = position,
            .velocity = velocity,
            .acceleration = .{ 0.0, 0.0 },
            .mass = mass,
            .node = undefined,
        };
    }

    /// Calculates the force applied on a `Particle` by another mass at a given
    /// position according to Newton's law of universal gravitation. This mass
    /// can either be another `Particle` or the generalized center of mass from
    /// a `Quadtree` cell.
    pub fn force(self: Particle, position: @Vector(2, f32), mass: f32) @Vector(2, f32) {
        const distance = utils.length(position - self.position);
        const direction = (position - self.position) / @splat(2, distance);
        return direction * @splat(2, consts.GRAVITATIONAL_CONSTANT *
            (self.mass * mass) / (distance * distance));
    }

    /// Updates the particle's position via velocity Verlet integration.
    pub fn updatePosition(self: *Particle, dt: f32) void {
        self.position += self.velocity * @splat(2, dt) + self.acceleration * @splat(2, 0.5 * dt * dt);
    }

    /// Updates the particle's velocity and acceleration via velocity Verlet
    /// integration.
    pub fn updateForces(self: *Particle, acceleration: @Vector(2, f32), dt: f32) void {
        self.velocity += (self.acceleration + acceleration) * @splat(2, 0.5 * dt);
        self.acceleration = acceleration;
    }
};

test "particle force" {
    var random = std.rand.DefaultPrng.init(0);
    const rng = random.random();
    var particles = std.ArrayList(Particle).init(std.testing.allocator);
    defer particles.deinit();
    var i: usize = 0;
    while (i < 5000) : (i += 1) {
        const x = rng.float(f32) * consts.QUADTREE_LIMITS;
        const y = rng.float(f32) * consts.QUADTREE_LIMITS;
        try particles.append(Particle.new(.{ x, y }, .{ 0.0, 0.0 }, 0.0));
    }

    // The forces between all bodies should cancel out, due to Newton's third law.
    var forces = @Vector(2, f32){ 0.0, 0.0 };
    for (particles.items) |a, j| {
        for (particles.items) |b, k| {
            if (j == k) continue;
            forces += a.force(b.position, b.mass);
        }
    }
    try std.testing.expectEqual(@Vector(2, f32){ 0.0, 0.0 }, forces);
}
