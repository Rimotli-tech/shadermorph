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

vec4 drawSourceMove(vec2 screenCoord) {
  vec2 movedOrigin = mix(uSourceRect.xy, uTargetRect.xy, uProgress);
  vec2 movedSize = mix(uSourceRect.zw, uTargetRect.zw, uProgress);
  vec4 movedRect = vec4(movedOrigin, movedSize);

  bool isInsideX = screenCoord.x >= movedRect.x && screenCoord.x <= movedRect.x + movedRect.z;
  bool isInsideY = screenCoord.y >= movedRect.y && screenCoord.y <= movedRect.y + movedRect.w;

  if (!isInsideX || !isInsideY) {
    return vec4(0.0, 0.0, 0.0, 0.0);
  }

  vec2 uv = (screenCoord - movedRect.xy) / movedRect.zw;
  uv.y = 1.0 - uv.y;
  vec4 sourceColor = texture(uTexture, uv);
  vec4 targetColor = texture(uTargetTexture, uv);
  return mix(sourceColor, targetColor, uProgress);
}

void main() {
  vec2 screenCoord = FlutterFragCoord().xy;
  vec4 sourceColor = drawSourceMove(screenCoord);
  fragColor = sourceColor;
}
