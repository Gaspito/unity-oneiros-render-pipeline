using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering.ShadowRendering
{
    [System.Serializable]
    public class PointLightShadowRenderer : ShadowRenderer
    {
        public RenderTexture m_bakedTexture;

        [Range(0, 0.5f)]
        public float m_nearRange = 0.01f;

        public override void OnRenderBaked(AdditionalLightData ald)
        {
            m_bakedTexture = new RenderTexture(Resolution, Resolution, 16, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
            m_bakedTexture.dimension = TextureDimension.Cube;
            m_bakedTexture.Create();

            Camera camera = new GameObject("Shadow Renderer", typeof(Camera)).GetComponent<Camera>();
            camera.hideFlags = HideFlags.HideAndDontSave;
            camera.transform.position = ald.Light.transform.position;
            camera.transform.rotation = Quaternion.identity;

            camera.farClipPlane = ald.Light.range;
            camera.nearClipPlane = m_nearRange;

            OneirosRenderPipeline.IsRenderingShadows = true;

            camera.allowHDR = true;
            camera.RenderToCubemap(m_bakedTexture, 63);

            OneirosRenderPipeline.IsRenderingShadows = false;

            Destroy(camera.gameObject);
        }

        public override void OnRenderLight(AdditionalLightData ald, CommandBuffer commandBuffer)
        {
            commandBuffer.SetGlobalFloat(ShadowBiasId, bias);
            commandBuffer.SetGlobalTexture(ShadowTextureId, m_bakedTexture);
        }

        public override void OnRenderRuntime(AdditionalLightData ald, OneirosCameraRenderer cameraRenderer)
        {
            //throw new System.NotImplementedException();
        }
    }
}