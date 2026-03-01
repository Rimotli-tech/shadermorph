#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uSourceRect;
uniform float uTime;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 screenCoord = FlutterFragCoord().xy;

  float wave = sin((screenCoord.y / uSourceRect.w) * 15.0 + uTime) * 10.0;

  vec2 shiftedCoord = vec2(screenCoord.x + wave, screenCoord.y);

  bool isInsideX = shiftedCoord.x >= uSourceRect.x && shiftedCoord.x <= uSourceRect.x + uSourceRect.z;
  bool isInsideY = shiftedCoord.y >= uSourceRect.y && shiftedCoord.y <= uSourceRect.y + uSourceRect.w;

  if (isInsideX && isInsideY) {
    vec2 uv = (shiftedCoord - uSourceRect.xy) / uSourceRect.zw;
    uv.y = 1.0 - uv.y;
    fragColor = texture(uTexture, uv);
  } else {
    fragColor = vec4(0.0);
  }
}