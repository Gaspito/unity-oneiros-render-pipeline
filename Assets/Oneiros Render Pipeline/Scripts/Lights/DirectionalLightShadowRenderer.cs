using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering.ShadowRendering
{
    [System.Serializable]
    public class DirectionalLightShadowRenderer : ShadowRenderer
    {
        public RenderTexture m_bakedTexture;

        public RenderTargetIdentifier m_rti;

        public Matrix4x4 m_projectMatrix;

        public Camera m_camera;

        [Range(0, 0.5f)]
        public float m_nearRange = 0.01f;

        public void FollowMainCamera(AdditionalLightData ald)
        {
            Transform mainCam = Camera.main.transform;
            Vector3 pos = mainCam.transform.position;
            pos += mainCam.transform.forward * 5.0f;
            pos += ald.Light.transform.forward * -10f;
            ald.Light.transform.position = pos;
            m_camera.transform.position = pos;
            m_projectMatrix = m_camera.worldToCameraMatrix;
        }

        public override void OnDisable(AdditionalLightData ald)
        {
            base.OnDisable(ald);
            if (m_camera) Destroy(m_camera);
        }

        private void CreateCamera(AdditionalLightData ald)
        {
            m_camera = new GameObject("Shadow Renderer", typeof(Camera)).GetComponent<Camera>();
            m_camera.hideFlags = HideFlags.HideAndDontSave;
            m_camera.transform.position = ald.Light.transform.position;
            m_camera.transform.rotation = ald.Light.transform.rotation;

            m_camera.targetTexture = m_bakedTexture;
            m_camera.forceIntoRenderTexture = true;

            m_camera.orthographic = true;
            m_camera.orthographicSize = 10;
            m_camera.aspect = 1.0f;

            m_camera.farClipPlane = 1000f;
            m_camera.nearClipPlane = m_nearRange;
            m_camera.enabled = false;

            m_camera.allowHDR = true;
        }

        public override async void OnRenderBaked(AdditionalLightData ald)
        {
            return;
            if (m_bakedTexture == null)
            {
                m_bakedTexture = new RenderTexture(Resolution, Resolution, 16, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
                m_bakedTexture.dimension = TextureDimension.Tex2D;
                m_bakedTexture.Create();
                m_rti = new RenderTargetIdentifier(m_bakedTexture);
            }

            Camera m_camera = new GameObject("ShadowRenderer", typeof(Camera)).GetComponent<Camera>();
            m_camera.hideFlags = HideFlags.HideAndDontSave;
            m_camera.transform.position = ald.Light.transform.position;
            m_camera.transform.rotation = ald.Light.transform.rotation;

            m_camera.targetTexture = m_bakedTexture;
            m_camera.forceIntoRenderTexture = true;

            m_camera.orthographic = true;
            m_camera.orthographicSize = 10;
            m_camera.aspect = 1.0f;

            m_camera.farClipPlane = 1000f;
            m_camera.nearClipPlane = m_nearRange;
            m_camera.enabled = false;

            OneirosRenderPipeline.IsRenderingShadows = true;

            m_camera.allowHDR = true;
            m_camera.Render();
            m_camera.targetTexture = null;

            OneirosRenderPipeline.IsRenderingShadows = false;

            m_projectMatrix = m_camera.worldToCameraMatrix;

            await System.Threading.Tasks.Task.Delay(100);
            
            Destroy(m_camera.gameObject);
        }

        public override void OnEnable(AdditionalLightData ald)
        {
            base.OnEnable(ald);
            m_bakedTexture = null;
            if (m_bakedTexture == null)
            {
                m_bakedTexture = new RenderTexture(Resolution, Resolution, 16, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
                m_bakedTexture.dimension = TextureDimension.Tex2D;
                m_bakedTexture.Create();
                m_rti = new RenderTargetIdentifier(m_bakedTexture);
            }
            if (m_camera == null)
                CreateCamera(ald);
            //OnRenderBaked(ald);
        }

        public override void OnRenderLight(AdditionalLightData ald, CommandBuffer commandBuffer)
        {
            
            commandBuffer.SetGlobalFloat(ShadowBiasId, bias);
            commandBuffer.SetGlobalTexture(ShadowTextureId, m_rti);
            commandBuffer.SetGlobalMatrix(ShadowProjectionId, m_projectMatrix);
        }

        public override void OnRenderRuntime(AdditionalLightData ald, OneirosCameraRenderer cameraRenderer)
        {
            if (m_camera == null)
                CreateCamera(ald);
            //throw new System.NotImplementedException();
            FollowMainCamera(ald);

            OneirosRenderPipeline.IsRenderingShadows = true;
            cameraRenderer.RenderCamera(m_camera, m_bakedTexture);
            CullingResults culling = cameraRenderer.GetCameraCullingResults(m_camera);
            cameraRenderer.DoRenderCustomPass(culling, SortingCriteria.CommonOpaque, RenderQueueRange.all, shadowsTagId);
            OneirosRenderPipeline.IsRenderingShadows = false;
            cameraRenderer.EndRenderCamera();
            //OnRenderBaked(ald);
            //Debug.Log("Rendering shadow map");
        }
    }
}