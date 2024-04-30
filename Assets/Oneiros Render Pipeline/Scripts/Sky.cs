using UnityEngine;
using System.Collections;
using Utilities;
using UnityEngine.Rendering;

namespace Oneiros.Rendering
{
    [ExecuteInEditMode]
    public class Sky : MonoBehaviour
    {
        public static Sky Instance;

        private static int p_indirectCube = Shader.PropertyToID("_environment");
        private static int p_indirectStrength = Shader.PropertyToID("_environmentStrength");

        public static Texture Texture
        {
            get
            {
                if (Instance != null)
                {
                    return Instance.cubemap;
                }
                else return Texture2D.blackTexture;
            }
        }

        public static float Strength
        {
            get
            {
                if (Instance != null) return Instance.strenght;
                return 1;
            }
        }

        public enum RenderMode { Cubemap, Material}

        public RenderMode renderMode = RenderMode.Cubemap;
        [ConditionalField(nameof(renderMode), ConditionType.Enum, RenderMode.Cubemap)]
        public Cubemap cubemap;
        [ConditionalField(nameof(renderMode), ConditionType.Enum, RenderMode.Cubemap), Range(0,1)]
        public float strenght;
        [ConditionalField(nameof(renderMode), ConditionType.Enum, RenderMode.Material)]
        public Material material;

        public float fogThickness = 0.2f;
        public Texture2D fogTexture;

        private void OnEnable()
        {
            if (Instance != this && Instance != null)
            {
                Destroy(Instance.gameObject);
            }
            Instance = this;
            Shader.SetGlobalFloat("_VolumeThickness", fogThickness);
            Shader.SetGlobalTexture("_VolumeFogTex", fogTexture);
        }

        public static void OnRender(Camera _camera, CommandBuffer _buffer, Mesh _mesh, Matrix4x4 _matrix, Material _defaultMaterial)
        {
            if (!Instance) return;

            switch (Instance.renderMode)
            {
                case RenderMode.Cubemap:
                    _buffer.SetGlobalTexture(p_indirectCube, Sky.Texture);
                    _buffer.SetGlobalFloat(p_indirectStrength, Sky.Strength);
                    //if (_camera.cameraType == CameraType.Preview)
                    _buffer.DrawMesh(_mesh, _matrix, _defaultMaterial, 0, 3);
                    _buffer.DrawMesh(_mesh, _matrix, _defaultMaterial, 0, 4);
                    break;
                case RenderMode.Material:
                    _buffer.DrawMesh(_mesh, _matrix, Instance.material, 0, 0);
                    _buffer.DrawMesh(_mesh, _matrix, Instance.material, 0, 1);
                    break;
                default: break;
            }
        }
    }
}
