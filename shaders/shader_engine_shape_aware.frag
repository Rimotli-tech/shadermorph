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

vec2 rectCenter(vec4 rect) {
  return rect.xy + (rect.zw * 0.5);
}

vec2 aspectPreservingUv(vec2 screenUv, vec4 movedRect, vec4 referenceRect) {
  vec2 movedCenter = rectCenter(movedRect);
  vec2 referenceSize = max(referenceRect.zw, vec2(0.00001));
  float referenceAspect = referenceSize.x / referenceSize.y;
  float movingMinSide = max(min(movedRect.z, movedRect.w), 0.00001);
  vec2 fittedSize;
  if (referenceAspect >= 1.0) {
    fittedSize = vec2(movingMinSide, movingMinSide / referenceAspect);
  } else {
    fittedSize = vec2(movingMinSide * referenceAspect, movingMinSide);
  }
  return ((screenUv - movedCenter) / fittedSize) + vec2(0.5);
}

float roundedRectSdf(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + vec2(radius);
  return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - (2.0 * f));
  float a = hash12(i);
  float b = hash12(i + vec2(1.0, 0.0));
  float c = hash12(i + vec2(0.0, 1.0));
  float d = hash12(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  mat2 rotate = mat2(0.80, -0.60, 0.60, 0.80);
  for (int i = 0; i < 4; i++) {
    value += amplitude * valueNoise(p);
    p = rotate * p * 2.03 + vec2(11.7, 3.9);
    amplitude *= 0.5;
  }
  return value;
}

float alphaAt(sampler2D tex, vec2 uv) {
  if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
    return 0.0;
  }
  return texture(tex, vec2(uv.x, 1.0 - uv.y)).a;
}

float sampledAlphaSdf(sampler2D tex, vec2 uv) {
  float centerAlpha = alphaAt(tex, uv);
  bool inside = centerAlpha >= 0.08;
  float nearest = 0.22;
  const vec2 dirs[12] = vec2[12](
    vec2(1.0, 0.0),
    vec2(-1.0, 0.0),
    vec2(0.0, 1.0),
    vec2(0.0, -1.0),
    vec2(0.7071, 0.7071),
    vec2(-0.7071, 0.7071),
    vec2(0.7071, -0.7071),
    vec2(-0.7071, -0.7071),
    vec2(0.9239, 0.3827),
    vec2(-0.9239, 0.3827),
    vec2(0.3827, -0.9239),
    vec2(-0.3827, -0.9239)
  );

  for (int ring = 1; ring <= 6; ring++) {
    float radius = float(ring) * 0.018;
    for (int i = 0; i < 12; i++) {
      float sampleAlpha = alphaAt(tex, uv + (dirs[i] * radius));
      bool sampleInside = sampleAlpha >= 0.08;
      if (sampleInside != inside) {
        nearest = min(nearest, radius);
      }
    }
  }

  float antiAliasBand = 0.018 * (1.0 - smoothstep(0.08, 0.75, centerAlpha));
  float field = nearest - antiAliasBand;
  return inside ? -field : field;
}

float shapeDataRadius(vec4 shapeData) {
  int shapeType = int(shapeData.x + 0.5);
  if (shapeType == 2 || shapeType == 3) {
    return 0.5;
  }
  return clamp(shapeData.y, 0.0, 0.5);
}

float geometricShapeSdf(vec2 localUv, vec4 shapeData) {
  vec2 p = (localUv * 2.0) - 1.0;
  float radius = shapeDataRadius(shapeData) * 2.0;
  return roundedRectSdf(p, vec2(1.0), radius) * 0.5;
}

float endpointField(
  sampler2D tex,
  vec2 localUv,
  vec4 shapeData
) {
  float alphaField = sampledAlphaSdf(tex, localUv);
  float shapeField = geometricShapeSdf(localUv, shapeData);
  float rectGuard = geometricShapeSdf(localUv, vec4(1.0, 0.02, 0.0, 0.0));
  float textureHasShape = smoothstep(0.03, 0.18, abs(alphaAt(tex, localUv) - 1.0));
  float field = mix(shapeField, alphaField, textureHasShape);

  // Texture captures can be fully opaque cards. Keep a stable geometric field
  // as a fallback, but never let sampled alpha spill past the moving bounds.
  return max(field, rectGuard);
}

vec2 flowWarp(vec2 uv, vec2 direction, float t, float strength) {
  float envelope = sin(clamp(t, 0.0, 1.0) * 3.14159265359);
  float n1 = fbm((uv * 5.0) + (direction * t * 1.7));
  float n2 = fbm((uv.yx * 5.0) - (direction.yx * t * 1.3) + vec2(4.2, 8.1));
  vec2 flow = vec2(n1 - 0.5, n2 - 0.5);
  return uv + ((flow + direction * 0.35) * strength * envelope);
}

float organicFieldOffset(vec2 uv, vec2 direction, float t, float pairSeed) {
  float envelope = sin(clamp(t, 0.0, 1.0) * 3.14159265359);
  float low = fbm((uv * 4.5) + (direction * t * 1.8) + pairSeed);
  float high = fbm((uv * 13.0) - (direction.yx * t * 2.4) + pairSeed * 1.7);
  float ridged = abs((low * 0.72 + high * 0.28) - 0.5) * 2.0;
  return (ridged - 0.5) * 0.040 * envelope;
}

vec4 samplePairColor(
  vec2 screenUv,
  vec4 sourceRect,
  vec4 targetRect,
  vec4 sourceShape,
  vec4 targetShape,
  float pairSeed
) {
  float t = ease(clamp(u_progress, 0.0, 1.0));
  float rawT = clamp(u_progress, 0.0, 1.0);
  vec4 movedRect = vec4(
    mix(sourceRect.xy, targetRect.xy, t),
    mix(sourceRect.zw, targetRect.zw, t)
  );

  float organicEnvelope = sin(rawT * 3.14159265359);
  vec4 fieldBounds = vec4(
    movedRect.x - (0.035 * organicEnvelope),
    movedRect.y - (0.035 * organicEnvelope),
    movedRect.z + (0.070 * organicEnvelope),
    movedRect.w + (0.070 * organicEnvelope)
  );
  if (!isInsideRect(screenUv, fieldBounds)) {
    return vec4(0.0);
  }

  float safeW = max(movedRect.z, 0.00001);
  float safeH = max(movedRect.w, 0.00001);
  vec2 localUv = vec2(
    (screenUv.x - movedRect.x) / safeW,
    (screenUv.y - movedRect.y) / safeH
  );

  vec2 sourceSampleUv = aspectPreservingUv(screenUv, movedRect, sourceRect);
  vec2 targetSampleUv = localUv;

  vec2 motion = rectCenter(targetRect) - rectCenter(sourceRect);
  vec2 direction = normalize(motion + vec2(0.0001, 0.0001));
  vec2 sourceFieldUv = flowWarp(sourceSampleUv, -direction, rawT, 0.055);
  vec2 targetFieldUv = flowWarp(targetSampleUv, direction, 1.0 - rawT, 0.040);

  float sourceField = endpointField(
    uTexture,
    sourceFieldUv,
    sourceShape
  );
  float targetField = endpointField(
    uTargetTexture,
    targetFieldUv,
    targetShape
  );
  float morphField = mix(sourceField, targetField, t);
  morphField += organicFieldOffset(localUv, direction, rawT, pairSeed);
  float silhouette = smoothstep(0.018, -0.018, morphField);

  float colorMix = smoothstep(0.18, 0.88, rawT);
  vec2 sourceColorUv = flowWarp(sourceSampleUv, -direction, rawT, 0.025);
  vec2 targetColorUv = flowWarp(targetSampleUv, direction, 1.0 - rawT, 0.018);
  vec4 sourceColor = texture(
    uTexture,
    vec2(clamp(sourceColorUv.x, 0.0, 1.0), 1.0 - clamp(sourceColorUv.y, 0.0, 1.0))
  );
  vec4 targetColor = texture(
    uTargetTexture,
    vec2(clamp(targetColorUv.x, 0.0, 1.0), 1.0 - clamp(targetColorUv.y, 0.0, 1.0))
  );
  vec4 mixed = mix(sourceColor, targetColor, colorMix);

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
    float pairSeed = float(i + 1) * 17.31;
    vec4 sampled = samplePairColor(
      screenUv,
      u_sourceRects[i],
      u_targetRects[i],
      u_sourceShapeData[i],
      u_targetShapeData[i],
      pairSeed
    );
    if (sampled.a > 0.0) {
      color = sampled;
      break;
    }
  }

  fragColor = color + protocolKeepAlive;
}
