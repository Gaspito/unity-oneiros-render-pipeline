Shader "LOCAL/Billboard/Additive Animated with Mask"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_MainColor("Tint", Color) = (1,1,1,1)
		_MaskTex("Mask Texture", 2D) = "white" {}
		_HorizontalSpeed("Horizontal Speed", float) = 0
		_VerticalSpeed("Vertical Speed", float) = 1
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

				sampler2D _MaskTex;
				float _HorizontalSpeed;
				float _VerticalSpeed;

				float4 frag(FragmentInput i) : SV_TARGET{
					float2 translation;
					translation.x = _HorizontalSpeed * _Time;
					translation.y = _VerticalSpeed * _Time;
					float mask = tex2D(_MaskTex, i.uv).r;
					float4 color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw + translation) * _MainColor;
					color = lerp(float4(0, 0, 0, 0), color, mask);
					return color;
				}

				ENDHLSL
			}
		}
}
