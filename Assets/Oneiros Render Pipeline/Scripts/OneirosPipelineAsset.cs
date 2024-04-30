using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering
{
    /// <summary>
    /// An asset for creating and storing settings for the Oneiros Rendering Pipeline.
    /// It needs to be created as an asset, then dragged in the project settings, under graphics -> render pipeline.
    /// </summary>
    [CreateAssetMenu(menuName ="Oneiros/Rendering/Pipeline Asset")]
    public class OneirosPipelineAsset : RenderPipelineAsset
    {
        /// <summary>
        /// Shadow settings for this pipeline.
        /// </summary>
        public ShadowSettings shadowSettings;

        /// <summary>
        /// Checker-based rendering reconstruction shader.
        /// This is the compute shader responsible for piecing together the different renders of each frame back together.
        /// There are several approaches to this, so the shader itself can be changed by the user.
        /// The default shader is located under <c>Assets/Oneiros Render Pipeline/Shaders/Special/CBR Frame Reconstruction.compute</c>.
        /// </summary>
        [Header("CBR")]
        public ComputeShader cbrFrameReconstructShader;

        /// <summary>
        /// This method called by Unity actually creates the pipeline, using the settings of this asset.
        /// See Main.cs for the definition of OneirosRenderPipeline.
        /// </summary>
        /// <returns>A new Oneiros Render Pipeline</returns>
        protected override RenderPipeline CreatePipeline()
        {
            return new OneirosRenderPipeline(shadowSettings, cbrFrameReconstructShader);
        }
    }
}