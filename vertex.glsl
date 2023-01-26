#version 300 es

in vec2 position;
in vec2 velocity;
in float mass;

out vec2 out_velocity;

void main() {
  gl_Position = vec4(position * 0.1, 0.0, 1.0);
  gl_PointSize = mass * 10.0;
  out_velocity = velocity;
}
