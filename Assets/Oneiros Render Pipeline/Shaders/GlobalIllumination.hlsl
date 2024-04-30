#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

TEXTURE2D(unity_Lightmap);
SAMPLER(samplerunity_Lightmap);
TEXTURE2D(unity_LightmapInd);
SAMPLER(samplerunity_LightmapInd);

struct GI
{
    float3 diffuse;
};

float3 SampleLightMap(float2 lightMapUV, float3 normal)
{
#if defined(LIGHTMAP_ON)
#if defined(DIRLIGHTMAP_COMBINED)
	return SampleDirectionalLightmap(TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap), 
        TEXTURE2D_ARGS(unity_LightmapInd, samplerunity_LightmapInd), 
        lightMapUV, 
        float4(1.0, 1.0, 0.0, 0.0),
        normal, 
        #if defined(UNITY_LIGHTMAP_FULL_HDR)
			false,
		#else
			true,
		#endif
        float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0)
    );
#else
    return SampleSingleLightmap(TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap), lightMapUV,
        float4(1.0, 1.0, 0.0, 0.0),
        #if defined(UNITY_LIGHTMAP_FULL_HDR)
			false,
		#else
			true,
		#endif
		float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0)
    );
#endif
#else
    return 0.0;
#endif
}

GI GetGI(float2 lightMapUV, float3 normal)
{
    GI gi;
    gi.diffuse = SampleLightMap(lightMapUV, normal);
    return gi;
}

#endif