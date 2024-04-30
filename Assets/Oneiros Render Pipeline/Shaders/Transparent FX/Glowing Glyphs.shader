Shader "LOCAL/Transparent FX/Glowing Glyphs"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_MainColor("Tint", Color) = (1,1,1,1)
	}
		SubShader
		{
			Tags { "RenderType" = "Transparent" }
			LOD 100

			Pass
			{
				Name "Main"
				Blend One One
				ZWrite Off
				Cull Off
				Tags {"LightMode" = "Transparent"}

				HLSLPROGRAM
				#pragma vertex vert
				#pragma fragment frag
			
				#include "../ShaderCore.hlsl"

				FragmentInput vert(VertexInput i) {
					FragmentInput o;
					o.worldPosition = TransformObjectToWorld(i.position);
					o.clipPosition = TransformWorldToClip(o.worldPosition);
					o.normal = TransformNormalToWorld(i.normal);
					o.uv = i.uv;
					return o;
				}

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float4 _MainColor;

				float4 frag(FragmentInput i) : SV_TARGET{
					float4 color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw) * _MainColor;
					return color;
				}

				ENDHLSL
			}
		}
}
