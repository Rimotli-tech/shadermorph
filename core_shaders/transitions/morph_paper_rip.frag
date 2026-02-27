#ifdef GL_ES
  #ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
  #else
precision mediump float;
  #endif
#else
precision highp float;
#endif

uniform float u_progress;
uniform vec2 u_resolution;
uniform float u_time;

float getProgress() {
    float p = u_progress;
    if (p <= 0.0001)
        p = fract(u_time * 0.5); // fast preview
    return clamp(p, 0.0, 1.0);
}

// Perlin-style gradient noise (smooth)
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float perlin(vec2 p) {
    vec2 pi = floor(p);
    vec2 pf = fract(p);
    vec2 w = pf * pf * (3.0 - 2.0 * pf);

    float a = dot(hash(pi + vec2(0.0, 0.0)), pf - vec2(0.0, 0.0));
    float b = dot(hash(pi + vec2(1.0, 0.0)), pf - vec2(1.0, 0.0));
    float c = dot(hash(pi + vec2(0.0, 1.0)), pf - vec2(0.0, 1.0));
    float d = dot(hash(pi + vec2(1.0, 1.0)), pf - vec2(1.0, 1.0));

    return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

float fbm3(vec2 p) {
    // unrolled 3 octaves
    float v = 0.0;
    v += 0.50 * perlin(p);
    v += 0.25 * perlin(p * 2.0);
    v += 0.125 * perlin(p * 4.0);
    return v;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = gl_FragCoord.xy / res;
    float aspect = res.x / max(res.y, 1.0);
    float px = 1.0 / res.x;

    // Two flat colors
    vec3 outColor = vec3(0.11, 0.15, 0.22); // outgoing (right)
    vec3 inColor = vec3(0.88, 0.52, 0.24); // incoming (left)

    // --- 1) Macro tear boundary (UV-based, resolution independent) ---
    float amp = 0.07;
    float p = getProgress();
    float padded = p * (1.0 + 2.0 * amp) - amp;

    // IMPORTANT: drive from uv.y, not uv.x, and keep the x component meaningful
    float macro = fbm3(vec2(uv.y * 3.0 * aspect, 4.2)) * amp;

    float boundary = padded + macro;
    float dist = uv.x - boundary;

    // --- 2) Micro erosion (this is what makes it “torn”, not “jagged line”) ---
    // Micro noise tied to both axes so it doesn't become horizontal brushing.
    float micro = fbm3(vec2(uv.x * 18.0 * aspect, uv.y * 60.0));
    float eroded = dist + (micro * 0.020); // erosion strength

    // --- 3) Masks: incoming side, paper band, outgoing side ---
    // These widths are in normalized units (resolution independent).
    float edgeW = max(px * 6.0, 0.0035);  // paper thickness band
    float featherW = max(px * 2.5, 0.0015);  // anti-alias / softness

    // Incoming fills left side (eroded edge)
    float incomingMask = 1.0 - smoothstep(-featherW, featherW, eroded);

    // Thin paper band ONLY around the edge (centered at eroded == 0)
    float bandMask = 1.0 - smoothstep(edgeW, edgeW + featherW, abs(eroded));

    // --- 4) Paper band texture (STRICTLY multiplied by bandMask) ---
    vec3 paperBase = vec3(0.96, 0.94, 0.89);

    // Fiber grain and specks: only meaningful inside band
    float grain = fbm3(vec2(uv.y * 140.0 * aspect, uv.x * 40.0));
    float speck = smoothstep(0.78, 0.98, fbm3(vec2(uv.x * 220.0 * aspect, uv.y * 220.0)));

    vec3 paperTex = paperBase + (grain - 0.5) * 0.08 + speck * vec3(0.02, 0.015, 0.01);

    // Make band alpha ragged (fibers)
    float rag = smoothstep(0.25, 0.95, grain + micro * 0.6);
    float bandAlpha = clamp(bandMask * mix(0.65, 1.0, rag), 0.0, 1.0);

    // --- 5) Shadow + highlight (depth cue) ---
    float shadowW = max(px * 55.0, 0.02);
    float shadow = (1.0 - smoothstep(0.0, shadowW, max(dist, 0.0))) * 0.28;
    // Keep shadow mostly on outgoing side
    shadow *= (1.0 - incomingMask);

    float hiW = max(px * 24.0, 0.012);
    float highlight = (1.0 - smoothstep(0.0, hiW, abs(min(dist, 0.0)))) * 0.10;

    // --- 6) Compose ---
    vec3 color = outColor;

    // Shadow on outgoing
    color *= 1.0 - shadow;

    // Incoming fill
    color = mix(color, inColor, incomingMask);

    // Subtle highlight on incoming near edge (helps “lift”)
    color += paperBase * highlight * incomingMask;

    // Paper band on top (only at edge)
    color = mix(color, paperTex, bandAlpha);

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}