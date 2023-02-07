const std = @import("std");
const Quadtree = @import("quadtree.zig").Quadtree;

pub const Particle = packed struct {
    position: @Vector(2, f32),
    velocity: @Vector(2, f32),
    acceleration: @Vector(2, f32),
    mass: f32,
    node: *Quadtree.Node,

    /// The `node` property must be set afterwards by a matching
    /// `Quadtree.insertParticle` call.
    pub fn new(position: @Vector(2, f32), velocity: @Vector(2, f32), mass: f32) Particle {
        return .{
            .position = position,
            .velocity = velocity,
            .acceleration = .{ 0.0, 0.0 },
            .mass = mass,
            .node = undefined,
        };
    }

    pub fn radius(self: Particle) f32 {
        return @sqrt(self.mass / std.math.pi);
    }

    pub fn force(self: Particle, position: @Vector(2, f32), mass: f32, big_g: f32) @Vector(2, f32) {
        const position_diff = position - self.position;
        const distance = @sqrt(@reduce(.Add, position_diff * position_diff));
        const direction = (position - self.position) / @splat(2, distance);
        return direction * @splat(2, big_g * (self.mass * mass) / (distance * distance));
    }

    pub fn updatePosition(self: *Particle, dt: f32) void {
        self.position += self.velocity * @splat(2, dt) + self.acceleration * @splat(2, 0.5 * dt * dt);
    }

    pub fn updateVelocity(self: *Particle, forces: @Vector(2, f32), dt: f32) void {
        const acceleration = forces / @splat(2, self.mass);
        self.velocity += (self.acceleration + acceleration) * @splat(2, 0.5 * dt);
        self.acceleration = acceleration;
    }

    pub fn collides(self: Particle, other: Particle) bool {
        const position_diff = other.position - self.position;
        const distance = @sqrt(@reduce(.Add, position_diff * position_diff));
        return distance < self.radius() + other.radius();
    }

    pub fn collide(self: Particle, other: Particle) Particle {
        return .{
            .position = (self.position * @splat(2, self.mass) +
                other.position * @splat(2, other.mass)) /
                @splat(2, self.mass + other.mass),
            .velocity = (self.velocity * @splat(2, self.mass) +
                other.velocity * @splat(2, other.mass)) /
                @splat(2, self.mass + other.mass),
            .acceleration = .{ 0.0, 0.0 },
            .mass = self.mass + other.mass,
            .node = undefined,
        };
    }
};

test "particle" {
    // Figure eight orbit, taken from https://arxiv.org/abs/math/0011268
    const period: f32 = 6.32591398;
    const p = @Vector(2, f32){ 0.97000436, -0.24308753 };
    const v = @Vector(2, f32){ -0.93240737, -0.86473146 };

    const p0 = p;
    const p1 = -p;
    const p2 = @Vector(2, f32){ 0.0, 0.0 };

    const v0 = -v / @Vector(2, f32){ 2.0, 2.0 };
    const v1 = -v / @Vector(2, f32){ 2.0, 2.0 };
    const v2 = v;

    var particles = [_]Particle{
        Particle.new(p0, v0, 1.0),
        Particle.new(p1, v1, 1.0),
        Particle.new(p2, v2, 1.0),
    };

    // The forces between all bodies should cancel out, due to Newton's third law.
    var forces = @Vector(2, f32){ 0.0, 0.0 };
    for (particles) |a, i| {
        for (particles) |b, j| {
            if (i == j) continue;
            forces += a.force(b.position, b.mass, 1.0);
        }
    }
    try std.testing.expectEqual(@Vector(2, f32){ 0.0, 0.0 }, forces);

    // Figure eight orbit should be periodic
    const dt = 1e-3;
    var time: f32 = 0;
    while (time < period) : (time += dt) {
        for (particles) |*particle| particle.updatePosition(dt);
        for (particles) |*particle, i| {
            forces = @Vector(2, f32){ 0.0, 0.0 };
            for (particles) |other_particle, j| {
                if (i == j) continue;
                forces += particle.force(other_particle.position, other_particle.mass, 1.0);
            }
            particle.updateVelocity(forces, dt);
        }
    }

    const tolerance = 1e-3;

    try std.testing.expectApproxEqAbs(p0[0], particles[0].position[0], tolerance);
    try std.testing.expectApproxEqAbs(p0[1], particles[0].position[1], tolerance);
    try std.testing.expectApproxEqAbs(v0[0], particles[0].velocity[0], tolerance);
    try std.testing.expectApproxEqAbs(v0[1], particles[0].velocity[1], tolerance);

    try std.testing.expectApproxEqAbs(p1[0], particles[1].position[0], tolerance);
    try std.testing.expectApproxEqAbs(p1[1], particles[1].position[1], tolerance);
    try std.testing.expectApproxEqAbs(v1[0], particles[1].velocity[0], tolerance);
    try std.testing.expectApproxEqAbs(v1[1], particles[1].velocity[1], tolerance);

    try std.testing.expectApproxEqAbs(p2[0], particles[2].position[0], tolerance);
    try std.testing.expectApproxEqAbs(p2[1], particles[2].position[1], tolerance);
    try std.testing.expectApproxEqAbs(v2[0], particles[2].velocity[0], tolerance);
    try std.testing.expectApproxEqAbs(v2[1], particles[2].velocity[1], tolerance);
}
