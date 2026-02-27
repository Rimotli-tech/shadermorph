#ifdef GL_ES
precision highp float;
#endif

uniform float u_progress;
uniform vec2 u_resolution;
uniform float u_time;

// --- Helper: Procedural Patterns (So we can sample them multiple times) ---
vec3 getOutgoing(vec2 uv, float aspect) {
    float grid = smoothstep(0.35, 0.37, fract(uv.x * 10.0)) * smoothstep(0.35, 0.37, fract(uv.y * 10.0 * aspect));
    return mix(vec3(0.08, 0.12, 0.22), vec3(0.15, 0.22, 0.38), grid);
}

vec3 getIncoming(vec2 uv, float aspect) {
    float stripes = smoothstep(0.4, 0.45, sin(uv.y * 30.0 + uv.x * 15.0));
    return mix(vec3(0.85, 0.45, 0.15), vec3(1.0, 0.65, 0.3), stripes);
}

// --- Noise Stack ---
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = gl_FragCoord.xy / res;
    float aspect = res.x / res.y;

    // 1. Progress & Frost Amount
    float p = u_progress;
    // Auto-animate if you aren't touching the slider
    if (p <= 0.0)
        p = fract(u_time * 0.3);

    // Frost peaks at 0.5 progress
    float frost = sin(p * 3.14159); 

    // 2. Jitter Math
    float n1 = noise(uv * 12.0);
    float n2 = noise(uv * 50.0);
    float angle = n1 * 6.2831;
    vec2 dir = vec2(cos(angle), sin(angle));

    // Blur radius (High value to make the frost OBVIOUS)
    float blur = frost * 0.06;
    vec2 jitter = dir * blur * (0.7 + 0.3 * n2);

    // Diamond offset pattern
    vec2 o1 = jitter;
    vec2 o2 = vec2(-jitter.y, jitter.x);
    vec2 o3 = -o1;
    vec2 o4 = -o2;

    // 3. MULTI-TAP PROCEDURAL SAMPLING
    // We sample our pattern functions 5 times to create the "Scattered" look
    vec3 c0 = (getOutgoing(uv, aspect) +
        getOutgoing(uv + o1, aspect) +
        getOutgoing(uv + o2, aspect) +
        getOutgoing(uv + o3, aspect) +
        getOutgoing(uv + o4, aspect)) / 5.0;

    vec3 c1 = (getIncoming(uv, aspect) +
        getIncoming(uv + o1 * 0.5, aspect) +
        getIncoming(uv + o2 * 0.5, aspect) +
        getIncoming(uv + o3 * 0.5, aspect) +
        getIncoming(uv + o4 * 0.5, aspect)) / 5.0;

    // 4. Composition
    vec3 color = mix(c0, c1, p);

    // Add "Glass Veil" (Milky lift)
    color += vec3(0.12) * frost;

    // Add "Tactile Grain"
    color += (noise(uv * 300.0) - 0.5) * 0.08 * frost;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}