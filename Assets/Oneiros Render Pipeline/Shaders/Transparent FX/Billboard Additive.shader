Shader "LOCAL/Billboard/Additive"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_MainColor("Tint", Color) = (1,1,1,1)
	}
		SubShader
		{
			//Tags { "RenderType" = "Transparent" "DisableBatching"="True" }
			Tags { "RenderType" = "Transparent"}

			Pass
			{
				Name "Main"
				Blend One One
				ZWrite Off
				Cull Off
				Tags {"LightMode" = "Transparent"}

				HLSLPROGRAM
				#pragma vertex common_vert
				#pragma fragment frag
				#pragma multi_compile_instancing

				#define LIGHTMAP_ON
				#define BILLBOARD
			
				#include "../ShaderCore.hlsl"

				// included in common pass

				#include "../CommonPasses.hlsl"

				float4 frag(FragmentInput i) : SV_TARGET{
					float4 color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw) * _MainColor;
					return color;
				}

				ENDHLSL
			}
		}
}
