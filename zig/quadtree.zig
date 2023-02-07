const std = @import("std");
const Particle = @import("particle.zig").Particle;

pub const Quadtree = struct {
    pub const Node = struct {
        center: @Vector(2, f32),
        radius: f32,
        is_child: ?struct {
            parent: *Node,
            index: usize,
        },
        data: union(enum) {
            leaf: usize,
            trunk: struct {
                children: [4]?*Node,
                weighted_sum: @Vector(2, f32),
                total_mass: f32,
            },
        },

        /// Assumes node is a trunk.
        pub fn update(self: *Node, weighted_sum_change: @Vector(2, f32), mass_change: f32) void {
            self.data.trunk.weighted_sum += weighted_sum_change;
            self.data.trunk.total_mass += mass_change;
            if (self.is_child) |data| data.parent.update(weighted_sum_change, mass_change);
        }

        pub fn isInside(self: Node, position: @Vector(2, f32)) bool {
            const corner_0 = self.center - @splat(2, self.radius);
            const corner_1 = self.center + @splat(2, self.radius);
            // Inclusive on the negative corner to handle the edge case of a
            // particle being right in the middle.
            return @reduce(.And, position >= corner_0) and @reduce(.And, position < corner_1);
        }
    };

    alloc: std.mem.Allocator,
    root: ?*Node,
    particles: std.ArrayList(Particle),
    big_g: f32,
    theta: f32,
    scale: f32,

    pub fn init(alloc: std.mem.Allocator, scale: f32, big_g: f32, theta: f32) Quadtree {
        return Quadtree{
            .alloc = alloc,
            .root = null,
            .particles = std.ArrayList(Particle).init(alloc),
            .big_g = big_g,
            .theta = theta,
            .scale = scale,
        };
    }

    pub fn deinit(self: *Quadtree) void {
        self.particles.deinit();
        if (self.root) |root| self.deinitNode(root);
    }

    fn deinitNode(self: *Quadtree, node: *Node) void {
        if (node.data == .trunk) for (node.data.trunk.children) |child| {
            if (child) |child_node| self.deinitNode(child_node);
        };
        self.alloc.destroy(node);
    }

    pub fn insertParticle(self: *Quadtree, particle: Particle) !void {
        try self.particles.append(particle);
        try self.insertIntoTree(self.particles.items.len - 1);
    }

    fn insertIntoTree(self: *Quadtree, particle_index: usize) !void {
        if (self.root) |root| try self.insertIntoTreeRecursive(particle_index, root) else {
            self.root = try self.alloc.create(Node);
            self.root.?.* = Node{
                .center = .{ 0.0, 0.0 },
                .radius = self.scale,
                .is_child = null,
                .data = .{ .leaf = particle_index },
            };
        }
    }

    fn insertIntoTreeRecursive(self: *Quadtree, particle_index: usize, node: *Node) !void {
        switch (node.data) {
            .leaf => {
                const other_particle = node.data.leaf;
                node.data = .{ .trunk = .{
                    .children = .{ null, null, null, null },
                    .weighted_sum = .{ 0.0, 0.0 },
                    .total_mass = 0.0,
                } };
                try self.insertIntoTreeRecursive(other_particle, node);
                try self.insertIntoTreeRecursive(particle_index, node);
            },
            .trunk => |*data| {
                const particle = &self.particles.items[particle_index];
                data.weighted_sum += particle.position * @splat(2, particle.mass);
                data.total_mass += particle.mass;
                const x = particle.position[0] < node.center[0];
                const y = particle.position[1] < node.center[1];
                const child_index: usize = if (x) if (y) 0 else 2 else if (y) 1 else 3;
                if (data.children[child_index]) |child| {
                    try self.insertIntoTreeRecursive(particle_index, child);
                } else {
                    const child = try self.alloc.create(Node);
                    node.data.trunk.children[child_index] = child;
                    child.* = .{
                        .center = node.center + @splat(2, node.radius / 2.0) * @Vector(2, f32){
                            if (child_index & 1 == 1) 1.0 else -1.0,
                            if (child_index & 2 == 2) 1.0 else -1.0,
                        },
                        .radius = node.radius / 2.0,
                        .is_child = .{ .parent = node, .index = child_index },
                        .data = .{ .leaf = particle_index },
                    };
                    particle.node = child;
                }
            },
        }
    }

    /// Assumes `removeFromTree` has already been called.
    fn removeParticle(self: *Quadtree, particle_index: usize) void {
        _ = self.particles.swapRemove(particle_index);
        if (particle_index != self.particles.items.len) self.particles.items[particle_index].node.data.leaf = particle_index;
    }

    fn removeFromTree(self: *Quadtree, particle: *const Particle) void {
        const is_child = particle.node.is_child;
        self.alloc.destroy(particle.node);
        if (is_child) |data| {
            data.parent.data.trunk.children[data.index] = null;
            self.removeFromTreeRecursive(particle, data.parent);
        } else self.root = null;
    }

    /// Assumes `node` is a trunk.
    fn removeFromTreeRecursive(self: *Quadtree, removed_particle: *const Particle, node: *Node) void {
        node.data.trunk.weighted_sum -= removed_particle.position * @splat(2, removed_particle.mass);
        node.data.trunk.total_mass -= removed_particle.mass;
        var children_count: usize = 0;
        var only_leaf_child: ?*Node = null;
        for (node.data.trunk.children) |child| {
            if (child) |child_node| {
                children_count += 1;
                if (node.data == .leaf) only_leaf_child = child_node;
            }
        }
        if (children_count == 0) {
            const is_child = node.is_child;
            self.alloc.destroy(node);
            if (is_child) |data| {
                data.parent.data.trunk.children[data.index] = null;
                self.removeFromTreeRecursive(removed_particle, data.parent);
            } else self.root = null;
        } else if (children_count == 1 and only_leaf_child != null) {
            const particle = only_leaf_child.?.data.leaf;
            self.alloc.destroy(only_leaf_child.?);
            node.data = .{ .leaf = particle };
            if (node.is_child) |data| self.removeFromTreeRecursive(removed_particle, data.parent);
        } else if (node.is_child) |data| data.parent.update(
            -removed_particle.position * @splat(2, removed_particle.mass),
            -removed_particle.mass,
        );
    }

    fn forces(self: *Quadtree, particle: *const Particle) @Vector(2, f32) {
        return self.forcesRecursive(particle, self.root.?);
    }

    fn forcesRecursive(self: *Quadtree, particle: *const Particle, node: *Node) @Vector(2, f32) {
        switch (node.data) {
            .leaf => |other_particle_index| {
                if (particle.node == node) return @Vector(2, f32){ 0.0, 0.0 };
                const other_particle = self.particles.items[other_particle_index];
                return particle.force(other_particle.position, other_particle.mass, self.big_g);
            },
            .trunk => |data| {
                const center_of_mass = data.weighted_sum / @splat(2, data.total_mass);
                const position_diff = center_of_mass - particle.position;
                const distance = @sqrt(@reduce(.Add, position_diff * position_diff));
                const quotient = node.radius * 2.0 / distance;
                if (quotient > self.theta) {
                    var total = @Vector(2, f32){ 0.0, 0.0 };
                    for (data.children) |child| {
                        if (child) |child_node| total += self.forcesRecursive(particle, child_node);
                    }
                    return total;
                } else {
                    return particle.force(center_of_mass, data.total_mass, self.big_g);
                }
            },
        }
    }

    pub fn step(self: *Quadtree, dt: f32) !void {
        var i: usize = 0;
        while (i < self.particles.items.len) : (i +%= 1) {
            const particle = &self.particles.items[i];
            const old_position = particle.position;
            particle.updatePosition(dt);
            if (particle.node.is_child) |data| data.parent.update((particle.position - old_position) * @splat(2, particle.mass), 0.0);
            if (!particle.node.isInside(particle.position)) {
                self.removeFromTree(particle);
                if (self.root.?.isInside(particle.position)) try self.insertIntoTree(i) else {
                    self.removeParticle(i);
                    i -%= 1;
                }
            }
        }
        for (self.particles.items) |*particle| particle.updateForces(self.forces(particle), dt);
    }
};

test "quadtree" {
    const scale = 64.0;
    const particles = 1000;
    const steps = 100;

    var quadtree = Quadtree.init(std.testing.allocator, scale, 1.0, 0.5);
    defer quadtree.deinit();

    var random = std.rand.DefaultPrng.init(0);
    const rng = random.random();

    var weighted_sum = @Vector(2, f32){ 0.0, 0.0 };
    var i: usize = 0;
    while (i < particles) : (i += 1) {
        const position = @Vector(2, f32){ rng.float(f32) * scale * 2 - scale, rng.float(f32) * scale * 2 - scale };
        weighted_sum += position;
        try quadtree.insertParticle(Particle.new(position, .{ 0.0, 0.0 }, 1.0));
    }

    try std.testing.expectEqual(weighted_sum, quadtree.root.?.data.trunk.weighted_sum);
    try std.testing.expectEqual(@as(f32, particles), quadtree.root.?.data.trunk.total_mass);

    i = 0;
    while (i < steps) : (i += 1) try quadtree.step(1.0 / 60.0);

    try std.testing.expectEqual(@as(f32, scale), quadtree.root.?.radius);
    try std.testing.expectEqual(@as(f32, scale / 2.0), quadtree.root.?.data.trunk.children[0].?.radius);

    weighted_sum = @Vector(2, f32){ 0.0, 0.0 };
    var total_mass: f32 = 0.0;
    for (quadtree.particles.items) |particle| {
        weighted_sum += particle.position * @splat(2, particle.mass);
        total_mass += particle.mass;
    }
    try std.testing.expectApproxEqRel(total_mass, quadtree.root.?.data.trunk.total_mass, @sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqRel(weighted_sum[0], quadtree.root.?.data.trunk.weighted_sum[0], @sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqRel(weighted_sum[1], quadtree.root.?.data.trunk.weighted_sum[1], @sqrt(std.math.floatEps(f32)));

    while (quadtree.particles.items.len > 0) {
        quadtree.removeFromTree(&quadtree.particles.items[0]);
        quadtree.removeParticle(0);
    }

    try std.testing.expectEqual(@as(?*Quadtree.Node, null), quadtree.root);
}
