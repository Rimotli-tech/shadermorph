#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform sampler2D uTexture; // The slot for our snapshot

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  vec4 texColor = texture(uTexture, uv);

  fragColor = texColor;
}