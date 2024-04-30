using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering.ImageEffects
{
    [CreateAssetMenu(menuName = "Post Process/Apparate")]
    public class IE_Apparate : PostProcess
    {
        private static int mainTexId = Shader.PropertyToID("_BackgroundRenderTex");

        public Mesh mesh;
        public Material material;
        [Header("Transform")]
        public Vector3 position;
        public Vector3 rotation;
        public Vector3 scale = Vector3.one;

        [Header("Runtime"), Space(20)]
        public Texture2D sourceTexture;

        public Matrix4x4 Matrix { get; set; }

        private void Initialize()
        {
            Matrix = Matrix4x4.TRS(position, Quaternion.Euler(rotation), scale);
        }

        private void ReadScreenTexture(Camera cam)
        {
            sourceTexture = new Texture2D(cam.pixelWidth, cam.pixelHeight, TextureFormat.ARGB32, false);
            sourceTexture.ReadPixels(new Rect(0, 0, cam.pixelWidth, cam.pixelHeight), 0, 0, false);
            sourceTexture.Apply();
            material.SetTexture("_SrcRenderTex", sourceTexture);
        }

        public override void OnLowResProcess(OneirosCameraRenderer renderer, RenderTargetIdentifier src, RenderTargetIdentifier dest)
        {
            if (sourceTexture == null)
                ReadScreenTexture(renderer.Camera);

            renderer.Commands.SetGlobalTexture(mainTexId, src);

            renderer.Commands.DrawMesh(mesh, Matrix, material);

            // blit dest to src for next post processes.
            renderer.Commands.Blit(dest, src);
        }

        private void OnEnable()
        {
            Initialize();
        }

        public void SetMatrix(Matrix4x4 _matrix)
        {
            Matrix = _matrix;
        }

        public void SetMatrix(Transform _transform)
        {
            Matrix = _transform.localToWorldMatrix;
        }
    }
}