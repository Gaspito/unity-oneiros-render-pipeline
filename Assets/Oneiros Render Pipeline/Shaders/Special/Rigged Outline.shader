Shader "LOCAL/RIG/Outline"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_MainColor ("Tint", Color) = (1,1,1,1)
		_BumpTex("Normal", 2D) = "bump" {}
		_Smoothness ("Smoothness", range(0, 100)) = 10
		_Metallic ("Metallic", range(0, 1)) = 0
		_TransluencyColor("Transluency Color", Color) = (1,1,1,1)
		_Density("Density", range(0,20)) = 0
		_OutlineWidth ("Outline Width", range(0,10)) = 2
		_OutlineColor ("Outline Color", Color) = (0,0,0,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

		UsePass "LOCAL/RIG/PBR Opaque/Main"
        Pass
        {
			Name "Outline"
			Blend One Zero
			ZWrite On
			Cull Front
			Tags {"LightMode"="Deferred Add0" "Queue"="Geometry+10"}

			HLSLPROGRAM
			#pragma vertex common_vert
			#pragma fragment common_frag_deferred

			#define RIG_SHADER

			#include "../ShaderCore.hlsl"

			float _OutlineWidth;

			FragmentInput OnVertexProgram(VertexInput i, FragmentInput o)
			{
				float4 clipPos = TransformWorldToClip(o.worldPosition);
				float3 clipNormal = TransformWorldToClipNormal(o.normal);

				float2 offset = normalize(clipNormal.xy) * _OutlineWidth * clipPos.w * _InverseScreenSize * 2;
				clipPos.xy += offset;

				o.clipPosition = clipPos;

				return o;
			}

			#define CUSTOM_VS_PASS OnVertexProgram(i, o);

			#include "../CommonPasses.hlsl"

			/*
			FragmentInput vert(VertexInput i) {

				int blendIndices[4];
				float blendWeights[4];

				GetBlendValues(i.blendIndices, i.blendWeights, blendIndices, blendWeights);

				FragmentInput o;

				o.worldPosition = BlendPosition(i.position, blendIndices, blendWeights);
				o.normal = -TransformNormalToWorld(i.normal);
				o.uv = i.uv;

				#if defined(VS_POST_PROCESS)
				VS_POST_PROCESS(i, o)
				#endif

				float4 clipPos = TransformWorldToClip(o.worldPosition);
				float3 clipNormal = -TransformWorldToClipNormal(o.normal);

				float2 offset = normalize(clipNormal.xy) * _OutlineWidth * clipPos.w * _InverseScreenSize * 2;
				clipPos.xy += offset;

				o.clipPosition = clipPos;
				o.uv = i.uv;
				return o;
			}

			float4 _OutlineColor;

			FragmentOutput frag(FragmentInput i){
				FragmentOutput o;
				o.albedo = _OutlineColor;
				o.position = i.worldPosition;
				o.normal = -i.normal;
				o.reflections = float3(0, 0, 0);
				o.transluency = float4(0, 0, 0, 20);
				return o;
			}
			*/
			ENDHLSL
        }
		Pass
        {
			Name "Depth Only"
			Blend One Zero
			ZWrite On
			Cull Front
			Tags {"LightMode"="Depth Only" "Queue"="Geometry+10"}

			HLSLPROGRAM
			#define RIG_SHADER

			#include "../ShaderCore.hlsl"

			float _OutlineWidth;

			FragmentInput OnVertexProgram(VertexInput i, FragmentInput o)
			{
				float4 clipPos = TransformWorldToClip(o.worldPosition);
				float3 clipNormal = TransformWorldToClipNormal(o.normal);

				float2 offset = normalize(clipNormal.xy) * _OutlineWidth * clipPos.w * _InverseScreenSize * 2;
				clipPos.xy += offset;

				o.clipPosition = clipPos;

				return o;
			}

			#define CUSTOM_VS_PASS OnVertexProgram(i, o);

			#include "../CommonPasses.hlsl"
			#pragma vertex common_vert
			#pragma fragment common_frag_depth
			ENDHLSL
        }
		//UsePass "SHADOWS/Casters/Opaque"
    }
}
