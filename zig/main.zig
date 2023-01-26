const std = @import("std");
const Particle = @import("Particle.zig");
const Vec2 = @import("Vec2.zig");
const consts = @import("consts.zig");

const alloc = std.heap.wasm_allocator;

var particles: std.ArrayList(Particle) = undefined;

extern fn bufferParticles(ptr: [*]Particle, len: usize) void;

export fn setup() void {
    // Figure 8 orbit
    const px = 0.97000436;
    const py = -0.24308753;
    const vx = -0.93240737;
    const vy = -0.86473146;
    particles = std.ArrayList(Particle).init(alloc);
    particles.appendSlice(&[_]Particle{
        .{ .position = .{ .x = px, .y = py }, .velocity = .{ .x = -vx / 2.0, .y = -vy / 2.0 }, .mass = 1 },
        .{ .position = .{ .x = -px, .y = -py }, .velocity = .{ .x = -vx / 2.0, .y = -vy / 2.0 }, .mass = 1 },
        .{ .position = .{ .x = 0, .y = 0 }, .velocity = .{ .x = vx, .y = vy }, .mass = 1 },
    }) catch unreachable;
}

export fn update(dt: f32) void {
    for (particles.items) |*particle, i| {
        var forces = Vec2{ .x = 0, .y = 0 };
        for (particles.items) |other_particle, j| {
            if (i == j) continue;
            const position_diff = other_particle.position.sub(particle.position);
            const distance = position_diff.length();
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
    bufferParticles(particles.items.ptr, particles.items.len);
}
