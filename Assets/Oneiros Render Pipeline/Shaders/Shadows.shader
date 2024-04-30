Shader "SHADOWS/Casters"
{
    Properties
    {
        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
			Name "Opaque"
			Blend One Zero
			ZWrite On
			Tags {"LightMode"="ShadowCaster"}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "ShaderCore.hlsl"

			FragmentInput vert(VertexInput i) {
				FragmentInput o;
				o.worldPosition = TransformObjectToWorld(i.position);
				o.clipPosition = TransformWorldToClip(o.worldPosition);
				o.normal = TransformNormalToWorld(i.normal);
				o.uv = i.uv;
				return o;
			}

			void frag(FragmentInput i){
				
			}

			ENDHLSL
        }
    }
}
