#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Vertex data for 3D scene
struct SceneVertex {
    simd_float3 position;
    simd_float3 normal;
    simd_float2 texCoord;
};

// Uniforms for 3D scene rendering
struct SceneUniforms {
    simd_float4x4 modelMatrix;
    simd_float4x4 viewMatrix;
    simd_float4x4 projectionMatrix;
    simd_float4x4 normalMatrix;
    simd_float3 lightPosition;
    float ambientIntensity;
    simd_float3 lightColor;
    float diffuseIntensity;
    simd_float3 cameraPosition;
    float specularIntensity;
    float specularPower;
    float padding1;
    float padding2;
    float padding3;
};

// Uniforms for CRT post-processing
struct CRTUniforms {
    float time;
    float curvature;          // barrel distortion amount (~0.02)
    float scanlineIntensity;  // 0-1
    float scanlineCount;      // number of scanlines
    float glowIntensity;      // bloom/glow strength
    float vignetteStrength;   // edge darkening
    float flickerAmount;      // temporal flicker
    float brightness;         // overall brightness
    simd_float2 resolution;   // texture resolution
    float greenTintR;         // green phosphor tint R (~0.1)
    float greenTintG;         // green phosphor tint G (~1.0)
    float greenTintB;         // green phosphor tint B (~0.1)
    float phosphorPersistence;
    float noiseAmount;
    float padding;
};

// Simple fullscreen quad vertex
struct QuadVertex {
    simd_float2 position;
    simd_float2 texCoord;
};

// Material properties for the monitor body
struct MaterialUniforms {
    simd_float3 baseColor;
    float roughness;
    float metallic;
    float padding1;
    float padding2;
    float padding3;
};

#endif
