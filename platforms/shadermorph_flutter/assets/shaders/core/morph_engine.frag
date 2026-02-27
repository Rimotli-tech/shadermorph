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

void main() {
  vec2 safeResolution = max(u_resolution, vec2(1.0));
  vec2 uv = clamp(gl_FragCoord.xy / safeResolution, vec2(0.0), vec2(1.0));
  float p = clamp(u_progress, 0.0, 1.0);
  int pairCount = int(clamp(u_pairCount, 0.0, 8.0));
  int morphStyle = int(floor(u_morphStyle + 0.5));

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
    vec4 bgFrom = SM_TEXTURE(u_texFrom, uv);
    vec4 bgTo = SM_TEXTURE(u_texTo, uv);
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
    vec2 jitter = (vec2(n, fract(n * 19.19)) - 0.5) * 0.012;
    fromUV += jitter;
    toUV += jitter;
  }

  fromUV = clamp(fromUV, vec2(0.0), vec2(1.0));
  toUV = clamp(toUV, vec2(0.0), vec2(1.0));

  vec4 cFrom = SM_TEXTURE(u_texFrom, fromUV);
  vec4 cTo = SM_TEXTURE(u_texTo, toUV);
  SM_OUT = mix(cFrom, cTo, p);
}
