using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Utilities;

namespace Oneiros.Rendering
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Light))]
    [AddComponentMenu("Rendering/Additional Lighting Data")]
    public class AdditionalLightData : MonoBehaviour
    {
        public enum ShadowCastMode { Disabled, Runtime, Baked, OnEnable}

        // Static

        private static Dictionary<Light, AdditionalLightData> loadedLightData = new Dictionary<Light, AdditionalLightData>();

        public static AdditionalLightData GetDataOfLight(Light light)
        {
            if (loadedLightData.ContainsKey(light)) return loadedLightData[light];

            AdditionalLightData data;

            if (light.TryGetComponent<AdditionalLightData>(out data))
            {
                loadedLightData.Add(light, data);
                return data;
            }
            else
            {
                data = light.gameObject.AddComponent<AdditionalLightData>();

            }
            return data;
        }

        // Instance

        private Light m_light;

        [SerializeField]
        private ShadowCastMode m_shadowCastMode = ShadowCastMode.Disabled;

        //[SerializeField]
        //private RenderTexture m_bakedShadowsFlat;

        [SerializeField, SerializeReference]
        private ShadowRenderer m_shadowRenderer;

        public Texture2D pointLightCookie;

        public Light Light => m_light;

        private void Awake()
        {
            m_light = GetComponent<Light>();

            CreateNewShadowRenderer();
        }

        private void OnEnable()
        {
            if (loadedLightData.ContainsKey(m_light))
            {
                loadedLightData.Remove(m_light);
            }
            loadedLightData.Add(m_light, this);

            m_shadowRenderer?.OnEnable(this);

            if (m_shadowCastMode == ShadowCastMode.OnEnable)
            {
                m_shadowRenderer?.OnRenderBaked(this);
            }
        }

        private void OnDisable()
        {
            loadedLightData.Remove(m_light);

            m_shadowRenderer?.OnDisable(this);
        }

        private void CreateNewShadowRenderer()
        {
            switch (m_light.type)
            {
                case LightType.Spot:
                    if (m_shadowRenderer == null || m_shadowRenderer is ShadowRendering.SpotLightShadowRenderer == false)
                        m_shadowRenderer = new ShadowRendering.SpotLightShadowRenderer();
                    break;
                case LightType.Directional:
                    if (m_shadowRenderer == null || m_shadowRenderer is ShadowRendering.DirectionalLightShadowRenderer == false)
                        m_shadowRenderer = new ShadowRendering.DirectionalLightShadowRenderer();
                    break;
                case LightType.Point:
                    if (m_shadowRenderer == null || m_shadowRenderer is ShadowRendering.PointLightShadowRenderer == false)
                        m_shadowRenderer = new ShadowRendering.PointLightShadowRenderer();
                    break;
                case LightType.Area:
                    break;
                case LightType.Disc:
                    break;
                default:
                    break;
            }
        }

        [ContextMenu("Bake Shadows")]
        public void BakeShadows()
        {
            m_shadowRenderer?.OnRenderBaked(this);
        }

        public void OnRenderLight(CommandBuffer commandBuffer)
        {
            if (m_shadowCastMode != ShadowCastMode.Disabled) commandBuffer.EnableShaderKeyword("SHADOWS_ON");
            else commandBuffer.DisableShaderKeyword("SHADOWS_ON");
            
            m_shadowRenderer?.OnRenderLight(this, commandBuffer);
        }

        public void OnRenderShadows(OneirosCameraRenderer cameraRenderer)
        {
            if (m_shadowCastMode == ShadowCastMode.Runtime)
            {
                m_shadowRenderer?.OnRenderRuntime(this, cameraRenderer);
            }
        }
    }
}