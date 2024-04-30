using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering
{
    /// <summary>
    /// Handles the rendering of shadows.
    /// </summary>
    public class Shadows
    {
        private struct ShadowRenderer
        {
            public int type;
            public Matrix4x4 matrix;
            public float bias;
            public int visibleId;

            public const int SIZE = sizeof(float) * 4 * 4 + sizeof(float) + sizeof(int) * 2;
        }

        private const string BUFFER_NAME = "Shadows";
        private const int SHADOW_COUNT_LIMIT = 7;

        private static int p_shadowMatrices = Shader.PropertyToID("shadowMatrices");
        private static int p_shadowCount = Shader.PropertyToID("shadowCount");
        protected static int t_shadowTarget = Shader.PropertyToID("shadowAtlas");

        protected OneirosCameraRenderer cameraRenderer;

        protected CommandBuffer commands;

        private List<ShadowRenderer> ShadowCasters;
        private Matrix4x4[] ShadowMatrices;
        private ComputeBuffer shadowBuffer;

        public int ShadowTargetSize { get; private set; }

        public int ShadowCount { get; private set; }

        public Shadows(OneirosCameraRenderer _cameraRenderer)
        {
            cameraRenderer = _cameraRenderer;
            commands = new CommandBuffer() { name = BUFFER_NAME };
            ShadowTargetSize = (int) cameraRenderer.ShadowSettings.directional.atlasSize;
            ShadowCasters = new List<ShadowRenderer>();
            ShadowMatrices = new Matrix4x4[SHADOW_COUNT_LIMIT];
        }

        public void Setup()
        {
            ShadowCount = 0;
            ShadowCasters.Clear();
        }

        public int AssignShadowIndex(LightRenderer renderer, Light light, int visibleLightId)
        {
            if (light.shadows == LightShadows.None) return -1;
            ShadowCasters.Add(new ShadowRenderer() {
                bias = light.shadowBias,
                type = (int)light.type,
                visibleId = visibleLightId
            });
            int shadowId = ShadowCount;
            ShadowCount++;
            return shadowId;
        }

        public void BeginRender()
        {
            if (shadowBuffer != null) shadowBuffer.Dispose();
            shadowBuffer = new ComputeBuffer( Mathf.Max(ShadowCount, 1), ShadowRenderer.SIZE);
            commands.BeginSample(BUFFER_NAME);
            ExecuteBuffer();
            CreateShadowTarget();
            Render();
            SendShadowBufferToGpu();
            SendTextureArrayToGpu();    
            commands.EndSample(BUFFER_NAME);
            ExecuteBuffer();
        }

        protected void CreateShadowTarget()
        {
            commands.GetTemporaryRTArray(t_shadowTarget,
                ShadowTargetSize,
                ShadowTargetSize,
                ShadowCount, 
                16, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
            ExecuteBuffer();
        }

        private void Render()
        {
            for (int i = 0; i < ShadowCount; i++)
            {
                RenderShadow(i);
            }
        }

        private void RenderShadow(int shadowId)
        {
            commands.SetRenderTarget(t_shadowTarget, 1, CubemapFace.Unknown, shadowId);
            commands.ClearRenderTarget(true, false, Color.clear);
            ExecuteBuffer();
            if (ShadowCasters[shadowId].type == (int)LightType.Directional)
            {
                RenderDirectionalShadow(shadowId);
            }
        }

        private void RenderDirectionalShadow(int shadowId)
        {
            ShadowRenderer renderer = ShadowCasters[shadowId];
            int index = renderer.visibleId;
            ShadowDrawingSettings settings = new ShadowDrawingSettings(cameraRenderer.Culling, index);
            cameraRenderer.Culling.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                index, 0, 1, Vector3.zero, ShadowTargetSize, 0f,
                out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData
            );
            settings.splitData = splitData;
            renderer.matrix = ComputeShadowMatrix(projectionMatrix, viewMatrix);
            ShadowCasters[shadowId] = renderer;
            commands.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
            ExecuteBuffer();
            cameraRenderer.RenderContext.DrawShadows(ref settings);
        }

        private Matrix4x4 ComputeShadowMatrix(Matrix4x4 projection, Matrix4x4 view)
        {
            Matrix4x4 m = projection * view;
            if (SystemInfo.usesReversedZBuffer)
            {
                m.m20 = -m.m20;
                m.m21 = -m.m21;
                m.m22 = -m.m22;
                m.m23 = -m.m23;
            }
            m.m00 = 0.5f * (m.m00 + m.m30);
            m.m01 = 0.5f * (m.m01 + m.m31);
            m.m02 = 0.5f * (m.m02 + m.m32);
            m.m03 = 0.5f * (m.m03 + m.m33);
            m.m10 = 0.5f * (m.m10 + m.m30);
            m.m11 = 0.5f * (m.m11 + m.m31);
            m.m12 = 0.5f * (m.m12 + m.m32);
            m.m13 = 0.5f * (m.m13 + m.m33);
            m.m20 = 0.5f * (m.m20 + m.m30);
            m.m21 = 0.5f * (m.m21 + m.m31);
            m.m22 = 0.5f * (m.m22 + m.m32);
            m.m23 = 0.5f * (m.m23 + m.m33);
            return m;
        }

        private void SendShadowBufferToGpu()
        {
            //shadowBuffer.SetData(ShadowCasters);
            //commands.SetComputeBufferCounterValue(shadowBuffer, (uint)ShadowCount);
            commands.SetComputeBufferData(shadowBuffer, ShadowCasters);
            commands.SetGlobalBuffer(p_shadowMatrices, shadowBuffer);
            commands.SetGlobalInt(p_shadowCount, ShadowCount);
            ExecuteBuffer();
        }

        private void SendTextureArrayToGpu()
        {
            commands.SetGlobalTexture(t_shadowTarget, t_shadowTarget);
            ExecuteBuffer();
        }

        public void EndRender()
        {
            commands.ReleaseTemporaryRT(t_shadowTarget);
            //shadowBuffer.Release();
            ExecuteBuffer();
        }

        private void ExecuteBuffer()
        {
            cameraRenderer.RenderContext.ExecuteCommandBuffer(commands);
            commands.Clear();
        }
    }
}