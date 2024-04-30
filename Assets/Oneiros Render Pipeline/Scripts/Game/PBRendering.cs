using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering
{
    public class PBRendering : OneirosCameraRenderer
    {
        private static ShaderTagId s_PbrShaderTag = new ShaderTagId("PBROpaque");
        private static ShaderTagId s_outlineShaderTag = new ShaderTagId("Outline");
        private static ShaderTagId s_BackDepthShaderTag = new ShaderTagId("Back Depth");
        private static ShaderTagId s_TransparentFxShaderTag = new ShaderTagId("Transparent FX");

        private static class ShaderProperties
        {
            public readonly static int backdepthTarget = Shader.PropertyToID("backdepthTarget");
            public readonly static int depthTarget = Shader.PropertyToID("depthTarget");
            public readonly static int albedoTarget = Shader.PropertyToID("albedoTarget");
            public readonly static int positionTarget = Shader.PropertyToID("positionTarget");
            public readonly static int normalTarget = Shader.PropertyToID("normalTarget");
            public readonly static int reflectionTarget = Shader.PropertyToID("reflectionTarget");
            public readonly static int transluencyTarget = Shader.PropertyToID("transluencyTarget");
            public readonly static int frameDefferedTarget = Shader.PropertyToID("out_diffuse");
            public readonly static int reconstructDefferedTarget = Shader.PropertyToID("cameraColorBuffer");
            public readonly static int transparentTarget = Shader.PropertyToID("cameraColorBuffer1");
            public readonly static int inverseScreenSize = Shader.PropertyToID("_InverseScreenSize");
            public readonly static int timeProperty = Shader.PropertyToID("_Time");
            public readonly static int cameraPositionId = Shader.PropertyToID("worldSpaceCameraPos");
            public readonly static int viewProjectionMatrix = Shader.PropertyToID("unity_MatrixVP");

            public readonly static int cbrJitterOffset = Shader.PropertyToID("JitterOffset");
            public readonly static int cbrResultSize = Shader.PropertyToID("ResultSize");
            public readonly static int cbrFrame = Shader.PropertyToID("Frame");
            public readonly static int cbrResult = Shader.PropertyToID("Result");
        }

        private static Material _diffuseMaterial;

        private bool m_IsCbrJitterFrame = false;

        private static int renderWidth = 800;
        private static int renderHeight = Mathf.RoundToInt((9f / 16f) * renderWidth);
        private static int halfRenderWidth = renderWidth / 2;
        private static int halfRenderHeight = renderHeight / 2;
        private static float cbrJitterWidth = -2.0f / renderWidth;

        private void ResetRenderSize()
        {
            renderWidth = camera.pixelWidth;
            renderHeight = camera.pixelHeight;
        }

        public override void OnEnable()
        {
            Shader diffuseShader = Shader.Find("Hidden/PBLighting");
            _diffuseMaterial = new Material(diffuseShader);
        }

        private void CreateGBufferStandard()
        {
            int colorBufferWidth = renderWidth;
            int colorBufferHeight = renderHeight;

            CreateRenderTarget(ShaderProperties.albedoTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGB32, false);
            CreateRenderTarget(ShaderProperties.positionTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGBFloat, true);
            CreateRenderTarget(ShaderProperties.normalTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGBFloat, true);
            CreateRenderTarget(ShaderProperties.reflectionTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGBFloat, true);
            CreateRenderTarget(ShaderProperties.transluencyTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGBFloat, false);
            CreateRenderTarget(ShaderProperties.frameDefferedTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGBFloat, false);
            CreateRenderTarget(ShaderProperties.depthTarget, colorBufferWidth, colorBufferHeight, 24, RenderTextureFormat.RGFloat, false);
            CreateRenderTarget(ShaderProperties.backdepthTarget, colorBufferWidth, colorBufferHeight, 16, RenderTextureFormat.RFloat, true);
            CreateRenderTarget(ShaderProperties.reconstructDefferedTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGB32, false, 1, true);
        }

        private void CreateGBufferCBR()
        {
            int colorBufferWidth = halfRenderWidth;
            int colorBufferHeight = halfRenderHeight;

            camera.allowMSAA = true;
            int msaa = 4;

            CreateRenderTarget(ShaderProperties.albedoTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGB32, false, msaa);
            CreateRenderTarget(ShaderProperties.positionTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGBFloat, true, msaa);
            CreateRenderTarget(ShaderProperties.normalTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGBFloat, true, msaa);
            CreateRenderTarget(ShaderProperties.reflectionTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGBFloat, true, msaa);
            CreateRenderTarget(ShaderProperties.transluencyTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGBFloat, true, msaa);
            CreateRenderTarget(ShaderProperties.frameDefferedTarget, colorBufferWidth, colorBufferHeight, 0, RenderTextureFormat.ARGBFloat, true, msaa);
            // to enable msaa, depth buffer is given x2 antialiasing
            CreateRenderTarget(ShaderProperties.depthTarget, colorBufferWidth, colorBufferHeight, 24, RenderTextureFormat.Depth, true, msaa);
            CreateRenderTarget(ShaderProperties.backdepthTarget, colorBufferWidth, colorBufferHeight, 16, RenderTextureFormat.RFloat, true, msaa);
            CreateRenderTarget(ShaderProperties.reconstructDefferedTarget, renderWidth, renderHeight, 0, RenderTextureFormat.ARGB32, true, 1, true);
            CreateRenderTarget(ShaderProperties.transparentTarget, renderWidth, renderHeight, 0, RenderTextureFormat.ARGB32, true, 1, false);
        }

        private void DoCbrJitter()
        {
            // every other frame is jittered exactly one pixel to the right.
            // this variable keeps track of wether the frame should be jittered.
            m_IsCbrJitterFrame = !m_IsCbrJitterFrame;

            if (m_IsCbrJitterFrame)
            {
                Vector2 jitterDirection = new Vector2(cbrJitterWidth * 1, 0);
                camera.projectionMatrix = Matrix4x4.Translate(jitterDirection) * camera.projectionMatrix;
                SetCbrInt(ShaderProperties.cbrJitterOffset, 1);
            }
            else
            {
                camera.ResetProjectionMatrix();
                SetCbrInt(ShaderProperties.cbrJitterOffset, 0);
            }
        }

        protected override void OnRenderCamera()
        {
            InitCbr();
            DoCbrJitter();
            BeginRenderLighting();
            Setup();
            BeginRender();

            ProceduralDrawCall.CullAll(camera);

            SetVectorParam(ShaderProperties.inverseScreenSize, new Vector2(1.0f / renderWidth, 1.0f / renderHeight));
            commands.SetGlobalFloat(ShaderProperties.timeProperty, Time.time);

            CreateGBufferCBR();
            ExecuteCommands();

            //BeginSample("Render Back Depth");
            SetRenderTarget(ShaderProperties.backdepthTarget, ShaderProperties.backdepthTarget);
            ClearRenderTarget(false, true);
            ExecuteCommands();
            DrawGeometry(SortingCriteria.CommonOpaque, RenderQueueRange.all, s_BackDepthShaderTag);
            ExecuteCommands();
            //EndSample();

            //BeginSample("Render Opaque");
            SetRenderTarget(
                new int[] 
                {
                    ShaderProperties.albedoTarget,
                    ShaderProperties.positionTarget,
                    ShaderProperties.normalTarget,
                    ShaderProperties.reflectionTarget,
                    ShaderProperties.transluencyTarget
                },
                ShaderProperties.depthTarget);

            ClearRenderTarget(false, true);
            ExecuteCommands();

            DrawGeometry(SortingCriteria.CommonOpaque, RenderQueueRange.all, s_PbrShaderTag, s_outlineShaderTag);
            ProceduralDrawCall.DrawAll(commands, 0);
            ExecuteCommands();

            // GBuffer is built

            SetTexParam(ShaderProperties.backdepthTarget, ShaderProperties.backdepthTarget);
            SetTexParam(ShaderProperties.albedoTarget, ShaderProperties.albedoTarget);
            SetTexParam(ShaderProperties.positionTarget, ShaderProperties.positionTarget);
            SetTexParam(ShaderProperties.normalTarget, ShaderProperties.normalTarget);
            SetTexParam(ShaderProperties.reflectionTarget, ShaderProperties.reflectionTarget);
            SetTexParam(ShaderProperties.transluencyTarget, ShaderProperties.transluencyTarget);
            SetVectorParam(ShaderProperties.cameraPositionId, camera.transform.position);

            SetRenderTarget(ShaderProperties.frameDefferedTarget, ShaderProperties.depthTarget);
            ClearRenderTarget(true, false);
            ExecuteCommands();

            // Lights are rendered (deffered)

            LightingPipeline.RenderLights();
            LightingPipeline.RenderReflections();
            LightingPipeline.RenderSky();
            ExecuteCommands();

            // Transparent objects are rendered
            //camera.ResetProjectionMatrix();

            SetRenderTarget(ShaderProperties.reconstructDefferedTarget, CameraDepthTarget);
            ExecuteCommands();

            DrawGeometry(SortingCriteria.CommonTransparent, RenderQueueRange.all, s_TransparentFxShaderTag);
            ProceduralDrawCall.DrawAll(commands, 1);
            ExecuteCommands();

            DrawGizmos();
            ExecuteCommands();

            // display is reconstructed from previous and current frames
            SetRenderTarget(ShaderProperties.reconstructDefferedTarget);
            SetCbrTexture(ShaderProperties.cbrFrame, ShaderProperties.frameDefferedTarget);
            SetCbrTexture(ShaderProperties.cbrResult, ShaderProperties.reconstructDefferedTarget);
            SetCbrVector(ShaderProperties.cbrResultSize, new Vector2(renderWidth, renderHeight));
            ReconstructFrame(halfRenderWidth, halfRenderHeight);
            ExecuteCommands();

            // Result is copied to camera target
            SetRenderTarget(CameraTarget, CameraDepthTarget);
            ClearRenderTarget(false, true);
            ExecuteCommands();

            BlitRenderTarget(ShaderProperties.reconstructDefferedTarget, CameraTarget);
            ExecuteCommands();

            ReleaseRenderTarget(ShaderProperties.albedoTarget);
            ReleaseRenderTarget(ShaderProperties.positionTarget);
            ReleaseRenderTarget(ShaderProperties.normalTarget);
            ReleaseRenderTarget(ShaderProperties.reflectionTarget);
            ReleaseRenderTarget(ShaderProperties.depthTarget);
            ReleaseRenderTarget(ShaderProperties.transluencyTarget);
            ReleaseRenderTarget(ShaderProperties.backdepthTarget);
            ReleaseRenderTarget(ShaderProperties.frameDefferedTarget);
            ReleaseRenderTarget(ShaderProperties.transparentTarget);

            EndRender();
        }
    }
}