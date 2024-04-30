Shader "LOCAL/LIGHT/Directional Light"
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
			Name "Main"

			Blend One One
			ZWrite Off
			ZTest Always

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature LIGHTING_ON
			#pragma target 5.0

			#include "Lighting.hlsl"

			float3 SampleCookieAtPos(float3 position, Texture2D tex, SamplerState samp, int level) {
				float3 lightSpacePos = TransformWorldToObject(position);
				float2 cookiePos = lightSpacePos.xy / lightSpacePos.z + float2(0.5, 0.5);
				cookiePos.x = clamp(cookiePos.x, 0, 1);
				cookiePos.y = clamp(cookiePos.y, 0, 1);
				return tex.SampleLevel(samp, cookiePos, level).rgb;
			}

			//#ifdef SHADOWS_ON
			Texture2D<float> _ShadowTex;
			float4x4 _ShadowProjection;

			sampler2D _DitherTex;

			SamplerComparisonState linear_mirror_compare_sampler;
			SamplerState linear_mirror_sampler;

			float _ShadowBias = 0.1;

			float2 DisplaceSamplePos(float2 pos, float2 vect, float disp) {
				float r = tex2Dlod(_DitherTex, float4(vect * 0.1, 0, 0)).r - 0.5;
				float2 d = float2(cos(r), sin(r));
				pos += d * disp * r;
				return pos;
			}

			float SampleShadow(float2 cookiePos, float distTolight) {
				float2 shadowCoords = cookiePos;
				float cmpValue = distTolight;
				return 1.0 - _ShadowTex.SampleCmp(linear_mirror_compare_sampler, shadowCoords, cmpValue - _ShadowBias * distTolight);
				//return _ShadowTex.SampleLevel(linear_mirror_sampler, shadowCoords, 0) / _Range;
			}

			float SampleFullShadow(float2 cookiePos) {
				return _ShadowTex.Sample(linear_mirror_sampler, cookiePos);
				//return _ShadowTex.SampleLevel(linear_mirror_sampler, shadowCoords, 0) / _Range;
			}
			//#endif

			struct VertexData {
				float4 position : POSITION;
				float2 texcoord : TEXCOORD0;
			};

			struct Varyings {
				float4 clipPosition : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldPosition : TEXCOORD1;
				float3 dir : NORMAL;
			};

			Varyings vert(VertexData i) {
				Varyings o;

				o.clipPosition = i.position;
				o.uv = i.texcoord;
				o.worldPosition = TransformObjectToWorld(float3(0, 0, 0));
				o.dir = TransformNormalToWorld(float3(0, 0, 1));

				return o;
			}

			float _Intensity;
			float3 _Color;
			float3 _LightDirection;

			int _FrameId;

			float4 frag(Varyings i) : SV_TARGET{
				float4 color = float4(0, 0, 0, 0);

				float2 screenPos = i.uv;
				if (_ProjectionParams.x > 0) screenPos.y = 1.0 - screenPos.y;
				float2 pixelCoords = screenPos * _ScreenSize;

				int2 checkerCoords = int2(floor((pixelCoords.x + _FrameId) % 2), floor((pixelCoords.y + 1) % 2));
				//return float4(checkerCoords.x, checkerCoords.y, 0, 0);

				if (checkerCoords.x + checkerCoords.y != 1) discard;

				

				float3 position = SAMPLE_POSITION(screenPos);

				float3 ldir = normalize(i.dir);

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

				float atten = 1.0;

				float rshadow = _ShadowTex.Sample(CUSTOM_GLOBAL_SAMPLER, i.uv.xy).x;
				//atten *= rshadow * _ShadowBias;

				//float3 lightPixelPos = TransformWorldToObject(position.xyz);
				float3 lightPixelPos = TransformWorldToObject(position.xyz);
				float4 shadowProjectPos = mul(_ShadowProjection, float4(position.xyz, 1.0));

				float2 shadowMapPos = shadowProjectPos.xy * 0.05 + float2(0.5, 0.5);
				//float shadow = SampleFullShadow(shadowMapPos, lightPixelPos.z );
				//float shadow = SampleShadow(shadowMapPos, lightPixelPos.z * 0.01 );
				float lightDistance = distance(i.worldPosition, position);
				float sharpShadow = SampleShadow(shadowMapPos, lightDistance * 0.001 ) * 5;
				float softShadow = 0;
				float shadowDisp = 0.007;
				softShadow += SampleShadow(DisplaceSamplePos(shadowMapPos, pixelCoords, shadowDisp), lightDistance * 0.001);
				softShadow += SampleShadow(DisplaceSamplePos(shadowMapPos, pixelCoords + float2(1, 1), shadowDisp), lightDistance * 0.001);
				softShadow += SampleShadow(DisplaceSamplePos(shadowMapPos, pixelCoords + float2(-1, 1), shadowDisp), lightDistance * 0.001);
				softShadow += SampleShadow(DisplaceSamplePos(shadowMapPos, pixelCoords + float2(1, -1), shadowDisp), lightDistance * 0.001);
				softShadow += SampleShadow(DisplaceSamplePos(shadowMapPos, pixelCoords + float2(-1, -1), shadowDisp), lightDistance * 0.001);
				float shadow = sharpShadow * 0.3 + softShadow * 0.7;
				shadow *= 0.2;
				if (shadowMapPos.x < 0.0 || shadowMapPos.x > 1.0 || shadowMapPos.y < 0.0 || shadowMapPos.y > 1.0) {
					shadow = 1.0;
				}

				atten *= 0.01 + shadow * 1.0;

				float oneMinusMetallic = clamp(1.0 - metallic, 0.04, 1.0);

				color.rgb +=
					diffuse * lcolor * albedo * oneMinusMetallic
					+ specular * lcolor * oneMinusMetallic
					+ specular * lcolor * albedo * metallic
					;

				color.rgb += Transluency(position, backDepth, ldir, normal , transluency.rgb * lcolor, transluency.a);

				color *= clamp(atten, 0.0, 1.0);

				return color;
			}

			ENDHLSL
        }
    }
}
