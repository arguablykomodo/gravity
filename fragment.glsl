#version 300 es

precision highp float;

in vec2 v_velocity;
in vec2 v_uv;

out vec4 color;

void main() {
  float mask = step(length(v_uv), 1.0);
  color = mask * vec4(v_velocity / (2.0 + abs(v_velocity)) * 0.5 + 0.5, 1.0, 1.0);
}
