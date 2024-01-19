const PI = 3.14159265359;

struct Particle {
    position: vec2<f32>,
    velocity: vec2<f32>,
    acceleration: vec2<f32>,
    mass: f32,
    parent: u32,
}

struct Node {
    min_corner: vec2<f32>,
    max_corner: vec2<f32>,
    center_of_mass: vec2<f32>,
    total_mass: f32,
    left_leaf: i32,
    left_node: i32,
    right_leaf: i32,
    right_node: i32,
    parent: u32,
    times_visited: atomic<u32>,
}

@group(0) @binding(0) var<storage, read_write> particles: array<Particle>;
@group(0) @binding(1) var<storage, read_write> nodes: array<Node>;

fn lcp(i: i32, j: i32) -> i32 {
    if (j < 0 || j > i32(arrayLength(&nodes))) {
        return -1;
    }
    let a = particles[i].position;
    let b = particles[j].position;
    let xored_pairs = bitcast<u32>(a.x) ^ bitcast<u32>(b.x);
    let xored_odds = bitcast<u32>(a.y) ^ bitcast<u32>(b.y);
    let pairs_zeroes: u32 = countLeadingZeros(xored_pairs);
    let odds_zeroes: u32 = countLeadingZeros(xored_odds);
    let shortest = min(pairs_zeroes, odds_zeroes);
    if (pairs_zeroes == odds_zeroes) {
        return i32(pairs_zeroes + odds_zeroes);
    } else if (odds_zeroes > pairs_zeroes) {
        return i32(shortest * 2 + 1);
    } else {
        return i32(shortest * 2);
    }
}

@compute @workgroup_size(1) fn buildTree(@builtin(global_invocation_id) id: vec3<u32>) {
    let i = i32(id.x);
    // Determine direction of the range
    let d = sign(lcp(i, i + 1) - lcp(i, i - 1));
    // Compute upper bound for the length of the range
    let lcp_min = lcp(i, i - d);
    var l_max = 2;
    while (lcp(i, i + l_max * d) > lcp_min) {
        l_max *= 2;
    }
    // Find the other end using binary search
    var l = 0;
    while (l_max > 1) {
        l_max /= 2;
        if (lcp(i, i + (l + l_max) * d) > lcp_min) {
            l += l_max;
        }
    }
    let j = i + l * d;
    // Find the split position using binary search
    let lcp_node = lcp(i, j);
    var s = 0;
    while (l > 1) {
        l = (l / 2) + (l & 1);
        if (lcp(i, i + (s + l) * d) > lcp_node) {
            s += l;
        }
    }
    let gamma = i + s * d + min(d, 0);
    // Output child pointers
    nodes[i].min_corner = vec2<f32>(0.0, 0.0);
    nodes[i].max_corner = vec2<f32>(0.0, 0.0);
    nodes[i].center_of_mass = vec2<f32>(0.0, 0.0);
    nodes[i].total_mass = 0.0;
    atomicStore(&nodes[i].times_visited, 0);
    if (min(i, j) == gamma) {
        nodes[i].left_leaf = gamma;
        nodes[i].left_node = -1;
        particles[gamma].parent = u32(i);
    } else {
        nodes[i].left_leaf = -1;
        nodes[i].left_node = gamma;
        nodes[gamma].parent = u32(i);
    }
    if (max(i, j) == gamma + 1) {
        nodes[i].right_leaf = gamma + 1;
        nodes[i].right_node = -1;
        particles[gamma + 1].parent = u32(i);
    } else {
        nodes[i].right_leaf = -1;
        nodes[i].right_node = gamma + 1;
        nodes[gamma + 1].parent = u32(i);
    }
}

fn radius(mass: f32) -> f32 {
    return sqrt(mass / PI);
}

@compute @workgroup_size(1) fn buildBvh(@builtin(global_invocation_id) id: vec3<u32>) {
    var i = particles[id.x].parent;
    while (true) {
        if (atomicAdd(&nodes[i].times_visited, 1) == 1) {
            if (nodes[i].left_leaf > -1) {
                let child = particles[nodes[i].left_leaf];
                nodes[i].center_of_mass += child.position * 0.5;
                nodes[i].total_mass += child.mass;
                nodes[i].min_corner = child.position - radius(child.mass);
                nodes[i].max_corner = child.position + radius(child.mass);
            } else {
                let child = &nodes[nodes[i].left_node];
                nodes[i].center_of_mass += (*child).center_of_mass * 0.5;
                nodes[i].total_mass += (*child).total_mass;
                nodes[i].min_corner = (*child).min_corner;
                nodes[i].max_corner = (*child).max_corner;
            }
            if (nodes[i].right_leaf > -1) {
                let child = particles[nodes[i].right_leaf];
                nodes[i].center_of_mass += child.position * 0.5;
                nodes[i].total_mass += child.mass;
                nodes[i].min_corner = min(nodes[i].min_corner, child.position - radius(child.mass));
                nodes[i].max_corner = max(nodes[i].max_corner, child.position + radius(child.mass));
            } else {
                let child = &nodes[nodes[i].right_node];
                nodes[i].center_of_mass += (*child).center_of_mass * 0.5;
                nodes[i].total_mass += (*child).total_mass;
                nodes[i].min_corner = min(nodes[i].min_corner, (*child).min_corner);
                nodes[i].max_corner = max(nodes[i].max_corner, (*child).max_corner);
            }
            if (i == 0) {
                break;
            } else {
                i = nodes[i].parent;
                continue;
            }
        } else {
            break;
        }
    }
}

@compute @workgroup_size(1) fn physics(@builtin(global_invocation_id) id: vec3<u32>) {
    var particle = particles[id.x];
    particle.acceleration = vec2<f32>(0.0, 0.0);
    for (var i: u32 = 0; i < arrayLength(&particles); i++) {
        if (i == id.x) {
            continue;
        }
        particle.acceleration += normalize(particles[i].position - particle.position) * (
            (particles[i].mass * particle.mass) /
            pow(max(0.01, distance(particles[i].position, particle.position)), 2)
        );
    }
    particle.velocity += particle.acceleration * 0.5;
    particle.position += particle.velocity * 0.5;
    particles[id.x] = particle;
}
