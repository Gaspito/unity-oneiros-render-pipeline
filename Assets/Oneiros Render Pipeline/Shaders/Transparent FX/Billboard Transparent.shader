Shader "LOCAL/Billboard/Transparent"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_MainColor("Tint", Color) = (1,1,1,1)
		[Toggle(AXIS_BILLBOARD)] _AxisBillboard("Rotate Around Y only", float) = 0
	}
		SubShader
		{
			//Tags { "RenderType" = "Transparent" "DisableBatching"="True" }
			Tags { "RenderType" = "Transparent" "Queue"="Transparent-50"}

			Pass
			{
				Name "Main"
				Blend SrcAlpha OneMinusSrcAlpha
				ZWrite Off
				Cull Off
				Tags {"LightMode" = "Transparent"}

				HLSLPROGRAM
				#pragma vertex common_vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma shader_feature AXIS_BILLBOARD

				#define LIGHTMAP_ON
				#define BILLBOARD
			
				#include "../ShaderCore.hlsl"

				// included in common pass

				#include "../CommonPasses.hlsl"

				float4 frag(FragmentInput i) : SV_TARGET{
					float4 color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw) * _MainColor;
					if (color.a < 0.001) discard;
					return color;
				}

				ENDHLSL
			}

			Pass
			{
				Name "Main"
				Blend One Zero
				ZWrite On
				Cull Off
				Tags {"LightMode" = "Depth Only"}

				HLSLPROGRAM
				#pragma vertex common_vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma shader_feature AXIS_BILLBOARD

				#define LIGHTMAP_ON
				#define BILLBOARD
			
				#include "../ShaderCore.hlsl"

				// included in common pass

				#include "../CommonPasses.hlsl"

				float4 frag(FragmentInput i) : SV_TARGET{
					float4 color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw) * _MainColor;
					if (color.a < 0.99) discard;
					return color;
				}

				ENDHLSL
			}
		}
}
