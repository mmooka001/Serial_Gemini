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
    float magnification;
    float glassStrength;
} ubuf;
layout(binding = 1) uniform sampler2D source;

float roundedBox(vec2 p, vec2 halfSize, float radius)
{
    vec2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

vec4 over(vec4 foreground, vec4 background)
{
    return foreground + background * (1.0 - foreground.a);
}

void main()
{
    vec2 size = ubuf.surfaceSize;
    vec2 pixel = qt_TexCoord0 * size;
    vec2 center = vec2(ubuf.lensX + ubuf.lensWidth * 0.5,
                       ubuf.lensY + ubuf.lensHeight * 0.5);
    vec2 halfSize = vec2(ubuf.lensWidth, ubuf.lensHeight) * 0.5;
    vec2 local = pixel - center;
    float radius = 14.0;
    float distanceToLens = roundedBox(local, halfSize, radius);
    float pixelWidth = ubuf.pixelSize;
    float coverage = 1.0 - smoothstep(-0.5 * pixelWidth, 0.5 * pixelWidth, distanceToLens);

    // 静态左上光源；阴影只跟随选框移动。
    float shadowDistance = roundedBox(local - vec2(0.0, 1.5), halfSize, radius);
    float shadow = exp(-max(shadowDistance, 0.0) / 2.0) * 0.10;
    vec4 original = texture(source, qt_TexCoord0);
    vec4 outside = over(original, vec4(0.0, 0.0, 0.0, shadow * ubuf.presence));

    // 边缘位移按三次方衰减，中心保持清晰；RGB 分别采样产生细微色散。
    vec2 normal = normalize(local + vec2(0.001));
    float rim = pow(clamp(1.0 + distanceToLens / 7.0, 0.0, 1.0), 3.0);
    vec2 samplePixel = center + local / ubuf.magnification - normal * rim * 1.5;
    vec2 uv = clamp(samplePixel / size, vec2(0.0), vec2(1.0));
    vec2 dispersion = normal * rim * 0.25 / size;
    vec4 red = texture(source, clamp(uv + dispersion, vec2(0.0), vec2(1.0)));
    vec4 green = texture(source, uv);
    vec4 blue = texture(source, clamp(uv - dispersion, vec2(0.0), vec2(1.0)));
    vec4 content = vec4(red.r, green.g, blue.b, max(red.a, max(green.a, blue.a)));

    float vertical = clamp(local.y / halfSize.y * 0.5 + 0.5, 0.0, 1.0);
    float sheen = exp(-dot((local / halfSize - vec2(-0.35, -0.55))
                         * vec2(1.7, 2.8),
                         (local / halfSize - vec2(-0.35, -0.55))
                         * vec2(1.7, 2.8)));
    float glassAlpha = (mix(0.065, 0.018, vertical) + sheen * 0.07) * ubuf.glassStrength;
    vec3 glassTint = mix(vec3(0.60, 0.67, 0.76), vec3(0.90, 0.94, 1.0), ubuf.darkMode);
    vec4 glass = vec4(glassTint * glassAlpha, glassAlpha);
    vec4 inside = over(content, glass);

    // 高光仅占一个物理像素内，沿光照方向衰减，不绘制整圈白描边。
    float lowerShade = exp(-abs(distanceToLens + 1.2) / 1.0) * vertical * 0.06;
    inside = over(vec4(0.0, 0.0, 0.0, lowerShade), inside);
    float edge = exp(-pow((distanceToLens + 0.45 * pixelWidth) / (0.38 * pixelWidth), 2.0));
    float lighting = clamp(dot(normal, normalize(vec2(-0.6, -0.8))) * 0.5 + 0.5, 0.0, 1.0);
    float edgeAlpha = edge * (0.025 + 0.21 * pow(lighting, 4.0));
    inside = over(vec4(vec3(0.91, 0.96, 1.0) * edgeAlpha, edgeAlpha), inside);

    fragColor = mix(outside, inside, coverage * ubuf.presence) * ubuf.qt_Opacity;
}
