Shader "LOCAL/Procedural/Additive FX"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_MainColor ("Tint", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" }
        LOD 100

        Pass
        {
			Name "Main"
			Blend One One
			ZWrite Off
			Tags {"LightMode"="Transparent FX" "Queue"="Transparent+100"}

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

			//void ConfigureProcedural(uint instanceId, out float4x4 obj2World, out float lifetime)
			void ConfigureProcedural()
			{
				int id = unity_InstanceID;
				float3 position = _OutputBuffer[id].position;
				float lifetime = _OutputBuffer[id].lifetime;

				float scale = 0.3;

				float3 view = GetCameraView(position);
				float4x4 obj2World = LookAtMatrix(-view, float3(0, 1, 0));
				obj2World = ScaleMatrix(obj2World, float3(1, 1, 1) * scale);
				obj2World = TranslateMatrix(obj2World, position);

				unity_ObjectToWorld = obj2World;
			}

			FragmentInput vert(VertexInput i) {

				FragmentInput o;
				UNITY_SETUP_INSTANCE_ID(i);
				UNITY_TRANSFER_INSTANCE_ID(i, o);
				
				int id = unity_InstanceID;
				float4x4 obj2World = unity_ObjectToWorld;
				float lifetime = _OutputBuffer[id].lifetime;
				//ConfigureProcedural(unity_InstanceID, obj2World, lifetime);

				o.worldPosition = mul(obj2World, float4(i.position, 1)).xyz;

				o.clipPosition = TransformWorldToClip(o.worldPosition);

				o.normal = mul((float3x3)obj2World, i.normal);
				o.uv = i.uv;
				o.color = float3(1, 1, 1) * lifetime;
				return o;
			}

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainColor;

			float4 frag(FragmentInput i) : SV_TARGET
			{
				i.uv = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
				float4 color = tex2D(_MainTex, i.uv) * _MainColor;
				if (i.color.r == 1.0) discard;
				color.rgb *= 1.0 - i.color.r;
				if (color.a < 0.1) discard;
				return color;
			}

			ENDHLSL
        }
    }
}
