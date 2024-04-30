using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering.ImageEffects
{
    [CreateAssetMenu(menuName = "Post Process/Vignette Effect")]
    public class IE_VignetteEffect : PostProcess
    {
        private const string SHADER_NAME = "Hidden/PostProcess/VignetteEffect";

        private static int mainTexId = Shader.PropertyToID("_MainTex");

        private Mesh fullscreenTriangle;
        private Material material;

        [SerializeField]
        private Texture2D maskTex;
        [SerializeField, Range(0, 1)]
        private float strength = 0.5f;
        [SerializeField]
        private Color tint;

        private void Initialize()
        {
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
            material = new Material(Shader.Find(SHADER_NAME));
            material.SetTexture("_MaskTex", maskTex);
            material.SetFloat("_Strength", strength);
            material.SetColor("_Tint", tint);
        }

        public override void OnLowResProcess(OneirosCameraRenderer renderer, RenderTargetIdentifier src, RenderTargetIdentifier dest)
        {
            if (material == null) return;

            renderer.Commands.SetGlobalTexture(mainTexId, src);

            renderer.Commands.Blit(src, dest, material);

            renderer.Commands.Blit(dest, src);

            return;

            Camera camera = renderer.Camera;
            Matrix4x4 matrix = Matrix4x4.TRS(camera.transform.position + camera.transform.forward * (camera.nearClipPlane + 0.0001f),
                camera.transform.rotation, Vector3.one);
            renderer.Commands.DrawMesh(fullscreenTriangle, matrix, material);
        }

        private void OnEnable()
        {
            Initialize();
        }
    }
}