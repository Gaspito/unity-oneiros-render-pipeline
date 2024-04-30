Shader "LOCAL/PBR Two Sided"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_MainColor ("Tint", Color) = (1,1,1,1)
		_Smoothness("Smoothness", range(0, 100)) = 10
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
			Cull Off

			Tags {"LightMode" = "PBROpaque"}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "ShaderCore.hlsl"

			FragmentInput vert(VertexInput i) {
				FragmentInput o;
				o.worldPosition = TransformObjectToWorld(i.position);
				o.clipPosition = TransformWorldToClip(o.worldPosition);
				o.normal = TransformNormalToWorld(i.normal);
				o.uv = i.uv;
				return o;
			}

			sampler2D _MainTex;
			float4 _MainColor;

			float _Smoothness;

			FragmentOutput frag(FragmentInput i) {
				FragmentOutput o;
				o.albedo = tex2D(_MainTex, i.uv) * _MainColor;
				if (o.albedo.a < 0.1) discard;
				o.position = i.worldPosition;
				o.normal = i.normal;
				o.reflections = float3(_Smoothness, 0, 0);
				return o;
			}

			ENDHLSL
		}
    }
}
