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
  if (style == 3) {
    // Liquid: slightly eased with no overshoot.
    return clamp((t * t * (3.0 - (2.0 * t))) * 0.96 + (0.04 * t), 0.0, 1.0);
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
  if (style == 3) {
    // Liquid: bobbing + wobble + directional anticipation.
    vec2 center = vec2(0.5, 0.5);
    vec2 d = localUv - center;
    float dist = length(d);
    vec2 safeDir = dist > 0.00001 ? (d / dist) : vec2(0.0);

    float phase = t * 6.28318530718;
    float envelope = sin(t * 3.14159265359);
    float bob = sin((localUv.x * 6.0) + (phase * 1.3)) * 0.020 * envelope;
    float wobble = sin((dist * 24.0) - (phase * 2.1)) * 0.030 * envelope;
    float edgeFalloff = 1.0 - smoothstep(0.35, 0.75, dist);
    vec2 radial = safeDir * wobble * edgeFalloff;

    // Directional anticipation toward target center.
    // Approximate motion direction using progress-weighted axis bias.
    vec2 dirBias = normalize(
      vec2(0.00001 + (t * 0.02), 0.00001 + ((1.0 - t) * 0.02))
    );
    vec2 anticipate = dirBias * 0.018 * envelope;

    return localUv + radial + vec2(0.0, bob) + anticipate;
  }
  return localUv;
}

float alphaMaskByStyle(vec2 localUv, float t, int style) {
  if (style != 3) {
    return 1.0;
  }

  // Liquid hybrid silhouette: blob in-rect + tiny adaptive spill.
  vec2 center = vec2(0.5, 0.5);
  vec2 d = localUv - center;
  float x = d.x;
  float y = d.y;

  // Elliptic blob base.
  float rx = 0.50;
  float ry = 0.44;
  float blobField = ((x * x) / (rx * rx)) + ((y * y) / (ry * ry));

  // Mid-flight wobble contour.
  float envelope = sin(clamp(t, 0.0, 1.0) * 3.14159265359);
  float contour = 0.11 * envelope *
      sin((atan(y, x) * 4.0) + (length(d) * 18.0) - (t * 11.0));

  // Tiny controlled spill near mid-flight.
  float spill = 0.03 * envelope;
  float threshold = 1.0 + contour + spill;

  return 1.0 - smoothstep(threshold, threshold + 0.03, blobField);
}

vec4 samplePairColor(vec2 screenUv, vec4 sourceRect, vec4 targetRect) {
  int style = int(u_morphStyle + 0.5);

  vec4 movedRect = vec4(
    mix(sourceRect.xy, targetRect.xy, u_progress),
    mix(sourceRect.zw, targetRect.zw, u_progress)
  );

  // Hybrid adaptive spill for liquid style only.
  float spillEps = 0.0;
  if (style == 3) {
    float env = sin(clamp(u_progress, 0.0, 1.0) * 3.14159265359);
    spillEps = 0.014 * env;
  }
  vec4 membershipRect = vec4(
    movedRect.x - spillEps,
    movedRect.y - spillEps,
    movedRect.z + (2.0 * spillEps),
    movedRect.w + (2.0 * spillEps)
  );

  if (!isInsideRect(screenUv, membershipRect)) {
    return vec4(0.0);
  }

  float safeW = max(movedRect.z, 0.00001);
  float safeH = max(movedRect.w, 0.00001);
  vec2 localUv = vec2(
    (screenUv.x - movedRect.x) / safeW,
    (screenUv.y - movedRect.y) / safeH
  );
  localUv = warpLocalUvByStyle(localUv, u_progress, style);
  float styleAlpha = alphaMaskByStyle(localUv, u_progress, style);
  if (styleAlpha <= 0.001) {
    return vec4(0.0);
  }
  localUv = clamp(localUv, vec2(0.0), vec2(1.0));
  localUv.y = 1.0 - localUv.y;

  vec4 sourceColor = texture(uTexture, localUv);
  vec4 targetColor = texture(uTargetTexture, localUv);
  float t = mixFactorByStyle(clamp(u_progress, 0.0, 1.0), style);
  vec4 mixed = mix(sourceColor, targetColor, t);
  mixed.a *= styleAlpha;
  return mixed;
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
