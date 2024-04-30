Shader "LOCAL/UI/Default"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MainColor("Color", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode" = "UI" }
            ZTest Always
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex common_vert
            #pragma fragment frag

            #include "ShaderCore.hlsl"
            #include "CommonPasses.hlsl"

            //half4 _MainColor;

            half4 frag (FragmentInput i) : SV_Target
            {
                half4 col = tex2D(_MainTex, i.uv) * _MainColor;
                if (col.a < 0.01) discard;
                return col;
            }
            ENDHLSL
        }
    }
}
