#version 300 es

precision highp float;

in vec2 out_velocity;

out vec4 color;

void main() {
  color = vec4(abs(out_velocity), 1.0, 1.0);
}
