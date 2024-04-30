Shader "LOCAL/Effects/Apparate"
{
	Properties
	{
		_SrcRenderTex("Texture In", 2D) = "white" {}
		_DestRenderTex("Texture Out", 2D) = "white" {}
		_TimeDispTex("Time Displacement Texture", 2D) = "black" {}
		_PlaybackTime("Time", range(0, 1)) = 0.5
		_Duration("Duration", float) = 3
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "DisableBatching" = "True"}

		Pass
		{
			Name "Main"
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off
			ZTest Always
			Cull Front
			Tags {"LightMode" = "Transparent" "Queue"="Transparent-10"}

			HLSLPROGRAM
			#pragma target 4.6
			#pragma vertex common_vert
			#pragma fragment frag
			//#pragma shader_feature DENSITY_MASK
			//#pragma multi_compile_instancing
				
			//#define LIGHTMAP_ON

			#include "Assets/Oneiros Render Pipeline/Shaders/ShaderCore.hlsl"

			// included in common pass

			#include "Assets/Oneiros Render Pipeline/Shaders/Lighting.hlsl"
			#include "Assets/Oneiros Render Pipeline/Shaders/CommonPasses.hlsl"

			Texture2D _SrcRenderTex;
			Texture2D _DestRenderTex;
			SamplerState sampler_DestRenderTex;

			sampler2D _TimeDispTex;

			float _Duration;

			static float2 Center;

			float2 Zoom(float2 uv, float time) {
				float2 offset = uv - Center;
				float magnitude = length(offset);
				time *= 2;
				time = time > 1 ? 1 - time + 1 : time;
				time *= 0.5;
				float strength = magnitude * (1.0 + time);
				float2 zoom = Center + normalize(offset)  * strength;
				uv = lerp(zoom, uv, magnitude * magnitude);
				return uv;
			}

			float2 Twirl(float2 uv, float time) {
				float magnitude = distance(uv, Center);
				float angle = time * (radians(360) + lerp(radians(magnitude * 360), 0, time));
				float2x2 rotation = { float2(cos(angle), sin(angle)),
									float2(-sin(angle), cos(angle)) };
				float2 twirledUV = mul(rotation, uv - Center) + Center;
				uv = lerp(uv, twirledUV, magnitude);
				return uv;
			}

			float _PlaybackTime;
			
			float4 frag(FragmentInput i) : SV_TARGET {
				float4 o = float4(1, 0.5, 1, 1);

				//float time = frac(_Time / _Duration * 30);
				float time = _PlaybackTime;

				float2 screenPosition = WorldToScreenPos(i.worldPosition);

				float timeDisp = tex2D(_TimeDispTex, screenPosition).r;
				timeDisp *= time < 0.2 ? lerp(0, 1, time * 5) : 1;
				timeDisp *= time > 1.0 - 0.2 ? lerp(1, 0, (time - 1.0 + 0.2) * 5) : 1;
				time += timeDisp * 0.1;

				//Center = float2(0.5, 0.2);
				Center = WorldToScreenPos(i.TransformObjectToWorld(float3(0,0,0)));

				float2 uv = screenPosition;
				uv = Zoom(uv, time);
				uv = Twirl(uv, time);

				float4 src = _SrcRenderTex.Sample(sampler_DestRenderTex, uv);
				float4 dest = _DestRenderTex.Sample(sampler_DestRenderTex, uv);

				o = lerp(src, dest, time);
				
				return o;
			}

			ENDHLSL
		}
	}
}
