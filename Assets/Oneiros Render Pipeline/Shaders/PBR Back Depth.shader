Shader "Hidden/Opaque Back Depth"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
			Name "Main"
			Blend One Zero
			ZWrite On
			Cull Front
			Tags {"LightMode"="Back Depth"}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "ShaderCore.hlsl"

			struct Attributes
			{
				float4 position : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct Varyings
			{
				float2 uv : TEXCOORD0;
				float depth : TEXCOORD1;
				float4 clipPosition : SV_POSITION;
			};

			Varyings vert(Attributes i) {
				Varyings o;
				float3 worldPosition = TransformObjectToWorld(i.position);
				o.depth = distance(worldPosition, worldSpaceCameraPos);
				o.clipPosition = TransformWorldToClip(worldPosition);
				o.uv = i.uv;
				return o;
			}

			sampler2D _MainTex;

			float frag(Varyings i) : SV_TARGET
			{
				
				return i.depth;
			}

			ENDHLSL
        }

		UsePass "SHADOWS/Casters/Opaque"
    }
}
