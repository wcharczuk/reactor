#include <metal_stdlib>
using namespace metal;

struct SceneVertex {
    float3 position;
    float3 normal;
    float2 texCoord;
};

struct SceneUniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 normalMatrix;
    float3 lightPosition;
    float ambientIntensity;
    float3 lightColor;
    float diffuseIntensity;
    float3 cameraPosition;
    float specularIntensity;
    float specularPower;
    float padding1;
    float padding2;
    float padding3;
};

struct MaterialUniforms {
    float3 baseColor;
    float roughness;
    float metallic;
    float padding1;
    float padding2;
    float padding3;
};

struct SceneVertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float2 texCoord;
};

// ---- Monitor body shaders (beige plastic) ----

vertex SceneVertexOut scene_vertex(uint vertexID [[vertex_id]],
                                    constant SceneVertex *vertices [[buffer(0)]],
                                    constant SceneUniforms &uniforms [[buffer(1)]]) {
    SceneVertexOut out;
    float4 worldPos = uniforms.modelMatrix * float4(vertices[vertexID].position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    out.worldNormal = (uniforms.normalMatrix * float4(vertices[vertexID].normal, 0.0)).xyz;
    out.texCoord = vertices[vertexID].texCoord;
    return out;
}

fragment float4 scene_fragment(SceneVertexOut in [[stage_in]],
                                constant SceneUniforms &uniforms [[buffer(0)]],
                                constant MaterialUniforms &material [[buffer(1)]]) {
    float3 N = normalize(in.worldNormal);
    float3 L = normalize(uniforms.lightPosition - in.worldPosition);
    float3 V = normalize(uniforms.cameraPosition - in.worldPosition);
    float3 H = normalize(L + V);

    // Ambient
    float3 ambient = material.baseColor * uniforms.ambientIntensity;

    // Diffuse (Lambertian)
    float NdotL = max(dot(N, L), 0.0);
    float3 diffuse = material.baseColor * uniforms.lightColor * NdotL * uniforms.diffuseIntensity;

    // Specular (Blinn-Phong)
    float NdotH = max(dot(N, H), 0.0);
    float spec = pow(NdotH, uniforms.specularPower);
    float3 specular = uniforms.lightColor * spec * uniforms.specularIntensity * (1.0 - material.roughness);

    float3 finalColor = ambient + diffuse + specular;
    return float4(clamp(finalColor, float3(0.0), float3(1.0)), 1.0);
}

// ---- Screen face shader (uses CRT texture) ----

fragment float4 screen_fragment(SceneVertexOut in [[stage_in]],
                                 constant SceneUniforms &uniforms [[buffer(0)]],
                                 texture2d<float> screenTexture [[texture(0)]],
                                 sampler texSampler [[sampler(0)]]) {
    // The screen face just shows the CRT-processed texture
    // Add slight emissive glow effect - screen is self-illuminating
    float4 texColor = screenTexture.sample(texSampler, in.texCoord);

    // Screen emits light, so it's mostly emissive with slight ambient contribution
    float3 emissive = texColor.rgb * 1.2;

    // Slight Fresnel darkening at edges for glass effect
    float3 N = normalize(in.worldNormal);
    float3 V = normalize(uniforms.cameraPosition - in.worldPosition);
    float fresnel = pow(1.0 - max(dot(N, V), 0.0), 3.0);
    float3 reflection = float3(0.02) * fresnel;

    float3 finalColor = emissive + reflection;
    return float4(clamp(finalColor, float3(0.0), float3(1.0)), 1.0);
}

// ---- Fullscreen quad for intermediate passes ----

struct FullscreenVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex FullscreenVertexOut fullscreen_vertex(uint vertexID [[vertex_id]]) {
    // Generate a fullscreen triangle (3 vertices covering the screen)
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    float2 texCoords[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0)
    };

    FullscreenVertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}
