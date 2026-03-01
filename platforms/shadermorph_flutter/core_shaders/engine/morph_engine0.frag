#version 460 core
#include <flutter/runtime_effect.glsl>

// This is Float Index 0 (x) and 1 (y)
uniform vec2 uSize;

out vec4 fragColor;

void main() {
    // Standard UV calculation
  vec2 uv = FlutterFragCoord().xy / uSize;

    // Output: Red = X, Green = Y, Blue = 0, Alpha = 1
  fragColor = vec4(uv.x, uv.y, 0.0, 1.0);
}