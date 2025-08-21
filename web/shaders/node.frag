#version 300 es
#define PI 3.1415926535898

precision highp float;

in vec2 v_center;
in float v_radius;
in float v_totalMass;
in vec2 v_centerOfMass;
in vec2 v_vertexPos;
in vec2 v_uv;

uniform float scale;

out vec4 out_color;

void main() {
  float massRadius = sqrt(v_totalMass / PI);
  float centerOfMass = 1.0 - step(massRadius, distance(v_vertexPos, v_centerOfMass));

  vec2 corner0 = abs(v_vertexPos - (v_center - v_radius));
  vec2 corner1 = abs(v_vertexPos - (v_center + v_radius));
  vec2 sides = 1.0 - step(fwidth(v_uv * v_radius) * 1.0, min(corner0, corner1));
  float border = max(sides.x, sides.y);

  vec2 sigmoid_distance = v_center / vec2(scale) * 0.5 + 0.5;
  vec3 color = vec3(sigmoid_distance, 0.5);

  float mask = max(centerOfMass * 0.1, border * 0.2);

  out_color = vec4(color, mask);
}
