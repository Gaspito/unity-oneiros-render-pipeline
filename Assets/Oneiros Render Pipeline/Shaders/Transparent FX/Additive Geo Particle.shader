Shader "LOCAL/Geo Particles/Additive"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_MainColor("Tint", Color) = (1,1,1,1)
		_Scale("Scale", float) = 1
		_Speed("Speed", float) = 3
		_Jitter("Jitter", float) = 1
		_Lifetime("Lifetime", float) = 4
		_LifetimeRand("Lifetime Randomization", float) = 0.2
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
				#pragma geometry geom
				#pragma fragment frag
				#pragma multi_compile_instancing

				#define LIGHTMAP_ON
				//#define BILLBOARD

				#include "../ShaderCore.hlsl"
				#include "../Geometry.hlsl"

				float _Scale;
				float _Lifetime;
				float _Speed;
				float _Jitter;
				float _LifetimeRand;

				[maxvertexcount(8)]
				void geom(triangle GEOMETRY_TYPE input[3], inout TriangleStream<GEOMETRY_TYPE> OutputStream)
				{
					float3 center = input[0].worldPosition + input[1].worldPosition + input[2].worldPosition;
					center *= (1.0 / 3.0);
					float3 normal = input[0].normal + input[1].normal + input[2].normal;
					normal *= (1.0 / 3.0);
					float3 tangent = input[1].worldPosition - input[0].worldPosition;
					tangent = normalize(tangent);
					float3 bitangent = input[2].worldPosition - input[0].worldPosition;
					bitangent = normalize(bitangent);
					float life = (_Time * _Speed * _Lifetime + center.x + center.y * 17) % ((_Lifetime + cos(center.z)) * _LifetimeRand);
					center += normal * life + tangent * cos(life * 3.4) * _Jitter + bitangent * cos(life * 1.7) * _Jitter;
					GenerateBillboard(center, float2(1, 1) * _Scale, OutputStream);
				}

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
