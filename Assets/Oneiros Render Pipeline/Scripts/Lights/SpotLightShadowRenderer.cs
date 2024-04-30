using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering.ShadowRendering
{
    [System.Serializable]
    public class SpotLightShadowRenderer : ShadowRenderer
    {
        public RenderTexture m_bakedTexture;

        [Range(0, 0.5f)]
        public float m_nearRange = 0.01f;

        public override async void OnRenderBaked(AdditionalLightData ald)
        {
            m_bakedTexture = new RenderTexture(Resolution, Resolution, 16, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
            m_bakedTexture.dimension = TextureDimension.Tex2D;
            m_bakedTexture.Create();

            Camera camera = new GameObject("Shadow Renderer", typeof(Camera)).GetComponent<Camera>();
            camera.hideFlags = HideFlags.DontSave;
            camera.transform.position = ald.Light.transform.position;
            camera.transform.rotation = ald.Light.transform.rotation;

            camera.targetTexture = m_bakedTexture;
            camera.forceIntoRenderTexture = true;

            camera.fieldOfView = ald.Light.spotAngle;

            camera.farClipPlane = ald.Light.range;
            camera.nearClipPlane = m_nearRange;
            camera.enabled = false;

            OneirosRenderPipeline.IsRenderingShadows = true;

            camera.allowHDR = true;
            camera.Render();
            camera.targetTexture = null;

            OneirosRenderPipeline.IsRenderingShadows = false;

            await System.Threading.Tasks.Task.Delay(100);

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