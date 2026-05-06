#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_progress;
uniform float u_pairCount;
uniform float u_morphStyle;
uniform vec4 u_sourceRects[8];
uniform vec4 u_targetRects[8];
uniform vec4 u_sourceShapeData[8];
uniform vec4 u_targetShapeData[8];
uniform sampler2D uTexture;
uniform sampler2D uTargetTexture;

out vec4 fragColor;

bool isInsideRect(vec2 uv, vec4 rect) {
  return uv.x >= rect.x &&
      uv.x <= rect.x + rect.z &&
      uv.y >= rect.y &&
      uv.y <= rect.y + rect.w;
}

float ease(float t) {
  return t * t * (3.0 - (2.0 * t));
}

float rectAspect(vec4 rect) {
  return max(rect.z, 0.00001) / max(rect.w, 0.00001);
}

vec2 aspectAwareLocalUv(
  vec2 localUv,
  vec4 sourceRect,
  vec4 targetRect,
  vec4 movedRect,
  float t
) {
  vec2 centered = (localUv * 2.0) - 1.0;
  float sourceAspect = rectAspect(sourceRect);
  float targetAspect = rectAspect(targetRect);
  float movedAspect = rectAspect(movedRect);
  float blendedAspect = mix(sourceAspect, targetAspect, t);
  float xScale = clamp(blendedAspect / movedAspect, 0.60, 1.70);
  float yScale = clamp(movedAspect / blendedAspect, 0.60, 1.70);
  centered = vec2(centered.x * xScale, centered.y * yScale);
  return (centered * 0.5) + 0.5;
}

float softRectEdge(vec2 localUv, vec4 movedRect) {
  float minDimPx = max(
    min(movedRect.z * u_resolution.x, movedRect.w * u_resolution.y),
    1.0
  );
  float featherUv = clamp(1.25 / minDimPx, 0.001, 0.035);
  vec2 edgeDist2 = min(localUv, vec2(1.0) - localUv);
  float edgeDist = min(edgeDist2.x, edgeDist2.y);
  return smoothstep(0.0, featherUv, edgeDist);
}

vec4 samplePairColor(vec2 screenUv, vec4 sourceRect, vec4 targetRect) {
  float t = ease(clamp(u_progress, 0.0, 1.0));
  vec4 movedRect = vec4(
    mix(sourceRect.xy, targetRect.xy, t),
    mix(sourceRect.zw, targetRect.zw, t)
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
  vec2 shapedUv = aspectAwareLocalUv(
    localUv,
    sourceRect,
    targetRect,
    movedRect,
    t
  );
  vec2 sampleUv = clamp(shapedUv, vec2(0.0), vec2(1.0));
  vec2 textureUv = vec2(sampleUv.x, 1.0 - sampleUv.y);

  vec4 sourceColor = texture(uTexture, textureUv);
  vec4 targetColor = texture(uTargetTexture, textureUv);
  vec4 mixed = mix(sourceColor, targetColor, t);

  float sourceMask = smoothstep(0.01, 0.18, sourceColor.a);
  float targetMask = smoothstep(0.01, 0.18, targetColor.a);
  float silhouette = mix(sourceMask, targetMask, t);
  silhouette *= softRectEdge(localUv, movedRect);

  mixed.a *= silhouette;
  if (mixed.a <= 0.001) {
    return vec4(0.0);
  }
  return mixed;
}

void main() {
  vec2 safeResolution = max(u_resolution, vec2(0.00001));
  vec2 screenUv = FlutterFragCoord().xy / safeResolution;
  vec4 color = vec4(0.0);
  vec4 protocolKeepAlive =
      (u_sourceShapeData[0] + u_targetShapeData[0]) * 0.0 +
      vec4(u_morphStyle * 0.0);

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

  fragColor = color + protocolKeepAlive;
}
