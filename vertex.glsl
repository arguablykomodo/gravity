#version 300 es

in vec2 position;
in vec2 velocity;
in float mass;
in vec2 vertex;

out vec2 v_velocity;
out vec2 v_uv;

void main() {
  float radius = sqrt(mass / 3.1415926535898);
  gl_Position = vec4((position + vertex * radius) / 200.0, 0.0, 1.0);
  v_velocity = velocity;
  v_uv = vertex;
}
