#ifndef TESSELLATION_INCLUDE
#define TESSELLATION_INCLUDE

#include "ShaderCore.hlsl"

#ifndef TESSELLATION_PATCH_TYPE
#define TESSELLATION_PATCH_TYPE FragmentInput
#endif

// Hull stage is after vertex stage
[domain("tri")]
[outputcontrolpoints(3)]
[outputtopology("triangle_cw")]
[partitioning("integer")]
[patchconstantfunc("patch_constant_function")]
TESSELLATION_PATCH_TYPE hull_program(
    InputPatch<TESSELLATION_PATCH_TYPE, 3> patch,
	uint id : SV_OutputControlPointID
) {
    return patch[id];
}

struct TessellationFactors
{
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

#ifndef TESSELLATION_EDGE_FACTORS
#define TESSELLATION_EDGE_FACTORS(patch, id) 1
#endif

#ifndef TESSELLATION_IN_FACTORS
#define TESSELLATION_IN_FACTORS 1
#endif

TessellationFactors patch_constant_function(InputPatch<TESSELLATION_PATCH_TYPE, 3> patch,
    uint PatchID : SV_PrimitiveID)
{
    TessellationFactors f;
    #ifdef TESSELLATION_FACTORS_VERTICES
    f.edge[0] = TESSELLATION_EDGE_FACTORS(patch[1], patch[2]); 
    f.edge[1] = TESSELLATION_EDGE_FACTORS(patch[0], patch[2]);
    f.edge[2] = TESSELLATION_EDGE_FACTORS(patch[1], patch[0]);
    f.inside = TESSELLATION_IN_FACTORS(patch[0], patch[1], patch[2]);
    #else
    f.edge[0] = TESSELLATION_EDGE_FACTORS(patch, 0);
    f.edge[1] = TESSELLATION_EDGE_FACTORS(patch, 1);
    f.edge[2] = TESSELLATION_EDGE_FACTORS(patch, 2);
    f.inside = TESSELLATION_IN_FACTORS;
    #endif
    return f;
}

#define DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
		patch[0].fieldName * barycentricCoordinates.x + \
		patch[1].fieldName * barycentricCoordinates.y + \
		patch[2].fieldName * barycentricCoordinates.z;

TESSELLATION_PATCH_TYPE DomainInterpolateDefault(OutputPatch<TESSELLATION_PATCH_TYPE, 3> patch, float3 barycentricCoordinates)
{
    TESSELLATION_PATCH_TYPE data;
    //DOMAIN_PROGRAM_INTERPOLATE(clipPosition)
    DOMAIN_PROGRAM_INTERPOLATE(worldPosition)
    DOMAIN_PROGRAM_INTERPOLATE(normal)
    DOMAIN_PROGRAM_INTERPOLATE(uv)
	#ifdef CUSTOM_GI_INCLUDED
    DOMAIN_PROGRAM_INTERPOLATE(lightmapUv)
    #endif
	#ifdef BINORMAL
    DOMAIN_PROGRAM_INTERPOLATE(binormal)
    DOMAIN_PROGRAM_INTERPOLATE(tangent)
    #endif
    #ifdef VERTEX_COLOR
    DOMAIN_PROGRAM_INTERPOLATE(color)
    #endif
    #if defined(UNITY_PROCEDURAL_INSTANCING_ENABLED)
	data.instanceId = patch[0].instanceId;
	#endif
    data.clipPosition = TransformWorldToClip(data.worldPosition);
    return data;
}

[domain("tri")]
TESSELLATION_PATCH_TYPE domain_program(
	TessellationFactors factors,
	OutputPatch<TESSELLATION_PATCH_TYPE, 3> patch,
	float3 barycentricCoordinates : SV_DomainLocation // Where the new vertex is on the triangle
)
{
    TESSELLATION_PATCH_TYPE data;
    
    #ifndef DOMAIN_PROGRAM
    #define DOMAIN_PROGRAM DomainInterpolateDefault(patch, barycentricCoordinates)
    #endif
    
    data = DOMAIN_PROGRAM;
    return data;
}

#endif