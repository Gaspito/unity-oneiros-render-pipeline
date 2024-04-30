Shader "LOCAL/Billboard/Reflection"
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
				Blend One One
				ZWrite Off
				ZTest Always
				Cull Off
				Tags {"LightMode" = "Transparent"}

				HLSLPROGRAM
				#pragma vertex common_vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma shader_feature AXIS_BILLBOARD

				#define BILLBOARD
			
				#include "../ShaderCore.hlsl"
				
				#define CUSTOM_GLOBAL_SAMPLER sampler_reflectionTarget

				#include "../Lighting.hlsl"

				// included in common pass

				#include "../CommonPasses.hlsl"

				float4 frag(FragmentInput i) : SV_TARGET{
					float4 color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw) * _MainColor;
					if (color.a < 0.001) discard;
					float4 clipPos = TransformWorldToClip(i.worldPosition);
					float2 screenPos = clipPos.xy / clipPos.w * 0.5 + float2(0.5, 0.5);
					if (_ProjectionParams.x < 0) screenPos.y = 1.0 - screenPos.y;
					float3 _reflection = SAMPLE_REFLECTION(screenPos);
					color *= _reflection.x * 0.01;
					if (color.a < 0.001) discard;
					color.rgb *= color.a;
					return color;
				}

				ENDHLSL
			}
		}
}
