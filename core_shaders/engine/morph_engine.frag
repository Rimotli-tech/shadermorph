#ifdef GL_ES
precision mediump float;
precision mediump sampler2D;
#endif

uniform sampler2D u_texFrom;
uniform sampler2D u_texTo;

uniform vec2 u_resolution;
uniform float u_progress;
uniform float u_pairCount;
uniform float u_morphStyle;
uniform vec4 u_sourceRects[8];
uniform vec4 u_targetRects[8];
uniform float u_debugMode;
uniform float u_texFlipY;

#if __VERSION__ >= 300
out vec4 fragColor;
#define SM_TEXTURE texture
#define SM_OUT fragColor
#else
#define SM_TEXTURE texture2D
#define SM_OUT gl_FragColor
#endif

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

bool containsPoint(vec2 uv, vec4 rect) {
  vec2 minPt = rect.xy;
  vec2 maxPt = rect.xy + rect.zw;
  return uv.x >= minPt.x && uv.x <= maxPt.x && uv.y >= minPt.y && uv.y <= maxPt.y;
}

vec2 sampleUV(vec2 v) {
  return (u_texFlipY > 0.5) ? vec2(v.x, 1.0 - v.y) : v;
}

void main() {
  vec2 safeResolution = max(u_resolution, vec2(1.0));
  vec2 rawUV = gl_FragCoord.xy / safeResolution;
  vec2 uv = clamp(vec2(rawUV.x, 1.0 - rawUV.y), vec2(0.0), vec2(1.0));
  float p = clamp(u_progress, 0.0, 1.0);
  int pairCount = int(clamp(u_pairCount, 0.0, 8.0));
  int morphStyle = int(floor(u_morphStyle + 0.5));
  int debugMode = int(floor(u_debugMode + 0.5));

  if (debugMode == 9) {
    SM_OUT = vec4(rawUV.x, rawUV.y, 0.0, 1.0);
    return;
  }

  if (debugMode == 1) {
    SM_OUT = vec4(uv.x, uv.y, 0.0, 1.0);
    return;
  }

  if (debugMode == 4) {
    SM_OUT = SM_TEXTURE(u_texFrom, sampleUV(uv));
    return;
  }

  if (debugMode == 5) {
    SM_OUT = SM_TEXTURE(u_texFrom, sampleUV(uv));
    return;
  }

  if (debugMode == 2 || debugMode == 3) {
    float inCur = 0.0;
    float inSrc = 0.0;
    float inDst = 0.0;

    if (pairCount > 0) {
      vec4 src = u_sourceRects[0];
      vec4 dst = u_targetRects[0];
      vec4 cur = mix(src, dst, p);

      inCur = containsPoint(uv, cur) ? 1.0 : 0.0;
      inSrc = containsPoint(uv, src) ? 1.0 : 0.0;
      inDst = containsPoint(uv, dst) ? 1.0 : 0.0;
    }

    vec3 mask = vec3(inCur, inSrc, inDst);
    if (debugMode == 2) {
      SM_OUT = vec4(mask, 1.0);
      return;
    }

    vec3 base = vec3(uv.x, uv.y, 0.0);
    SM_OUT = vec4(mix(base, mask, 0.7), 1.0);
    return;
  }

  int activeIndex = -1;
  vec4 activeSource = vec4(0.0);
  vec4 activeTarget = vec4(0.0);
  vec4 activeCurrent = vec4(0.0);

  for (int i = 0; i < 8; i++) {
    if (i >= pairCount) {
      continue;
    }
    vec4 src = u_sourceRects[i];
    vec4 dst = u_targetRects[i];
    vec4 cur = mix(src, dst, p);
    if (containsPoint(uv, cur)) {
      activeIndex = i;
      activeSource = src;
      activeTarget = dst;
      activeCurrent = cur;
      break;
    }
  }

  if (activeIndex < 0) {
    vec2 uvSample = sampleUV(uv);
    vec4 bgFrom = SM_TEXTURE(u_texFrom, uvSample);
    vec4 bgTo = SM_TEXTURE(u_texTo, uvSample);
    SM_OUT = mix(bgFrom, bgTo, p);
    return;
  }

  vec2 safeSize = max(activeCurrent.zw, vec2(0.0001));
  vec2 localUV = (uv - activeCurrent.xy) / safeSize;
  localUV = clamp(localUV, vec2(0.0), vec2(1.0));

  vec2 fromUV = activeSource.xy + (localUV * activeSource.zw);
  vec2 toUV = activeTarget.xy + (localUV * activeTarget.zw);

  if (morphStyle == 1) {
    float n = hash12(floor(gl_FragCoord.xy) + float(activeIndex) * 17.0);
    vec2 jitterScale = vec2(8.0) / safeResolution;
    vec2 jitter = (vec2(n, fract(n * 19.19)) - 0.5) * jitterScale;
    fromUV += jitter;
    toUV += jitter;
  }

  fromUV = clamp(fromUV, vec2(0.0), vec2(1.0));
  toUV = clamp(toUV, vec2(0.0), vec2(1.0));

  vec4 cFrom = SM_TEXTURE(u_texFrom, sampleUV(fromUV));
  vec4 cTo = SM_TEXTURE(u_texTo, sampleUV(toUV));
  SM_OUT = mix(cFrom, cTo, p);
}
