Shader "LOCAL/Geo Particles/Tessel Additive"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_MainColor("Tint", Color) = (1,1,1,1)
		_TesselQuantity("Particles Count", int) = 1
		_Scale("Scale", float) = 1
		_Speed("Speed", float) = 3
		_Jitter("Jitter", float) = 1
		_Lifetime("Lifetime", float) = 4
		_LifetimeRand("Lifetime Randomization", float) = 0.2
		[Toggle(_IS_LOOP)]_IsLoop("Is Loop", float) = 0
		[Toggle(_IS_ANIM)][Space(10)]_IsAnim("Is Anim", float) = 0
		_AnimTime("Anim Time", range(0, 1)) = 0.5
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
				Cull Front
				Tags {"LightMode" = "Transparent"}

				HLSLPROGRAM
				#pragma target 4.6
				#pragma vertex common_vert
				#pragma geometry particle_geom
				#pragma fragment frag
				#pragma hull hull_program
				#pragma domain domain_program
				#pragma shader_feature _IS_LOOP, _IS_ANIM
				#pragma multi_compile_instancing

				int _TesselQuantity;

				#define TESSELLATION_EDGE_FACTORS(patch, id) (id == 0) ? _TesselQuantity : 1
				#define TESSELLATION_IN_FACTORS 1

				#define LIGHTMAP_ON
				#define VERTEX_COLOR

				#include "../ShaderCore.hlsl"

				float _Scale;
				float _Lifetime;
				float _Speed;
				float _Jitter;
				float _LifetimeRand;

				struct Particle {
					uint id;
					float3 position;
					float3 normal;
					float lifetime;
					float3 scale;
					float3 color;
				};

				static float3 _ParticleColor;

				void particle(inout Particle p) {
					p.position = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
					float3 randDir = float3(
						cos(p.id * 37845), 
						sin(p.id * 25672 + 1),
						cos(p.id * 68145 + 2.1)
						);
					p.position += normalize(randDir) *_Speed* p.lifetime;
					p.color = float3(1, 1, 1) * sin(p.lifetime * 3.14);
					p.scale = clamp(_Scale * p.color.r, _Scale * 0.2, _Scale);
					_ParticleColor = p.color;
				} 

				#ifdef _IS_ANIM
				float _AnimTime;
				#endif

				float GetLifetime(Particle p) {
					#ifdef _IS_ANIM
					float t = _AnimTime * (_Lifetime + _LifetimeRand * 2)
						+ _LifetimeRand * RandomNoise(p.id);
					return frac(t / (_Lifetime + _LifetimeRand * 2));
					#else
					float t = (_Time * 10 + p.id * _LifetimeRand) % _Lifetime;
					return frac(t / _Lifetime);
					#endif
				}

				#define PARTICLE_COUNT _TesselQuantity + 1
				#define PARTICLE_TYPE Particle
				#define PARTICLE_LIFETIME(p) GetLifetime(p);
				#define PARTICLE_PROGRAM(p) particle(p);

				FragmentInput particle_to_pixel(FragmentInput i) {
					i.color = _ParticleColor;
					return i;
				}

				#define DEFAULT_GEOMETRY_TYPE particle_to_pixel(o);

				#include "Assets/Oneiros Render Pipeline/Shaders/Tessellation.hlsl"
				#include "Assets/Oneiros Render Pipeline/Shaders/Particles.hlsl"
				#include "../Geometry.hlsl"
				/*
				[maxvertexcount(8)]
				void geom(triangle GEOMETRY_TYPE input[3], inout TriangleStream<GEOMETRY_TYPE> OutputStream)
				{
					float3 center = input[0].worldPosition + input[1].worldPosition + input[2].worldPosition;
					center *= (1.0 / 3.0);
					float3 normal = input[0].normal + input[1].normal + input[2].normal;
					normal *= (1.0 / 3.0);
					float3 tangent = input[1].worldPosition - input[0].worldPosition;
					tangent = normalize(tangent);
					float3 bitangent = normalize(cross(normal, tangent));
					float life = (_Time * _Speed + center.x + center.y * 17) % ((_Lifetime + cos(center.z)) * _LifetimeRand);
					center += normal * life + tangent * cos(life * 3.4) * _Jitter + bitangent * cos(life * 1.7) * _Jitter;
					GenerateBillboard(center, float2(1, 1) * _Scale, OutputStream);
				}
				*/
				// included in common pass

				#include "../CommonPasses.hlsl"

				float4 frag(FragmentInput i) : SV_TARGET{
					float4 color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw) * _MainColor;
					color.rgb *= i.color.rgb;
					return color;
				}

				ENDHLSL
			}
		}
}
