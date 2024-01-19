struct Particle {
    position: vec2<f32>,
    velocity: vec2<f32>,
    acceleration: vec2<f32>,
    mass: f32,
    parent: u32,
}

@group(0) @binding(0) var<storage, read_write> particles: array<Particle>;

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
