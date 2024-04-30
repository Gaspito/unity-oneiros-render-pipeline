Shader "Hidden/PostProcess/ShadowRealmEffect"
{
    Properties
    {
        _DisplacementTex("Displacement", 2D) = "gray" {}
        _DisplacementStrength("Strength", range(0, 0.3)) = 0.2
        _DisplacementSpeed("Speed", float) = 1
        _DisplacementMin("Min", float) = 20
        _DisplacementMax("Max", float) = 100
        _Desaturation("Desaturation", range(0, 1)) = 0.5

        _ViewAngle("View Angle", range(0, 90)) = 30
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

            float _DisplacementSpeed;
            float _DisplacementStrength;
            sampler2D _DisplacementTex;
            sampler2D _MainTex;

            float _DisplacementMin;
            float _DisplacementMax;

            float _Desaturation;

            float _ViewAngle;
            float3 _CameraDirection;
            float3 _Offset;

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

                float3 position = SAMPLE_POSITION(samplePos);

                float3 camProj = position - worldSpaceCameraPos;
                float sqrDistToCam = camProj.x * camProj.x + camProj.y * camProj.y + camProj.z * camProj.z;

                float proximity = _DisplacementMin;
                proximity *= proximity;
                sqrDistToCam -= proximity;

                float strength;
                if (sqrDistToCam <= 0) strength = 0;
                else strength = sqrt(sqrDistToCam) / (_DisplacementMax);
                strength = saturate(strength);

                float4 displacement = tex2D(_DisplacementTex, screenPos + float2(_Time * _DisplacementSpeed, 0));
                displacement -= tex2D(_DisplacementTex, screenPos + float2(0, _Time * _DisplacementSpeed * 0.5));

                displacement.rg = saturate(displacement.rg + float2(1, 1)) - float2(1, 1);

                float2 displacedCoords = screenPos + displacement.rg
                    * strength * _DisplacementStrength * _InverseScreenSize.x;

                if (Checker(displacedCoords)) displacedCoords += float2(_InverseScreenSize.x, 0);

                float4 color = lerp(tex2D(_MainTex, screenPos), tex2D(_MainTex, displacedCoords), strength);

                float luminance = (color.r + color.g + color.b) * 0.33;

                color.rgb = lerp(color.rgb, luminance, max(_Desaturation, strength));

                float4x4 cameraRotation = LookAtMatrix(_CameraDirection);
                float3 rayOrigin = worldSpaceCameraPos + mul(cameraRotation, float4(_Offset, 0)).xyz;
                float3 rayDir = position - rayOrigin;
                float angleToPos = (1.0 - dot(normalize(rayDir), normalize(_CameraDirection))) * 90.0;
                if (angleToPos > _ViewAngle) color.rgb *= 0.1f;

                return color;
            }
            ENDHLSL
        }
    }
}
