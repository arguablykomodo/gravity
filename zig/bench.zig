const std = @import("std");
const Quadtree = @import("quadtree.zig").Quadtree;
const Particle = @import("particle.zig").Particle;

pub fn main() !void {
    var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer allocator.deinit();

    var env = try std.process.getEnvMap(allocator.allocator());
    defer env.deinit();

    const scale = try std.fmt.parseFloat(f32, env.get("SCALE").?);
    const gravitational_constant = try std.fmt.parseFloat(f32, env.get("GRAVITATIONAL_CONSTANT").?);
    const theta = try std.fmt.parseFloat(f32, env.get("THETA").?);
    const particles = try std.fmt.parseUnsigned(usize, env.get("PARTICLES").?, 10);
    const dispersion = try std.fmt.parseFloat(f32, env.get("DISPERSION").?);
    const mass = try std.fmt.parseFloat(f32, env.get("MASS").?);
    var steps = try std.fmt.parseUnsigned(usize, env.get("STEPS").?, 10);

    var quadtree = Quadtree.init(allocator.allocator(), scale, gravitational_constant, theta);
    defer quadtree.deinit();
    try quadtree.disk(0, particles, dispersion, mass);

    while (steps > 0) : (steps -= 1) try quadtree.step(1.0 / 60.0);
}
