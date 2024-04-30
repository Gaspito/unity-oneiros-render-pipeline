// import:
// #include ""
#if !defined( SHADER_CORE_LIB)
#define SHADER_CORE_LIB

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Matrices.hlsl"

CBUFFER_START(UnityPerDraw)
	float4x4 unity_ObjectToWorld;
	float4x4 unity_WorldToObject;

	//float4 unity_LODFade;
	#ifdef CUSTOM_GI_INCLUDED
	float4 unity_LightmapST;
	float4 unity_DynamicLightmapST;
	#endif
	#ifndef LIGHTMAP_ON
	float4 unity_SHAr;
	float4 unity_SHAg;
	float4 unity_SHAb;
	float4 unity_SHBr;
	float4 unity_SHBg;
	float4 unity_SHBb;
	float4 unity_SHC;
	#endif
CBUFFER_END

CBUFFER_START(UnityPerFrame)
	float4x4 unity_MatrixVP;
	float4 _ProjectionParams;
	float3 worldSpaceCameraPos;
	float2 _ScreenSize;
	float2 _InverseScreenSize;
	float _Time;
CBUFFER_END

#define UNITY_MATRIX_M unity_ObjectToWorld
#define UNITY_MATRIX_I_M unity_WorldToObject

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"


struct VertexInput {
	float3 position : POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
	#ifdef CUSTOM_GI_INCLUDED
	float2 lightmapUv : TEXCOORD1;
	#endif
	#if defined(RIG_SHADER)
	int4 blendIndices : BLENDINDICES;
	float4 blendWeights : BLENDWEIGHTS;
	#endif
	#if defined(BINORMAL)
	float3 tangent : TANGENT;
	#endif
	#if defined(VERTEX_COLOR)
	float3 color : COLOR;
	#endif
	
    float3 TransformObjectToWorld(float3 pos)
    {
        return mul(UNITY_MATRIX_M, float4(pos, 1.0)).xyz;
    }

	float3 TransformDirToWorld(float3 dir)
	{
		return mul(UNITY_MATRIX_M, float4(dir, 0.0)).xyz;
	}

	float3 TransformWorldToObject(float3 pos) {
		return mul(UNITY_MATRIX_I_M, float4(pos, 1.0)).xyz;
	}
};

struct FragmentInput {
	float4 clipPosition : SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
	float3 worldPosition : TEXCOORD1;
	float3 normal : NORMAL0;
	float2 uv : TEXCOORD0;
	#ifdef CUSTOM_GI_INCLUDED
	float2 lightmapUv : TEXCOORD2;
	#endif
	#if defined(BINORMAL)
	float3 binormal : TANGENT1;
	float3 tangent : TANGENT0;
	#endif
	#if defined(VERTEX_COLOR)
	float3 color : COLOR;
	#endif
	#ifdef CUSTOM_FRAGMENT_INPUT_DATA
	CUSTOM_FRAGMENT_INPUT_DATA
	#endif

	float3 TransformObjectToWorld(float3 pos)
    {
        return mul(UNITY_MATRIX_M, float4(pos, 1.0)).xyz;
    }

	float3 TransformWorldToObject(float3 pos) {
		return mul(UNITY_MATRIX_I_M, float4(pos, 1.0)).xyz;
	}
};

struct FragmentOutput {
	float4 albedo : SV_TARGET0;
	float3 position : SV_TARGET1;
	float3 normal : SV_TARGET2;
	float3 reflections : SV_TARGET3;
    float4 transluency : SV_TARGET4; // rgb: color, a: density
	#ifdef CUSTOM_GI_INCLUDED
    float4 gi : SV_TARGET5;
	#endif
	#if defined(PS_OUTPUT_DEPTH)
	float depth : SV_Depth;
	#endif
};

#if defined(RIG_SHADER)

struct Bone{
	float3 position;
	float4 rotation;
};

int _RigOffsetId;
StructuredBuffer<Bone> _RigPosesBuffer;
StructuredBuffer<Bone> _RigBonesBuffer;

float4x4 GetRigPoseMatrix(int id){
	Bone b = _RigPosesBuffer[id];
	float4x4 m = RotationMatrix(b.rotation);
	m = TranslateMatrix(m, b.position);
	return m;
}

float4x4 GetRigBoneMatrix(int id){
	Bone b = _RigBonesBuffer[id];
	float4x4 m = RotationMatrix(b.rotation);
	m = TranslateMatrix(m, b.position);
	return m;
}

#endif

float3 TransformObjectToWorld(float3 pos) {
    return mul(UNITY_MATRIX_M, float4(pos, 1.0)).xyz;
}

float3 TransformNormalToWorld(float3 pos) {
    return normalize(mul(UNITY_MATRIX_M, float4(pos, 0.0)).xyz);
}

float3 TransformWorldToObject(float3 pos) {
    return mul(UNITY_MATRIX_I_M, float4(pos, 1.0)).xyz;
}

float4 TransformWorldToClip(float3 pos) {
	return mul(unity_MatrixVP, float4(pos, 1.0));
}

float3 TransformWorldToClipNormal(float3 pos)
{
    return mul(unity_MatrixVP, float4(pos, 0.0)).xyz;
}

float SqrLength(float3 vect) {
	return vect.x * vect.x + vect.y * vect.y + vect.z * vect.z;
}

float SqrLength(float2 vect) {
	return vect.x * vect.x + vect.y * vect.y;
}

float3 GetCameraView(float3 p) {
	return normalize(p - worldSpaceCameraPos);
}

float2 GetScreenPos(float4 clipPos)
{
    return (clipPos.xy / clipPos.w * 0.5 + float2(0.5, 0.5)) * _ScreenSize;
}

float2 GetScreenPos(float3 worldPos)
{
	return GetScreenPos(TransformWorldToClip(worldPos));
}

float3 ProjectOnPlane(float3 vec, float3 normal)
{
    return vec - normal * dot(vec, normal);
}

float3 Project(float3 vec, float3 dir)
{
    float3 normalizedDir = normalize(dir);
    return normalizedDir * length(vec) * dot(normalize(vec), normalizedDir);
}

float RandomNoise(float seed) {
	return frac(sin(seed) * 43758.5453);
}

float RandomNoise(float2 seed) {
	return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
}

float RandomNoise(float3 seed) {
	return RandomNoise(float2(seed.x + seed.y * 1.7, seed.z + seed.x * 3.14 + seed.y * 1.17));
}

#ifdef CUSTOM_GI_INCLUDED
float3 SampleLightProbe(float3 normal)
{
#ifdef LIGHTMAP_ON
		return 0.0;
#else
    float4 coefficients[7];
    coefficients[0] = unity_SHAr;
    coefficients[1] = unity_SHAg;
    coefficients[2] = unity_SHAb;
    coefficients[3] = unity_SHBr;
    coefficients[4] = unity_SHBg;
    coefficients[5] = unity_SHBb;
    coefficients[6] = unity_SHC;
    return max(0.0, SampleSH9(coefficients, normal));
#endif
}
#endif

#if defined(RIG_SHADER)
void GetBlendValues(int4 blendIndices, float4 blendWeights, out int indices[4], out float weights[4]) {
		indices[0] = blendIndices.x;
		indices[1] = blendIndices.y;
		indices[2] = blendIndices.z;
		indices[3] = blendIndices.w;
		weights[0] = blendWeights.x;
		weights[1] = blendWeights.y;
		weights[2] = blendWeights.z;
		weights[3] = blendWeights.w;
}

float3 BlendPosition(float3 position, int indices[4], float weights[4]) {
	float3 finalPos = float3(0, 0, 0);

	for (int i = 0; i < 4; i++)
	{
		int boneId = indices[i] + _RigOffsetId;
		float boneWeight = weights[i];

		float3 localToBone = mul(GetRigPoseMatrix(boneId), float4(position, 1)).xyz * 100;
		float3 boneToWorld = mul(GetRigBoneMatrix(boneId), float4(localToBone, 1)).xyz;

		finalPos += boneToWorld * boneWeight;
	}

	return finalPos;
}
#endif

#endif