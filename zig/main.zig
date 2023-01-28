const std = @import("std");
const Particle = @import("Particle.zig");
const Vec2 = @import("Vec2.zig");
const consts = @import("consts.zig");

const alloc = std.heap.wasm_allocator;

var particles: std.ArrayList(Particle) = undefined;

extern fn bufferParticles(ptr: [*]Particle, len: usize) void;

export fn setup() void {
    // Protoplanetary disk
    const amount = 5000;
    const radius = 50.0;
    const speed = 0.075;
    var rng = std.rand.DefaultPrng.init(0);
    const rand = rng.random();
    particles = std.ArrayList(Particle).initCapacity(alloc, amount) catch unreachable;
    var i: usize = 0;
    while (i < amount) : (i += 1) {
        const x = (rand.floatNorm(f32)) * radius;
        const y = (rand.floatNorm(f32)) * radius;
        const r = @sqrt(x * x + y * y);
        const direction = std.math.atan2(f32, y, x) + std.math.pi / 2.0;
        particles.append(.{
            .position = Vec2.new(x, y),
            .velocity = Vec2.new(@cos(direction), @sin(direction)).mul(r).mul(speed),
            .mass = (rand.float(f32) + 1.0) / 2.0,
        }) catch unreachable;
    }
}

export fn update(dt: f32) void {
    var deleted_particles = std.ArrayList(usize).init(alloc);
    defer deleted_particles.deinit();

    for (particles.items) |*particle, i| {
        if (particle.mass == 0) continue;
        var forces = Vec2.new(0, 0);
        for (particles.items) |*other_particle, j| {
            if (other_particle.mass == 0) continue;
            if (i == j) continue;
            const position_diff = other_particle.position.sub(particle.position);
            const distance = position_diff.length();
            const combined_masses = particle.mass + other_particle.mass;
            const radius_a = @sqrt(particle.mass / std.math.pi);
            const radius_b = @sqrt(other_particle.mass / std.math.pi);
            if (distance <= radius_a + radius_b) {
                deleted_particles.append(i) catch unreachable;
                other_particle.* = .{
                    .position = particle.position.mul(particle.mass)
                        .add(other_particle.position.mul(other_particle.mass))
                        .div(combined_masses),
                    .velocity = particle.velocity.mul(particle.mass)
                        .add(other_particle.velocity.mul(other_particle.mass))
                        .div(combined_masses),
                    .mass = combined_masses,
                };
                particle.mass = 0;
            }
            const force = position_diff
                .div(distance)
                .mul(consts.GRAVITATIONAL_CONSTANT *
                (particle.mass * other_particle.mass) /
                (distance * distance));
            forces = forces.add(force);
        }
        const acceleration = forces.div(particle.mass);
        particle.position = particle.position
            .add(particle.velocity.mul(dt))
            .add(acceleration.mul(0.5).mul(dt * dt));
        particle.velocity = particle.velocity
            .add(acceleration.mul(dt));
    }

    if (deleted_particles.items.len > 0) {
        var i: usize = deleted_particles.items.len - 1;
        while (i > 0) : (i -= 1) _ = particles.swapRemove(deleted_particles.items[i]);
    }

    bufferParticles(particles.items.ptr, particles.items.len);
}
