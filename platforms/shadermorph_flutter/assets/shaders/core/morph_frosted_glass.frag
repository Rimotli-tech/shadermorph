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

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
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
    vec2 fragCoord = gl_FragCoord.xy;
    vec2 uv = fragCoord / res;

    float p = u_progress;
    if (p <= 0.0001) {
        p = fract(u_time * 0.3);
    }
    p = clamp(p, 0.0, 1.0);

    float frost = sin(p * 3.14159265);

    float n1 = noise(uv * 12.0);
    float n2 = noise(uv * 50.0);
    float angle = n1 * 6.2831853;
    vec2 dir = vec2(cos(angle), sin(angle));

    float blurInPixels = frost * 0.06 * res.x;
    vec2 jitter = dir * blurInPixels * (0.7 + 0.3 * n2);

    vec2 o1 = jitter;
    vec2 o2 = vec2(-jitter.y, jitter.x);
    vec2 o3 = -o1;
    vec2 o4 = -o2;

    vec2 uv0 = clamp((fragCoord + o1) / res, vec2(0.0), vec2(1.0));
    vec2 uv1 = clamp((fragCoord + o2) / res, vec2(0.0), vec2(1.0));
    vec2 uv2 = clamp((fragCoord + o3) / res, vec2(0.0), vec2(1.0));
    vec2 uv3 = clamp((fragCoord + o4) / res, vec2(0.0), vec2(1.0));

    vec3 c0 = (
        SM_TEXTURE(u_texture0, uv).rgb +
        SM_TEXTURE(u_texture0, uv0).rgb +
        SM_TEXTURE(u_texture0, uv1).rgb +
        SM_TEXTURE(u_texture0, uv2).rgb +
        SM_TEXTURE(u_texture0, uv3).rgb
    ) * 0.2;

    vec2 uv0b = clamp((fragCoord + o1 * 0.5) / res, vec2(0.0), vec2(1.0));
    vec2 uv1b = clamp((fragCoord + o2 * 0.5) / res, vec2(0.0), vec2(1.0));
    vec2 uv2b = clamp((fragCoord + o3 * 0.5) / res, vec2(0.0), vec2(1.0));
    vec2 uv3b = clamp((fragCoord + o4 * 0.5) / res, vec2(0.0), vec2(1.0));

    vec3 c1 = (
        SM_TEXTURE(u_texture1, uv).rgb +
        SM_TEXTURE(u_texture1, uv0b).rgb +
        SM_TEXTURE(u_texture1, uv1b).rgb +
        SM_TEXTURE(u_texture1, uv2b).rgb +
        SM_TEXTURE(u_texture1, uv3b).rgb
    ) * 0.2;

    vec3 color = mix(c0, c1, p);
    color += vec3(0.12 * frost);
    color += vec3((noise(uv * 300.0) - 0.5) * 0.08 * frost);

    SM_OUT = vec4(clamp(color, 0.0, 1.0), 1.0);
}