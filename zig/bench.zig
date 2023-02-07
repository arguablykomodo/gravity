const std = @import("std");
const Quadtree = @import("quadtree.zig").Quadtree;
const Particle = @import("particle.zig").Particle;

pub fn main() !void {
    var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer allocator.deinit();

    var particles = try std.fmt.parseUnsigned(usize, std.os.getenv("PARTICLES").?, 10);
    var steps = try std.fmt.parseUnsigned(usize, std.os.getenv("STEPS").?, 10);
    const spread = try std.fmt.parseFloat(f32, std.os.getenv("SPREAD").?);
    const speed = try std.fmt.parseFloat(f32, std.os.getenv("SPEED").?);
    const scale = try std.fmt.parseFloat(f32, std.os.getenv("SCALE").?);
    const gravitational_constant = try std.fmt.parseFloat(f32, std.os.getenv("GRAVITATIONAL_CONSTANT").?);
    const theta = try std.fmt.parseFloat(f32, std.os.getenv("THETA").?);

    var quadtree = Quadtree.init(allocator.allocator(), scale, gravitational_constant, theta);
    defer quadtree.deinit();

    var random = std.rand.DefaultPrng.init(0);
    const rng = random.random();
    while (particles > 0) : (particles -= 1) {
        try quadtree.insertParticle(Particle.new(
            .{ (rng.float(f32) * 2.0 - 1.0) * spread, (rng.float(f32) * 2.0 - 1.0) * spread },
            .{ (rng.float(f32) * 2.0 - 1.0) * speed, (rng.float(f32) * 2.0 - 1.0) * speed },
            1.0,
        ));
    }

    while (steps > 0) : (steps -= 1) try quadtree.step(1.0 / 60.0);
}
