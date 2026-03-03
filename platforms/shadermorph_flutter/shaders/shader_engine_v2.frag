#version 460 core
#include <flutter/runtime_effect.glsl>

// Protocol-V2 uniforms (inactive asset for future controlled switch).
uniform vec2 u_resolution;
uniform float u_progress;
uniform float u_pairCount;
uniform float u_morphStyle;
uniform vec4 u_sourceRects[8];
uniform vec4 u_targetRects[8];

// Keep sampler declarations for compatibility with current host texture setup.
uniform sampler2D uTexture;
uniform sampler2D uTargetTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_resolution;
  uv = clamp(uv, vec2(0.0), vec2(1.0));

  // Inactive placeholder behavior: blend full-screen source/target by progress.
  // Segment 6 will enable controlled routing to a full V2 render path.
  vec4 sourceColor = texture(uTexture, vec2(uv.x, 1.0 - uv.y));
  vec4 targetColor = texture(uTargetTexture, vec2(uv.x, 1.0 - uv.y));
  fragColor = mix(sourceColor, targetColor, u_progress);
}
