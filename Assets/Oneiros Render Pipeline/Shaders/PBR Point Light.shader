Shader "LOCAL/LIGHT/Point Light"
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
			};

			Varyings vert(VertexData i) {
				Varyings o;

				o.origin = TransformObjectToWorld(float3(0, 0, 0));
				o.worldPos = TransformObjectToWorld(i.position.xyz);

				o.clipPosition = TransformWorldToClip(o.worldPos);
				o.uv = i.texcoord;

				return o;
			}

			float Cull(float3 pixelPos, float3 lightPos) {
				float sqrDist = SqrLength(pixelPos - lightPos);
				if (sqrDist > _Range * _Range) return 0.0;
				return 1.0;
			}

			float2 RaySphereIntersect(float3 r0, float3 rd, float3 s0, float sr) {
				float a = dot(rd, rd);
				float3 s0_r0 = r0 - s0;
				float b = 2.0 * dot(rd, s0_r0);
				float c = dot(s0_r0, s0_r0) - (sr * sr);
				float disc = b * b - 4.0 * a * c;
				if (disc < 0.0) {
					return float2(-1.0, -1.0);
				}
				else {
					return float2(-b - sqrt(disc), -b + sqrt(disc)) / (2.0 * a);
				}
			}

			Texture2D _CookieTex;
			SamplerState sampler_CookieTex;
			float _Intensity;
			float3 _Color;

			Texture2D _VolumeFogTex;
			SamplerState sampler_VolumeFogTex;
			float _VolumeThickness;

			int _FrameId;

			#ifdef SHADOWS_ON
			TextureCube<float> _ShadowTex;
			//SamplerState sampler_ShadowTex;
			
			SamplerComparisonState linear_mirror_compare_sampler;/*
			{
				// sampler state
				Filter = COMPARISON_MIN_MAG_LINEAR_MIP_POINT;
				AddressU = MIRROR;
				AddressV = MIRROR;

				// sampler comparison state
				ComparisonFunc = LESS;
			};*/

			float _ShadowBias = 0.1;
			
			float SampleShadow(float3 lightPosition, float3 pixelPosition, float distToPixel) {
				float3 toPosition = pixelPosition - lightPosition;
				float cmpValue = length(toPosition);
				//float shadow = _ShadowTex.Sample(sampler_ShadowTex, toPosition);
				//return (shadow <= cmpValue - 0.01) ? 0.0 : 1.0;
				return 1.0 - _ShadowTex.SampleCmp(linear_mirror_compare_sampler, toPosition, cmpValue - _ShadowBias * distToPixel);
			}
			#endif

			float4 frag(Varyings i) : SV_TARGET{
				float4 color = float4(0, 0, 0, 0);

				float4 clipPos = TransformWorldToClip(i.worldPos);
				float2 screenPos = clipPos.xy / clipPos.w * 0.5 + float2(0.5, 0.5);
				if (_ProjectionParams.x < 0) screenPos.y = 1.0 - screenPos.y;
				float2 pixelCoords = screenPos * _ScreenSize;

				int2 checkerCoords = int2(floor((pixelCoords.x + _FrameId) % 2), floor((pixelCoords.y + 1) % 2));
				//return float4(checkerCoords.x, checkerCoords.y, 0, 0);

				if (checkerCoords.x + checkerCoords.y != 1) discard;


				float3 position = SAMPLE_POSITION(screenPos);

				float cull = Cull(position, i.origin);

				float3 ldir = position - i.origin;

				float sqrDist = SqrLength(ldir);

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

				float3 lcolor = _Color * _Intensity;

				float invRange = 1.0 / (_Range * _Range);

				float atten = 1.0 - clamp(sqrDist * invRange, 0, 1);

				#ifdef SHADOWS_ON
				float shadow = SampleShadow(i.origin, position, sqrDist);
				//shadow = shadow < 0.5 ? 0.0 : 1.0;
				atten *= shadow;
				//color = float4(SampleShadow(i.origin, position), 0.5, 0, 1);
				//return color;
				#endif

				float oneMinusMetallic = clamp(1.0 - metallic, 0.04, 1.0);

				//diffuse = diffuse < 0.2 ? 0.0 : 1.0;
				//specular = specular < 0.5 ? 0.0 : 1.0;
				//atten = atten < 0.1 ? 0.0 : 1.0;

				// Volumetrics
				float3 lvolume = float3(1.0, 1.0, 1.0);
				float fogDensity = _VolumeFogTex.SampleLevel(sampler_VolumeFogTex, screenPos.xy + float2(_Time, 0.0), 0).r;
				fogDensity += _VolumeFogTex.SampleLevel(sampler_VolumeFogTex, screenPos.xy + float2(-_Time, 0.5), 0).r;
				lvolume *= clamp(fogDensity, 0.0, 1.0);
				lvolume *= _VolumeThickness;
				float maxDist = SqrLength(i.origin - i.worldPos);
				view = normalize(view);
				float2 intersections = RaySphereIntersect(worldSpaceCameraPos, view, i.origin, _Range);
				float3 i1 = worldSpaceCameraPos + view * intersections.x;
				float3 i2 = worldSpaceCameraPos + view * intersections.y;
				float fogTravel = SqrLength(i1 - i2);
				fogTravel = fogTravel * invRange;
				float fogReduce = (1.0 - SqrLength((i1 + i2) * 0.5 - i.origin) * invRange);
				fogTravel *= pow(fogReduce, 20) * 0.1 + fogReduce * 0.05;
				lvolume *= clamp(fogTravel, 0.0, 1.0);
				lvolume *= clamp(intersections.x + 1.0, 0.0, 1.0);
				lvolume *= 1.0 - clamp(SqrLength(i.origin - worldSpaceCameraPos) - SqrLength(position - worldSpaceCameraPos), 0.0, 1.0);

				color.rgb +=
					diffuse * lcolor * albedo * oneMinusMetallic
					+ specular * lcolor * oneMinusMetallic
					+ specular * lcolor * albedo * metallic
					;

				color.rgb += Transluency(position, backDepth, ldir, normal, transluency.rgb * lcolor, transluency.a);

				color *= atten;
				color *= cull;
				
				color.rgb += lvolume * lcolor;

				return color;
			}

			ENDHLSL
        }
    }
}
