using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering
{
    [System.Serializable]
    public abstract class ShadowRenderer
    {
        protected static int ShadowTextureId = Shader.PropertyToID("_ShadowTex");
        protected static int ShadowBiasId = Shader.PropertyToID("_ShadowBias");
        protected static int ShadowProjectionId = Shader.PropertyToID("_ShadowProjection");
        protected static ShaderTagId shadowsTagId;

        public enum ShadowResolution : int { _32 = 32, _64 = 64, _128 = 128, _256 = 256, _512 = 512, _1024 = 1024 }

        [SerializeField]
        protected ShadowResolution resolution = ShadowResolution._128;

        public int Resolution => (int)resolution;

        [Range(0, 1)]
        public float bias = 0.1f;

        public virtual void OnEnable(AdditionalLightData ald) {
            shadowsTagId = new ShaderTagId("Shadow Caster");
        }
        public virtual void OnDisable(AdditionalLightData ald) { }

        public abstract void OnRenderRuntime(AdditionalLightData ald, OneirosCameraRenderer cameraRenderer);
        public abstract void OnRenderBaked(AdditionalLightData ald);
        public abstract void OnRenderLight(AdditionalLightData ald, CommandBuffer commandBuffer);

        protected void Destroy(Object obj)
        {
            #if UNITY_EDITOR
                if (UnityEditor.EditorApplication.isPlaying) Object.Destroy(obj);
                else Object.DestroyImmediate(obj);
            #else
                Object.Destroy(obj);
            #endif
        }
    }
}