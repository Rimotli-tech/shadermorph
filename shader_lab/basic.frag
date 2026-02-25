#ifdef GL_ES
precision mediump float;
#endif

// Standard uniforms provided by glsl-canvas
uniform vec2 u_resolution;
uniform float u_time;

void main() {
    // Normalize coordinates (0.0 to 1.0)
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;

    // Output a color: Red relies on X, Green relies on Y, Blue pulses with Time
    gl_FragColor = vec4(uv.x, uv.y, abs(sin(u_time)), 1.0);
}