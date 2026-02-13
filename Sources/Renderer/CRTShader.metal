#include <metal_stdlib>
using namespace metal;

struct CRTUniforms {
    float time;
    float curvature;
    float scanlineIntensity;
    float scanlineCount;
    float glowIntensity;
    float vignetteStrength;
    float flickerAmount;
    float brightness;
    float2 resolution;
    float greenTintR;
    float greenTintG;
    float greenTintB;
    float phosphorPersistence;
    float noiseAmount;
    float padding;
};

struct QuadVertex {
    float2 position;
    float2 texCoord;
};

struct CRTVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Simple hash for noise
float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Barrel distortion
float2 barrelDistort(float2 uv, float curvature) {
    float2 centered = uv * 2.0 - 1.0;
    float r2 = dot(centered, centered);
    float distortion = 1.0 + r2 * curvature + r2 * r2 * curvature * 0.5;
    centered *= distortion;
    return centered * 0.5 + 0.5;
}

vertex CRTVertexOut crt_vertex(uint vertexID [[vertex_id]],
                                constant QuadVertex *vertices [[buffer(0)]]) {
    CRTVertexOut out;
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.texCoord = vertices[vertexID].texCoord;
    return out;
}

fragment float4 crt_fragment(CRTVertexOut in [[stage_in]],
                              constant CRTUniforms &uniforms [[buffer(0)]],
                              texture2d<float> terminalTexture [[texture(0)]],
                              sampler texSampler [[sampler(0)]]) {
    float2 uv = in.texCoord;

    // Apply barrel distortion
    float2 distortedUV = barrelDistort(uv, uniforms.curvature);

    // Check bounds after distortion - outside the screen is black
    if (distortedUV.x < 0.0 || distortedUV.x > 1.0 ||
        distortedUV.y < 0.0 || distortedUV.y > 1.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    // Sample the terminal texture
    float4 color = terminalTexture.sample(texSampler, distortedUV);

    // Phosphor mask (RGB sub-pixel pattern)
    float2 pixelCoord = distortedUV * uniforms.resolution;
    float maskX = fmod(pixelCoord.x, 3.0);
    float3 phosphorMask;
    if (maskX < 1.0) {
        phosphorMask = float3(1.0, 0.5, 0.5);
    } else if (maskX < 2.0) {
        phosphorMask = float3(0.5, 1.0, 0.5);
    } else {
        phosphorMask = float3(0.5, 0.5, 1.0);
    }
    // Subtle phosphor mask effect
    color.rgb *= mix(float3(1.0), phosphorMask, 0.04);

    // Scanlines
    float scanline = sin(pixelCoord.y * M_PI_F * 2.0 / (uniforms.resolution.y / uniforms.scanlineCount)) * 0.5 + 0.5;
    scanline = mix(1.0, scanline, uniforms.scanlineIntensity);
    color.rgb *= scanline;

    // Green phosphor tint — preserve saturated source colors (warning/danger)
    float luminance = dot(color.rgb, float3(0.299, 0.587, 0.114));
    float3 greenTint = float3(uniforms.greenTintR, uniforms.greenTintG, uniforms.greenTintB);
    float3 tinted = luminance * greenTint;
    float maxC = max(color.r, max(color.g, color.b));
    float minC = min(color.r, min(color.g, color.b));
    float saturation = maxC > 0.001 ? (maxC - minC) / maxC : 0.0;
    color.rgb = mix(tinted, color.rgb, saturation);

    // Bloom/glow - sample nearby pixels and add
    float3 bloom = float3(0.0);
    float bloomRadius = uniforms.glowIntensity * 3.0;
    float2 texelSize = 1.0 / uniforms.resolution;
    for (int dx = -2; dx <= 2; dx++) {
        for (int dy = -2; dy <= 2; dy++) {
            if (dx == 0 && dy == 0) continue;
            float2 offset = float2(float(dx), float(dy)) * texelSize * bloomRadius;
            float4 s = terminalTexture.sample(texSampler, distortedUV + offset);
            // Preserve source color hue in bloom
            float sLum = dot(s.rgb, float3(0.299, 0.587, 0.114));
            float3 sTinted = sLum * greenTint;
            float sMax = max(s.r, max(s.g, s.b));
            float sMin = min(s.r, min(s.g, s.b));
            float sSat = sMax > 0.001 ? (sMax - sMin) / sMax : 0.0;
            bloom += mix(sTinted, s.rgb, sSat);
        }
    }
    bloom /= 24.0;
    color.rgb += bloom * uniforms.glowIntensity;

    // Vignette
    float2 vignetteUV = uv * 2.0 - 1.0;
    float vignette = 1.0 - dot(vignetteUV, vignetteUV) * uniforms.vignetteStrength;
    vignette = clamp(vignette, 0.0, 1.0);
    color.rgb *= vignette;

    // Temporal flicker
    float flicker = 1.0 + uniforms.flickerAmount * sin(uniforms.time * 60.0) * 0.02;
    color.rgb *= flicker;

    // Film noise
    float noise = hash(distortedUV * uniforms.resolution + uniforms.time * 1000.0);
    color.rgb += (noise - 0.5) * uniforms.noiseAmount * 0.02;

    // Overall brightness
    color.rgb *= uniforms.brightness;

    // Clamp
    color.rgb = clamp(color.rgb, float3(0.0), float3(1.0));
    color.a = 1.0;

    return color;
}
