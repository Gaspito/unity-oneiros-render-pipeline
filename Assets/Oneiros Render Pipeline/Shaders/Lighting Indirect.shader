Shader "LOCAL/LIGHT/Indirect Light"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_MainColor("Tint", Color) = (1,1,1,1)
	}
		SubShader
		{
			Tags { "RenderType" = "Light" }
			LOD 100

			HLSLINCLUDE

			#include "ShaderCore.hlsl"

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

				if (_ProjectionParams.x < 0) o.uv.y = 1.0 - o.uv.y;

				return o;
			}

			ENDHLSL

			Pass
		{
			Name "Stencil Broad"
			Blend One Zero
			ZWrite Off
			Cull Front
			ZTest LEqual
			ColorMask 0
			Stencil {
				Ref 1
				Comp Greater
				Pass Keep
				Fail Keep
				ZFail Replace
			}
			Tags {"LightMode" = "LightStencil"}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Lighting.hlsl"

			float4 frag(Varyings i) : SV_TARGET
			{
				return float4(1,0,0,0);
			}
			ENDHLSL
		}

		Pass
		{
			Name "Stencil Narrow"
			Blend One Zero
			ZWrite Off
			Cull Back
			ZTest GEqual
			ColorMask 0
			Stencil {
				Ref 1
				Comp Equal
				Pass Zero
			}
			Tags {"LightMode" = "LightStencil"}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Lighting.hlsl"

			float4 frag(Varyings i) : SV_TARGET
			{
				return float4(0,0,1,0);
			}
			ENDHLSL
		}

			Pass
			{
				Name "Indirect Color"
				Blend One One
				ZWrite Off
				ZTest Always
				Cull Front
				Stencil {
					Ref 1
					Comp Equal
					Pass IncrSat
					Fail Keep
				}
				Tags {"LightMode" = "LightCaster"}

				HLSLPROGRAM
				#pragma vertex vert
				#pragma fragment frag

				#include "Lighting.hlsl"

				TextureCube _environment;
				SamplerState sampler_environment;
				float _environmentStrength;

				float4 frag(Varyings i) : SV_TARGET{
					float4 color = float4(0, 0, 0, 0);

					float4 clipPos = TransformWorldToClip(i.worldPos);
					float2 screenPos = clipPos.xy / clipPos.w * 0.5 + float2(0.5, 0.5);
					if (_ProjectionParams.x < 0) screenPos.y = 1.0 - screenPos.y;

					if (SAMPLE_ALPHA(screenPos) < 0.5) discard;

					float3 position = SAMPLE_POSITION(screenPos);
					float3 normal = SAMPLE_NORMAL(screenPos);
					float3 view = GetCameraView(position);

					float3 reflections = SAMPLE_REFLECTION(screenPos);
					float smoothness = reflections.x;
					float metallic = reflections.y;
					float roughness = 1.0 - smoothness * 0.01f;

					float3 albedo = SAMPLE_ALBEDO(screenPos);

					float3 uvw = reflect(view, normal);

					float mip = 7 * roughness;
					int mipLow = floor(mip);
					int mipHigh = ceil(mip);
					float mipLerp = mip - mipLow;

					float3 lcolor = lerp(_environment.SampleLevel(sampler_environment, uvw, mip).rgb,
						_environment.SampleLevel(sampler_environment, uvw, mip).rgb,
						mipLerp);

					color.rgb += lcolor * metallic;
					color.rgb *= _environmentStrength;

					return color;
				}

				ENDHLSL
			}

			Pass
			{
				Name "Sky Indirect"
				Blend One One
				ZWrite Off
				ZTest Always
				Cull Front
				Stencil {
					Ref 2
					Comp NotEqual
					Pass Keep
					Fail Keep
				}
				Tags {"LightMode" = "LightCaster"}

				HLSLPROGRAM
				#pragma vertex vert
				#pragma fragment frag

				#include "Lighting.hlsl"

				TextureCube _environment;
				SamplerState sampler_environment;
				float _environmentStrength;

				float4 frag(Varyings i) : SV_TARGET{
					float4 color = float4(0, 0, 0, 0);

					float4 clipPos = TransformWorldToClip(i.worldPos);
					float2 screenPos = clipPos.xy / clipPos.w * 0.5 + float2(0.5, 0.5);
					if (_ProjectionParams.x < 0) screenPos.y = 1.0 - screenPos.y;

					if (SAMPLE_ALPHA(screenPos) < 0.5) discard;

					float3 position = SAMPLE_POSITION(screenPos);
					float3 normal = SAMPLE_NORMAL(screenPos);
					float3 view = GetCameraView(position);

					float3 reflections = SAMPLE_REFLECTION(screenPos);
					float smoothness = reflections.x;
					float metallic = reflections.y;
					float roughness = 1.0 - smoothness * 0.01f;

					float3 albedo = SAMPLE_ALBEDO(screenPos);

					float mip = roughness * 7;
					int mipLow = floor(mip);
					int mipHigh = ceil(mip);
					float mipLerp = mip - mipLow;

					float3 uvw = reflect(view, normal);

					float3 specular = lerp(_environment.SampleLevel(sampler_environment, uvw, mip).rgb,
						_environment.SampleLevel(sampler_environment, uvw, mip).rgb,
						mipLerp) * smoothness * 0.01;

					uvw = normal;

					float3 diffuse = albedo * lerp(_environment.SampleLevel(sampler_environment, uvw, mip).rgb,
						_environment.SampleLevel(sampler_environment, uvw, mip).rgb,
						mipLerp);

					float oneMinusMetallic = clamp(1.0 - metallic, 0.04, 1.0);

					color.rgb += diffuse * _environmentStrength * oneMinusMetallic;
					color.rgb += specular * _environmentStrength * oneMinusMetallic;
					color.rgb += specular * _environmentStrength * albedo * metallic;

					return color;
				}

				ENDHLSL
			}

			Pass
			{
				Name "Sky"
				Blend One Zero
				ZWrite Off
				ZTest LEqual
				Cull Off
				Tags {"LightMode" = "LightCaster"}

				HLSLPROGRAM
				#pragma vertex vert
				#pragma fragment frag

				#define CUSTOM_GLOBAL_SAMPLER sampler_albedoTarget

				#include "Lighting.hlsl"

				TextureCube _environment;
				SamplerState sampler_environment;

				float4 frag(Varyings i) : SV_TARGET{
					float4 color = float4(0, 0, 0, 0);

					float4 clipPos = TransformWorldToClip(i.worldPos);
					float2 screenPos = clipPos.xy / clipPos.w * 0.5 + float2(0.5, 0.5);
					if (_ProjectionParams.x < 0) screenPos.y = 1.0 - screenPos.y;
					//screenPos = i.uv;

					if (SAMPLE_ALPHA(screenPos) > 0.5) discard;

					float3 view = GetCameraView(i.worldPos);
					float3 uvw = view;

					color.rgb = _environment.SampleLevel(sampler_environment, uvw, 0).rgb;

					return color;
				}

				ENDHLSL
			}

			Pass
			{
				Name "GI"
				Blend One Zero
				ZWrite Off
				ZTest Always
				Cull Off
				Tags {"LightMode" = "LightCaster"}

				HLSLPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma shader_feature LIGHTING_ON

				#define CUSTOM_GLOBAL_SAMPLER sampler_globalIlluminationTarget

				#include "Lighting.hlsl"

				float4 frag(Varyings i) : SV_TARGET{
					float4 color = float4(0, 0, 0, 0);
					discard;

					#ifndef LIGHTING_ON
					return color;
					#else
					float4 clipPos = TransformWorldToClip(i.worldPos);
					float2 screenPos = clipPos.xy / clipPos.w * 0.5 + float2(0.5, 0.5);
					if (_ProjectionParams.x < 0) screenPos.y = 1.0 - screenPos.y;

					if (SAMPLE_ALPHA(screenPos) < 0.01) return color;

					if (SAMPLE_TEST_GI(screenPos) < 0.5) return color;

					float3 gi = SAMPLE_GI(screenPos).rgb;
					float3 albedo = SAMPLE_ALBEDO(screenPos);

					color.rgb = gi * albedo;

					return color;
					#endif
				}

				ENDHLSL
			}
		}
}
