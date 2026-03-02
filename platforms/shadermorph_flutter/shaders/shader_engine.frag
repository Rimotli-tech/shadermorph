#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uSourceRect;
uniform vec4 uTargetRect;
uniform float uTime;
uniform float uProgress;
uniform sampler2D uTexture;
uniform sampler2D uTargetTexture;

out vec4 fragColor;

vec4 drawWobble(vec2 screenCoord, vec4 rect, sampler2D tex) {
  float wave = sin((screenCoord.y / rect.w) * 15.0 + uTime) * 10.0;
  vec2 shiftedCoord = vec2(screenCoord.x + wave, screenCoord.y);

  bool isInsideX = shiftedCoord.x >= rect.x && shiftedCoord.x <= rect.x + rect.z;
  bool isInsideY = shiftedCoord.y >= rect.y && shiftedCoord.y <= rect.y + rect.w;

  if (!isInsideX || !isInsideY) {
    return vec4(0.0, 0.0, 0.0, 0.0);
  }

  vec2 uv = (shiftedCoord - rect.xy) / rect.zw;
  uv.y = 1.0 - uv.y;
  return texture(tex, uv) * (1.0 - uProgress);
}

void main() {
  vec2 screenCoord = FlutterFragCoord().xy;
  vec4 sourceColor = drawWobble(screenCoord, uSourceRect, uTexture);
  vec4 targetColor = drawWobble(screenCoord, uTargetRect, uTargetTexture);

  fragColor = sourceColor;
  if (targetColor.a > 0.0) {
    fragColor = targetColor;
  }
}
