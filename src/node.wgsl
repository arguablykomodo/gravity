const PI = 3.14159265359;
const QUAD = array<vec2<f32>, 4>(
    vec2<f32>(0.0, 0.0),
    vec2<f32>(0.0, 1.0),
    vec2<f32>(1.0, 0.0),
    vec2<f32>(1.0, 1.0),
);

struct Node {
    @location(0) min_corner: vec2<f32>,
    @location(1) max_corner: vec2<f32>,
    @location(2) center_of_mass: vec2<f32>,
    @location(3) total_mass: f32,
};

struct VertexData {
    @builtin(position) position: vec4<f32>,
    @location(0) min_corner: vec2<f32>,
    @location(1) max_corner: vec2<f32>,
    @location(2) center_of_mass: vec2<f32>,
    @location(3) total_mass: f32,
    @location(4) world_position: vec2<f32>,
};

struct Controls {
    translation: vec2<f32>,
    window_scale: vec2<f32>,
    scale: f32,
}

@group(0) @binding(0) var<uniform> controls: Controls;

@vertex fn vertex(
    @builtin(vertex_index) vertex_index: u32,
    node: Node,
) -> VertexData {
    var out: VertexData;
    var pos = mix(node.min_corner, node.max_corner, QUAD[vertex_index]);
    out.world_position = pos;
    pos += controls.translation * vec2<f32>(-1.0, 1.0);
    pos /= controls.window_scale * 0.5;
    pos *= controls.scale;
    out.position = vec4<f32>(pos, 0.0, 1.0);
    out.min_corner = node.min_corner;
    out.max_corner = node.max_corner;
    out.center_of_mass = node.center_of_mass;
    out.total_mass = node.total_mass;
    return out;
}

fn radius(mass: f32) -> f32 {
    return sqrt(mass / PI);
}

@fragment fn fragment(data: VertexData) -> @location(0) vec4<f32> {
    let center_of_mass = 1.0 - step(radius(data.total_mass), distance(data.world_position, data.center_of_mass));

    let corner_0 = abs(data.world_position - data.min_corner);
    let corner_1 = abs(data.world_position - data.max_corner);
    let sides = 1.0 - step(fwidth(data.world_position), min(corner_0, corner_1));
    let border = max(sides.x, sides.y);

    let mask = max(center_of_mass * 0.1, border * 0.2);

    let center = (data.min_corner + data.max_corner) / 2.0;
    let sigmoid_distance = center / (1.0 + abs(center));
    let color = vec3(sigmoid_distance, 0.5);

    return vec4(color * mask, mask);
}
