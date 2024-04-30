using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering
{
    /// <summary>
    /// Base class for the oneiros rendering sub pipeline.
    /// It contains all the rendering commands.
    /// It also has a default order in which it calls them.
    /// However, you can customize this order in subclasses.
    /// </summary>
    public class OneirosCameraRenderer
    {
        protected OneirosRenderPipeline pipeline;

        /// <summary>
        /// The shadow settings of the current pipeline.
        /// </summary>
        public ShadowSettings ShadowSettings { get => pipeline.ShadowSettings; }

        public ScriptableRenderContext RenderContext { get => pipeline.RenderContext; }

        /// <summary>
        /// This object stores data on which renderers are currently visible in the scene and should be rendered.
        /// By passing down this object to drawing methods, the pipeline makes sure to not draw something off frame.
        /// For specific neeeds (like acheiving special effects), specific objects can be drawn directly without culling as well.
        /// </summary>
        public CullingResults Culling { get; protected set; }

        /// <summary>
        /// Sub-pipeline handling lighting related rendering.
        /// </summary>
        protected Lighting LightingPipeline { get; set; }

        /// <summary>
        /// The camera currently being processed.
        /// </summary>
        protected Camera camera;

        /// <summary>
        /// The current command buffer to append commands to and to process next.
        /// A command buffer is like a list of drawing commands to send to the gpu.
        /// The least commands the better. Also, for futur optimization, command buffers could be stored and reused every frame.
        /// </summary>
        protected CommandBuffer commands;

        /// <summary>
        /// The name of the current sample group. This is usefull to label processes in the frame debugger.
        /// </summary>
        protected string currentSample;

        protected static RenderTargetIdentifier CameraTarget { get { return BuiltinRenderTextureType.CameraTarget; } }
        protected static RenderTargetIdentifier CameraDepthTarget { get { return BuiltinRenderTextureType.Depth; } }

        // Getters for private or protected fields.
        public Camera Camera { get => camera; }
        public CommandBuffer Commands { get => commands; }

        // Shader properties used for image blitting.
        private static int p_uvStartOnTop = Shader.PropertyToID("uv_start_on_top");
        private readonly static int m_screenSizeProperty = Shader.PropertyToID("_ScreenSize");
        private readonly static int m_projectionParams = Shader.PropertyToID("_ProjectionParams");
        
        /// <summary>
        /// Renders this frame to the given camera.
        /// </summary>
        /// <param name="pipeline">The pipeline executing this renderer.</param>
        /// <param name="camera">The target camera.</param>
        public void Render(OneirosRenderPipeline pipeline, Camera camera)
        {
            this.pipeline = pipeline;
            this.camera = camera;
            this.commands = new CommandBuffer() { name = camera.name };
            currentSample = "";

            // Try culling, and abort if exception occurs.
            if (!Cull()) { return; }

            // Process different camera types differently.
            if (camera.cameraType == CameraType.Preview) OnRenderPreview();
            if (OneirosRenderPipeline.IsRenderingShadows) OnRenderShadows();
            else OnRenderCamera();

        }

        /// <summary>
        /// Tries to get the culling results for this camera, and sets it to the current instance field.
        /// </summary>
        /// <returns>True if the culling was successful.</returns>
        protected bool Cull()
        {
            if (camera.TryGetCullingParameters(out ScriptableCullingParameters parameters))
            {
                parameters.shadowDistance = Mathf.Min( ShadowSettings.directional.maxDistance, camera.farClipPlane);
                Culling = RenderContext.Cull(ref parameters);
                return true;
            }
            return false;
        }

        /// <summary>
        /// Gets the culling results for a camera and returns it.
        /// </summary>
        /// <param name="camera">The camera used as the point of view for culling.</param>
        /// <returns>Culling results to use in drawing commands.</returns>
        public CullingResults GetCameraCullingResults(Camera camera)
        {
            if (camera.TryGetCullingParameters(out ScriptableCullingParameters parameters))
            {
                parameters.shadowDistance = Mathf.Min(ShadowSettings.directional.maxDistance, camera.farClipPlane);
                return RenderContext.Cull(ref parameters);
            }
            return default;
        }

        /// <summary>
        /// Simpler pipeline for rendering with a preview camera in the inspector.
        /// </summary>
        protected virtual void OnRenderPreview()
        {
            OnRenderCamera();
            // TBD actually simplify the pipeline
        }

        /// <summary>
        /// Simpler pipeline for rendering with a shadow camera.
        /// </summary>
        protected virtual void OnRenderShadows()
        {
            OnRenderCamera();
            // TBD actually simplify the pipeline
        }

        /// <summary>
        /// Default lit render pipeline.
        /// </summary>
        protected virtual void OnRenderCamera()
        {
            BeginRenderLighting();
            Setup();
            BeginRender();
            DrawGeometry(SortingCriteria.CommonOpaque, RenderQueueRange.all, unlitShaderTagId);
            DrawSkybox();
            EndRender();
        }

        /// <summary>
        /// Begin a sample, a "category" of rendering, visible in the frame debugger.
        /// All drawing commands executed before endsample is called will be under that named sample.
        /// </summary>
        /// <param name="sampleName">The name to give the sample.</param>
        protected void BeginSample(string sampleName)
        {
            if (currentSample.Length > 0)
            {
                EndSample();
            }
            //Debug.Log("Begin Sample : " + sampleName);
            currentSample = sampleName;
            commands.BeginSample(sampleName);
            ExecuteCommands();
        }

        /// <summary>
        /// Ends the current named sample.
        /// </summary>
        protected void EndSample()
        {
            if (currentSample.Length == 0)
            {
                return;
            }
            //Debug.Log("End Sample : " + currentSample);
            commands.EndSample(currentSample);
            currentSample = "";
            ExecuteCommands();
        }

        /// <summary>
        /// Executes the current command buffer, then clears it.
        /// This method is called often as some commands need to be processed before others can start.
        /// </summary>
        protected void ExecuteCommands()
        {
            RenderContext.ExecuteCommandBuffer(commands);
            commands.Clear();
        }

        /// <summary>
        /// Initializes the Lighting pipeline, creating a default one if the field is null.
        /// </summary>
        protected void SetupLighting()
        {
            if (LightingPipeline == null) LightingPipeline = new Lighting(this);

            LightingPipeline.Setup();
        }

        /// <summary>
        /// Starts rendering lighting. After this step, each light type should be rendered (ambient, sky, point lights, spot lights, etc.).
        /// Shadows are rendered during this step (as shadow maps may be needed for lights.)
        /// </summary>
        protected void BeginRenderLighting()
        {
            SetupLighting();
            LightingPipeline.OnBeginRender();
            LightingPipeline.RenderShadows();
        }

        /// <summary>
        /// Marks the end of lighting rendering.
        /// Cleanup may be called during this callback.
        /// </summary>
        protected void EndRenderLighting()
        {
            LightingPipeline.OnEndRender();
        }

        /// <summary>
        /// Sets the current camera parameters to match the given camera.
        /// These parameters include global shader variables.
        /// </summary>
        /// <param name="camera">The camera to use from now on.</param>
        public void SetupCamera(Camera camera)
        {
            RenderContext.SetupCameraProperties(camera);
            commands.SetGlobalVector(m_screenSizeProperty, new Vector2(camera.pixelWidth, camera.pixelHeight));
            commands.SetGlobalVector(m_projectionParams, new Vector4(
                -1.0f,
                camera.nearClipPlane,
                camera.farClipPlane,
                1.0f / camera.farClipPlane));
            ExecuteCommands();
        }

        /// <summary>
        /// Basic initialization. Call this before rendering anything.
        /// </summary>
        protected void Setup()
        {
            SetupCamera(camera);
        }

        /// <summary>
        /// Called when the renderer is added to the pipeline.
        /// Use it to initialize processes.
        /// </summary>
        public virtual void OnEnable() { }

        /// <summary>
        /// Called at the start of rendering, before anything is actually rendered.
        /// Use this to create runtime objects.
        /// </summary>
        protected void BeginRender()
        {
        }

        /// <summary>
        /// Called at the end of rendering, when everything is rendered.
        /// Use this to cleanup resources.
        /// </summary>
        protected void EndRender()
        {
            //EndSample();
            //LightingPipeline.OnEndRender();
            ExecuteCommands();
            RenderContext.Submit();
        }

        /// <summary>
        /// Draws the skybox of the current camera.
        /// </summary>
        protected void DrawSkybox()
        {
            RenderContext.DrawSkybox(camera);
        }

        static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");

        // Drawing Commands


        protected void DrawGeometry(SortingCriteria sorting, RenderQueueRange range, params ShaderTagId[] passes)
        {
            DrawGeometry(Culling, sorting, range, passes);
        }

        /// <summary>
        /// Draws geometry (renderers) filtered by culling, sorting and passes criterias.
        /// Only renderers with materials with the given passes ID will be rendered.
        /// The less calls to this method the better for performances.
        /// </summary>
        /// <param name="culling">Culling parameters to use.</param>
        /// <param name="sorting">Sorting order</param>
        /// <param name="range">Render Queue Range filter</param>
        /// <param name="passes">The passes to render. Materials without any of these passes will be ignored.</param>
        protected void DrawGeometry(CullingResults culling, SortingCriteria sorting, RenderQueueRange range, params ShaderTagId[] passes)
        {
            SortingSettings sortingSettings = new SortingSettings(camera);
            sortingSettings.criteria = sorting;
            DrawingSettings drawingSettings = new DrawingSettings(passes[0], sortingSettings);
            for (int i = 1; i < passes.Length; i++)
            {
                drawingSettings.SetShaderPassName(i, passes[i]);
            }
            drawingSettings.enableDynamicBatching = true;
            drawingSettings.enableInstancing = true;
            drawingSettings.perObjectData = PerObjectData.Lightmaps | PerObjectData.LightProbe;
            FilteringSettings filteringSettings = new FilteringSettings(range);

            RenderContext.DrawRenderers(culling, ref drawingSettings, ref filteringSettings);
        }

        /// <summary>
        /// Creates a render target with the given parameters.
        /// </summary>
        /// <param name="nameID">Name of the texture</param>
        /// <param name="width">Width in pixels</param>
        /// <param name="height">Height in pixels</param>
        /// <param name="depth">Bit depth (16 or 24)</param>
        /// <param name="format">Color format of the texture (ARGB, RFloat, etc.)</param>
        /// <param name="isLinear">Color space of the texture. Color textures should not be linear. Data texture should.</param>
        /// <param name="aa">Anti Aliasing (0: none, 1+: multisampling)</param>
        /// <param name="isRW">determines if the texture should be set to Read & Write instead of standard write.</param>
        protected void CreateRenderTarget(int nameID, int width, int height, int depth, RenderTextureFormat format, bool isLinear, int aa=1, bool isRW=false)
        {
            commands.GetTemporaryRT(nameID, width, height, depth, FilterMode.Point, format,
                isLinear ? RenderTextureReadWrite.Linear : RenderTextureReadWrite.Default, aa, isRW, aa > 1 ? RenderTextureMemoryless.MSAA : RenderTextureMemoryless.None);
        }

        /// <summary>
        /// Sets the current render target of the pipeline to the given name IDs.
        /// The render target must have been created prior to this call.
        /// </summary>
        /// <param name="nameID">The name of the texture</param>
        protected void SetRenderTarget(int nameID)
        {
            commands.SetRenderTarget(nameID);
            ExecuteCommands();
        }

        /// <summary>
        /// Sets the current render target of the pipeline to the given name IDs.
        /// The render target must have been created prior to this call.
        /// </summary>
        protected void SetRenderTarget(int nameId, int depthId)
        {
            commands.SetRenderTarget(nameId, depthId, 0, 0, 0);
            ExecuteCommands();
        }

        /// <summary>
        /// Sets the current render target of the pipeline to the given name IDs.
        /// The render target must have been created prior to this call.
        /// </summary>
        protected void SetRenderTarget(RenderTargetIdentifier nameId, RenderTargetIdentifier depthId)
        {
            commands.SetRenderTarget(nameId, depthId);
            ExecuteCommands();
        }

        /// <summary>
        /// Sets the current render target arrays of the pipeline to the given name IDs.
        /// The render target must have been created prior to this call.
        /// </summary>
        protected void SetRenderTarget(int[] colorID, int depthID)
        {
            RenderTargetIdentifier[] colorBuffer = new RenderTargetIdentifier[colorID.Length];
            for (int i = 0; i < colorID.Length; i++)
            {
                colorBuffer[i] = colorID[i];
            }
            commands.SetRenderTarget(colorBuffer, depthID);
            ExecuteCommands();
        }

        /// <summary>
        /// Sets the current render target of the pipeline to the camera's target texture.
        /// </summary>
        protected void SetRenderTarget()
        {
            commands.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
            ExecuteCommands();
        }

        /// <summary>
        /// Clears the render target currently set as active by SetRenderTarget().
        /// </summary>
        /// <param name="color">True clears the color buffer.</param>
        /// <param name="depth">True clears the depth buffer.</param>
        protected void ClearRenderTarget(bool color, bool depth)
        {
            commands.ClearRenderTarget(depth, color, Color.clear);
            ExecuteCommands();
        }

        /// <summary>
        /// Disposes of a render target given by name and releases its memory.
        /// </summary>
        /// <param name="nameID">The name of the render target to release.</param>
        protected void ReleaseRenderTarget(int nameID)
        {
            commands.ReleaseTemporaryRT(nameID);
        }

        /// <summary>
        /// Copies the content of a render target to another render target.
        /// </summary>
        /// <param name="nameID">The source texture to copy.</param>
        /// <param name="destID">The destination texture to paste the source to.</param>
        protected void BlitRenderTarget(RenderTargetIdentifier nameID, RenderTargetIdentifier destID)
        {
            commands.Blit(nameID, destID);
            ExecuteCommands();
        }

        /// <summary>
        /// Copies the content of a render target to another render target, using a material and a pass ID to process each pixel.
        /// </summary>
        /// <param name="nameID">The source texture to copy.</param>
        /// <param name="destID">The destination texture to paste the source to.</param>
        /// <param name="material">The material to fetch the pass from.</param>
        /// <param name="pass">The pass index to process each pixel. Defaults to 0, the first pass in the material's shader.</param>
        protected void BlitRenderTarget(RenderTargetIdentifier nameID, RenderTargetIdentifier destID, Material material, int pass=0)
        {
            commands.Blit(nameID, destID, material, pass);
            ExecuteCommands();
        }

        // The following commands set global shader uniform values.
        
        protected void SetTexParam(int nameId, int textureId)
        {
            commands.SetGlobalTexture(nameId, textureId);
        }

        protected void SetIntParam(int nameId, int value)
        {
            commands.SetGlobalInt(nameId, value);
        }

        protected void SetBufferParam(int nameId, ComputeBuffer buffer)
        {
            commands.SetGlobalBuffer(nameId, buffer);
        }

        protected void SetVectorParam(int nameId, Vector4 vector)
        {
            commands.SetGlobalVector(nameId, vector);
        }

        protected void SetFloatParam(int nameId, float value)
        {
            commands.SetGlobalFloat(nameId, value);
        }

        /// <summary>
        /// Renders the Gizmos on screen.
        /// </summary>
        protected void DrawGizmos()
        {
            #if UNITY_EDITOR
            if (!UnityEditor.Handles.ShouldRenderGizmos()) return;
            #endif
            RenderContext.DrawGizmos(camera, GizmoSubset.PreImageEffects);
            RenderContext.DrawGizmos(camera, GizmoSubset.PostImageEffects);
        }

        /// <summary>
        /// Runs a compute shader kernel with the given group sizes. Rendering stops until the kernel is done running.
        /// </summary>
        /// <param name="shader">The shader to run</param>
        /// <param name="kernel">The kernel of the shader to run.</param>
        /// <param name="x">How many groups to dispatch in X</param>
        /// <param name="y">How many groups to dispatch in Y</param>
        /// <param name="z">How many groups to dispatch in Z</param>
        protected void DispatchCShader(ComputeShader shader, int kernel, int x, int y, int z)
        {
            commands.DispatchCompute(shader, kernel, x, y, z);
            ExecuteCommands();
        }

        /// <summary>
        /// Assigns a compute buffer uniform to a given compute shader kernel.
        /// </summary>
        protected void SetCShaderBuffer(ComputeShader shader, int kernel, int name, ComputeBuffer buffer)
        {
            commands.SetComputeBufferParam(shader, kernel, name, buffer);
        }

        /// <summary>
        /// Fill a compute buffer with the values in the given array.
        /// </summary>
        protected void FillCShaderBuffer(ComputeBuffer buffer, System.Array values)
        {
            commands.SetComputeBufferCounterValue(buffer,  (uint)values.Length);
            commands.SetComputeBufferData(buffer, values);
        }

        /// <summary>
        /// Set a compute shader global int parameter.
        /// </summary>
        protected void SetCShaderInt(ComputeShader shader, int name, int value)
        {
            commands.SetComputeIntParam(shader, name, value);
        }

        /// <summary>
        /// Sets texture as a uniform value of a given compute shader kernel.
        /// </summary>
        protected void SetCShaderTexture(ComputeShader shader, int kernel, int name, int texture)
        {
            commands.SetComputeTextureParam(shader, kernel, name, texture);
        }

        /// <summary>
        /// Releases the compute buffer into memory.
        /// </summary>
        protected void ReleaseCShaderBuffer(ComputeBuffer buffer)
        {
            buffer.Release();
        }

        /// <summary>
        /// Returns a list of all light renderers (point lights, spot lights, etc.) that are currently even partially visible this frame.
        /// </summary>
        protected LightRenderer[] GetLightRenderers()
        {
            return LightingPipeline.GetLightRenderers(Culling);
        }


        // CBR Processing


        /// <summary>
        /// Kernel ID of the Checkered-Based rendering compute shader to use to stitch frames back together.
        /// </summary>
        protected int m_cbrKernelId = -1;

        /// <summary>
        /// Initialize Checkered Based Rendering.
        /// </summary>
        protected void InitCbr()
        {
            if (m_cbrKernelId < 0) m_cbrKernelId = pipeline.cbrFrameReconstructShader.FindKernel("CSMain");
        }

        protected void SetCbrTexture(int propertyId, RenderTargetIdentifier texture)
        {
            commands.SetComputeTextureParam(pipeline.cbrFrameReconstructShader, m_cbrKernelId, propertyId, texture);
        }

        protected void SetCbrVector(int propertyId, Vector4 vector)
        {
            commands.SetComputeVectorParam(pipeline.cbrFrameReconstructShader, propertyId, vector);
        }

        protected void SetCbrInt(int propertyId, int value)
        {
            commands.SetComputeIntParam(pipeline.cbrFrameReconstructShader, propertyId, value);
        }

        /// <summary>
        /// Reconstructs a full image using only half a frame rendered in a checkered based manner.
        /// </summary>
        /// <param name="frameWidth">The full width of the frame to render.</param>
        /// <param name="frameHeight">The full height of the frame to render.</param>
        protected void ReconstructFrame(int frameWidth, int frameHeight)
        {
            // Dividing by 8 seams to be the optimized thead group size.
            int threadX = frameWidth / 8;
            int threadY = frameHeight / 8;
            commands.DispatchCompute(pipeline.cbrFrameReconstructShader, m_cbrKernelId, threadX, threadY, 1);
            ExecuteCommands();
        }

        public virtual void RenderCamera(Camera camera, RenderTargetIdentifier target) { }

        public virtual void EndRenderCamera() { }

        public virtual void DoRenderCustomPass(CullingResults culling, SortingCriteria sorting, RenderQueueRange range, params ShaderTagId[] passes) { }
    }
}