#version 300 es
#define PI 3.1415926535898

in vec2 position;
in vec2 velocity;
in vec2 acceleration;
in float mass;
in vec2 vertex;

out vec2 v_velocity;
out vec2 v_acceleration;
out vec2 v_uv;

uniform mat3 view;

void main() {
  float radius = sqrt(mass / PI);
  vec2 vertexPos = position + vertex * radius;
  gl_Position = vec4((view * vec3(vertexPos, 1.0)).xy, 0.0, 1.0);
  v_velocity = velocity;
  v_acceleration = acceleration;
  v_uv = vertex;
}
