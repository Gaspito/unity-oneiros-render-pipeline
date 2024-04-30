Shader "LOCAL/PBR Opaque"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_MainColor ("Tint", Color) = (1,1,1,1)
		[NoScaleOffset]_BumpTex("Normal", 2D) = "bump" {}
		[Space(50)][Header(Roughness)][Toggle(ROUGHNESS_MAP)] _Has_Rougness_Maps("Use Textures for Roughness ?", float) = 0
		_RoughnessTex("Roughness", 2D) = "gray" {}
		_Smoothness("Smoothness", range(0, 100)) = 10
		_Metallic("Metallic", range(0, 1)) = 0
		[Space(50)][Header(Transluency)][Toggle(TRANSLUCENT)] _Is_Translucent("Is the material translucent?", float) = 0
		[NoScaleOffset]_TransluencyTex("Transluency Texture", 2D) = "white" {}
		_TransluencyColor ("Transluency Color", Color) = (1,1,1,1)
		_Density("Density", range(0,20)) = 0

		[Space(50)][Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Int) = 0
		[Space(50)][NoScaleOffset]_DitherTex("Dither", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
			Name "Main"
			Blend One Zero
			ZWrite Off
			ZTest LEqual
			Cull [_CullMode]
			Tags {"LightMode"="Deferred Base"}

			HLSLPROGRAM
			#pragma vertex common_vert
			#pragma fragment common_frag_deferred
			#pragma shader_feature TRANSLUCENT
			#pragma shader_feature ROUGHNESS_MAP
			#pragma multi_compile _ LIGHTMAP_ON DIRLIGHTMAP_COMBINED 
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED 
			#pragma multi_compile_instancing

			#define BINORMAL
			#define DITHER

			#include "GlobalIllumination.hlsl"
			#include "ShaderCore.hlsl"

			#include "CommonPasses.hlsl"

			/*
			FragmentInput vert(VertexInput i) {
				FragmentInput o;
				o.worldPosition = TransformObjectToWorld(i.position);
				o.clipPosition = TransformWorldToClip(o.worldPosition);
				o.normal = TransformNormalToWorld(i.normal);
				//o.binormal = TransformNormalToWorld(i.binormal);
				o.tangent = TransformNormalToWorld(i.tangent);
				o.binormal = cross(o.normal, o.tangent);
				o.uv = i.uv;
				#ifdef CUSTOM_GI_INCLUDED
				o.lightmapUv = i.lightmapUv * unity_LightmapST.xy + unity_LightmapST.zw;
				#endif
				return o;
			}

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainColor;

			sampler2D _BumpTex;

			float _Smoothness;
			float _Metallic;

			#if defined(TRANSLUCENT)
			sampler2D _TransluencyTex;
			float4 _TransluencyColor;
			float _Density;
			#endif

			sampler2D _DitherTex;

			bool Dither(float alpha, float2 screenPos) {
				return (tex2Dlod(_DitherTex, float4(screenPos, 0, 0)).r > alpha);
			}

			FragmentOutput frag(FragmentInput i){
				FragmentOutput o;
				i.uv = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
				o.albedo = tex2D(_MainTex, i.uv) * _MainColor;
				if (Dither(o.albedo.a, GetScreenPos(i.clipPosition))) discard;
				o.position = i.worldPosition;

				float3 normalmap = tex2D(_BumpTex, i.uv).xyz;
				normalmap = normalmap * 2.0 - 1.0;
				float3 normal = normalmap.x * normalize(i.tangent)
					+ normalmap.y * normalize(i.binormal)
					+ normalmap.z * normalize(i.normal);
				o.normal = normalize(normal); 

				o.reflections = float3(_Smoothness, _Metallic, 0);

				#if defined(TRANSLUCENT)
				o.transluency = float4(_TransluencyColor.rgb * tex2D(_TransluencyTex, i.uv).rgb, _Density);
				#else
				o.transluency = float4(0, 0, 0, 20);
				#endif

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
			Cull[_CullMode]
			Tags {"LightMode" = "Depth Only"}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment common_frag_depth

			#define DITHER

			#include "ShaderCore.hlsl"
			#include "CommonPasses.hlsl"

			FragmentInput vert(VertexInput i) {
				FragmentInput o;
				o.worldPosition = TransformObjectToWorld(i.position);
				o.clipPosition = TransformWorldToClip(o.worldPosition);
				o.normal = TransformNormalToWorld(i.normal);
				o.uv = i.uv;
				return o;
			}

			void frag(FragmentInput i) {
				return ;
			}

			ENDHLSL
		}

		Pass
		{
			Name "Lightmapping"
			
			Cull Off

			Tags {"LightMode" = "Meta"}

			HLSLPROGRAM
			#pragma vertex vert_meta
			#pragma fragment frag_meta2
			#pragma shader_feature _EMISSION
			#pragma shader_feature _METALLICGLOSSMAP
			#pragma shader_feature ___ _DETAIL_MULX2

			//#include "ShaderCore.hlsl"
			#include "UnityStandardMeta.cginc"

			//sampler2D _MainTex;
			//float4 _MainTex_ST;

			float4 _MainColor;

			float4 frag_meta2(v2f_meta i) : SV_Target
			{
				// we're interested in diffuse & specular colors,
				// and surface roughness to produce final albedo.
				FragmentCommonData data = UNITY_SETUP_BRDF_INPUT(i.uv);

				UnityMetaInput o;
				UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);

				o.Albedo = float3(_MainColor.rgb * tex2D(_MainTex, i.uv.xy).rgb);
				o.Emission = float3(0, 0, 0);

				return UnityMetaFragment(o);
			}

			ENDHLSL
		}

		UsePass "Hidden/Opaque Back Depth/Main"
		
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

			#include "ShaderCore.hlsl"

			FragmentInput vert(VertexInput i) {
				FragmentInput o;
				o.worldPosition = TransformObjectToWorld(i.position);
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
    }
}
