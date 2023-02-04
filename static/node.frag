#version 300 es

precision highp float;

flat in ivec2 v_position;
flat in uint v_depth;

uniform float quadtreeLimits;

out vec4 out_color;

void main() {
  vec2 thing = vec2(v_position) / float(2 << v_depth) * 0.5 + 0.5;
  out_color = vec4(thing, 1.0, 1.0 - 100.0 / float(v_depth + 100u));
}
