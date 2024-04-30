#ifndef CUSTOM_COMMON_PASSES
#define CUSTOM_COMMON_PASSES

#ifdef BILLBOARD
#ifdef AXIS_BILLBOARD
float3 GetBillboardPosition(float3 worldPosition, float3 objectOriginInWorld, float3 localUp)
#else
float3 GetBillboardPosition(float3 worldPosition, float3 objectOriginInWorld)
#endif
{
	float3 originToWorld = worldPosition - objectOriginInWorld;
	float3 view = GetCameraView(objectOriginInWorld);
	#ifdef AXIS_BILLBOARD
	float4x4 rotation = LookAtMatrix(view, localUp);
	#else
	float4x4 rotation = LookAtMatrix(view);
	#endif
	float3 rotatedPos = mul(rotation, float4(originToWorld, 0)).xyz;
	return rotatedPos + objectOriginInWorld;
}
#endif

FragmentInput common_vert(VertexInput i)
{
    FragmentInput o;
    UNITY_SETUP_INSTANCE_ID(i);
    UNITY_TRANSFER_INSTANCE_ID(i, o);
	#ifdef RIG_SHADER
    int blendIndices[4];
    float blendWeights[4];
    GetBlendValues(i.blendIndices, i.blendWeights, blendIndices, blendWeights);
    o.worldPosition = BlendPosition(i.position, blendIndices, blendWeights);
	#else
    o.worldPosition = i.TransformObjectToWorld(i.position);
	#endif
	#ifdef BILLBOARD
	#ifdef AXIS_BILLBOARD
	o.worldPosition = GetBillboardPosition(o.worldPosition, 
		i.TransformObjectToWorld(float3(0, 0, 0)), 
		i.TransformDirToWorld(float3(0,1,0)));
	#else
	o.worldPosition = GetBillboardPosition(o.worldPosition, i.TransformObjectToWorld(float3(0, 0, 0)));
	#endif
	#endif
    o.clipPosition = TransformWorldToClip(o.worldPosition);
    o.normal = i.TransformDirToWorld(i.normal);
    #ifdef BINORMAL
    o.tangent = i.TransformDirToWorld(i.tangent);
    o.binormal = cross(o.normal, o.tangent);
    #endif
    o.uv = i.uv;
    #ifdef CUSTOM_GI_INCLUDED
	o.lightmapUv = i.lightmapUv * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif
    #ifdef CUSTOM_VS_PASS
    return CUSTOM_VS_PASS
	#else
    return o;
    #endif
}

sampler2D _MainTex;
float4 _MainTex_ST;
float4 _MainColor;

#ifdef BINORMAL
sampler2D _BumpTex;
#endif

#if defined(ROUGHNESS_MAP)
sampler2D _RoughnessTex;
#endif

float _Smoothness;
float _Metallic;

#if defined(TRANSLUCENT)
sampler2D _TransluencyTex;
float4 _TransluencyColor;
float _Density;
#endif

#ifdef DITHER
sampler2D _DitherTex;
bool Dither(float alpha, float2 screenPos)
{
    return (tex2Dlod(_DitherTex, float4(screenPos, 0, 0)).r > alpha);
}
#endif

FragmentOutput common_frag_deferred(FragmentInput i){
	FragmentOutput o;
    UNITY_SETUP_INSTANCE_ID(i);
	i.uv = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
	o.albedo = tex2D(_MainTex, i.uv) * _MainColor;
	
	#ifdef DITHER
	if (Dither(o.albedo.a, GetScreenPos(i.clipPosition))) discard;
	#endif

	o.position = i.worldPosition;

	#ifdef BINORMAL
	float3 normalmap = tex2D(_BumpTex, i.uv).xyz;
	normalmap = normalmap * 2.0 - 1.0;
	float3 normal = normalmap.x * normalize(i.tangent)
		+ normalmap.y * normalize(i.binormal)
		+ normalmap.z * normalize(i.normal);
	o.normal = normalize(normal); 
	#else
    o.normal = normalize(i.normal);
	#endif

	#ifdef ROUGHNESS_MAP
	float3 roughnessMap = tex2D(_RoughnessTex, i.uv);
	o.reflections = float3(roughnessMap.r * _Smoothness, roughnessMap.g * _Metallic, 0);
	#else
	o.reflections = float3(_Smoothness, _Metallic, 0);
	#endif

	#if defined(TRANSLUCENT)
	o.transluency = float4(_TransluencyColor.rgb * tex2D(_TransluencyTex, i.uv).rgb, _Density);
	#else
	o.transluency = float4(0, 0, 0, 20);
	#endif

	#ifdef CUSTOM_GI_INCLUDED
	GI gi = GetGI(i.lightmapUv, o.normal);
	o.gi = float4(gi.diffuse + SampleLightProbe(i.normal), 1);
	#endif
	
	#ifdef CUSTOM_PS_PASS
    CUSTOM_PS_PASS
    #endif

	return o;
}

float common_frag_depth(FragmentInput i) : SV_TARGET
{
	#ifdef DITHER
	float4 albedo = tex2D(_MainTex, i.uv) * _MainColor;
	if (Dither(albedo.a, GetScreenPos(i.clipPosition))) discard;
	#endif
	#ifdef CUSTOM_PS_PASS
    CUSTOM_PS_PASS
    #endif
    return i.clipPosition.z / i.clipPosition.w;
}

#endif