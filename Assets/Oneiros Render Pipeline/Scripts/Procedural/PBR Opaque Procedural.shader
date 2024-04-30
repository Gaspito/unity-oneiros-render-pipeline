Shader "LOCAL/Procedural/Opaque"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_MainColor ("Tint", Color) = (1,1,1,1)
		_Smoothness("Smoothness", range(0, 100)) = 10
		_Metallic("Metallic", range(0, 1)) = 0
		[HideInInspector] _DitherTex("Dithering", 2D) = "transparent" {}
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
			Tags {"LightMode"="PBROpaque"}

			HLSLPROGRAM
			#pragma multi_compile_instancing
			#pragma vertex vert
			#pragma fragment frag
			#pragma instancing_options procedural:ConfigureProcedural
			#pragma target 4.5

			#define VERTEX_COLOR
			#define UNITY_PROCEDURAL_INSTANCING_ENABLED

			#include "../../Shaders/ShaderCore.hlsl"
			#include "../../Shaders/Matrices.hlsl"

			struct ComputeOutput
			{
				float3 position;
				float lifetime;
			};

			StructuredBuffer<ComputeOutput> _OutputBuffer;

			void ConfigureProcedural(uint instanceID, out float4x4 obj2World, out float lifetime)
			{
				int id = instanceID;
				float3 position = _OutputBuffer[id].position;
				lifetime = _OutputBuffer[id].lifetime;

				float scale = 0.3;

				float3 view = GetCameraView(position);
				obj2World = LookAtMatrix(-view, float3(0, 1, 0));
				obj2World = ScaleMatrix(obj2World, float3(1, 1, 1) * scale);
				obj2World = TranslateMatrix(obj2World, position);
			}

			FragmentInput vert(VertexInput i) {

				FragmentInput o;
				UNITY_SETUP_INSTANCE_ID(i);
				UNITY_TRANSFER_INSTANCE_ID(i, o);
				
				float4x4 obj2World;
				float lifetime;
				ConfigureProcedural(i.instanceID, obj2World, lifetime);

				o.worldPosition = mul(obj2World, float4(i.position, 1)).xyz;

				o.clipPosition = TransformWorldToClip(o.worldPosition);

				o.normal = o.worldPosition - mul(obj2World, float4(i.normal, 0));

				o.color = float3(1, 0, 0) * lifetime;

				o.uv = i.uv;
				return o;
			}

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainColor;

			float _Smoothness;
			float _Metallic;

			sampler2D _DitherTex;

			bool Dither(float alpha, float2 screenPos) {
				return (tex2Dlod(_DitherTex, float4(screenPos, 0, 0)).r <= 1.0 - alpha);
			}

			FragmentOutput frag(FragmentInput i){

				FragmentOutput o;
				UNITY_SETUP_INSTANCE_ID(i);
				i.uv = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
				o.albedo.rgb = _MainColor.rgb;
				o.albedo.a = tex2D(_MainTex, i.uv).r * (1.0 - i.color.r);
				
				if (Dither(o.albedo.a, GetScreenPos(i.clipPosition))) discard;

				o.position = i.worldPosition;

				o.normal = normalize(i.normal); 

				o.reflections = float3(_Smoothness, _Metallic, 0);

				o.transluency = float4(0, 0, 0, 20);

				return o;
			}

			ENDHLSL
        }
    }
}
