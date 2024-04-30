#ifndef CUSTOM_PARTICLES
#define CUSTOM_PARTICLES

#include "ShaderCore.hlsl"
#include "Geometry.hlsl"

#ifndef PARTICLE_TYPE
struct Particle {
	uint id;
	float3 position;
	float3 normal;
	float3 tangent;
	float3 bitangent;
	float lifetime;
	float3 scale;
	float3 color;
};
#define PARTICLE_TYPE Particle
#endif

#ifndef PARTICLE_COUNT
#define PARTICLE_COUNT 100;
#endif

#ifndef PARTICLE_LIFETIME
#define PARTICLE_LIFETIME(p) 0.5;
#endif

#ifndef PARTICLE_PROGRAM
#define PARTICLE_PROGRAM(p) p;
#endif

#ifndef GENERATE_PARTICLE_FUNC
#define GENERATE_PARTICLE_FUNC(p) GenerateBillboard(p.position, p.scale.xy, OutputStream);
#endif

[maxvertexcount(8)]
void particle_geom(triangle GEOMETRY_TYPE input[3], inout TriangleStream<GEOMETRY_TYPE> OutputStream)
{
	float3 center = input[0].worldPosition + input[1].worldPosition + input[2].worldPosition;
	center *= 1.0 / 3.0;
	float3 normal = input[0].normal + input[1].normal + input[2].normal;
	normal *= 1.0 / 3.0;
	float3 tangent = input[1].worldPosition - input[0].worldPosition;
	tangent = normalize(tangent);
	float3 bitangent = normalize(cross(normal, tangent));

	float2 uv = input[0].uv.xy + input[1].uv.xy + input[2].uv.xy;
	uv *= 1.0 / 3.0;

	PARTICLE_TYPE p;
	p.id = floor(uv.x * PARTICLE_COUNT);
	//p.randomSeed = RandomNoise(mul(unity_WorldToObject, float4(center, 1)).xyz);
	p.position = center;
	p.lifetime = PARTICLE_LIFETIME(p);
	p.normal = normal;
	//p.tangent = tangent;
	//p.bitangent = bitangent;
	PARTICLE_PROGRAM(p);
	//PARTICLE_TYPE p = PARTICLE_PROGRAM(center, normal, tangent, bitangent);

	//float life = (_Time * _Speed + center.x + center.y * 17) % ((_Lifetime + cos(center.z)) * _LifetimeRand);
	//center += normal * life + tangent * cos(life * 3.4) * _Jitter + bitangent * cos(life * 1.7) * _Jitter;

	//GenerateBillboard(center, float2(1, 1) * _Scale, OutputStream);
	GENERATE_PARTICLE_FUNC(p)
}

#endif