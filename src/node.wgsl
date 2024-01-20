struct Node {
    @location(0) min_corner: vec2<f32>,
    @location(1) max_corner: vec2<f32>,
};

struct VertexData {
    @builtin(position) position: vec4<f32>,
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
    let bit_0 = vertex_index & 1;
    let bit_1 = (vertex_index & 2) >> 1;
    var pos = select(node.min_corner, node.max_corner, vec2<bool>((bit_0 ^ bit_1) == 1, bit_1 == 1));
    pos += controls.translation * vec2<f32>(-1.0, 1.0);
    pos /= controls.window_scale * 0.5;
    pos *= controls.scale;
    out.position = vec4<f32>(pos, 0.0, 1.0);
    return out;
}

@fragment fn fragment(data: VertexData) -> @location(0) vec4<f32> {
    return vec4(vec3(0.1), 1.0);
}
