Shader "LOCAL/Volumetrics/Volume Box"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_MainColor("Tint", Color) = (1,1,1,1)
		_Density("Density", float) = 1
		[Toggle(DENSITY_MASK)]_UseDensityMask("Use Density Mask ?", float) = 0
		_DensityMask("Mask", 2D) = "white" {}
		_DensityMaskSpeed("Mask Speed", float) = 0.5
		_DensityMaskStrength("Mask Stength", range(0, 10)) = 0.5
		_DensityMaskPanning("Mask Panning", range(-1, 1)) = -0.3
	}
		SubShader
		{
			//Tags { "RenderType" = "Transparent" "DisableBatching"="True" }
			Tags { "RenderType" = "Transparent" "DisableBatching" = "True"}

			Pass
			{
				Name "Main"
				Blend SrcAlpha OneMinusSrcAlpha
				ZWrite Off
				ZTest Always
				Cull Front
				Tags {"LightMode" = "Transparent" "Queue"="Transparent-10"}

				HLSLPROGRAM
				#pragma target 4.6
				#pragma vertex common_vert
				#pragma fragment frag
				#pragma shader_feature DENSITY_MASK
				//#pragma multi_compile_instancing
				
				#define LIGHTMAP_ON

				#include "../ShaderCore.hlsl"

				// included in common pass

				struct Box{
					float3 bounds[2];

					float3 min() { return bounds[0]; }
					float3 max() { return bounds[1]; }
				};

				struct Ray{
					float3 origin;
					float3 dir;

					float3 GetPoint(float dist) {
						return origin + dir * dist;
					}
				};

				Box BuildBox() {
					Box b;
					b.bounds[0] = float3(1, 1, 1) * -0.5;
					b.bounds[1] = float3(1, 1, 1) * 0.5;
					return b;
				}

				bool BoxContainsPoint(Box b, float3 p) {
					float3 min = b.min();
					float3 max = b.max();
					return p.x >= min.x && p.x <= max.x && p.y >= min.y && p.y <= max.y && p.z >= min.z && p.z <= max.z;
				}

				Ray GetLocalSpaceRay(float3 origin, float3 target, FragmentInput i) {
					origin = i.TransformWorldToObject(origin);
					target = i.TransformWorldToObject(target);
					float3 direction = normalize(target - origin);
					Ray r;
					r.origin = origin;
					r.dir = direction;
					return r;
				}

				void GetIntersections(Box box, Ray ray, FragmentInput i, out float3 i1, out float3 i2)
				{
					i1 = 0;
					i2 = 0;

					float3 invDir = float3(1.0 / ray.dir.x, 1.0 / ray.dir.y, 1.0 / ray.dir.z);
					int3 signs = int3(invDir.x < 0, invDir.y < 0, invDir.z < 0);

					float txmin = (box.bounds[signs.x].x - ray.origin.x) * invDir.x;
					float txmax = (box.bounds[1 - signs.x].x - ray.origin.x) * invDir.x;
					float tymin = (box.bounds[signs.y].y - ray.origin.y) * invDir.y;
					float tymax = (box.bounds[1 - signs.y].y - ray.origin.y) * invDir.y;

					if (tymin > txmin)
						txmin = tymin;
					if (tymax < txmax)
						txmax = tymax;

					float tzmin = (box.bounds[signs.z].z - ray.origin.z) * invDir.z;
					float tzmax = (box.bounds[1 - signs.z].z - ray.origin.z) * invDir.z;

					if (tzmin > txmin)
						txmin = tzmin;
					if (tzmax < txmax)
						txmax = tzmax;

					i1 = ray.GetPoint(txmin);
					i2 = ray.GetPoint(txmax);

					i1 = i.TransformObjectToWorld(i1);
					i2 = i.TransformObjectToWorld(i2);
				}

				#include "../Lighting.hlsl"
				#include "../CommonPasses.hlsl"

				float _Density;

				#ifdef DENSITY_MASK
				sampler2D _DensityMask;
				float4 _DensityMask_ST;
				float _DensityMaskSpeed;
				float _DensityMaskStrength;
				float _DensityMaskPanning;
				#endif

				float4 frag(FragmentInput i) : SV_TARGET{
					float4 color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw) * _MainColor;

					float2 screenPosition = i.clipPosition.xy / _ScreenSize;
					//color.rgb = float3(screenPosition, 0);
					//return color;

					//float3 hitGeometry = i.worldPosition;
					float3 hitGeometry = SAMPLE_POSITION(screenPosition);

					//color.rgb = float3(1, 0, 0) * distance(hitGeometry, worldSpaceCameraPos) * 0.1;
					//return color;

					if (SqrLength(worldSpaceCameraPos - hitGeometry) > SqrLength(worldSpaceCameraPos - i.worldPosition)) hitGeometry = i.worldPosition;

					Box b = BuildBox();
					Ray r = GetLocalSpaceRay(worldSpaceCameraPos, i.worldPosition, i);

					float3 i1;
					float3 i2;

					bool inside = BoxContainsPoint(b, r.origin);

					if (inside) {
						i1 = worldSpaceCameraPos;
						i2 = hitGeometry;
					}
					else
					{
						GetIntersections(b, r, i, i1, i2);
						if (SqrLength(worldSpaceCameraPos - hitGeometry) < SqrLength(worldSpaceCameraPos - i1)) discard;
					}

					float distanceInVolume = distance(i1, hitGeometry);
					//float distanceInVolume = distance(worldSpaceCameraPos, i.worldPosition);
					float volumeDensity = _Density;

					#ifdef DENSITY_MASK
					float2 _screenCoords = screenPosition;
					_screenCoords *= _DensityMask_ST.xy;
					float2 _viewDisp;
					_viewDisp.y = worldSpaceCameraPos.y + r.dir.y;
					_viewDisp.x = worldSpaceCameraPos.x + worldSpaceCameraPos.z + r.dir.x + r.dir.z;
					_viewDisp *= 0.01;
					float2 _timeDisp = float2(_Time, _Time * 0.1) * _DensityMaskSpeed;
					float _mask = tex2D(_DensityMask, _screenCoords + _timeDisp + _viewDisp).r;
					_timeDisp = float2(-_Time * 0.3, _Time * 0.5) * _DensityMaskSpeed;
					_mask *= tex2D(_DensityMask, _screenCoords + _timeDisp + _viewDisp).r;
					volumeDensity += (_mask * _DensityMaskStrength + _DensityMaskPanning) * 2 * _Density;
					#endif

					//color.a = 1.0;
					color.a = distanceInVolume / volumeDensity;
					//color.rgb = i.TransformWorldToObject(i.worldPosition);
					//color.rgb = float3(1, 0, 0) * distanceInVolume / _Density;


					return color;
				}

				ENDHLSL
			}
		}
}
