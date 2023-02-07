#version 300 es

in vec2 center;
in float radius;
in float totalMass;
in vec2 weightedSum;
in vec2 vertex;

uniform mat3 view;

out vec2 v_center;
out float v_radius;
out float v_totalMass;
out vec2 v_centerOfMass;
out vec2 v_vertexPos;
out vec2 v_uv;

void main() {
  vec2 vertexPos = center + (vertex * radius);
  gl_Position = vec4((view * vec3(vertexPos, 1.0)).xy, 0.0, 1.0);
  v_center = center;
  v_radius = radius;
  v_totalMass = totalMass;
  v_centerOfMass = weightedSum / totalMass;
  v_vertexPos = vertexPos;
  v_uv = vertex;
}
