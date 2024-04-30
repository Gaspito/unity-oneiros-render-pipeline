using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Oneiros.Rendering
{
    [CreateAssetMenu(menuName = "Oneiros/Rendering/Terrain Layers", fileName ="New Terrain Layers")]
    public class OneirosTerrainLayersAsset : ScriptableObject
    {
        public enum TextureResolution:int { _128 = 128, _256 = 256, _512 = 512, _1024 = 1024}

        [Serializable]
        public class TerrainLayer
        {
            public Texture2D albedo;
            public Texture2D normal;
        }

        public TextureResolution resolution = TextureResolution._512;

        public List<TerrainLayer> layers;

        public int Count => layers.Count;

        [SerializeField, HideInInspector]
        private Texture2DArray m_arrayAlbedo;

        public void BuildAlbedo()
        {
            m_arrayAlbedo = new Texture2DArray((int)resolution, (int)resolution, layers.Count, TextureFormat.ARGB32, false);
            RenderTexture tempRender = new RenderTexture((int)resolution, (int)resolution, 0, RenderTextureFormat.ARGB32);
            tempRender.Create();
            for (int i = 0; i < layers.Count; i++)
            {
                Graphics.Blit(layers[i].albedo, tempRender);
                Graphics.CopyTexture(tempRender, 0, m_arrayAlbedo, i);
                //Graphics.CopyTexture(layers[i].albedo, 0, m_arrayAlbedo, i);
            }
            tempRender.Release();
        }

        public Texture2DArray AlbedoArray 
        { 
            get
            {
                if (m_arrayAlbedo == null || m_arrayAlbedo.depth != layers.Count)
                    BuildAlbedo();
                return m_arrayAlbedo;
            }
        }
    }

#if UNITY_EDITOR

    [UnityEditor.CustomEditor(typeof(OneirosTerrainLayersAsset))]
    public class OneirosTerrainLayersAssetEditor : UnityEditor.Editor
    {
        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();
            GUILayout.Space(20);
            GUILayout.BeginHorizontal();
            GUILayout.FlexibleSpace();
            if (GUILayout.Button("Build Arrays"))
            {
                OneirosTerrainLayersAsset obj = (OneirosTerrainLayersAsset)target;
                obj.BuildAlbedo();
            }
            GUILayout.EndHorizontal();
        }
    }

#endif
}