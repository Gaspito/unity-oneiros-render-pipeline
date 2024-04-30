Shader "Hidden/BrushBlit"
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
            Blend SrcAlpha OneMinusSrcAlpha
            Name "Mix"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            Texture2D _BrushTex;
            SamplerState sampler_BrushTex;
            float4 _BrushRect;
            float4 _BrushColor;

            float4 frag(v2f i) : SV_Target
            {
                if (i.uv.x >= _BrushRect.x && i.uv.x <= _BrushRect.z
                    && i.uv.y >= _BrushRect.y && i.uv.y <= _BrushRect.w)
                {
                    float2 brushCoords;
                    brushCoords.x = (i.uv.x - _BrushRect.x) / (_BrushRect.z - _BrushRect.x);
                    brushCoords.y = (i.uv.y - _BrushRect.y) / (_BrushRect.w - _BrushRect.y);
                    float4 brush = _BrushTex.Sample(sampler_BrushTex, brushCoords) * _BrushColor;
                    if (brush.a <= 0) discard;
                    return brush;
                }
                return float4(0, 0, 0, 0);
            }
            ENDHLSL
        }
    }
}
