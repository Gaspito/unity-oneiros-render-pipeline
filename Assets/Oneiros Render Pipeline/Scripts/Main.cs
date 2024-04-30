using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering
{

    /// <summary>
    /// A custom render pipeline with the following features:
    /// <list type="bullet">
    /// <term>Checker-Based Rendering</term>
    ///     <description>A feature used in PS4 games. Each frame rendered is only half the size of the screen. However, every other frame renders a different half of the screen, spread in a checker pattern. The frames are then reconstructed back together, using motion vectors to blur any gap. The result is a fast rendering pipeline.</description>
    /// </list>
    /// <list type="bullet">
    /// <term>Defferred Lighting</term>
    ///     <description>Instead of the standard Forward Lighting model, this pipeline uses the deffered approach, which limits shader passes to the minimum. A physically based rendering material is used to populate a number of rendering buffers, each with different info about their pixels (color, normal, position, roughness, etc.). Then, each light is processed as mesh with a special shader that fetches data from these buffers to write the actual lit-pixel color to the frame buffer.</description>
    /// </list>
    /// 
    /// All of this results in a very fast and efficient pipeline, sometimes boosting the framerate to more than 300 frames per seconds.
    /// 
    /// The pipeline is also highly customizable to every need of a project.
    /// </summary>
    public partial class OneirosRenderPipeline : RenderPipeline
    {
        /// <summary>
        /// The current running instance of the Oneiros Render pipeline.
        /// There can only be one rendering pipeline running per game.
        /// Although what the pipeline does can be changed on the fly during the game.
        /// </summary>
        public static OneirosRenderPipeline Instance { get; private set; }

        /// <summary>
        /// The shadow settings of this pipeline.
        /// </summary>
        public ShadowSettings ShadowSettings { get; private set; }

        /// <summary>
        /// The compute shader used to stitch back together the renders of 2 consecutive frames.
        /// </summary>
        public ComputeShader cbrFrameReconstructShader;

        public OneirosRenderPipeline(ShadowSettings shadowSettings, ComputeShader cbrFrameReconstructShader)
        {
            Instance = this;
            ShadowSettings = shadowSettings;
            this.cbrFrameReconstructShader = cbrFrameReconstructShader;
        }

        /// <summary>
        /// The current render context the pipeline is working with.
        /// Although this can be changed easily, the best performance is achieved when it stays the same.
        /// </summary>
        public ScriptableRenderContext RenderContext { get; private set; }

        /// <summary>
        /// The current camera renderer. This is a sub-pipeline specific to a camera in the game.
        /// A camera that needs to render a special effect needs a different camera renderer.
        /// </summary>
        public OneirosCameraRenderer CameraRenderer { get; private set; }

        /// <summary>
        /// A global flag to enable or disable shadow processing and rendering, which can be costly.
        /// </summary>
        public static bool IsRenderingShadows { get; set; }

        /// <summary>
        /// This number limits the total of frames rendered in 1 second. If the current count exceeds, the game will wait the end of the current second to render what's next.
        /// Otherwise, we reach over 300 fps, which is way too fast for the eye to see any difference anyway, and the machine will run too fast for nothing.
        /// </summary>
        public int targetFrameRate = 70;

        /// <summary>
        /// Called by unity each frame to render a set of cameras with a context.
        /// </summary>
        /// <param name="context">The scriptable render context given by unity</param>
        /// <param name="cameras">An array of cameras to process.</param>
        protected override void Render(ScriptableRenderContext context, Camera[] cameras)
        {
            // "Start" the pipeline
            InitializePipeline(context);

            foreach (Camera camera in cameras)
            {
                // use the current camera renderer object to render each camera.
                CameraRenderer.Render(this, camera);
            }
        }

        protected void InitializePipeline(ScriptableRenderContext context)
        {
            // Set the render context instance to this frame's context
            RenderContext = context;
            
            // If no camera renderer object is setup, create a new default one.
            if (CameraRenderer == null)
            {
                CameraRenderer = new CheckerBasedRendering(); // default renderer
                CameraRenderer.OnEnable();

                Application.targetFrameRate = targetFrameRate;
            }
        }
        
        /// <summary>
        /// Sets a new camera renderer as the current instance.
        /// </summary>
        /// <param name="renderer">The camera renderer to use as the new instance from now on.</param>
        public static void SetCameraRenderer(OneirosCameraRenderer renderer)
        {
            Instance.CameraRenderer = renderer;
        }
    }
}