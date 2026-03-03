#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_progress;
uniform float u_pairCount;
uniform float u_morphStyle;
uniform vec4 u_sourceRects[8];
uniform vec4 u_targetRects[8];
uniform sampler2D uTexture;
uniform sampler2D uTargetTexture;

out vec4 fragColor;

bool isInsideRect(vec2 uv, vec4 rect) {
  return uv.x >= rect.x &&
      uv.x <= rect.x + rect.z &&
      uv.y >= rect.y &&
      uv.y <= rect.y + rect.w;
}

float mixFactorByStyle(float t, int style) {
  if (style == 1) {
    // Soft: smoother blend ramp.
    return t * t * (3.0 - (2.0 * t));
  }
  if (style == 2) {
    // Ripple: slower start, faster finish.
    return pow(t, 0.7);
  }
  // Classic.
  return t;
}

vec2 warpLocalUvByStyle(vec2 localUv, float t, int style) {
  if (style == 2) {
    // Ripple style: radial wave around center.
    vec2 center = vec2(0.5, 0.5);
    vec2 d = localUv - center;
    float dist = length(d);
    float amp = 0.03 * (1.0 - t);
    float wave = sin((dist * 32.0) - (t * 18.0));
    vec2 safeDir = dist > 0.00001 ? (d / dist) : vec2(0.0);
    return localUv + (safeDir * wave * amp);
  }
  return localUv;
}

vec4 samplePairColor(vec2 screenUv, vec4 sourceRect, vec4 targetRect) {
  vec4 movedRect = vec4(
    mix(sourceRect.xy, targetRect.xy, u_progress),
    mix(sourceRect.zw, targetRect.zw, u_progress)
  );

  if (!isInsideRect(screenUv, movedRect)) {
    return vec4(0.0);
  }

  float safeW = max(movedRect.z, 0.00001);
  float safeH = max(movedRect.w, 0.00001);
  vec2 localUv = vec2(
    (screenUv.x - movedRect.x) / safeW,
    (screenUv.y - movedRect.y) / safeH
  );
  int style = int(u_morphStyle + 0.5);
  localUv = warpLocalUvByStyle(localUv, u_progress, style);
  localUv = clamp(localUv, vec2(0.0), vec2(1.0));
  localUv.y = 1.0 - localUv.y;

  vec4 sourceColor = texture(uTexture, localUv);
  vec4 targetColor = texture(uTargetTexture, localUv);
  float t = mixFactorByStyle(clamp(u_progress, 0.0, 1.0), style);
  return mix(sourceColor, targetColor, t);
}

void main() {
  vec2 safeResolution = max(u_resolution, vec2(0.00001));
  vec2 screenUv = FlutterFragCoord().xy / safeResolution;
  vec2 backgroundUv = clamp(screenUv, vec2(0.0), vec2(1.0));

  // Background remains transparent outside active moved rect membership.
  vec4 color = vec4(0.0);

  int cappedPairCount = clamp(int(u_pairCount + 0.5), 0, 8);
  for (int i = 0; i < 8; i++) {
    if (i >= cappedPairCount) {
      break;
    }
    vec4 sampled = samplePairColor(screenUv, u_sourceRects[i], u_targetRects[i]);
    if (sampled.a > 0.0) {
      color = sampled;
      break;
    }
  }

  // Keep background UV clamped as protocol safety rule.
  vec4 _unusedBg = texture(uTexture, vec2(backgroundUv.x, 1.0 - backgroundUv.y));
  fragColor = color;
}
