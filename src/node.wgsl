struct Node {
    @location(0) min_corner: vec2<f32>,
    @location(1) max_corner: vec2<f32>,
};

struct VertexData {
    @builtin(position) position: vec4<f32>,
};

@vertex fn vertex(
    @builtin(vertex_index) vertex_index: u32,
    node: Node,
) -> VertexData {
    var out: VertexData;
    let bit_0 = vertex_index & 1;
    let bit_1 = (vertex_index & 2) >> 1;
    let corner = select(node.min_corner - vec2<f32>(0.01, 0.01), node.max_corner + vec2<f32>(0.01, 0.01), vec2<bool>((bit_0 ^ bit_1) == 1, bit_1 == 1));
    out.position = vec4<f32>(corner, 0.0, 1.0);
    return out;
}

@fragment fn fragment(data: VertexData) -> @location(0) vec4<f32> {
    return vec4(1.0);
}
