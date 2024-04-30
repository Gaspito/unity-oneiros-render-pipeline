Shader "Hidden/TerrainLayersBlit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off 
        ZWrite Off 
        ZTest Always

        HLSLINCLUDE
        #include "Assets/Oneiros Render Pipeline/Shaders/ShaderCore.hlsl"

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

        v2f vert(appdata v)
        {
            v2f o;
            float3 worldPosition = TransformObjectToWorld(v.vertex.xyz);
            o.vertex = TransformWorldToClip(worldPosition);
            o.uv = v.uv;
            return o;
        }
        ENDHLSL

        Pass
        {
            Name "Separate"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            Texture2D<float4> _IndexMap;
            Texture2D<float4> _WeightsMap;
            SamplerState sampler_IndexMap;
            uniform int _LayerIndex;

            float frag(v2f i) : SV_Target
            {
                int4 indices = (int4)_IndexMap.Sample(sampler_IndexMap, i.uv);
                float4 weights = _WeightsMap.Sample(sampler_IndexMap, i.uv);
                
                if (_LayerIndex == indices.x) return weights.x;
                if (_LayerIndex == indices.y) return weights.y;
                if (_LayerIndex == indices.z) return weights.z;
                if (_LayerIndex == indices.w) return weights.w;

                return 0.0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Combine Indices"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            Texture2DArray<float> _Layers;
            SamplerState sampler_Layers;
            int _LayerCount;

            float4 frag(v2f i) : SV_Target
            {
                int indices[] = {0, 0, 0, 0};
                int count = 0;

                [loop]
                for (int layerId = 0; layerId < _LayerCount; layerId++)
                {
                    float weight = _Layers.Sample(sampler_Layers, float3(i.uv, layerId));
                    if (weight > 0.1) 
                    {
                        indices[count] = layerId;
                        count++;
                        if (count >= 4) break;
                    }
                }
                return float4(indices[0], indices[1], indices[2], indices[3]);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Combine Weights"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            Texture2DArray<float> _Layers;
            SamplerState sampler_Layers;
            int _LayerCount;

            float4 frag(v2f i) : SV_Target
            {
                float weights[] = {0, 0, 0, 0};
                int count = 0;

                [loop]
                for (int layerId = 0; layerId < _LayerCount; layerId++)
                {
                    float weight = _Layers.Sample(sampler_Layers, float3(i.uv, layerId));
                    if (weight > 0.1) 
                    {
                        weights[count] = weight;
                        count++;
                        if (count >= 4) break;
                    }
                }
                return float4(weights[0], weights[1], weights[2], weights[3]);
            }
            ENDHLSL
        }
    }
}
