const std = @import("std");
const consts = @import("consts.zig");
const utils = @import("utils.zig");
const Particle = @import("particle.zig").Particle;

pub const Coord = struct {
    x: i32,
    y: i32,
    depth: u32,

    fn children(self: Coord) [4]Coord {
        return .{
            Coord{ .x = self.x * 2 - 1, .y = self.y * 2 - 1, .depth = self.depth + 1 },
            Coord{ .x = self.x * 2 + 1, .y = self.y * 2 - 1, .depth = self.depth + 1 },
            Coord{ .x = self.x * 2 - 1, .y = self.y * 2 + 1, .depth = self.depth + 1 },
            Coord{ .x = self.x * 2 + 1, .y = self.y * 2 + 1, .depth = self.depth + 1 },
        };
    }

    fn parent(self: Coord) Coord {
        if (self.depth == 1) return ROOT;
        return Coord{ .x = roundToOdd(self.x), .y = roundToOdd(self.y), .depth = self.depth - 1 };
    }

    fn roundToOdd(n: i32) i32 {
        const divided = @divFloor(n, 2);
        return divided + (1 - (divided & 1));
    }

    fn isInside(self: Coord, vec: @Vector(2, f32)) bool {
        const depth = std.math.pow(f32, 2, @intToFloat(f32, self.depth));
        const c0 = @Vector(2, f32){
            @intToFloat(f32, self.x - 1) / depth * consts.QUADTREE_LIMITS,
            @intToFloat(f32, self.y - 1) / depth * consts.QUADTREE_LIMITS,
        };
        const c1 = @Vector(2, f32){
            @intToFloat(f32, self.x + 1) / depth * consts.QUADTREE_LIMITS,
            @intToFloat(f32, self.y + 1) / depth * consts.QUADTREE_LIMITS,
        };
        // Acts inclusively on the negative corners to handle the edge case of
        // a position right in the middle between nodes.
        return @reduce(.And, vec >= c0) and @reduce(.And, vec < c1);
    }

    fn width(self: Coord) f32 {
        return consts.QUADTREE_LIMITS / std.math.pow(f32, 2, @intToFloat(f32, self.depth) - 1.0);
    }

    const ROOT = Coord{ .x = 0, .y = 0, .depth = 0 };
};

const Trunk = struct {
    weighted_sum: @Vector(2, f32),
    total_mass: f32,
};

const Node = union(enum) {
    leaf: usize,
    trunk: Trunk,
};

pub const Quadtree = struct {
    nodes: std.AutoArrayHashMap(Coord, Node),
    particles: std.ArrayList(Particle),

    pub fn init(alloc: std.mem.Allocator) Quadtree {
        return Quadtree{
            .nodes = std.AutoArrayHashMap(Coord, Node).init(alloc),
            .particles = std.ArrayList(Particle).init(alloc),
        };
    }

    pub fn deinit(self: *Quadtree) void {
        self.particles.deinit();
        self.nodes.deinit();
    }

    pub fn insert(self: *Quadtree, particle: Particle) !void {
        try self.particles.append(particle);
        return self.insertInternal(Coord.ROOT, self.particles.items.len - 1);
    }

    fn insertInternal(self: *Quadtree, coord: Coord, index: usize) !void {
        if (self.nodes.getPtr(coord)) |node| switch (node.*) {
            .leaf => |other_particle| {
                node.* = Node{ .trunk = .{ .weighted_sum = .{ 0.0, 0.0 }, .total_mass = 0 } };
                try self.insertInternal(coord, other_particle);
                return try self.insertInternal(coord, index);
            },
            .trunk => |*data| for (coord.children()) |child| {
                const particle = self.particles.items[index];
                if (child.isInside(particle.position)) {
                    data.weighted_sum += particle.position * @splat(2, particle.mass);
                    data.total_mass += particle.mass;
                    return try self.insertInternal(child, index);
                }
            } else unreachable,
        } else {
            self.particles.items[index].node = coord;
            try self.nodes.put(coord, Node{ .leaf = index });
            return;
        }
    }

    fn remove(self: *Quadtree, index: usize) void {
        const particle = &self.particles.items[index];
        if (!self.nodes.swapRemove(particle.node)) unreachable;
        if (particle.node.depth > 0) self.collapse(particle.node.parent(), particle);
    }

    fn collapse(self: *Quadtree, coord: Coord, particle: *const Particle) void {
        const node = self.nodes.getPtr(coord).?;
        node.trunk.weighted_sum -= particle.position * @splat(2, particle.mass);
        node.trunk.total_mass -= particle.mass;

        var children: usize = 0;
        var only_child: Coord = undefined;
        for (coord.children()) |child| if (self.nodes.contains(child)) {
            children += 1;
            only_child = child;
        };

        switch (children) {
            0 => if (!self.nodes.swapRemove(coord)) unreachable,
            1 => {
                const child = self.nodes.get(only_child).?;
                if (child == .leaf) {
                    self.particles.items[child.leaf].node = coord;
                    if (!self.nodes.swapRemove(only_child)) unreachable;
                    self.nodes.putAssumeCapacity(coord, child);
                }
            },
            else => {},
        }

        if (coord.depth > 0) self.collapse(coord.parent(), particle);
    }

    fn changeSum(self: *Quadtree, coord: Coord, change: @Vector(2, f32)) void {
        self.nodes.getPtr(coord).?.trunk.weighted_sum += change;
        if (coord.depth > 0) self.changeSum(coord.parent(), change);
    }

    fn forces(self: *const Quadtree, coord: Coord, particle: *const Particle) @Vector(2, f32) {
        const node = if (self.nodes.getPtr(coord)) |node| node else return @Vector(2, f32){ 0.0, 0.0 };
        switch (node.*) {
            .leaf => |index| {
                if (std.meta.eql(coord, particle.node)) return @Vector(2, f32){ 0.0, 0.0 };
                const other_particle = self.particles.items[index];
                return particle.force(other_particle.position, other_particle.mass);
            },
            .trunk => |data| {
                const center_of_mass = data.weighted_sum / @splat(2, data.total_mass);
                const distance = utils.length(center_of_mass - particle.position);
                const quotient = coord.width() / distance;
                if (quotient > consts.QUADTREE_THETA) {
                    var total = @Vector(2, f32){ 0.0, 0.0 };
                    for (coord.children()) |child| total += self.forces(child, particle);
                    return total;
                } else {
                    return particle.force(center_of_mass, data.total_mass);
                }
            },
        }
    }

    fn delete(self: *Quadtree, index: usize) void {
        _ = self.particles.swapRemove(index);
        self.nodes.getPtr(self.particles.items[index].node).?.leaf = index;
    }

    pub fn step(self: *Quadtree, dt: f32) !void {
        var i: usize = 0;
        while (i < self.particles.items.len) : (i += 1) {
            const particle = &self.particles.items[i];
            const old_position = particle.position;
            particle.updatePosition(dt);
            if (particle.node.depth > 0) self.changeSum(particle.node.parent(), (particle.position - old_position) * @splat(2, particle.mass));
            if (!particle.node.isInside(particle.position)) {
                self.remove(i);
                if (Coord.ROOT.isInside(particle.position)) {
                    try self.insertInternal(Coord.ROOT, i);
                } else {
                    self.delete(i);
                    i -= 1;
                }
            }
        }
        for (self.particles.items) |*particle| {
            particle.updateForces(self.forces(Coord.ROOT, particle), dt);
        }
    }
};

test "quadtree insert/remove/step" {
    var random = std.rand.DefaultPrng.init(0);
    const rng = random.random();

    var quadtree = Quadtree.init(std.testing.allocator);
    defer quadtree.deinit();

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const x = (rng.float(f32) * 2.0 - 1.0) * consts.QUADTREE_LIMITS;
        const y = (rng.float(f32) * 2.0 - 1.0) * consts.QUADTREE_LIMITS;
        try quadtree.insert(Particle.new(.{ x, y }, .{ 0.0, 0.0 }, 1.0));
    }

    var iter = quadtree.nodes.iterator();
    var leafs: usize = 0;
    while (iter.next()) |entry| if (entry.value_ptr.* == .leaf) {
        leafs += 1;
    };
    try std.testing.expectEqual(quadtree.particles.items.len, leafs);

    i = 0;
    while (i < 10) : (i += 1) try quadtree.step(1.0 / 60.0);

    for (quadtree.particles.items) |_, j| quadtree.remove(j);
    try std.testing.expectEqual(@as(usize, 0), quadtree.nodes.count());
}
