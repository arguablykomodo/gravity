const std = @import("std");
const Quadtree = @import("quadtree.zig").Quadtree;
const Particle = @import("particle.zig").Particle;

pub fn main() !void {
    var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer allocator.deinit();

    var env = try std.process.getEnvMap(allocator.allocator());
    defer env.deinit();

    const big_g = try std.fmt.parseFloat(f32, env.get("BIG_G") orelse "1.0");
    const theta = try std.fmt.parseFloat(f32, env.get("THETA") orelse "0.5");
    const dt = try std.fmt.parseFloat(f32, env.get("TIMESTEP") orelse "0.5");
    const scale = try std.fmt.parseFloat(f32, env.get("SCALE") orelse "4096.0");
    const count = try std.fmt.parseUnsigned(usize, env.get("COUNT") orelse "10000", 10);
    const mass = try std.fmt.parseFloat(f32, env.get("MASS") orelse "1.0");
    const spread = try std.fmt.parseFloat(f32, env.get("SPREAD") orelse "512.0");
    const steps = try std.fmt.parseUnsigned(usize, env.get("STEPS") orelse "100", 10);

    var quadtree = Quadtree.init(allocator.allocator(), scale, big_g, theta);
    defer quadtree.deinit();
    try quadtree.disk(0, count, spread, mass);

    for (0..steps) |_| try quadtree.step(dt);
}
