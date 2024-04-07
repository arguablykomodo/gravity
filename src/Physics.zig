const std = @import("std");
const core = @import("mach").core;
const gpu = @import("mach").gpu;

const Particle = @import("Particles.zig").Particle;
const Node = @import("Nodes.zig").Node;

particle_buffer: *gpu.Buffer,
particle_staging_buffer: *gpu.Buffer,
node_staging_buffer: *gpu.Buffer,

pub fn init(max_particles: u32, particle_buffer: *gpu.Buffer) @This() {
    const particle_staging_buffer = core.device.createBuffer(&.{
        .label = "particle staging buffer",
        .usage = .{ .map_read = true, .copy_dst = true },
        .size = @sizeOf(Particle) * max_particles,
    });
    const node_staging_buffer = core.device.createBuffer(&.{
        .label = "node staging buffer",
        .usage = .{ .map_read = true, .copy_dst = true },
        .size = @sizeOf(Node) * (max_particles - 1),
    });
    return .{
        .particle_buffer = particle_buffer,
        .particle_staging_buffer = particle_staging_buffer,
        .node_staging_buffer = node_staging_buffer,
    };
}

pub fn deinit(self: *@This()) void {
    self.node_staging_buffer.release();
    self.particle_staging_buffer.release();
}

pub fn copy(self: *@This(), encoder: *gpu.CommandEncoder, particle_buffer: *gpu.Buffer, node_buffer: *gpu.Buffer) void {
    encoder.copyBufferToBuffer(particle_buffer, 0, self.particle_staging_buffer, 0, particle_buffer.getSize());
    encoder.copyBufferToBuffer(node_buffer, 0, self.node_staging_buffer, 0, node_buffer.getSize());
}

pub fn step(self: *@This()) void {
    self.particle_staging_buffer.mapAsync(.{ .read = true }, 0, self.particle_staging_buffer.getSize(), self, callback);
    self.node_staging_buffer.mapAsync(.{ .read = true }, 0, self.node_staging_buffer.getSize(), self, callback);
}

pub fn pending(self: *@This()) bool {
    return self.particle_staging_buffer.getMapState() != .unmapped or
        self.node_staging_buffer.getMapState() != .unmapped;
}

inline fn callback(self: *@This(), status: gpu.Buffer.MapAsyncStatus) void {
    if (status != .success) {
        std.log.err("callback error: {}\n", .{status});
        return;
    }
    if (self.particle_staging_buffer.getMapState() != .mapped or self.node_staging_buffer.getMapState() != .mapped) return;
    defer self.node_staging_buffer.unmap();
    defer self.particle_staging_buffer.unmap();
    const particles = self.particle_staging_buffer.getConstMappedRange(Particle, 0, 32768).?;
    const nodes = self.node_staging_buffer.getConstMappedRange(Node, 0, 32767).?;
    const new_particles = core.allocator.dupe(Particle, particles) catch unreachable;
    defer core.allocator.free(new_particles);
    for (new_particles, 0..) |*p, i| {
        p.acceleration = forces(i, 0, particles, nodes) * @as(@Vector(2, f32), @splat(1000.0));
        p.velocity += p.acceleration * @Vector(2, f32){ 0.016, 0.016 };
        p.position += p.velocity * @Vector(2, f32){ 0.016, 0.016 };
    }
    core.queue.writeBuffer(self.particle_buffer, 0, new_particles[0..]);
}

fn length(v: @Vector(2, f32)) f32 {
    return @sqrt(@reduce(.Add, v * v));
}

pub fn force(self: Particle, position: @Vector(2, f32), mass: f32) @Vector(2, f32) {
    const position_diff = position - self.position;
    const distance = length(position_diff);
    const direction = position_diff / @Vector(2, f32){ distance, distance };
    return direction * @as(@Vector(2, f32), @splat((self.mass * mass) / @max(0.01, distance * distance)));
}

fn forces(particle: usize, node_i: usize, particles: []const Particle, nodes: []const Node) @Vector(2, f32) {
    var total = @Vector(2, f32){ 0.0, 0.0 };
    const node = nodes[node_i];
    if (node.left_leaf > -1) {
        if (node.left_leaf != particle) {
            total += force(particles[particle], particles[@intCast(node.left_leaf)].position, particles[@intCast(node.left_leaf)].mass);
        }
    } else {
        const distance = length(node.center_of_mass - particles[particle].position);
        const size = @sqrt(@reduce(.Mul, node.max_corner - node.min_corner));
        if (size / distance < 1.5) {
            total += force(particles[particle], node.center_of_mass, node.total_mass);
        } else {
            total += forces(particle, @intCast(node.left_node), particles, nodes);
        }
    }
    if (node.right_leaf > -1) {
        if (node.right_leaf != particle) {
            total += force(particles[particle], particles[@intCast(node.right_leaf)].position, particles[@intCast(node.right_leaf)].mass);
        }
    } else {
        const distance = length(node.center_of_mass - particles[particle].position);
        const size = @sqrt(@reduce(.Mul, node.max_corner - node.min_corner));
        if (size / distance < 1.5) {
            total += force(particles[particle], node.center_of_mass, node.total_mass);
        } else {
            total += forces(particle, @intCast(node.right_node), particles, nodes);
        }
    }
    return total;
}
