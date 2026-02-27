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
uniform sampler2D u_texture0;
uniform sampler2D u_texture1;

#if __VERSION__ >= 300
out vec4 fragColor;
#define SM_TEXTURE texture
#define SM_OUT fragColor
#else
#define SM_TEXTURE texture2D
#define SM_OUT gl_FragColor
#endif

float getProgress() {
    float p = u_progress;
    if (p <= 0.0001)
        p = fract(u_time * 0.5); // Fast preview.
    return clamp(p, 0.0, 1.0);
}

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

    vec3 outColor = SM_TEXTURE(u_texture0, uv).rgb;
    vec3 inColor = SM_TEXTURE(u_texture1, uv).rgb;

    float amp = 0.07;
    float p = getProgress();
    float padded = p * (1.0 + 2.0 * amp) - amp;
    float macro = fbm3(vec2(uv.y * 3.0 * aspect, 4.2)) * amp;

    float boundary = padded + macro;
    float dist = uv.x - boundary;

    float micro = fbm3(vec2(uv.x * 18.0 * aspect, uv.y * 60.0));
    float eroded = dist + (micro * 0.020);

    float edgeW = max(px * 6.0, 0.0035);
    float featherW = max(px * 2.5, 0.0015);

    float incomingMask = 1.0 - smoothstep(-featherW, featherW, eroded);
    float bandMask = 1.0 - smoothstep(edgeW, edgeW + featherW, abs(eroded));

    vec3 paperBase = vec3(0.96, 0.94, 0.89);
    float grain = fbm3(vec2(uv.y * 140.0 * aspect, uv.x * 40.0));
    float speck = smoothstep(0.78, 0.98, fbm3(vec2(uv.x * 220.0 * aspect, uv.y * 220.0)));

    vec3 paperTex = paperBase + (grain - 0.5) * 0.08 + speck * vec3(0.02, 0.015, 0.01);

    float rag = smoothstep(0.25, 0.95, grain + micro * 0.6);
    float bandAlpha = clamp(bandMask * mix(0.65, 1.0, rag), 0.0, 1.0);

    float shadowW = max(px * 55.0, 0.02);
    float shadow = (1.0 - smoothstep(0.0, shadowW, max(dist, 0.0))) * 0.28;
    shadow *= (1.0 - incomingMask);

    float hiW = max(px * 24.0, 0.012);
    float highlight = (1.0 - smoothstep(0.0, hiW, abs(min(dist, 0.0)))) * 0.10;

    vec3 color = outColor;
    color *= 1.0 - shadow;
    color = mix(color, inColor, incomingMask);
    color += paperBase * highlight * incomingMask;
    color = mix(color, paperTex, bandAlpha);

    SM_OUT = vec4(clamp(color, 0.0, 1.0), 1.0);
}