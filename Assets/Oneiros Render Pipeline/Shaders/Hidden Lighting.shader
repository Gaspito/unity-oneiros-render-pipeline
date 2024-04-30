Shader "Hidden/PBLighting"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
			Name "Diffuse"

			Blend One Zero

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 5.0

			#include "ShaderCore.hlsl"
			#include "Shadows.hlsl"

			#define DIRECTIONAL_LIGHT 0
			#define POINT_LIGHT 1

			struct Light {
				int type;
				float3 position;
				float3 direction;
				float3 color;
				float sqrRange;
				float intensity;
				int shadowId;
			};

			int in_light_count = 0;
			StructuredBuffer<Light> in_lights;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
				float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
				o.vertex = TransformWorldToClip(worldPos);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;

			Texture2D positionTarget;
			Texture2D albedoTarget;
			Texture2D normalTarget;
			Texture2D reflectionTarget;

			SamplerState sampler_positionTarget;
			
			float LambertDiffuse(float3 normal, float3 ldir) {
				float ndotl = dot(normal, normalize(-ldir));
				if (ndotl <= 0.0) return 0.0;
				return clamp(ndotl, 0.0, 1.0);
			}

			float GetDirectionalShadow(float3 position, int shadowId) {
				if (shadowId < 0) return 1.0;
				return SampleDirectionalShadowAtlas(shadowId, position);
			}

			float PhongSpecular(float3 normal, float3 ldir, float3 view, float smoothness) {
				if (smoothness <= 0.0) return 0.0;
				float3 lreflect = reflect(ldir, normal);
				float rdotv = dot(normalize(-lreflect), view);
				return pow(clamp(rdotv, 0.0, 1.0), smoothness) * smoothness * 0.01;
			}

            float4 frag (v2f i) : SV_Target
            {
				float3 position = positionTarget.Sample(sampler_positionTarget, i.uv).xyz;
				float4 albedo = albedoTarget.Sample(sampler_positionTarget, i.uv);
				float3 normal = normalTarget.Sample(sampler_positionTarget, i.uv).xyz;
				float3 reflections = reflectionTarget.Sample(sampler_positionTarget, i.uv).xyz;

				float smoothness = reflections.x;
				float metallic = reflections.y;
				float oneMinusMetallic = 1.0 - metallic;

				normal = normalize(normal);

				float3 viewDir = normalize(position - worldSpaceCameraPos);
				
				float3 diffuse = float3(0, 0, 0);
				float3 specular = float3(0, 0, 0);

				[loop]
				for (int lightId = 0; lightId < in_light_count; lightId++)
				{
					Light light = in_lights[lightId];
					/*
					if (light.type == POINT_LIGHT) {
						float3 ldir = position - light.position;
						float ldist = SqrLength(ldir);
						if (ldist > light.sqrRange) continue;
						float range = 1.0 - clamp(ldist / light.sqrRange, 0.0, 1.0);
						float lambert = LambertDiffuse(normal, ldir);
						if (lambert <= 0.0) continue;
						float atten = lambert * range;
						float3 lcolor = light.color * light.intensity;
						float3 ldiff = lcolor * atten;
						float3 lspec = lcolor * PhongSpecular(normal, ldir, viewDir, smoothness);
						float3 lmetal = albedo.rgb * metallic + float3(1, 1, 1) * oneMinusMetallic;
						diffuse += ldiff * albedo.rgb * oneMinusMetallic;
						specular += atten * lspec * lmetal;
					}
					*/
					if (light.type == DIRECTIONAL_LIGHT) {
						float3 ldir = normalize(light.direction);
						float lambert = LambertDiffuse(normal, ldir);
						if (lambert <= 0.0) continue;
						float atten = lambert * GetDirectionalShadow(position, light.shadowId);
						if (atten <= 0.0) continue;
						float3 lcolor = light.color * light.intensity;
						float3 ldiff = lcolor * atten;
						float3 lspec = lcolor * PhongSpecular(normal, ldir, viewDir, smoothness);
						float3 lmetal = albedo.rgb * metallic + float3(1, 1, 1) * oneMinusMetallic;
						diffuse += ldiff * albedo.rgb * oneMinusMetallic;
						specular += atten * lspec * lmetal;
					}
				}

				return float4(diffuse + specular, 1.0);
            }
            ENDHLSL
        }
    }
}
