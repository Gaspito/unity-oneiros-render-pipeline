Shader "LOCAL/RIG/PBR Opaque"
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
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
			Name "Main"
			Blend One Zero
			ZWrite On
			Tags {"LightMode"="Deferred Base"}

			HLSLPROGRAM
			#pragma vertex common_vert
			#pragma fragment common_frag_deferred
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile_instancing

			#define RIG_SHADER
			#define BINORMAL

			#include "GlobalIllumination.hlsl"
			#include "ShaderCore.hlsl"
			#include "CommonPasses.hlsl"
			/*
			FragmentInput vert(VertexInput i) {

				int blendIndices[4];
				float blendWeights[4];

				GetBlendValues(i.blendIndices, i.blendWeights, blendIndices, blendWeights);

				FragmentInput o;

				o.worldPosition = BlendPosition(i.position, blendIndices, blendWeights);

				o.normal = TransformNormalToWorld(i.normal);
				o.tangent = TransformNormalToWorld(i.tangent);
				o.binormal = cross(o.normal, o.tangent);
				o.uv = i.uv;

				#ifdef CUSTOM_GI_INCLUDED
				o.lightmapUv = i.lightmapUv * unity_LightmapST.xy + unity_LightmapST.zw;
				#endif

				#if defined(VS_POST_PROCESS)
				VS_POST_PROCESS(i, o)
				#endif

				o.clipPosition = TransformWorldToClip(o.worldPosition);
				return o;
			}

			sampler2D _MainTex;
			float4 _MainColor;

			sampler2D _BumpTex;

			float _Smoothness;
			float _Metallic;

			float4 _TransluencyColor;
			float _Density;

			FragmentOutput frag(FragmentInput i){
				FragmentOutput o;
				o.albedo = tex2D(_MainTex, i.uv) * _MainColor;
				if (o.albedo.a < 0.1) discard;
				o.position = i.worldPosition;
				
				float3 normalmap = tex2D(_BumpTex, i.uv).xyz;
				normalmap = normalmap * 2.0 - 1.0;
				float3 normal = normalmap.x * normalize(i.tangent)
					+ normalmap.y * normalize(i.binormal)
					+ normalmap.z * normalize(i.normal);
				o.normal = normalize(normal);

				o.reflections = float3(_Smoothness, _Metallic, 0);
				o.transluency = float4(_TransluencyColor.rgb, _Density);

				#ifdef CUSTOM_GI_INCLUDED
				GI gi = GetGI(i.lightmapUv);
				o.gi = float4(gi.diffuse + SampleLightProbe(i.normal), 1);
				#endif

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
			Tags {"LightMode"="Depth Only"}

			HLSLPROGRAM
			#pragma vertex common_vert
			#pragma fragment common_frag_depth

			#define RIG_SHADER

			#include "ShaderCore.hlsl"
			#include "CommonPasses.hlsl"
			/*
			struct Attributes
			{
				float4 position : POSITION;
				float2 uv : TEXCOORD0;
				int4 blendIndices : BLENDINDICES;
				float4 blendWeights : BLENDWEIGHTS;
			};

			struct Varyings
			{
				float2 uv : TEXCOORD0;
				float depth : TEXCOORD1;
				float4 clipPosition : SV_POSITION;
			};

			Varyings vert(Attributes i) {

				int blendIndices[4];
				float blendWeights[4];

				GetBlendValues(i.blendIndices, i.blendWeights, blendIndices, blendWeights);

				Varyings o;

				float3 worldPosition = BlendPosition(i.position, blendIndices, blendWeights);

				o.clipPosition = TransformWorldToClip(worldPosition);
				o.uv = i.uv;
				o.depth = distance(worldPosition, worldSpaceCameraPos);
				return o;
			}

			sampler2D _MainTex;

			float frag(Varyings i) : SV_TARGET{
				return i.depth;
			}
				*/
			ENDHLSL
        }

		Pass
		{
			Name "Shadow Caster"
			Blend One Zero
			ZWrite On
			Cull[_CullMode]
			Tags {"LightMode" = "Shadow Caster"}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#define RIG_SHADER
			#define BINORMAL

			#include "ShaderCore.hlsl"

			FragmentInput vert(VertexInput i) {
				FragmentInput o;
				int blendIndices[4];
				float blendWeights[4];
				GetBlendValues(i.blendIndices, i.blendWeights, blendIndices, blendWeights);
				o.worldPosition = BlendPosition(i.position, blendIndices, blendWeights);
				o.clipPosition = TransformWorldToClip(o.worldPosition);
				o.normal = TransformNormalToWorld(i.normal);
				o.uv = i.uv;
				return o;
			}

			float frag(FragmentInput i) : SV_TARGET {
				return distance(i.worldPosition, worldSpaceCameraPos) * 0.001;
			}

			ENDHLSL
		}

		//UsePass "SHADOWS/Casters/Opaque"
    }
}
