Shader "LOCAL/Sky/Panoramic"
{
    Properties
    {
        _MainTex ("Panorama", 2D) = "white" {}
        _TopTex ("Top", 2D) = "white" {}
        _BottomHeight("Bottom Height", float) = 0
        _TopHeight("Top Height", float) = 1
        _ColorBlend("Color Blend", range(0,0.5)) = 0.1
        _BottomColor("Bottom Color", Color) = (0, 0, 0, 1)
        _TopColor("Top Color", Color) = (0, 0, 0, 1)
        _ReflectionTint("Reflection Tint", Color) = (1, 1, 1, 1)
    }
        SubShader
        {
            Tags { "RenderType" = "Sky" }
            LOD 100



            Pass
            {
                Name "Sky"
                Blend One Zero
                ZWrite Off
                ZTest LEqual
                Cull Off
                Tags {"LightMode" = "Sky"}

                HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #define _DRAW_SKY

                float4 frag(FragmentInput i) : SV_Target
                {
                    return _frag(i, false);
                }

                ENDHLSL

            }

            Pass
            {
                Name "Environment"
                Blend One One
                ZWrite Off
                ZTest Always
                Cull Off
                Tags {"LightMode" = "Indirect"}

                HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #define _DRAW_REFLECT

                float4 frag(FragmentInput i) : SV_Target
                {
                    return saturate(_frag(i, true));
                }

            ENDHLSL

        }

        HLSLINCLUDE
        #include "Assets/Oneiros Render Pipeline/Shaders/ShaderCore.hlsl"
        #include "Assets/Oneiros Render Pipeline/Shaders/CommonPasses.hlsl"

        #define CUSTOM_GLOBAL_SAMPLER sampler_albedoTarget

        #include "Assets/Oneiros Render Pipeline/Shaders/Lighting.hlsl"

        //sampler2D _MainTex;

        float2 GetSphereCoords(float3 _view)
        {
            float2 uv;
            _view = normalize(_view);
            //float3 _cameraPos = worldSpaceCameraPos;
            //float3 _VertexPos = worldPosition;
            //float3 _view = _VertexPos - _cameraPos;
            float3 _flatView = normalize(_view * float3(1, 0, 1));
            float _angle = degrees(acos(dot(_flatView, float3(1, 0, 0))));
            float _viewDotFwd = dot(_flatView, float3(0, 0, 1));
            if (_viewDotFwd <= 0) _angle = 360 - _angle;
            uv.x = _angle * (1.0 / 360.0);
            uv.y = normalize(_view).y * 0.5 + 0.5;
            return uv;
        }

        FragmentInput vert(VertexInput v)
        {
            FragmentInput i = common_vert(v);
            return i;
        }

        float _BottomHeight;
        float _TopHeight;
        float _ColorBlend;
        float4 _BottomColor;
        float4 _TopColor;
        float4 _ReflectionTint;

        sampler2D _TopTex;
        float4 _TopTex_ST;

        float3 GetSphereColor(float3 _vect, uint _lod) {
            float2 coords = GetSphereCoords(_vect);
            coords.y -= _BottomHeight;
            coords.y /= _TopHeight - _BottomHeight;
            float _topLerp = coords.y > 1.0 - _ColorBlend ? saturate((coords.y - 1.0 + _ColorBlend) / _ColorBlend) : 0.0;
            float _bottomLerp = coords.y < 0.0 + _ColorBlend ? saturate((_ColorBlend - coords.y) / _ColorBlend) : 0.0;
            float2 _topCoords = (normalize(_vect).xz * _TopTex_ST.xy + float2(0.5, 0.5));
            float4 color = tex2Dlod(_MainTex, float4(coords, 0, _lod));
            float4 _topColor = tex2Dlod(_TopTex, float4(_topCoords, 0, _lod));
            color = lerp(color, _topColor * _TopColor, _topLerp);
            color = lerp(color, _BottomColor, _bottomLerp);
            return color.rgb;
        }

        float4 _frag(FragmentInput i, bool isIndirect)
        {
            float2 _screenCoords = WorldToScreenPos(i.worldPosition);
            float _alpha = SAMPLE_ALPHA(_screenCoords);
            float3 _view = i.worldPosition - worldSpaceCameraPos;
            if (!isIndirect) {
                if (_alpha <= 0.001) {
                    float3 _color = GetSphereColor(_view, 0);
                    return float4(_color, 1);
                }
                discard;
            }
            else {
                if (_alpha >= 0.001) {
                    float3 _normal = SAMPLE_NORMAL(_screenCoords);
                    _view = reflect(_view, _normal);
                    float3 _reflection = SAMPLE_REFLECTION(_screenCoords);
                    uint _lod = floor((1.0 - _reflection.x * 0.01) * 10);
                    float3 _diffuse = GetSphereColor(_normal, _lod);
                    float3 _reflectColor = GetSphereColor(_view, 0);
                    float3 _albedo = SAMPLE_ALBEDO(_screenCoords);
                    _diffuse *= _albedo;
                    _reflectColor *= _reflection.x * 0.01;
                    _reflectColor = lerp(_reflectColor * _albedo, _reflectColor, _reflection.y);
                    float4 _color;
                    _color.rgb = _diffuse + _reflectColor;
                    _color.rgb *= _ReflectionTint;
                    _color.a = 1;
                    return _color;
                }
                discard;
            }
            return float4(0, 0, 0, 0);
        }
        ENDHLSL
    }
}
