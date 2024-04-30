Shader "LOCAL/Deferred Terrain"
{
	Properties
	{
		_TerrainLayers_Albedo ("Albedo Array", 2DArray) = "white" {}
		[Header(Tessellation)][Space(30)]
		_TessellationFactor("Factor", range(1, 64)) = 2
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		HLSLINCLUDE

		Texture2D<float> _Heightmap;

		float3 _Heightmap_Size;

		float SampleHeight(float2 uv) {
			return _Heightmap.Load(int3(uv.x * _Heightmap_Size.x, uv.y * _Heightmap_Size.y, 0)) * _Heightmap_Size.z;
		}

		float _TessellationFactor;

		ENDHLSL
		
		Pass
		{
			Name "Depth Only"
			Blend One Zero
			ZWrite On
			Tags {"LightMode" = "Depth Only"}

			HLSLPROGRAM
			#pragma target 4.6
			#pragma vertex vert
			#pragma fragment frag
			#pragma hull hull_program
			#pragma domain domain_program
			#pragma geometry geometry_program

			#define TESSELLATION_EDGE_FACTORS _TessellationFactor;
			#define TESSELLATION_IN_FACTORS _TessellationFactor;

			#include "Assets/Oneiros Render Pipeline/Shaders/ShaderCore.hlsl"
			 
			FragmentInput vert(VertexInput i) {
				FragmentInput o;
				o.worldPosition = TransformObjectToWorld(i.position);
				o.clipPosition = TransformWorldToClip(o.worldPosition);
				o.normal = TransformNormalToWorld(i.normal);
				o.uv = i.uv;
				return o;
			}

			FragmentInput on_process_geom(FragmentInput i) {
				FragmentInput o = i;
				float height = SampleHeight(i.uv);
				o.worldPosition.y += height;

				o.clipPosition = TransformWorldToClip(o.worldPosition);
				return o;
			}

			#define ON_PROCESS_GEOMETRY_INPUT(i) on_process_geom(i)

			void frag(FragmentInput i) {
				return;
			}

			#include "Assets/Oneiros Render Pipeline/Shaders/Tessellation.hlsl"
			#include "Assets/Oneiros Render Pipeline/Shaders/Geometry.hlsl"

			ENDHLSL
		}
		
		Pass
        {
			Name "Main"
			Blend One Zero
			ZWrite On
			ZTest LEqual
			Tags {"LightMode"="Deferred Base"}

			HLSLPROGRAM
			#pragma target 4.6
			#pragma vertex common_vert
			#pragma fragment frag
			#pragma hull hull_program
			#pragma domain domain_program
			#pragma geometry custom_geo
			#pragma shader_feature SAMPLE_TERRAIN_EXPLICIT

			#define BINORMAL

			#define CUSTOM_FRAGMENT_INPUT_DATA int4 layerIndices : TEXCOORD3; float4 layerWeights : TEXCOORD4;

			#define TESSELLATION_EDGE_FACTORS _TessellationFactor;
			#define TESSELLATION_IN_FACTORS _TessellationFactor;

			#include "Assets/Oneiros Render Pipeline/Shaders/GlobalIllumination.hlsl"
			#include "Assets/Oneiros Render Pipeline/Shaders/ShaderCore.hlsl"

			#ifdef SAMPLE_TERRAIN_EXPLICIT
			Texture2DArray<float> _TerrainPerLayerWeights;
			int _TerrainLayerCount = 0;
			#else
			Texture2D<int4> _TerrainLayerIndices;
			Texture2D<float4> _TerrainLayerWeights;
			#endif

			float2 _TerrainLayer_Size;

			FragmentInput on_process_geom(FragmentInput i) {
				FragmentInput o = i;

				float height = SampleHeight(i.uv);
				o.worldPosition.y += height;

				o.clipPosition = TransformWorldToClip(o.worldPosition);
				// to be modified
				o.normal = TransformNormalToWorld(i.normal);
				
				int2 coords = i.uv * _TerrainLayer_Size;

				#ifdef SAMPLE_TERRAIN_EXPLICIT
				int indices[] = { 0, 0, 0, 0 };
				float weights[] = { 0, 0, 0, 0 };
				int count = 0;
				for (uint k = 0; k < _TerrainLayerCount; k++)
				{
					float weight = _TerrainPerLayerWeights.Load(int4(coords, k, 0));
					if (weight > 0.1)
					{
						indices[count] = k;
						weights[count] = weight;
						count++;
						if (count >= 4) break;
					}
				}
				o.layerIndices = int4(indices[0], indices[1], indices[2], indices[3]);
				o.layerWeights = float4(weights[0], weights[1], weights[2], weights[3]);

				#else
				o.layerIndices = _TerrainLayerIndices.Load(int3(coords*2, 0));
				o.layerWeights = _TerrainLayerWeights.Load(int3(coords*2, 0));
				#endif

				return o;
			}

			[maxvertexcount(3)]
			void custom_geo(triangle FragmentInput input[3], inout TriangleStream<FragmentInput> OutputStream)
			{
				FragmentInput output[3];
				for (uint i = 0; i < 3; i++)
				{
					FragmentInput o = on_process_geom(input[i]);
					output[i] = o;
				}
				float3 edge01 = output[1].worldPosition - output[0].worldPosition;
				float3 edge02 = output[2].worldPosition - output[0].worldPosition;
				float3 normal = normalize(cross(edge01, edge02));

				output[0].normal = normal;
				output[1].normal = normal;
				output[2].normal = normal;

				OutputStream.Append(output[0]);
				OutputStream.Append(output[1]);
				OutputStream.Append(output[2]);

				OutputStream.RestartStrip();
			}

			Texture2DArray _TerrainLayers_Albedo;
			//Texture2DArray _TerrainLayers_Normal;

			SamplerState sampler_TerrainLayers_Albedo;

			float2 GetCoordsFromWorldNormal(float3 worldPosition, float3 worldNormal) 
			{
				float nDotX = dot(worldNormal, float3(1, 0, 0));
				float nDotY = dot(worldNormal, float3(0, 1, 0));
				float nDotZ = dot(worldNormal, float3(0, 0, 1));

				nDotX *= nDotX;
				nDotY *= nDotY;
				nDotZ *= nDotZ;

				if (nDotX > nDotY && nDotX > nDotZ) return worldPosition.zy;
				else if (nDotY > nDotX && nDotY > nDotZ) return worldPosition.xz;
				//else if (nDotZ > nDotX && nDotZ > nDotY) return worldPosition.xy;
				else return worldPosition.xy;
			}

			FragmentOutput frag(FragmentInput i) 
			{
				FragmentOutput o;

				float3 worldNormal = normalize(i.normal);

				float2 coords = GetCoordsFromWorldNormal(i.worldPosition, worldNormal);

				o.albedo = float4(0.8, 0.8, 0.8, 1);
				o.position = i.worldPosition;
				o.normal = worldNormal;
				o.reflections = float3(0, 0, 0);
				o.transluency = float4(0, 0, 0, 20);
				//o.gi = float4(0, 0, 0, 0);

				#ifdef SAMPLE_TERRAIN_EXPLICIT
				for (uint k = 0; k < _TerrainLayerCount; k++)
				{
					float4 albedo = _TerrainLayers_Albedo.Sample(sampler_TerrainLayers_Albedo, float3(coords, k));
					float weight = _TerrainPerLayerWeights.Sample(sampler_TerrainLayers_Albedo, float3(i.uv, k));
					o.albedo = lerp(o.albedo, albedo, weight);
				}

				#else
				int indices[] = {i.layerIndices.x, i.layerIndices.y, i.layerIndices.z, i.layerIndices.w};
				float weights[] = {i.layerWeights.x, i.layerWeights.y, i.layerWeights.z, i.layerWeights.w};
				 
				for (int k = 0; k < 4; k++)
				{
					int index = indices[k];
					float4 albedo = _TerrainLayers_Albedo.Sample(sampler_TerrainLayers_Albedo, float3(coords, index));
					o.albedo = lerp(o.albedo, albedo, weights[k]);
				}
				#endif

				return o;
			}

			//#define CUSTOM_VS_PASS o = vert(o);

			#include "Assets/Oneiros Render Pipeline/Shaders/Geometry.hlsl"
			#include "Assets/Oneiros Render Pipeline/Shaders/Tessellation.hlsl"
			#include "Assets/Oneiros Render Pipeline/Shaders/CommonPasses.hlsl"

			ENDHLSL
        }
    }
}
