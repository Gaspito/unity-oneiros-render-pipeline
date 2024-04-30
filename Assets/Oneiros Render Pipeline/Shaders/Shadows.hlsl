#ifndef ONEIROS_SHADOWS_INCLUDED
#define ONEIROS_SHADOWS_INCLUDED

struct ShadowRenderer {
	int type;
	float4x4 viewProjectionMatrix;
	float bias;
	int visibleId;
};

StructuredBuffer<ShadowRenderer> shadowMatrices;
int shadowCount = 0;

#define SHADOW_COUNT_LIMIT 8
TEXTURE2D_ARRAY(shadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp
SAMPLER(SHADOW_SAMPLER);
//float4x4 shadowMatrices[SHADOW_COUNT_LIMIT];
#define SHADOW_BIAS 0.01

float SampleDirectionalShadowAtlas(int shadowId, float3 position) {
	if (shadowId >= shadowCount) return 1.0;

	float3 positionSTS = mul(
		shadowMatrices[shadowId].viewProjectionMatrix,
		float4(position, 1)
	).xyz;

	if (positionSTS.x < 0.0 || positionSTS.x > 1.0 
		|| positionSTS.y < 0.0 || positionSTS.y > 1.0 
		|| positionSTS.z < 0.0 || positionSTS.z > 1.0) return 1.0;

	float bias = shadowMatrices[shadowId].bias;
	
	float shadow = shadowAtlas.Sample(SHADOW_SAMPLER, float3(positionSTS.xy, shadowId)).r;
	float cmp = shadow - bias < positionSTS.z + bias;
	return cmp;
}

#endif