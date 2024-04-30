using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering
{

    /// <summary>
    /// Default Checker Based Rendering Pipeline.
    /// It renders only half the frame's resolution then stitches back together to create a full frame using a compute shader.
    /// It also uses a defferred lighting model to limit rendering passes to the minimum.
    /// Most materials must use a Physical Based approach for the defferred lighting.
    /// </summary>
    public class CheckerBasedRendering : OneirosCameraRenderer
    {
        /// <summary>
        /// A collection of shader tags used often in the pipeline.
        /// </summary>
        private static class ShaderTags
        {
            public readonly static ShaderTagId depthOnly = new ShaderTagId("Depth Only");
            public readonly static ShaderTagId backDepth = new ShaderTagId("Back Depth");
            public readonly static ShaderTagId deferredBase = new ShaderTagId("Deferred Base");
            public readonly static ShaderTagId deferredAdd0 = new ShaderTagId("Deferred Add0");
            public readonly static ShaderTagId transparent = new ShaderTagId("Transparent");
            public readonly static ShaderTagId always = new ShaderTagId("Always");
            public readonly static ShaderTagId unlit = new ShaderTagId("Unlit");
            public readonly static ShaderTagId ui = new ShaderTagId("UI");
            public readonly static ShaderTagId shadows = new ShaderTagId("Shadow Caster");
            public readonly static ShaderTagId lowResPostProcess = new ShaderTagId("Low Post FX");

            public static ShaderTagId[] OpaquePasses { get => new ShaderTagId[] { deferredBase, deferredAdd0 }; }
            public static ShaderTagId[] TransparentPasses { get => new ShaderTagId[] { transparent }; }
            public static ShaderTagId[] UIPasses { get => new ShaderTagId[] { always, unlit, ui }; }
        }

        /// <summary>
        /// A collection of shader property IDs used often in the pipeline.
        /// </summary>
        private static class ShaderProperties
        {
            public readonly static int grabPostLightsTarget = Shader.PropertyToID("postLightsTarget");
            public readonly static int backdepthTarget = Shader.PropertyToID("backdepthTarget");
            public readonly static int depthTarget = Shader.PropertyToID("depthTarget");
            public readonly static int albedoTarget = Shader.PropertyToID("albedoTarget");
            public readonly static int positionTarget = Shader.PropertyToID("positionTarget");
            public readonly static int normalTarget = Shader.PropertyToID("normalTarget");
            public readonly static int reflectionTarget = Shader.PropertyToID("reflectionTarget");
            public readonly static int transluencyTarget = Shader.PropertyToID("transluencyTarget");
            public readonly static int globalIlluminationTarget = Shader.PropertyToID("globalIlluminationTarget");
            public readonly static int frameDefferedTarget = Shader.PropertyToID("out_diffuse");
            public readonly static int reconstructDefferedTarget = Shader.PropertyToID("cameraColorBuffer");
            public readonly static int transparentTarget = Shader.PropertyToID("cameraColorBuffer1");
            public readonly static int inverseScreenSize = Shader.PropertyToID("_InverseScreenSize");
            public readonly static int timeProperty = Shader.PropertyToID("_Time");
            public readonly static int cameraPositionId = Shader.PropertyToID("worldSpaceCameraPos");
            public readonly static int cameraDirectionId = Shader.PropertyToID("_CameraDirection");
            public readonly static int viewProjectionMatrix = Shader.PropertyToID("unity_MatrixVP");
            public readonly static int screenSize = Shader.PropertyToID("_ScreenSize");
            public readonly static int frameCheckerId = Shader.PropertyToID("_FrameId");

            public readonly static int cbrJitterOffset = Shader.PropertyToID("JitterOffset");
            public readonly static int cbrResultSize = Shader.PropertyToID("ResultSize");
            public readonly static int cbrFrame = Shader.PropertyToID("Frame");
            public readonly static int cbrResult = Shader.PropertyToID("Result");

            public readonly static int postProcessLow = Shader.PropertyToID("tempLow");
            public readonly static int postProcessFull = Shader.PropertyToID("tempFull");
        }

        /// <summary>
        /// This mesh is used to blit full screen effects with the minimum geometry count.
        /// </summary>
        private Mesh fullscreenTriangle;
        /// <summary>
        /// This material is used to mask half the frame's pixels in depth testing.
        /// </summary>
        private Material depthMaskMaterial;
        /// <summary>
        /// Contains the properties to apply to the depth mask material when blitting full screen.
        /// </summary>
        private MaterialPropertyBlock depthMaskProperties;
        /// <summary>
        /// Represents the odd or even frame. 0: even, 1: odd.
        /// This determines which pixels of the render are skipped this frame.
        /// </summary>
        private static int frameCheckerId = 0;
        /// <summary>
        /// If true, the current render is the editor's scene view.
        /// </summary>
        private bool isSceneView;

        public override void OnEnable()
        {
            // Force the use of the custom rendering pipeline.
            GraphicsSettings.useScriptableRenderPipelineBatching = true;
            // Create the full screen blitting triangle.
            fullscreenTriangle = new Mesh();
            fullscreenTriangle.SetVertices(new Vector3[]
            {
                new Vector2(-1, 1),
                new Vector2(3, 1),
                new Vector2(-1, -3)
            });
            fullscreenTriangle.SetTriangles(new int[] { 0, 1, 2 }, 0);
            fullscreenTriangle.SetUVs(0, new Vector2[]
            {
                new Vector2(0, 0),
                new Vector2(2, 0),
                new Vector2(0, 2)
            });
            fullscreenTriangle.UploadMeshData(false);
            // Get the depth checker mask material
            depthMaskMaterial = new Material(Shader.Find("Hidden/CheckerDepthMask"));
            depthMaskProperties = new MaterialPropertyBlock();
        }

        /// <summary>
        /// Creates the many render targets used by this pipeline, including the main GBuffer.
        /// </summary>
        private void CreateRenderTargets()
        {
            int w = camera.pixelWidth;
            int h = camera.pixelHeight;

            CreateRenderTarget(ShaderProperties.albedoTarget, w, h, 0, RenderTextureFormat.ARGBHalf, false);
            CreateRenderTarget(ShaderProperties.positionTarget, w, h, 0, RenderTextureFormat.ARGBFloat, true);
            CreateRenderTarget(ShaderProperties.normalTarget, w, h, 0, RenderTextureFormat.ARGBFloat, true);
            CreateRenderTarget(ShaderProperties.reflectionTarget, w, h, 0, RenderTextureFormat.ARGBFloat, true);
            CreateRenderTarget(ShaderProperties.transluencyTarget, w, h, 0, RenderTextureFormat.ARGBHalf, false);
            CreateRenderTarget(ShaderProperties.globalIlluminationTarget, w, h, 0, RenderTextureFormat.ARGBFloat, false);
            CreateRenderTarget(ShaderProperties.backdepthTarget, w, h, 16, RenderTextureFormat.RFloat, true);

            commands.GetTemporaryRT(ShaderProperties.depthTarget, w, h, 16, FilterMode.Point, RenderTextureFormat.Depth);
            commands.GetTemporaryRT(ShaderProperties.frameDefferedTarget, w, h, 0, FilterMode.Point, RenderTextureFormat.ARGB32);

            CreateRenderTarget(ShaderProperties.postProcessLow, w, h, 0, RenderTextureFormat.ARGBHalf, false);
            CreateRenderTarget(ShaderProperties.postProcessFull, w, h, 0, RenderTextureFormat.ARGBHalf, false);

            ExecuteCommands();
        }

        /// <summary>
        /// Cleans up all the created render targets when CreateRenderTargets() is called.
        /// </summary>
        private void ReleaseRenderTargets()
        {
            ReleaseRenderTarget(ShaderProperties.albedoTarget);
            ReleaseRenderTarget(ShaderProperties.positionTarget);
            ReleaseRenderTarget(ShaderProperties.normalTarget);
            ReleaseRenderTarget(ShaderProperties.reflectionTarget);
            ReleaseRenderTarget(ShaderProperties.depthTarget);
            ReleaseRenderTarget(ShaderProperties.transluencyTarget);
            ReleaseRenderTarget(ShaderProperties.globalIlluminationTarget);
            ReleaseRenderTarget(ShaderProperties.backdepthTarget);
            ReleaseRenderTarget(ShaderProperties.frameDefferedTarget);
            ReleaseRenderTarget(ShaderProperties.transparentTarget);

            ReleaseRenderTarget(ShaderProperties.postProcessLow);
            ReleaseRenderTarget(ShaderProperties.postProcessFull);

            ExecuteCommands();
        }

        /// <summary>
        /// Switches the frameCheckerId value from 0 to 1 or vis-versa and updates it corresponding global shader uniform value.
        /// Except if the render is an editor scene or preview, which only renders 1 frame at a time, so stitching back frames is not an option.
        /// In that case, only render 1 frame with id 0 always, and set isSceneView to true.
        /// </summary>
        private void UpdateCheckerId()
        {
            if (camera == Camera.main || !Application.isPlaying)
            {
                frameCheckerId = frameCheckerId == 0 ? 1 : 0;
            }
            isSceneView = false;

            if (Camera.cameraType == CameraType.SceneView)
            {
                frameCheckerId = 0;
                isSceneView = true;
            }
            else if (Camera.cameraType == CameraType.Preview)
            {
                frameCheckerId = 0;
            }

            SetIntParam(ShaderProperties.frameCheckerId, frameCheckerId);
        }

        /// <summary>
        /// Applies global shader uniform values like the current time, screen size and camera transforms.
        /// If no specific camera is given, defaults to this renderer's camera.
        /// </summary>
        /// <param name="cam">The specific camera to use, or defaults to the renderer's camera if null.</param>
        private void SetGlobalParams(Camera cam)
        {
            if (cam == null) {
                cam = camera;
            }
            SetFloatParam(ShaderProperties.timeProperty, Time.time);
            SetVectorParam(ShaderProperties.screenSize, new Vector2(cam.pixelWidth, cam.pixelHeight));
            SetVectorParam(ShaderProperties.inverseScreenSize, new Vector2(1.0f / cam.pixelWidth, 1.0f / cam.pixelHeight));
            SetVectorParam(ShaderProperties.cameraPositionId, cam.transform.position);
            SetVectorParam(ShaderProperties.cameraDirectionId, cam.transform.forward);
        }

        /// <summary>
        /// Starts the rendering process of 1 camera. This does not rendering anything per say, but prepares everything needed for that rendering.
        /// </summary>
        /// <param name="camera">The camera to render from.</param>
        /// <param name="target">The render target to render to.</param>
        public override void RenderCamera(Camera camera, RenderTargetIdentifier target)
        {
            if (camera == null)
            {
                Debug.LogError("Null camera");
                return;
            }
            commands.name = "RenderCamera" + camera.name;
            //SetRenderTarget(CameraTarget, ShaderProperties.depthTarget);
            commands.SetRenderTarget(target);
            ExecuteCommands();
            ClearRenderTarget(true, true);
            ExecuteCommands();
            SetupCamera(camera);
            SetGlobalParams(camera);

            ExecuteCommands();
        }

        /// <summary>
        /// Ends the rendering process started with RenderCamera().
        /// This must be called after RenderCamera().
        /// Resets the global shader uniforms to the renderer's camera.
        /// </summary>
        public override void EndRenderCamera()
        {
            SetGlobalParams();

            ExecuteCommands();
        }

        public void GrabRenderTarget(RenderTargetIdentifier rti)
        {
        }

        /// <summary>
        /// Sets the Deferred Lighting model's GBuffer as the current render targets for the next draw calls.
        /// These render targets include color (albedo), world position, world normal, roughness and metallicness (reflection), transluency, and GI.
        /// All fragment shaders called while these are render targets should output data to all these buffers. See the shader PBR Opaque for implementation.
        /// </summary>
        private void SetGBufferAsTarget()
        {
            if (Camera.cameraType == CameraType.Preview)
            {
                ClearRenderTarget(true, false);
                ExecuteCommands();
            }
            SetRenderTarget(
                new int[]
                {
                    ShaderProperties.albedoTarget,
                    ShaderProperties.positionTarget,
                    ShaderProperties.normalTarget,
                    ShaderProperties.reflectionTarget,
                    ShaderProperties.transluencyTarget,
                    ShaderProperties.globalIlluminationTarget
                },
                ShaderProperties.depthTarget);
            ExecuteCommands();
            if (Camera.cameraType == CameraType.Preview)
            {
                ClearRenderTarget(true, false);
            }
            else
            {
                ClearRenderTarget(true, false);
            }
            ExecuteCommands();
        }

        /// <summary>
        /// Set the next draw calls of the command buffer to render to the current camera, and clears it's color buffer.
        /// </summary>
        private void SetCameraAsTarget()
        {
            commands.name = "CameraTarget";
            //SetRenderTarget(CameraTarget, ShaderProperties.depthTarget);
            commands.SetRenderTarget(ShaderProperties.frameDefferedTarget, RenderBufferLoadAction.Load, RenderBufferStoreAction.DontCare,
                ShaderProperties.depthTarget, RenderBufferLoadAction.Load, RenderBufferStoreAction.DontCare);
            ExecuteCommands();
            ClearRenderTarget(true, false);
            ExecuteCommands();
        }

        /// <summary>
        /// Renders only the depth of the scene, optionnaly rendering the checker mask as well.
        /// </summary>
        private void DoRenderDepth(bool depthMask = true)
        {
            commands.name = "Depth_Only.Clear";
            commands.SetRenderTarget(ShaderProperties.depthTarget, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.DontCare,
                RenderBufferLoadAction.DontCare, RenderBufferStoreAction.DontCare);
            ClearRenderTarget(false, true);
            ExecuteCommands();

            commands.name = "Depth_Only.Render";
            if (depthMask)
                DoRenderDepthMask();
            commands.BeginSample("Depth_Only.Render");
            ExecuteCommands();
            DrawGeometry(SortingCriteria.CommonOpaque, RenderQueueRange.all, ShaderTags.depthOnly);
            ExecuteCommands();
            commands.EndSample("Depth_Only.Render");
            ExecuteCommands();

            commands.name = "Render";
        }

        /// <summary>
        /// Renders the back depth of the scene. This is similar to DoRenderDepth(), but the geometry is actually sorted backwards by depth testing.
        /// Combining the data of this render pass with the front depth gives data on the volume of each object's pixel. 
        /// Which is usefull for effects like screen space reflections and transluency.
        /// </summary>
        private void DoRenderBackDepth()
        {
            SetRenderTarget(ShaderProperties.backdepthTarget, ShaderProperties.backdepthTarget);
            ClearRenderTarget(false, true);
            ExecuteCommands();
            DrawGeometry(SortingCriteria.CommonOpaque, RenderQueueRange.all, ShaderTags.backDepth);
            ExecuteCommands();
        }

        /// <summary>
        /// Renders the standard opaque geometry of the scene, using deferred rendering.
        /// </summary>
        private void DoRenderOpaque()
        {
            commands.name = "Render.Deferred.Base";
            commands.BeginSample("Render.Deferred.Base");
            ExecuteCommands();
            DrawGeometry(SortingCriteria.CommonOpaque, RenderQueueRange.all, ShaderTags.deferredBase);
            ExecuteCommands();
            commands.EndSample("Render.Deferred.Base");
            ExecuteCommands();
            commands.name = "Render.Deferred.Add";
            commands.BeginSample("Render.Deferred.Add");
            ExecuteCommands();
            DrawGeometry(SortingCriteria.CommonOpaque, RenderQueueRange.all, ShaderTags.deferredAdd0);
            ProceduralDrawCall.DrawAll(commands, 0);
            ExecuteCommands();
            commands.EndSample("Render.Deferred.Add");
            ExecuteCommands();
        }

        /// <summary>
        /// Renders a list of custom shader passes, given culling, sorting and render queue.
        /// Lighting model is not imposed here, so special effects can be achieved.
        /// </summary>
        public override void DoRenderCustomPass(CullingResults culling, SortingCriteria sorting, RenderQueueRange range, params ShaderTagId[] passes)
        {
            commands.name = "Render.Custom";
            commands.BeginSample("Render.Custom");
            ExecuteCommands();
            DrawGeometry(culling, sorting, range, passes);
            ExecuteCommands();
            commands.EndSample("Render.Custom");
            ExecuteCommands();
        }

        /// <summary>
        /// Draws lighting effects on the final frame target.
        /// </summary>
        private void DoLightsPostProcess()
        {
            CreateRenderTarget(ShaderProperties.grabPostLightsTarget, camera.pixelWidth, camera.pixelHeight, 0, RenderTextureFormat.ARGB32, false);
            ExecuteCommands();
            BlitRenderTarget(ShaderProperties.frameDefferedTarget, ShaderProperties.grabPostLightsTarget);
            ExecuteCommands();
            SetTexParam(ShaderProperties.grabPostLightsTarget, ShaderProperties.grabPostLightsTarget);
            ExecuteCommands();
            commands.name = "Render.Lights.Post";
            commands.BeginSample("Render.Lights.Post");
            ExecuteCommands();
            DrawGeometry(SortingCriteria.CommonTransparent, RenderQueueRange.all, ShaderTags.lowResPostProcess);
            ProceduralDrawCall.DrawAll(commands, 0);
            ExecuteCommands();
            commands.EndSample("Render.Lights.Post");
            ExecuteCommands();
            ReleaseRenderTarget(ShaderProperties.grabPostLightsTarget);
            ExecuteCommands();
        }

        /// <summary>
        /// Makes the GBuffer accessible in shaders as texture uniforms.
        /// </summary>
        private void GrabGBuffer()
        {
            SetTexParam(ShaderProperties.backdepthTarget, ShaderProperties.backdepthTarget);
            SetTexParam(ShaderProperties.albedoTarget, ShaderProperties.albedoTarget);
            SetTexParam(ShaderProperties.positionTarget, ShaderProperties.positionTarget);
            SetTexParam(ShaderProperties.normalTarget, ShaderProperties.normalTarget);
            SetTexParam(ShaderProperties.reflectionTarget, ShaderProperties.reflectionTarget);
            SetTexParam(ShaderProperties.transluencyTarget, ShaderProperties.transluencyTarget);
            SetTexParam(ShaderProperties.globalIlluminationTarget, ShaderProperties.globalIlluminationTarget);
            SetTexParam(ShaderProperties.depthTarget, ShaderProperties.depthTarget);
            ExecuteCommands();
        }

        /// <summary>
        /// Renders the transparent geometry, which does not benefit from the deferred lighting model and is unlit by default.
        /// </summary>
        private void DoRenderTransparent()
        {
            DrawGeometry(SortingCriteria.CommonTransparent, RenderQueueRange.all, ShaderTags.TransparentPasses);
            ProceduralDrawCall.DrawAll(commands, 1);
            ExecuteCommands();
        }

        /// <summary>
        /// Renders the lighting onto the final render target.
        /// </summary>
        private void DoRenderLights()
        {
            commands.name = "Render.Lights";
            commands.BeginSample("Render.Lights");
            LightingPipeline.RenderGlobalIllumination();
            LightingPipeline.RenderLights();
            LightingPipeline.RenderReflections();
            LightingPipeline.RenderEditorLights();
            LightingPipeline.RenderSky();
            commands.EndSample("Render.Lights");
            ExecuteCommands();
        }

        private void DoRenderGizmos()
        {
            DrawGizmos();
            ExecuteCommands();
        }

        /// <summary>
        /// Renders the checker depth mask onto the screen, masking half its pixels in depth testing.
        /// </summary>
        private void DoRenderDepthMask()
        {
            if (isSceneView) return;
            Matrix4x4 matrix = Matrix4x4.TRS(camera.transform.position + camera.transform.forward * (camera.nearClipPlane + 0.0001f),
                camera.transform.rotation, Vector3.one);
            commands.DrawMesh(fullscreenTriangle, matrix, depthMaskMaterial, 0, 0, depthMaskProperties);
            ExecuteCommands();
        }

        /// <summary>
        /// Renders the final frame onto the camera's target texture.
        /// Call this after all your draw calls.
        /// </summary>
        private void DoRenderDeferred()
        {
            commands.name = "Blit Result to Screen";
            //commands.BeginSample("BlitToScreen");
            ExecuteCommands();

            commands.SetRenderTarget(BuiltinRenderTextureType.CameraTarget, RenderBufferLoadAction.Load, RenderBufferStoreAction.DontCare,
                ShaderProperties.depthTarget, RenderBufferLoadAction.Load, RenderBufferStoreAction.DontCare);
            ExecuteCommands();

            if (isSceneView)
            {
                Matrix4x4 matrix = Matrix4x4.TRS(camera.transform.position + camera.transform.forward * (camera.nearClipPlane + 0.0001f),
                camera.transform.rotation, Vector3.one);
                commands.SetGlobalTexture(ShaderProperties.frameDefferedTarget, ShaderProperties.frameDefferedTarget);
                commands.DrawMesh(fullscreenTriangle, matrix, depthMaskMaterial, 0, 2, depthMaskProperties);
            }
            else
            {
                Matrix4x4 matrix = Matrix4x4.TRS(camera.transform.position + camera.transform.forward * (camera.nearClipPlane + 0.0001f),
                camera.transform.rotation, Vector3.one);
                commands.SetGlobalTexture(ShaderProperties.frameDefferedTarget, ShaderProperties.frameDefferedTarget);
                commands.DrawMesh(fullscreenTriangle, matrix, depthMaskMaterial, 0, 1, depthMaskProperties);
            }
            //commands.EndSample("BlitToScreen");
            ExecuteCommands();
        }

        /// <summary>
        /// Displays the UI elements in the world for the camera to render them.
        /// Call this before attempting to render UI elements.
        /// </summary>
        private void DoEmitUI()
        {
            ScriptableRenderContext.EmitGeometryForCamera(camera);
        }

        /// <summary>
        /// Draws UI elements on screen.
        /// This should be done after the rest of the frame has been drawn.
        /// </summary>
        private void DoRenderUI()
        {
            commands.name = "Render.UI";
            commands.BeginSample("Render.UI");
            ExecuteCommands();

            DrawGeometry(SortingCriteria.CanvasOrder, RenderQueueRange.all, ShaderTags.UIPasses);
            if (camera.cameraType == CameraType.Game) RenderContext.DrawUIOverlay(camera);
            ExecuteCommands();

            commands.EndSample("Render.UI");
            ExecuteCommands();
        }

        /// <summary>
        /// Apply image filters and effect while the frame is still half its resolution to gain in efficiency.
        /// </summary>
        private void DoRenderLowResPostProcess()
        {
            commands.name = "PostProcess.LowRes";
            commands.BeginSample("PostProcess.LowRes");
            ExecuteCommands();

            // Blit current to src
            commands.Blit(ShaderProperties.frameDefferedTarget, ShaderProperties.postProcessLow);
            ExecuteCommands();

            PostProcess.RenderLowRes(this, ShaderProperties.postProcessLow, ShaderProperties.frameDefferedTarget);
            ExecuteCommands();

            commands.EndSample("PostProcess.LowRes");
            ExecuteCommands();
        }

        /// <summary>
        /// Apply image filters and effects when the frame is computed back to its full size.
        /// Filters in this stage take more resources.
        /// </summary>
        private void DoRenderFullResPostProcess()
        {
            commands.name = "PostProcess.FullRes";
            commands.BeginSample("PostProcess.FullRes");
            ExecuteCommands();

            // Blit current to src
            commands.Blit(CameraTarget, ShaderProperties.postProcessLow);
            ExecuteCommands();

            PostProcess.RenderFullRes(this, ShaderProperties.postProcessLow, CameraTarget);
            ExecuteCommands();

            commands.EndSample("PostProcess.FullRes");
            ExecuteCommands();
        }

        /// <summary>
        /// Draws the shadows of the camera that is currently set.
        /// </summary>
        private void DoRenderShadows()
        {
            commands.name = "Render.Shadows";
            commands.BeginSample("Render.Shadows");
            ExecuteCommands();

            commands.ClearRenderTarget(true, true, Color.black);
            ExecuteCommands();

            DrawGeometry(SortingCriteria.CommonOpaque, RenderQueueRange.opaque, ShaderTags.shadows);
            ExecuteCommands();

            commands.EndSample("Render.Shadows");
            ExecuteCommands();
        }

        /// <summary>
        /// The shadow rendering pipeline.
        /// </summary>
        protected override void OnRenderShadows()
        {
            Setup();
            BeginRender();
            SetGlobalParams();
            DoRenderShadows();
            EndRender();
        }

        /// <summary>
        /// Detects if any of the required resources for this renderer is broken,
        /// and if so, calls OnEnable again.
        /// </summary>
        private void InitializeIfBroken()
        {
            // It seams the pipeline object may be kept from the editor context to the game context, but assets such as the fullscreen triangle are not.
            if (fullscreenTriangle == null) 
                OnEnable();
        }

        /// <summary>
        /// The complete pipeline of rendering for this checker based process.
        /// </summary>
        protected override void OnRenderCamera()
        {
            // Setup
            InitializeIfBroken();
            DoEmitUI();
            BeginRenderLighting();
            Setup();
            BeginRender();
            ProceduralDrawCall.CullAll(camera);
            SetGlobalParams();
            UpdateCheckerId();
            CreateRenderTargets();

            // Depth only
            DoRenderDepth();

            // GBuffer, opaque
            SetGBufferAsTarget();
            DoRenderOpaque();
            GrabGBuffer();
            SetCameraAsTarget();

            // Lights
            DoRenderLights();

            // Transparent
            DoRenderTransparent();
             
            // Gizmos
            DoRenderGizmos();

            // Low Res Effects
            DoRenderLowResPostProcess();

            // Blit to screen
            DoRenderDeferred();

            // Full Res Effects
            DoRenderFullResPostProcess();

            // UI
            DoRenderUI();

            // Clean up
            ReleaseRenderTargets();
            EndRenderLighting();
            EndRender();
        }
    }
}