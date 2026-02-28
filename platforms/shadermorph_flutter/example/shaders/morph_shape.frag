#include <flutter/runtime_effect.glsl>

out vec4 fragColor;

uniform vec2 u_resolution;
uniform float u_progress;
uniform float u_pairCount;
uniform float u_morphStyle;
uniform vec4 u_sourceRects[8];
uniform vec4 u_targetRects[8];
uniform float u_debugMode;
uniform float u_texFlipY;

float sdBox(vec2 p, vec2 b) {
  vec2 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdCircle(vec2 p, float r) {
  return length(p) - r;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / max(u_resolution, vec2(1.0));
  vec4 rect = u_sourceRects[0];
  vec2 minPt = rect.xy;
  vec2 maxPt = rect.xy + rect.zw;

  if (uv.x < minPt.x || uv.x > maxPt.x || uv.y < minPt.y || uv.y > maxPt.y) {
    fragColor = vec4(1.0);
    return;
  }

  vec2 localUV = (uv - minPt) / rect.zw;
  vec2 p = localUV - vec2(0.5);

  float dRect = sdBox(p, vec2(0.5, 0.5));
  float dCircle = sdCircle(p, 0.5);
  float d = mix(dRect, dCircle, u_progress);

  float aa = fwidth(d);
  float alpha = 1.0 - smoothstep(0.0, aa, d);

  fragColor = vec4(0.0, 0.0, 1.0, alpha);
}
