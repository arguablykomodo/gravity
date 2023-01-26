#version 300 es

in vec2 position;
in vec2 velocity;
in float mass;

out vec2 out_velocity;

void main() {
  gl_Position = vec4(position / 200.0, 0.0, 1.0);
  gl_PointSize = sqrt(mass / 3.14159) * 1024.0 / 200.0;
  out_velocity = velocity;
}
