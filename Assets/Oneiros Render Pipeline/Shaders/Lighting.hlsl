// import:
// #include ""
#if !defined( LIGHTING_LIB)
#define LIGHTING_LIB

#include "ShaderCore.hlsl"

Texture2D positionTarget;
Texture2D albedoTarget;
Texture2D normalTarget;
Texture2D reflectionTarget;
Texture2D transluencyTarget;
Texture2D globalIlluminationTarget;
Texture2D backdepthTarget;

#ifdef CUSTOM_GLOBAL_SAMPLER
SamplerState CUSTOM_GLOBAL_SAMPLER;
#else
SamplerState sampler_positionTarget;
#define CUSTOM_GLOBAL_SAMPLER sampler_positionTarget
#endif

#define SAMPLE_POSITION(uv) positionTarget.Sample(CUSTOM_GLOBAL_SAMPLER, uv).xyz
#define SAMPLE_ALPHA(uv) albedoTarget.Sample(CUSTOM_GLOBAL_SAMPLER, uv).a
#define SAMPLE_ALBEDO(uv) albedoTarget.Sample(CUSTOM_GLOBAL_SAMPLER, uv).rgb
#define SAMPLE_NORMAL(uv) normalTarget.Sample(CUSTOM_GLOBAL_SAMPLER, uv).xyz
#define SAMPLE_REFLECTION(uv) reflectionTarget.Sample(CUSTOM_GLOBAL_SAMPLER, uv).xyz
#define SAMPLE_TRANSLUENCY(uv) transluencyTarget.Sample(CUSTOM_GLOBAL_SAMPLER, uv)
#define SAMPLE_TEST_GI(uv) globalIlluminationTarget.Sample(CUSTOM_GLOBAL_SAMPLER, uv).a
#define SAMPLE_GI(uv) globalIlluminationTarget.Sample(CUSTOM_GLOBAL_SAMPLER, uv).rgb
#define SAMPLE_BACK_DEPTH(uv) backdepthTarget.Sample(CUSTOM_GLOBAL_SAMPLER, uv).x;

float ComputePixelDepth(float3 position, float backDepth)
{
    float frontDepth = distance(position, worldSpaceCameraPos);
    return backDepth - frontDepth;
}

float LambertDiffuse(float3 normal, float3 ldir) {
	float ndotl = dot(normal, normalize(-ldir));
	return clamp(ndotl, 0.0, 1.0);
}

float PhongSpecular(float3 normal, float3 ldir, float3 view, float smoothness) {
	float3 lreflect = reflect(ldir, normal);
	float rdotv = dot(normalize(-lreflect), view);
	return max(0.0, pow(clamp(rdotv, 0.0, 1.0), smoothness) * smoothness * 0.01);
}

float3 Transluency(float3 position, float backDepth, float3 normal, float3 ldir, float3 color, float density)
{
    if (density >= 20)
        return float3(0, 0, 0);
    /*
    float depth = ComputePixelDepth(position, backDepth);
    float tangentLight = clamp(dot(ldir, normal), 0.0, 1.0);
    float lightScatter = saturate(1.0 - depth * density) * tangentLight;
    return color * lightScatter;
    */
    
    float ndotl = dot(normal, normalize(ldir));
    float fresnel = 1.0 - abs(ndotl);
    fresnel = pow(fresnel, max(1, density));
    float intensity = (20 - density) * 0.05;
    
    return saturate(fresnel * color * intensity);
}

float2 WorldToScreenPos(float3 worldPos) {
    float4 clipPos = TransformWorldToClip(worldPos);
    float2 screenPos = clipPos.xy / clipPos.w * 0.5 + float2(0.5, 0.5);
    if (_ProjectionParams.x < 0) screenPos.y = 1.0 - screenPos.y;
    return screenPos;
}

#endif