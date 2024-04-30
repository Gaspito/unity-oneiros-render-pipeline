using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering
{
    /// <summary>
    /// Base class to derive from to create image effects applied correctly by the pipeline.
    /// Use Register and unregister to enable / disable them.
    /// </summary>
    public class PostProcess : ScriptableObject
    {
        private static List<PostProcess> activeProcess = new List<PostProcess>();

        private static int tempTargetId = Shader.PropertyToID("_TempPostProcessTarget");

        protected static RenderTargetIdentifier tempTarget;

        public void Register()
        {
            if (!activeProcess.Contains(this)) activeProcess.Add(this);
        }

        public void Unregister()
        {
            if (activeProcess.Contains(this)) activeProcess.Remove(this);
        }

        public bool IsRegistered()
        {
            return activeProcess.Contains(this);
        }

        public static void RenderLowRes(OneirosCameraRenderer renderer, RenderTargetIdentifier src, RenderTargetIdentifier dest)
        {
            foreach (var i in activeProcess) i.OnLowResProcess(renderer, src, dest);
        }

        public static void RenderFullRes(OneirosCameraRenderer renderer, RenderTargetIdentifier src, RenderTargetIdentifier dest)
        {
            foreach (var i in activeProcess) i.OnFullResProcess(renderer, src, dest);
        }

        public virtual void OnLowResProcess(OneirosCameraRenderer renderer, RenderTargetIdentifier src, RenderTargetIdentifier dest)
        {
            // Blit here for image effects on half resolution
        }

        public virtual void OnFullResProcess(OneirosCameraRenderer renderer, RenderTargetIdentifier src, RenderTargetIdentifier dest)
        {
            // Blit here for image effects on full resolution
        }
    }
}