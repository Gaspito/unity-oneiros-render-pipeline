using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace Oneiros.Rendering
{
    [ExecuteInEditMode]
    public class OneirosTerrainRenderer : MonoBehaviour
    {
        public enum Resolution:int { _128 = 128, _256 = 256, _512 = 512, _1024 = 1024}

        [SerializeField]
        private Mesh m_mesh;

        [SerializeField]
        private Material m_material;
        [SerializeField]
        private OneirosTerrainLayersAsset m_layers;
        [SerializeField]
        private Resolution m_resolution;

        public int TextureResolution => (int)m_resolution;

        [SerializeField]
        private Texture2D m_heightmap;
        [SerializeField]
        private Texture2D m_layerIndices;
        [SerializeField]
        private Texture2D m_layerWeights;
        //[SerializeField]
        private Vector2 m_heightmapResolution;
        [SerializeField, Range(0, 200)]
        private float m_heightRange = 50;
        [SerializeField]
        private Vector2 m_layerResolution;

        private MeshFilter m_filter;
        private MeshRenderer m_renderer;
        private MaterialPropertyBlock m_materialProperties;

        private bool m_inEditMode = false;
        private Material m_sharedMaterial;
        private Texture2DArray m_perLayerWeights;

        public bool IsInEditMode => m_inEditMode;

        private void OnEnable()
        {
            if (!TryGetComponent<MeshFilter>(out m_filter))
            {
                m_filter = gameObject.AddComponent<MeshFilter>();
                m_filter.hideFlags = HideFlags.HideAndDontSave;
                m_filter.mesh = m_mesh;
            }

            if (!TryGetComponent<MeshRenderer>(out m_renderer))
            {
                m_renderer = gameObject.AddComponent<MeshRenderer>();
                m_renderer.hideFlags = HideFlags.HideAndDontSave;
            }

            m_heightmapResolution = new Vector2(m_heightmap.width, m_heightmap.height);

            m_materialProperties = new MaterialPropertyBlock();

            SetMaterialProperties();
        }

        private void SetMaterialProperties()
        {
            m_materialProperties.SetTexture("_Heightmap", m_heightmap);
            m_materialProperties.SetTexture("_TerrainLayers_Albedo", m_layers.AlbedoArray);
            m_materialProperties.SetTexture("_TerrainLayerIndices", m_layerIndices);
            m_materialProperties.SetTexture("_TerrainLayerWeights", m_layerWeights);
            m_materialProperties.SetVector("_Heightmap_Size", new Vector3(m_heightmapResolution.x, m_heightmapResolution.y, m_heightRange));
            m_materialProperties.SetVector("_TerrainLayer_Size", m_layerResolution);
            m_renderer.SetPropertyBlock(m_materialProperties);
        }

        private void OnDisable()
        {
            m_materialProperties = null;
        }

#if UNITY_EDITOR

        private TexturePainter m_painter;

        private Texture2D CopyTexture(Texture2D src, Texture2D dest)
        {
            if (src == null) return dest;

            RenderTextureFormat format = RenderTextureFormat.ARGB32;

            if (dest.format == TextureFormat.RGBAFloat) format = RenderTextureFormat.ARGBFloat;

            RenderTexture tempRender = new RenderTexture(dest.width, dest.height, 0, format, 1);
            tempRender.Create();
            Graphics.Blit(src, tempRender);
            Graphics.CopyTexture(tempRender, dest);
            tempRender.Release();

            return dest;
        }

        public void BeginEdit()
        {
            if (m_inEditMode) return;
            m_inEditMode = true;
            m_sharedMaterial = m_material;
            m_material = new Material(m_sharedMaterial);
            m_material.EnableKeyword("SAMPLE_TERRAIN_EXPLICIT");
            m_renderer.material = m_material;

            m_perLayerWeights = new Texture2DArray(TextureResolution, TextureResolution, m_layers.Count, TextureFormat.ARGB32, 1, true);

            SeparateIW();

            m_materialProperties.SetTexture("_TerrainPerLayerWeights", m_perLayerWeights);
            m_materialProperties.SetInt("_TerrainLayerCount", m_layers.Count);

            m_painter = TexturePainter.GetWindow<TexturePainter>("Paint Terrain");
            m_painter.collider = GetComponent<Collider>();
            m_painter.onCustomGui = OnPainterGUI;
            m_painter.onClose = OnPainterClose;

            SetMaterialProperties();
        }

        private System.Action m_onChangeEditedTexture;
        private int m_editedLayerId = 0;
        private bool m_needToSaveHeight = false;
        private bool m_needToSaveLayers = false;

        private void OnPainterGUI()
        {
            if (GUILayout.Button("Edit Height"))
            {
                m_needToSaveHeight = true;
                m_onChangeEditedTexture?.Invoke();

                m_heightmap = CopyTexture(m_heightmap,
                    new Texture2D(TextureResolution, TextureResolution, TextureFormat.ARGB32, 1, true));

                m_painter.target?.Release();
                m_painter.target = new RenderTexture(TextureResolution, TextureResolution, 0, RenderTextureFormat.ARGB32, 1);
                m_painter.target.Create();
                Graphics.CopyTexture(m_heightmap, m_painter.target);

                m_painter.onPaint = (RenderTexture result) =>
                {
                    Graphics.CopyTexture(result, m_heightmap);
                };

                m_materialProperties.SetTexture("_Heightmap", m_heightmap);
                m_renderer.SetPropertyBlock(m_materialProperties);

                m_onChangeEditedTexture = () => { m_heightmap = TexturePainter.RenderToTexture(m_painter.target); };
            }

            for (int i = 0; i < m_layers.Count; i++)
            {
                if (GUILayout.Button("Edit Layer "+(i+1)))
                {
                    m_needToSaveLayers = true;
                    m_onChangeEditedTexture?.Invoke();

                    m_editedLayerId = i;

                    m_painter.target?.Release();
                    m_painter.target = new RenderTexture(TextureResolution, TextureResolution, 0, RenderTextureFormat.ARGB32, 1);
                    m_painter.target.Create();
                    Graphics.CopyTexture(m_perLayerWeights, m_editedLayerId, m_painter.target, 0);

                    m_painter.onPaint = (RenderTexture result) =>
                    {
                        Graphics.CopyTexture(result, 0, m_perLayerWeights, m_editedLayerId);
                    };

                    m_onChangeEditedTexture = () => { };

                    m_materialProperties.SetTexture("_TerrainPerLayerWeights", m_perLayerWeights);
                    m_renderer.SetPropertyBlock(m_materialProperties);
                }
            }

            if (GUILayout.Button("save and quit"))
            {
                m_onChangeEditedTexture?.Invoke();
                EndEdit();
            }
        }

        private void OnPainterClose()
        {
            EndEdit();
            m_painter = null;
        }

        private void SeparateIW()
        {
            for (int i = 0; i < m_layers.Count; i++)
            {
                Color[] layerColor = m_perLayerWeights.GetPixels(i, 0);
                for (int x = 0; x < m_perLayerWeights.width; x++)
                {
                    for (int y = 0; y < m_perLayerWeights.height; y++)
                    {
                        Color indexColor = m_layerIndices.GetPixel(x, y);
                        int index = (int)indexColor.r;
                        if (index == i)
                        {
                            layerColor[x + y * m_perLayerWeights.width] = m_layerWeights.GetPixel(x, y);
                        }
                        else
                        {
                            layerColor[x + y * m_perLayerWeights.width] = Color.black;
                        }
                    }
                }
                m_perLayerWeights.SetPixels(layerColor, i);
            }
            m_perLayerWeights.Apply(false, false);
        }

        private void CombineIW()
        {
            RenderTexture tempRender = new RenderTexture(TextureResolution, TextureResolution, 0, RenderTextureFormat.ARGB32, 0);
            tempRender.Create();
            Material blitMat = new Material(Shader.Find("Hidden/TerrainLayersBlit"));
            blitMat.SetTexture("_Layers", m_perLayerWeights);
            blitMat.SetInt("_LayerCount", m_layers.Count);

            Graphics.Blit(m_layerIndices, tempRender, blitMat, 1);
            m_layerIndices = TexturePainter.RenderToTexture(tempRender);
            //Graphics.CopyTexture(tempRender, m_layerIndices);
            Graphics.Blit(m_layerWeights, tempRender, blitMat, 2);
            //Graphics.CopyTexture(tempRender, m_layerWeights);
            m_layerWeights = TexturePainter.RenderToTexture(tempRender);

            tempRender.Release();
        }

        private string TrimAssetPath(string path)
        {
            if (path.StartsWith(Application.dataPath))
            {
                path = "Assets" + path.Substring(Application.dataPath.Length);
            }
            return path;
        }

        public void EndEdit()
        {
            if (!m_inEditMode) return;
            m_inEditMode = false;
            m_material = m_sharedMaterial;
            m_material.DisableKeyword("SAMPLE_TERRAIN_EXPLICIT");
            m_renderer.material = m_material;

            m_painter?.Close();

            string ext = "png";

            string pathToTextures = EditorUtility.SaveFilePanelInProject("Save Textures", "Terrain Data", ext, "message");
            if (pathToTextures.Length > 0)
            {
                string pathToHeight = pathToTextures.Replace("."+ ext, "") + " height."+ ext;
                string pathToIndices = pathToTextures.Replace("."+ ext, "") + " indices."+ ext;
                string pathToWeights = pathToTextures.Replace("."+ ext, "") + " weights."+ ext;

                CombineIW();

                if (m_needToSaveHeight)
                {
                    m_needToSaveHeight = false;
                    System.IO.File.WriteAllBytes(pathToHeight, m_heightmap.EncodeToPNG());

                    AssetDatabase.Refresh();          
                    pathToHeight = TrimAssetPath(pathToHeight);
                    m_heightmap = AssetDatabase.LoadAssetAtPath<Texture2D>(pathToHeight);
                }
                if (m_needToSaveLayers)
                {
                    m_needToSaveLayers = false;
                    System.IO.File.WriteAllBytes(pathToIndices, m_layerIndices.EncodeToPNG());
                    System.IO.File.WriteAllBytes(pathToWeights, m_layerWeights.EncodeToPNG());

                    AssetDatabase.Refresh();
                    pathToIndices = TrimAssetPath(pathToIndices);
                    pathToWeights = TrimAssetPath(pathToWeights);
                    m_layerIndices = AssetDatabase.LoadAssetAtPath<Texture2D>(pathToIndices);
                    m_layerWeights = AssetDatabase.LoadAssetAtPath<Texture2D>(pathToWeights);
                }
            }

            SetMaterialProperties();
        }
#endif
    }

#if UNITY_EDITOR
    [CustomEditor(typeof(OneirosTerrainRenderer))]
    public class OneirosTerrainRendererEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            OneirosTerrainRenderer obj = (OneirosTerrainRenderer)target;
            if (GUILayout.Button("Paint"))
            {
                if (obj.IsInEditMode) obj.EndEdit();
                else obj.BeginEdit();
            }
            base.OnInspectorGUI();
        }
    }
#endif
}