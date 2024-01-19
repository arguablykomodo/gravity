struct Particle {
    position: vec2<f32>,
    velocity: vec2<f32>,
    acceleration: vec2<f32>,
    mass: f32,
    parent: u32,
}

struct Uniforms {
    width: u32,
    height: u32,
    step: u32,
}

@group(0) @binding(0) var<storage, read_write> particles: array<Particle>;
@group(0) @binding(1) var<uniform> uniforms: Uniforms;

fn removeSameBits(x: f32, y: f32) -> u32 {
    return bitcast<u32>(x) & ~bitcast<u32>(y);
}

fn greater(a: vec2<f32>, b: vec2<f32>) -> bool {
    let a_evens_diff_bit = (32 - countLeadingZeros(removeSameBits(a.x, b.x))) * 2;
    let a_odds_diff_bit = (32 - countLeadingZeros(removeSameBits(a.y, b.y))) * 2 + 1;
    let b_evens_diff_bit = (32 - countLeadingZeros(removeSameBits(b.x, a.x))) * 2;
    let b_odds_diff_bit = (32 - countLeadingZeros(removeSameBits(b.y, a.y))) * 2 + 1;

    let a_most_significant_bit = max(a_evens_diff_bit, a_odds_diff_bit);
    let b_most_significant_bit = max(b_evens_diff_bit, b_odds_diff_bit);

    return a_most_significant_bit > b_most_significant_bit;
}

@compute @workgroup_size(1) fn sort(@builtin(global_invocation_id) id: vec3<u32>) {
    let height_i = id.x & (uniforms.width - 1);
    let left_i = height_i + (uniforms.height + 1) * (id.x / uniforms.width);
    let right_i = left_i + select((uniforms.height + 1) / 2, uniforms.height - 2 * height_i, uniforms.step == 0);

    if (right_i >= arrayLength(&particles)) {
        return;
    }

    if (greater(particles[left_i].position, particles[right_i].position)) {
        let temp = particles[left_i];
        particles[left_i] = particles[right_i];
        particles[right_i] = temp;
    }
}
