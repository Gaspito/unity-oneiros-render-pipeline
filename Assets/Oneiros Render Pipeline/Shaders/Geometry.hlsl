#ifndef GEOMETRY_INCLUDE
#define GEOMETRY_INCLUDE

#include "ShaderCore.hlsl"

#ifndef GEOMETRY_TYPE
#define GEOMETRY_TYPE FragmentInput
#endif

[maxvertexcount(3)]
void geometry_program(triangle GEOMETRY_TYPE input[3], inout TriangleStream<GEOMETRY_TYPE> OutputStream)
{
    #ifdef ON_PRE_PROCESS_GEOMETRY
    ON_PRE_PROCESS_GEOMETRY
    #endif
    for (uint i = 0; i < 3; i++)
    {
        GEOMETRY_TYPE o;
        #ifdef ON_PROCESS_GEOMETRY_INPUT
        o = ON_PROCESS_GEOMETRY_INPUT(input[i]);
        #else
        o = input[i];
        #endif
        OutputStream.Append(o);
    }
    #ifdef ON_POST_PROCESS_GEOMETRY
    ON_POST_PROCESS_GEOMETRY
    #endif
    OutputStream.RestartStrip();
}

// Creates a quad of 4 vertices of type GEOMETRY_TYPE centered at center and of scale scale facing the camera.
void GenerateBillboard(float3 center, float2 scale, inout TriangleStream<GEOMETRY_TYPE> OutputStream)
{
    float2 uv[4] = {
        float2(0, 0),
        float2(1, 0),
        float2(0, 1),
        float2(1, 1)
    };
    float3 view = GetCameraView(center);
    float3 up = float3(0, 1, 0);
    float3 right = normalize(cross(view, up));
    up = normalize(cross(view, right));
    for (uint i = 0; i < 4; i++)
    {
        GEOMETRY_TYPE o;
        #ifdef DEFAULT_GEOMETRY_TYPE
        o = DEFAULT_GEOMETRY_TYPE;
        #endif
        o.worldPosition = center + (uv[i].x - 0.5) * right * scale.x
            + (uv[i].y - 0.5) * up * scale.y;
        o.uv = uv[i];
        o.normal = -view;
        o.clipPosition = TransformWorldToClip(o.worldPosition);
        OutputStream.Append(o);
    }
    OutputStream.RestartStrip();

}

#endif