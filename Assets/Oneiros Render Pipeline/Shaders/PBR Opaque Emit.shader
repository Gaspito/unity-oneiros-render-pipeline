Shader "LOCAL/PBR Opaque Emit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_MainColor ("Tint", Color) = (1,1,1,1)
		[NoScaleOffset]_BumpTex("Normal", 2D) = "bump" {}

		[Space(50)]_Smoothness("Smoothness", range(0, 100)) = 10
		_Metallic("Metallic", range(0, 1)) = 0

		[Space(50)][Header(Emission)] _EmitTex("Texture", 2D) = "black" {}
		_EmitColor("Color", Color) = (1,1,1,1)

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
			Name "Emission"
			Blend One One
			ZWrite Off
			ZTest LEqual
			Tags {"LightMode"="Transparent" "Queue"="Geometry+1"}

			HLSLPROGRAM
			#pragma vertex common_vert
			#pragma fragment frag

			#define BINORMAL

			#include "ShaderCore.hlsl"

			sampler2D _EmitTex;
			float4 _EmitColor;

			float4 frag(FragmentInput i) : SV_TARGET
			{
				return tex2D(_EmitTex, i.uv.xy) * _EmitColor;
			}

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

			//#include "ShaderCore.hlsl"
			#include "UnityStandardMeta.cginc"

			//sampler2D _MainTex;
			//float4 _MainTex_ST;

			float4 _MainColor;

			sampler2D _EmitTex;
			float4 _EmitColor;

			float4 frag_meta2(v2f_meta i) : SV_Target
			{
				// we're interested in diffuse & specular colors,
				// and surface roughness to produce final albedo.
				FragmentCommonData data = UNITY_SETUP_BRDF_INPUT(i.uv);

				UnityMetaInput o;
				UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);

				o.Albedo = float3(_MainColor.rgb * tex2D(_MainTex, i.uv.xy).rgb);
				o.Emission = float3(_EmitColor.rgb * tex2D(_EmitTex, i.uv.xy).rgb);

				return UnityMetaFragment(o);
			}

			ENDHLSL
		}

		UsePass "LOCAL/PBR Opaque/Main"
		UsePass "LOCAL/PBR Opaque/Depth Only"
		UsePass "Hidden/Opaque Back Depth/Main"
		UsePass "SHADOWS/Casters/Opaque"
    }
}
