//
//  Shaders.metal
//  HappyNY2025
//
//  Created by Aleksandr Strizhnev on 02.12.2024.
//

#include <metal_stdlib>

using namespace metal;

struct WindowUniforms {
    float2 position;
    float2 size;
    float fullscreen;
};

struct GlobalUniforms {
    float2 screenSize;
    float2 size;
};

struct RenderUniforms {
    float iTime;
    float bulbScale;
};

struct VertexOut {
    float4 position [[position]];
    float2 startPosition;
    float2 resolution;
    float fullscreen;
};

vertex VertexOut vertexFunction(
    uint vid [[vertex_id]],
    constant float2* vertices [[buffer(0)]],
    constant GlobalUniforms &globalUniforms [[buffer(1)]],
    constant WindowUniforms *windowUniforms [[buffer(2)]],
    uint instanceId [[ instance_id ]]
) {
    WindowUniforms windowUniform = windowUniforms[instanceId];
    
    VertexOut out;
    float2 vert = vertices[vid];
    out.startPosition = windowUniform.position / globalUniforms.screenSize * globalUniforms.size;
    out.resolution = windowUniform.size * globalUniforms.size / globalUniforms.screenSize;
    
    float2 position = windowUniform.position / globalUniforms.screenSize;
    position += vert * windowUniform.size / globalUniforms.screenSize;
    position = (position - 0.5) * 2.0;
    position.y = -position.y;
    
    out.position = float4(position, 0.0, 1.0);
    out.fullscreen = windowUniform.fullscreen;
    return out;
}

constant float spacing = 50.0;
constant float PI = 3.14159265359;

static float2 rotate2d(float2 uv, float rotation, float2 mid)
{
    float cosAngle = cos(rotation);
    float sinAngle = sin(rotation);

    return float2(
        cosAngle * (uv.x - mid.x) + sinAngle * (uv.y - mid.y) + mid.x,
        cosAngle * (uv.y - mid.y) - sinAngle * (uv.x - mid.x) + mid.y
    );
}

static float radians(float degrees)
{
    return degrees / 180.0 * PI;
}

static float smoothIndex(float index, RenderUniforms renderUniforms)
{
    return int(2 + index + renderUniforms.iTime * 0.5) % 2;
}

static float4 lightColor(float index, RenderUniforms renderUniforms)
{
    float4 enabledColor = float4(1.0, 0.9, 0.5, 1.0);
    float4 disabledColor = float4(0.4, 0.2, 0.1, 0.0);
    
    return mix(disabledColor, enabledColor, smoothIndex(index, renderUniforms));
}

static float lightFunc(float distance)
{
    float lightVal = (-distance / spacing);
    return exp(lightVal * 2.0) / 1.5;
}

float bulbRotation(float index, float count, RenderUniforms renderUniforms)
{
    return 15.0 * sin(index / count * 3.0 + renderUniforms.iTime * 1.5);
}

float4 sideLight(float shift, float index, float count, float2 uv, RenderUniforms renderUniforms, float2 iResolution) {
    float2 lightRadius = float2(8.0, 8.0) * renderUniforms.bulbScale;
    lightRadius.x /= iResolution.x / count;
    lightRadius.y /= iResolution.y;
    
    float2 bulbPosition = float2(0.5 + shift, 16.0 * renderUniforms.bulbScale / iResolution.y);
    float rotation = -bulbRotation(index + shift, count, renderUniforms);
    bulbPosition.y *= count / (iResolution.x / iResolution.y);
    bulbPosition = rotate2d(bulbPosition, radians(rotation), float2(0.5 + shift, 0));
    bulbPosition.y /= count / (iResolution.x / iResolution.y);
    
    float2 pos = uv - bulbPosition;
    float2 a = (pos * pos) / (lightRadius * lightRadius);
    float dist = a.x + a.y;
    
    return lightColor(index + shift, renderUniforms) * lightFunc(dist);
}

float windowSDF(float2 coord, float2 resolution, float fullscreen) {
    float radius = 24;
    
    return clamp(1 - (length(max(abs(coord - resolution / 2) - resolution / 2 + radius, 0.0)) - radius), fullscreen, 1.0);
}

fragment float4 decorationFragmentFunction(
    VertexOut in [[stage_in]],
    constant RenderUniforms &renderUniforms [[buffer(1)]]
) {
    float2 iResolution = in.resolution;
    float2 fragCoord = in.position.xy - in.startPosition;
    
    float count = floor(iResolution.x / (spacing * renderUniforms.bulbScale));
    float2 uv = fragCoord / iResolution.xy;
    
    uv.x = uv.x * count;
    float index = floor(uv.x);
    uv.x = fract(uv.x);
    
    float rotation = bulbRotation(index, count, renderUniforms);
    
    float2 st = uv;
    st.y *= count / (iResolution.x / iResolution.y);
    st = rotate2d(st, radians(rotation), float2(0.5, 0.0));
    st.y /= count / (iResolution.x / iResolution.y);
    
    float4 color = float4(0.0, 0.0, 0.0, 0.0);
    
    float2 bulbRadius = float2(8.0, 12.0) * renderUniforms.bulbScale;
    bulbRadius.x /= iResolution.x / count;
    bulbRadius.y /= iResolution.y;
    
    float2 bulbPosition = float2(0.5, 16.0 * renderUniforms.bulbScale / iResolution.y);
    
    float2 pos = st - bulbPosition;
    
    float2 a = (pos * pos) / (bulbRadius * bulbRadius);
    float dist = a.x + a.y;
    
    float4 outerColor = float4(1.0, 0.1, 0.1, 1.0);
    float4 innerColor = float4(1.0, 0.9, 0.5, 1.0);
    
    float4 enabledColor = mix(innerColor, outerColor, dist);
    float4 disabledColor = float4(0.3, 0.2, 0.2, 1.0);
    
    float4 bulbColor = mix(disabledColor, enabledColor, smoothIndex(index, renderUniforms));
    color += bulbColor * smoothstep(1.0, 0.7, dist);
    
    color += sideLight(0, index, count, uv, renderUniforms, iResolution);
    color += sideLight(-1, index, count, uv, renderUniforms, iResolution);
    color += sideLight(1, index, count, uv, renderUniforms, iResolution);
    color += sideLight(-2, index, count, uv, renderUniforms, iResolution);
    color += sideLight(2, index, count, uv, renderUniforms, iResolution);
    
    float2 wireSize = float2(4.0, 4.0) * renderUniforms.bulbScale;
    wireSize.x /= iResolution.x / count;
    wireSize.y /= iResolution.y;
    
    float2 wirePosition = float2(0.5, 3.0 * renderUniforms.bulbScale / iResolution.y);
    
    pos = st - wirePosition;
    a = (pos * pos) / (wireSize * wireSize);
    
    float4 wireColor = float4(0.0, 0.0, 0.0, 1.0);
    color -= float4(1.0, 1.0, 1.0, 0.0) * smoothstep(1.0, 0.7, a.x) * smoothstep(1.0, 0.7, a.y);
    color += wireColor * smoothstep(1.0, 0.7, a.x) * smoothstep(1.0, 0.7, a.y);
    
    return color * windowSDF(fragCoord, iResolution, in.fullscreen);
}
