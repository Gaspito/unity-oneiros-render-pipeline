Shader "LOCAL/RIG/Desire Body"
{
    Properties
    {
		_MaskTex("Mask", 2D) = "black" {}
		_BuffAmount("Buff Amount", range(0, 0.3)) = 0
		_MainTex ("Texture", 2D) = "white" {}
		_MainColor ("Tint", Color) = (1,1,1,1)
		_BumpTex("Normal", 2D) = "bump" {}
		_Smoothness ("Smoothness", range(0, 100)) = 10
		_Metallic ("Metallic", range(0, 1)) = 0
		_TransluencyColor("Transluency Color", Color) = (1,1,1,1)
		_Density("Density", range(0,20)) = 0
		_OutlineWidth ("Outline Width", range(0,10)) = 2
		_OutlineColor ("Outline Color", Color) = (0,0,0,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

		HLSLINCLUDE
		#define RIG_SHADER
		#define BINORMAL
		#include "../ShaderCore.hlsl"

		sampler2D _MaskTex;
		float _BuffAmount;

		FragmentInput VertexPostProcess(VertexInput i, FragmentInput o)
		{
			float pecsBuff = tex2Dlod(_MaskTex, float4(o.uv, 0, 0)).r;
			pecsBuff *= _BuffAmount;
			pecsBuff *= abs(cos(_Time * 10));
			o.worldPosition += o.normal * pecsBuff;
			return o;
		}

		#define VS_POST_PROCESS(i, o) o = VertexPostProcess(i, o);

		ENDHLSL

		Pass
        {
			Name "Main"
			Blend One Zero
			ZWrite On
			Tags {"LightMode"="PBROpaque"}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#define RIG_SHADER
			#define BINORMAL

			#include "../ShaderCore.hlsl"

			FragmentInput vert(VertexInput i) {

				int blendIndices[4];
				float blendWeights[4];

				GetBlendValues(i.blendIndices, i.blendWeights, blendIndices, blendWeights);

				FragmentInput o;

				o.worldPosition = BlendPosition(i.position, blendIndices, blendWeights);

				o.normal = TransformNormalToWorld(i.normal);
				o.tangent = TransformNormalToWorld(i.tangent);
				o.binormal = cross(o.normal, o.tangent);
				o.uv = i.uv;

				#if defined(VS_POST_PROCESS)
				VS_POST_PROCESS(i, o)
				#endif

				o.clipPosition = TransformWorldToClip(o.worldPosition);
				return o;
			}

			sampler2D _MainTex;
			float4 _MainColor;

			sampler2D _BumpTex;

			float _Smoothness;
			float _Metallic;

			float4 _TransluencyColor;
			float _Density;

			FragmentOutput frag(FragmentInput i){
				FragmentOutput o;
				o.albedo = tex2D(_MainTex, i.uv) * _MainColor;
				if (o.albedo.a < 0.1) discard;
				o.position = i.worldPosition;
				
				float3 normalmap = tex2D(_BumpTex, i.uv).xyz;
				normalmap = normalmap * 2.0 - 1.0;
				float3 normal = normalmap.x * normalize(i.tangent)
					+ normalmap.y * normalize(i.binormal)
					+ normalmap.z * normalize(i.normal);
				o.normal = normalize(normal);

				o.reflections = float3(_Smoothness, _Metallic, 0);
				o.transluency = float4(_TransluencyColor.rgb, _Density);
				return o;
			}

			ENDHLSL
        }
		UsePass "LOCAL/RIG/Outline/Outline"
        
		//UsePass "SHADOWS/Casters/Opaque"
    }
}
