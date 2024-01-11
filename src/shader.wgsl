const PI = 3.14159265359;
const QUAD = array<vec2<f32>, 4>(
    vec2<f32>(-1.0, -1.0),
    vec2<f32>(-1.0,  1.0),
    vec2<f32>( 1.0, -1.0),
    vec2<f32>( 1.0,  1.0),
);

struct Particle {
    @location(0) position: vec2<f32>,
    @location(1) velocity: vec2<f32>,
    @location(2) acceleration: vec2<f32>,
    @location(3) mass: f32,
};

struct VertexData {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) velocity: vec2<f32>,
    @location(2) acceleration: vec2<f32>,
};

@vertex fn vertex(
    @builtin(vertex_index) vertex_index: u32,
    particle: Particle,
) -> VertexData {
    let vertex = QUAD[vertex_index];
    var out: VertexData;
    out.position = vec4<f32>(vertex * particle.mass + particle.position, 0.0, 1.0);
    out.uv = vertex;
    out.velocity = particle.velocity;
    out.acceleration = particle.acceleration;
    return out;
}

fn aastep(threshold: f32, value: f32) -> f32 {
    let dx = length(vec2(dpdx(value), dpdy(value))) * 0.70710678118654757;
    return smoothstep(threshold - dx, threshold + dx, value);
}

fn mapAngle(vec: vec2<f32>) -> f32 {
    return (atan2(vec.y, vec.x) + PI) / (PI * 2.0);
}

fn sigmoid(value: f32) -> f32 {
    return value / (2.0 + abs(value));
}

fn vectorIndicator(vec: vec2<f32>, theta: f32, r: f32) -> f32 {
    let theta_mask = aastep(fract(theta - mapAngle(vec) + 0.125), 0.25);
    let r_mask = aastep(1.0 - r, sigmoid(length(vec)));
    return min(theta_mask, r_mask);
}

@fragment fn fragment(data: VertexData) -> @location(0) vec4<f32> {
    let theta = mapAngle(data.uv);
    let r = length(data.uv);
    let velocity_mask = vectorIndicator(data.velocity, theta, r);
    let acceleration_mask = vectorIndicator(data.acceleration, theta, r);
    let color = mix(
        mix(
            mix(
                vec3(0.2, 0.1, 0.5),
                vec3(0.0, 1.0, 0.5),
                acceleration_mask
            ),
            vec3(1.0, 0.0, 0.5),
            velocity_mask
        ),
        vec3(1.0, 1.0, 0.5),
        min(acceleration_mask, velocity_mask)
    );
    let mask = 1.0 - aastep(1.0, length(data.uv));
    return mask * vec4(color, 1.0);
}
