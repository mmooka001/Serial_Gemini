#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 surfaceSize;
    float lensY;
    float lensHeight;
    float lensX;
    float lensWidth;
    float pixelSize;
    float presence;
    float darkMode;
    vec4 baseColor;
    float materialMix;
    float blurRadius;
    float glassDepth;
    float bevelWidth;
    float cornerRadius;
    float edgeStrength;
    float saturation;
    float brightness;
    float dispersion;
} ubuf;
layout(binding = 1) uniform sampler2D source;

float roundedBox(vec2 p, vec2 halfSize, float radius)
{
    vec2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// Straight edges have parallel normals; only corners turn along an arc.
vec2 roundedBoxNormal(vec2 p, vec2 halfSize, float radius)
{
    vec2 q = abs(p) - halfSize + radius;
    vec2 corner = max(q, vec2(0.0));
    if (dot(corner, corner) > 0.0001)
        return normalize(corner) * sign(p);
    return q.x > q.y ? vec2(sign(p.x), 0.0) : vec2(0.0, sign(p.y));
}

vec4 sampleBackdrop(vec2 uv)
{
    return texture(source, clamp(uv, vec2(0.0), vec2(1.0)));
}

vec3 frostedBackdrop(vec2 uv, float radius)
{
    if (radius < 0.1) {
        vec4 color = sampleBackdrop(uv);
        return color.rgb + ubuf.baseColor.rgb * (1.0 - color.a);
    }
    vec2 stepSize = vec2(radius) / max(ubuf.surfaceSize, vec2(1.0));
    vec4 sum = sampleBackdrop(uv) * 0.20;
    sum += sampleBackdrop(uv + vec2(stepSize.x, 0.0)) * 0.10;
    sum += sampleBackdrop(uv - vec2(stepSize.x, 0.0)) * 0.10;
    sum += sampleBackdrop(uv + vec2(0.0, stepSize.y)) * 0.10;
    sum += sampleBackdrop(uv - vec2(0.0, stepSize.y)) * 0.10;
    sum += sampleBackdrop(uv + stepSize * vec2(0.707, 0.707)) * 0.05;
    sum += sampleBackdrop(uv + stepSize * vec2(-0.707, 0.707)) * 0.05;
    sum += sampleBackdrop(uv + stepSize * vec2(0.707, -0.707)) * 0.05;
    sum += sampleBackdrop(uv - stepSize * vec2(0.707, 0.707)) * 0.05;
    sum += sampleBackdrop(uv + vec2(stepSize.x * 1.8, 0.0)) * 0.05;
    sum += sampleBackdrop(uv - vec2(stepSize.x * 1.8, 0.0)) * 0.05;
    sum += sampleBackdrop(uv + vec2(0.0, stepSize.y * 1.8)) * 0.05;
    sum += sampleBackdrop(uv - vec2(0.0, stepSize.y * 1.8)) * 0.05;
    return sum.rgb + ubuf.baseColor.rgb * (1.0 - sum.a);
}

void main()
{
    vec2 size = max(ubuf.surfaceSize, vec2(1.0));
    vec2 pixel = qt_TexCoord0 * size;
    vec2 halfSize = max(vec2(ubuf.lensWidth, ubuf.lensHeight) * 0.5, vec2(1.0));
    vec2 center = vec2(ubuf.lensX, ubuf.lensY) + halfSize;
    vec2 local = pixel - center;
    float radius = min(ubuf.cornerRadius, min(halfSize.x, halfSize.y));
    float sd = roundedBox(local, halfSize, radius);
    float aa = max(0.35, ubuf.pixelSize);
    float coverage = 1.0 - smoothstep(-aa * 0.5, aa * 0.5, sd);
    float shadowDistance = roundedBox(local - vec2(0.0, 2.0), halfSize, radius);
    float shadow = exp(-max(shadowDistance, 0.0) / 3.0)
                 * mix(0.10, 0.16, ubuf.darkMode) * ubuf.presence;
    if (coverage <= 0.0) {
        fragColor = vec4(0.0, 0.0, 0.0, shadow) * ubuf.qt_Opacity;
        return;
    }

    // A convex squircle profile is flat in the centre and steep only at the bezel.
    float bezel = min(ubuf.bevelWidth, min(halfSize.x, halfSize.y) * 0.65);
    float u = clamp(-sd / max(bezel, 0.5), 0.005, 1.0);
    float a = 1.0 - u;
    float profile = pow(max(1.0 - pow(a, 4.0), 0.0001), 0.25);
    float slope = 2.5 * pow(a, 3.0) / max(bezel * pow(profile, 3.0), 0.001);
    vec2 edgeNormal = roundedBoxNormal(local, halfSize, radius);
    vec3 normal = normalize(vec3(edgeNormal * slope, 1.0));
    const float ior = 1.46;
    vec3 ray = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / ior);
    vec2 displacement = ray.xy / max(-ray.z, 0.1) * (ubuf.glassDepth + 2.5 * profile);
    vec2 uv = (pixel + displacement * ubuf.presence) / size;

    vec3 backdrop = frostedBackdrop(uv, ubuf.blurRadius);
    // Separate colour channels only along the curved bezel, leaving the centre clear.
    float dispersionMask = (1.0 - smoothstep(0.0, 0.8, u)) * ubuf.edgeStrength;
    vec2 dispersion = edgeNormal * ubuf.dispersion * (0.65 + length(displacement) * 0.12)
                    * dispersionMask * ubuf.presence / size;
    vec4 redSample = sampleBackdrop(uv + dispersion);
    vec4 blueSample = sampleBackdrop(uv - dispersion);
    backdrop.r = mix(backdrop.r, redSample.r + ubuf.baseColor.r * (1.0 - redSample.a), dispersionMask);
    backdrop.b = mix(backdrop.b, blueSample.b + ubuf.baseColor.b * (1.0 - blueSample.a), dispersionMask);
    float luminance = dot(backdrop, vec3(0.2126, 0.7152, 0.0722));
    backdrop = mix(vec3(luminance), backdrop, ubuf.saturation) * ubuf.brightness;
    vec3 material = mix(backdrop, ubuf.baseColor.rgb, ubuf.materialMix);

    // Schlick reflectance and directional specular light replace a painted white outline.
    float f0 = pow((ior - 1.0) / (ior + 1.0), 2.0);
    float fresnel = f0 + (1.0 - f0) * pow(1.0 - normal.z, 5.0);
    vec3 viewDirection = vec3(0.0, 0.0, 1.0);
    vec3 lightDirection = normalize(vec3(-0.45, -0.75, 0.70));
    vec3 halfVector = normalize(lightDirection + viewDirection);
    float specular = pow(max(dot(normal, halfVector), 0.0), 64.0);
    float counterLight = pow(max(dot(normal, normalize(vec3(0.45, 0.8, 1.4))), 0.0), 90.0);
    float rimLight = pow(max(dot(edgeNormal, normalize(vec2(-0.5, -0.8))), 0.0), 3.0);
    vec3 reflection = mix(backdrop, vec3(0.94, 0.97, 1.0), 0.85);
    material = mix(material, reflection, fresnel * (0.12 + 0.52 * rimLight));
    material += reflection * (specular * 0.46 + counterLight * 0.16);
    material += reflection * mix(0.010, 0.035, ubuf.darkMode) * (1.0 - ubuf.materialMix);

    float caustic = exp(-pow((sd + bezel * 0.78) / max(bezel * 0.30, 0.5), 2.0))
                  * max(dot(edgeNormal, normalize(vec2(0.25, 0.9))), 0.0);
    float innerShade = exp(-abs(sd + aa * 1.1) / max(aa, 0.5))
                     * max(dot(edgeNormal, normalize(vec2(0.6, 0.8))), 0.0);
    material += vec3(0.75, 0.86, 1.0) * caustic * 0.055;
    material *= 1.0 - innerShade * 0.075;

    // A fine contrast-reversing reflection follows the edge rather than painting a border.
    float edgeBand = exp(-pow((sd + 0.65) / 0.75, 2.0));
    float innerBand = exp(-pow((sd + 1.9) / 0.8, 2.0));
    float direction = dot(edgeNormal, normalize(vec2(-0.55, -0.85)));
    float contrast = 1.0 - 2.0 * smoothstep(0.18, 0.78, luminance);
    material += vec3(contrast) * (edgeBand * (0.13 + 0.10 * abs(direction))
                              - innerBand * 0.045) * ubuf.edgeStrength;
    vec3 spectralReflection = direction > 0.0 ? vec3(-0.025, 0.012, 0.045)
                                             : vec3(0.045, 0.005, -0.025);
    material += spectralReflection * edgeBand * ubuf.edgeStrength;

    float alpha = coverage * ubuf.presence;
    fragColor = vec4(clamp(material, vec3(0.0), vec3(1.0)) * alpha,
                     alpha + shadow * (1.0 - alpha)) * ubuf.qt_Opacity;
}
