#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uSourceRect;
uniform float uTime;       // <--- ADD THIS
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 screenCoord = FlutterFragCoord().xy;

  bool isInsideX = screenCoord.x >= uSourceRect.x && screenCoord.x <= uSourceRect.x + uSourceRect.z;
  bool isInsideY = screenCoord.y >= uSourceRect.y && screenCoord.y <= uSourceRect.y + uSourceRect.w;

  if (isInsideX && isInsideY) {
    vec2 uv = (screenCoord - uSourceRect.xy) / uSourceRect.zw;
    uv.y = 1.0 - uv.y;

    uv.x += sin(uv.y * 15.0 + uTime) * 0.05;

    fragColor = texture(uTexture, uv);
  } else {
    fragColor = vec4(0.6745, 0.1647, 0.1647, 0.0);
  }
}