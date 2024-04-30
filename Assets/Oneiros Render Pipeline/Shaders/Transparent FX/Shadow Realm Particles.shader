Shader "LOCAL/Geo Particles/Shadow Realm Particles"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_SpriteCount("Sprite Count", int) = 8
		_MainColor("Tint", Color) = (1,1,1,1)
		_TesselCountPerEdge("Particles Per meter", float) = 1
		_TesselCountPerFaceArea("Particles Per face area", float) = 1
		_Scale("Scale", float) = 1
		_Speed("Speed", float) = 3
		_Jitter("Jitter", float) = 1
		_Lifetime("Lifetime", float) = 4
		_LifetimeRand("Lifetime Randomization", float) = 0.2
		[Header(Fading)]
		_FadeMin("Min", float) = 10
		_FadeMax("Max", float) = 30
	}
		SubShader
		{
			//Tags { "RenderType" = "Transparent" "DisableBatching"="True" }
			Tags { "RenderType" = "Transparent"}

			Pass
			{
				Name "Main"
				Blend SrcAlpha OneMinusSrcAlpha
				ZWrite Off
				Cull Off
				Tags {"LightMode" = "Transparent"}

				HLSLPROGRAM
				#pragma target 4.6
				#pragma vertex common_vert
				#pragma geometry particle_geom
				#pragma fragment frag
				#pragma hull hull_program
				#pragma domain domain_program
				#pragma multi_compile_instancing
				
				#define LIGHTMAP_ON
				#define VERTEX_COLOR

				#include "../ShaderCore.hlsl"

				float _TesselCountPerEdge;

				float GetTesselCountPerEdge(FragmentInput a, FragmentInput b)
				{
					float length = distance(a.worldPosition, b.worldPosition);
					return max(1.0, _TesselCountPerEdge * length);
				}

				float _TesselCountPerFaceArea;

				float GetTesselCountPerTriangle(FragmentInput a, FragmentInput b, FragmentInput c)
				{
					float3 i = a.worldPosition;
					float3 j = b.worldPosition;
					float3 k = c.worldPosition;
					float area = distance(j, i) * distance(k, i) * 0.5;
					return max(1.0, area * _TesselCountPerFaceArea);
				}

				#define TESSELLATION_FACTORS_VERTICES
				#define TESSELLATION_EDGE_FACTORS(a, b) GetTesselCountPerEdge(a, b)
				#define TESSELLATION_IN_FACTORS(a, b, c) GetTesselCountPerTriangle(a, b, c)

				struct Particle {
					uint id;
					float3 position;
					float3 normal;
					//float3 tangent;
					//float3 bitangent;
					float lifetime;
					float3 scale;
					float3 color;
				};

				static float3 _ParticleColor;

				float _Scale;
				float _Lifetime;
				float _LifetimeRand;

				void particle(inout Particle p) {
					//p.position = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
					p.color = float3(1, 1, 1) * p.lifetime;
					p.scale = _Scale;
					_ParticleColor = p.color;
				}

				float GetLifetime(Particle p) {
					float t = (_Time * 10 + p.id * _LifetimeRand) % _Lifetime;
					return frac(t / _Lifetime);
				}

				#define PARTICLE_COUNT 100
				#define PARTICLE_LIFETIME(p) GetLifetime(p)
				#define PARTICLE_TYPE Particle
				#define PARTICLE_PROGRAM(p) particle(p)

				FragmentInput particle_to_pixel(FragmentInput i) {
					i.color = _ParticleColor;
					return i;
				}

				#define DEFAULT_GEOMETRY_TYPE particle_to_pixel(o);

				#include "Assets/Oneiros Render Pipeline/Shaders/Tessellation.hlsl"
				#include "../Geometry.hlsl"
				#include "Assets/Oneiros Render Pipeline/Shaders/Particles.hlsl"

				// included in common pass

				#include "../CommonPasses.hlsl"

				int _SpriteCount;

				float _FadeMin;
				float _FadeMax;

				float GetFading(float3 position) {
					float d = distance(worldSpaceCameraPos, position);
					d -= max(_FadeMin, 0.0);
					d /= (_FadeMax - _FadeMin);
					return clamp(1.0 - d, 0.0, 1.0);
				}

				float4 frag(FragmentInput i) : SV_TARGET{
					float2 coords = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
					float spriteStep = (1.0 / (float)_SpriteCount);
					coords.x *= spriteStep;
					float lifetime = i.color.r;
					float spriteLerp = lifetime * spriteStep;
					int spriteId0 = floor(spriteLerp);
					int spriteId1 = ceil(spriteLerp);
					spriteLerp = frac(spriteLerp);
					coords.x += spriteStep * floor(i.color.r * _SpriteCount);
					float4 sprite0 = tex2D(_MainTex, coords + float2(spriteStep * spriteId0, 0));
					float4 sprite1 = tex2D(_MainTex, coords + float2(spriteStep * spriteId1, 0));
					float4 color = lerp(sprite0, sprite1, spriteLerp);
					color *= _MainColor;
					color *= GetFading(i.worldPosition);
					return color;
				}

				ENDHLSL
			}
		}
}
