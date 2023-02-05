#version 300 es

in ivec2 position;
in uint depth;
in vec2 vertex;

uniform mat3 view;
uniform float scale;

flat out ivec2 v_position;
flat out uint v_depth;

void main() {
  vec2 vertexPos = (vec2(position) + vertex) / float(2 << depth) * scale * 2.0;
  gl_Position = vec4((view * vec3(vertexPos, 1.0)).xy, 0.0, 1.0);
  v_position = position;
  v_depth = depth;
}
