Shader "Hidden/CheckerDepthMask"
{
    Properties
    {
    }
    SubShader
    {
        

        Pass
        {
            Cull Off ZWrite On ZTest Always
            Name "Depth Mask"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "../ShaderCore.hlsl"

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

            v2f vert (appdata v)
            {
                v2f o;
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.vertex = TransformWorldToClip(worldPos);
                o.vertex = float4(v.vertex.x, v.vertex.y, 1, 1);
                o.uv = v.uv;
                return o;
            }

            int _FrameId;

            float4 frag(v2f i) : SV_Target
            {
                float2 pixelCoords = i.uv * _ScreenSize;

                int2 checkerCoords = int2(floor((pixelCoords.x + _FrameId) % 2), floor((pixelCoords.y + 1) % 2));

                if (checkerCoords.x + checkerCoords.y == 1) discard;

                return float4(1, 0, 0, 0);
                //return float4(checkerCoords.x, checkerCoords.y,0,0);
            }
            ENDHLSL
        }

        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Blit Deferred"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "../ShaderCore.hlsl"

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
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.vertex = TransformWorldToClip(worldPos);
                o.vertex = float4(v.vertex.x, v.vertex.y, 1, 1);
                o.uv = v.uv;
                return o;
            }

            sampler2D out_diffuse;

            int _FrameId;

            float4 frag(v2f i) : SV_Target
            {
                if (_ProjectionParams.x > 0) i.uv.y = 1.0 - i.uv.y;
                float2 pixelCoords = i.uv * _ScreenSize;

                int2 checkerCoords = int2(floor((pixelCoords.x + _FrameId) % 2), floor((pixelCoords.y + 1) % 2));

                if (checkerCoords.x + checkerCoords.y != 1) discard;

                return tex2D(out_diffuse, i.uv);
                //return float4(checkerCoords.x, checkerCoords.y,0,0);
            }
            ENDHLSL
        }

        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Blit Full"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "../ShaderCore.hlsl"

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
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.vertex = TransformWorldToClip(worldPos);
                o.vertex = float4(v.vertex.x, v.vertex.y, 1, 1);
                o.uv = v.uv;
                return o;
            }

            sampler2D out_diffuse;

            int _FrameId;

            float4 frag(v2f i) : SV_Target
            {
                if (_ProjectionParams.x > 0) i.uv.y = 1.0 - i.uv.y;
                float2 pixelCoords = i.uv * _ScreenSize;

                int2 checkerCoords = int2(floor((pixelCoords.x + _FrameId) % 2), floor((pixelCoords.y + 1) % 2));

                float2 finalCoords = i.uv;
                
                if (checkerCoords.x + checkerCoords.y != 1) 
                {
                    float leftOffset = _InverseScreenSize.x;
                    finalCoords.x += leftOffset;
                }

                return tex2D(out_diffuse, finalCoords);
            }
            ENDHLSL
        }
    }
}
