Shader "LOCAL/Vegetation/PBR Vegetation"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_MainColor ("Tint", Color) = (1,1,1,1)
		[Space(50)][Header(Wind)]_WindSpeed ("Speed", float) = 1
		_WindJitter ("Jitter", float) = 1
		[NoScaleOffset]_BumpTex("Normal", 2D) = "bump" {}
		[Space(50)]_Smoothness("Smoothness", range(0, 100)) = 10
		_Metallic("Metallic", range(0, 1)) = 0
		[Space(50)][Header(Transluency)][Toggle(TRANSLUCENT)] _Is_Translucent("Is the material translucent?", float) = 0
		[NoScaleOffset]_TransluencyTex("Transluency Texture", 2D) = "white" {}
		_TransluencyColor ("Transluency Color", Color) = (1,1,1,1)
		_Density("Density", range(0,20)) = 0
		[Space(50)][NoScaleOffset]_DitherTex("Dither", 2D) = "black" {}
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
			Name "Main"
			Blend One Zero
			ZWrite Off
			ZTest LEqual
			Cull Off
			Tags {"LightMode" = "Deferred Base"}

			HLSLPROGRAM
			#pragma vertex common_vert
			#pragma fragment common_frag_deferred
			#pragma shader_feature TRANSLUCENT
			#pragma multi_compile _ LIGHTMAP_ON DIRLIGHTMAP_COMBINED 
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED 
			#pragma multi_compile_instancing

			#define BINORMAL
			#define DITHER
			#define VERTEX_COLOR

			#include "GlobalIllumination.hlsl"
			#include "ShaderCore.hlsl"

			float _WindSpeed;
			float _WindJitter;

			FragmentInput custom_vert(VertexInput i, FragmentInput o)
			{
				float t = _Time * _WindSpeed + (o.worldPosition.x * _WindJitter * 1.7 + o.worldPosition.z * _WindJitter * 3.14 + o.worldPosition.y * _WindJitter * 6.28);
				o.worldPosition += (o.tangent * cos(t) + o.normal * sin(t)) * i.color.r;
				o.clipPosition = TransformWorldToClip(o.worldPosition);
				return o;
			}

			

			#define CUSTOM_VS_PASS o = custom_vert(i, o);

			#include "CommonPasses.hlsl"

			ENDHLSL
        }

		Pass
		{
			Name "Depth Only"
			Blend One Zero
			ZWrite On
			Cull Off
			Tags {"LightMode" = "Depth Only"}

			HLSLPROGRAM
			#pragma vertex common_vert
			#pragma fragment common_frag_depth

			#define BINORMAL
			#define DITHER
			#define VERTEX_COLOR

			#include "ShaderCore.hlsl"

			float _WindSpeed;
			float _WindJitter;

			FragmentInput custom_vert(VertexInput i, FragmentInput o)
			{
				float t = _Time * _WindSpeed + (o.worldPosition.x * _WindJitter * 1.7 + o.worldPosition.z * _WindJitter * 3.14 + o.worldPosition.y * _WindJitter * 6.28);
				o.worldPosition += (o.tangent * cos(t) + o.normal * sin(t)) * i.color.r;
				o.clipPosition = TransformWorldToClip(o.worldPosition);
				return o;
			}

			#define CUSTOM_VS_PASS o = custom_vert(i, o);

			#include "CommonPasses.hlsl"

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

			#include "UnityStandardMeta.cginc"

			float4 _MainColor;

			float4 frag_meta2(v2f_meta i) : SV_Target
			{
				FragmentCommonData data = UNITY_SETUP_BRDF_INPUT(i.uv);

				UnityMetaInput o;
				UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);

				o.Albedo = float3(_MainColor.rgb * tex2D(_MainTex, i.uv.xy).rgb);
				o.Emission = Emission(i.uv.xy);

				return UnityMetaFragment(o);
			}

			ENDHLSL
		}

		UsePass "Hidden/Opaque Back Depth/Main"
		UsePass "SHADOWS/Casters/Opaque"
    }
}
