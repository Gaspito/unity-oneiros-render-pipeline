Shader "LOCAL/LIGHT/Spot Light"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_MainColor ("Tint", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Light" }
        LOD 100

        Pass
        {
			Name "Main"
			Blend One One
			ZWrite Off
			ZTest Always
			Cull Front
			Tags {"LightMode"="LightCaster"}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature SHADOWS_ON

			#include "Lighting.hlsl"

			float _Range;

			struct VertexData {
				float4 position : POSITION;
				float2 texcoord : TEXCOORD0;
			};

			struct Varyings {
				float4 clipPosition : SV_POSITION;
				float3 origin : TEXCOORD1;
				float2 uv : TEXCOORD0;
				float3 worldPos : TEXCOORD2;
				float3 dir : NORMAL;
			};

			Varyings vert(VertexData i) {
				Varyings o;

				o.origin = TransformObjectToWorld(float3(0, 0, 0));
				o.worldPos = TransformObjectToWorld(i.position.xyz);
				o.dir = TransformObjectToWorld(float3(0, 0, 1)) - o.origin;

				o.clipPosition = TransformWorldToClip(o.worldPos);
				o.uv = i.texcoord;

				return o;
			}

			float Cull(float3 pixelPos, float4x4 worldToLight) {
				float factor = 1;
				float3 localPos = mul(worldToLight, float4(pixelPos, 1)).xyz;
				if (abs(localPos.x) > 1 || abs(localPos.y) > 1 || abs(localPos.z) > 1) 
					factor = 0;
				float localTan = localPos.x * localPos.x + localPos.y * localPos.y;
				if (localTan > localPos.z * localPos.z)
					factor = 0;
				return factor;
			}

			float3 GetRayPlaneIntersection(float3 rayOrigin, float3 rayDirection, float3 planePoint, float3 planeNormal)
			{
				float d = dot(planePoint, -planeNormal);
				float t = -(d + dot(rayOrigin, planeNormal)) / dot(rayDirection, planeNormal);
				return rayOrigin + t * rayDirection;
			}

			float3 SampleCookieAtPos(float3 position, Texture2D tex, SamplerState samp, int level) {
				float3 lightSpacePos = TransformWorldToObject(position);
				float2 cookiePos = lightSpacePos.xy / lightSpacePos.z + float2(0.5, 0.5);
				cookiePos.x = clamp(cookiePos.x, 0, 1);
				cookiePos.y = clamp(cookiePos.y, 0, 1);
				return tex.SampleLevel(samp, cookiePos, level).rgb;
			}

			#ifdef SHADOWS_ON
			Texture2D<float> _ShadowTex;
			
			SamplerComparisonState linear_mirror_compare_sampler;
			//SamplerState linear_mirror_sampler;

			float _ShadowBias = 0.1;
			
			float SampleShadow(float2 cookiePos, float distTolight) {
				float2 shadowCoords = cookiePos;
				float cmpValue = distTolight;
				return 1.0 - _ShadowTex.SampleCmp(linear_mirror_compare_sampler, shadowCoords, cmpValue - _ShadowBias * distTolight);
				//return _ShadowTex.SampleLevel(linear_mirror_sampler, shadowCoords, 0) / _Range;
			}
			#endif

			Texture2D _CookieTex;
			SamplerState sampler_CookieTex;
			float _Intensity;
			float3 _Color;

			Texture2D _VolumeFogTex;
			float _VolumeThickness;

			float4 frag(Varyings i) : SV_TARGET{
				float4 color = float4(0, 0, 0, 0);

				float4 clipPos = TransformWorldToClip(i.worldPos);
				float2 screenPos = clipPos.xy / clipPos.w * 0.5 + float2(0.5, 0.5);
				if (_ProjectionParams.x < 0) screenPos.y = 1.0 - screenPos.y;

				float3 position = SAMPLE_POSITION(screenPos);

				float cullFactor = Cull(position, unity_WorldToObject);

				float3 ldir = position - i.origin;

				float sqrDist = SqrLength(ldir);

				//if (sqrDist > _Range * _Range) discard;

				//float3 lightSpacePos = TransformWorldToObject(position);
				//float2 cookiePos = lightSpacePos.xy / lightSpacePos.z + float2(0.5, 0.5);
				//cookiePos.x = clamp(cookiePos.x, 0, 1);
				//cookiePos.y = clamp(cookiePos.y, 0, 1);
				//float3 cookie = _CookieTex.SampleLevel(sampler_CookieTex, cookiePos, 0).rgb;
				float3 cookie = SampleCookieAtPos(position, _CookieTex, sampler_CookieTex, 0);
				//cookie = float3(1, 1, 1);

				float3 normal = SAMPLE_NORMAL(screenPos);

				float diffuse = LambertDiffuse(normal, ldir);

				float3 view = GetCameraView(position);

				float3 reflections = SAMPLE_REFLECTION(screenPos);
				float smoothness = reflections.x;
				float metallic = reflections.y;

				float specular = PhongSpecular(normal, ldir, view, smoothness);

				float3 albedo = SAMPLE_ALBEDO(screenPos);
				float4 transluency = SAMPLE_TRANSLUENCY(screenPos);
				float backDepth = SAMPLE_BACK_DEPTH(screenPos);

				float3 lcolor = _Color * _Intensity * cookie;

				float atten = 1.0 - clamp(sqrDist / (_Range*_Range), 0, 1);

				//atten *= cullFactor;

				float oneMinusMetallic = clamp(1.0 - metallic, 0.04, 1.0);

				#ifdef SHADOWS_ON
				float shadow = SampleShadow(cookiePos, sqrt(sqrDist));
				atten *= shadow;
				#endif

				// Volumetrics
				float3 lvolume = float3(1.0, 1.0, 1.0);
				view = normalize(view);
				float3 absldir = normalize(i.dir);
				float3 lside = cross(absldir, view);
				float3 ltan = cross(absldir, lside);
				ltan = normalize(ltan);
				float3 center = GetRayPlaneIntersection(position, view, i.origin, ltan);
				float cdist = SqrLength(center - i.origin);
				cdist /= (_Range * _Range);
				float3 radius = i.worldPos - center;
				radius *= 0.5;
				float3 ccookie = SampleCookieAtPos(center, _CookieTex, sampler_CookieTex, 3) * 0.33
					+ SampleCookieAtPos(center + radius, _CookieTex, sampler_CookieTex, 3) * 0.33
					+ SampleCookieAtPos(center - radius, _CookieTex, sampler_CookieTex, 3) * 0.33;
				lvolume *= _Color * _Intensity * (1.0 - cdist) * ccookie;
				float fogDensity = _VolumeFogTex.SampleLevel(sampler_CookieTex, screenPos.xy + float2(_Time, 0.0), 0).r;
				fogDensity += _VolumeFogTex.SampleLevel(sampler_CookieTex, screenPos.xy + float2(-_Time, 0.5), 0).r;
				lvolume *= clamp(fogDensity, 0.0, 1.0);
				lvolume *= _VolumeThickness;
				lvolume *= clamp(1.0 - (SqrLength(center - worldSpaceCameraPos) - SqrLength(position - worldSpaceCameraPos)) / 3,
					0.0, 1.0);
				lvolume *= 1.0 - clamp((SqrLength(center - i.origin)) / (_Range * _Range) + 0.25, 0.0, 1.0);
				lvolume *= clamp(SqrLength(center - worldSpaceCameraPos) * 0.1 * _VolumeThickness, 0.0, 1.0);
				lvolume *= 1.0 - abs(dot(normalize(view), normalize(absldir)));
				//

				color.rgb +=
					diffuse * lcolor * albedo * oneMinusMetallic
					+ specular * lcolor * oneMinusMetallic
					+ specular * lcolor * albedo * metallic
					;

				color.rgb += Transluency(position, backDepth, ldir, normal, transluency.rgb * lcolor, transluency.a);

				color *= atten;

				color.rgb += lvolume;

				return color;
			}

			ENDHLSL
        }
    }
}
