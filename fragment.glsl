#version 300 es

precision highp float;

in vec2 v_velocity;
in vec2 v_uv;

out vec4 out_color;

void main() {
  float width = fwidth(length(v_uv));
  float mask = 1.0 - smoothstep(1.0 - width, 1.0, length(v_uv));
  vec3 color = vec3(v_velocity / (2.0 + abs(v_velocity)) * 0.5 + 0.5, 1.0);
  out_color = mask * vec4(color, 1.0);
}
