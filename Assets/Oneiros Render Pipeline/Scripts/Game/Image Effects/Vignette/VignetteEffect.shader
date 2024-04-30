Shader "Hidden/PostProcess/VignetteEffect"
{
    Properties
    {
        _MaskTex("Mask Texture", 2D) = "black" {}
        _Tint ("Tint", Color) = (0, 0, 0, 1)
        _Strength("Strength", range(0, 1)) = 0
    }
    SubShader
    {

        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Main"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Assets\Oneiros Render Pipeline\Shaders\Lighting.hlsl"

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
                o.uv = v.uv;
                return o;
            }

            int _FrameId;

            sampler2D _MainTex;

            sampler2D _MaskTex;
            float4 _Tint;
            float _Strength;

            bool Checker(float2 uv) {
                float2 pixelCoords = uv * _ScreenSize;

                int2 checkerCoords = int2(floor((pixelCoords.x + _FrameId) % 2), floor((pixelCoords.y + 1) % 2));

                return (checkerCoords.x + checkerCoords.y != 1);
            }

            float4 frag(v2f i) : SV_Target
            {
                if (Checker(i.uv)) discard;

                float2 screenPos = i.uv;
                float2 samplePos = screenPos;
                if (_ProjectionParams.x > 0) screenPos.y = 1.0 - screenPos.y;

                float4 color = tex2D(_MainTex, screenPos);
                float4 mask = tex2D(_MaskTex, screenPos);
                color.rgb = lerp(color.rgb, _Tint.rgb * mask.rgb, mask.a * _Strength);

                return color;
            }
            ENDHLSL
        }
    }
}
