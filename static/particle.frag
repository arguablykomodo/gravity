#version 300 es
#define PI 3.1415926535898

precision highp float;

in vec2 v_velocity;
in vec2 v_acceleration;
in vec2 v_uv;

out vec4 out_color;

float mapAngle(vec2 vec) {
  return (atan(vec.y, vec.x) + PI) / (PI * 2.0);
}

float sigmoid(float value) {
  return value / (2.0 + abs(value));
}

float vectorIndicator(vec2 vec, float theta, float r) {
  float directionMask = step(abs(0.5 - mod(theta - mapAngle(vec) + 0.5, 1.0)), 0.1);
  float magnitudeMask = step(1.0 - sigmoid(length(vec)), r);
  return min(directionMask, magnitudeMask);
}

void main() {
  float theta = mapAngle(v_uv);
  float r = length(v_uv);

  float velocity_mask = vectorIndicator(v_velocity, theta, r);
  float acceleration_mask = vectorIndicator(v_acceleration, theta, r);

  vec3 color = mix(
    mix(
      mix(
        vec3(0.2, 0.1, 0.5),
        vec3(0.0, 1.0, 0.5),
        acceleration_mask
      ),
      vec3(1.0, 0.0, 0.5),
      velocity_mask
    ),
    vec3(1.0, 1.0, 0.5),
    min(acceleration_mask, velocity_mask)
  );

  float mask = 1.0 - smoothstep(1.0 - fwidth(length(v_uv)), 1.0, length(v_uv));
  out_color = mask * vec4(color, 1.0);
}
