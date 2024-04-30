using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Oneiros.Rendering
{
    /// <summary>
    /// Handles getting light data and the rendering of shadows.
    /// </summary>
    public class Lighting
    {
        private static int p_lightCountId = Shader.PropertyToID("in_light_count");
        private static int p_lightBufferId = Shader.PropertyToID("in_lights");
        private static int p_lightColor = Shader.PropertyToID("_Color");
        private static int p_lightIntensity = Shader.PropertyToID("_Intensity");
        private static int p_lightRange = Shader.PropertyToID("_Range");
        private static int p_lightDirection = Shader.PropertyToID("_LightDirection");
        private static int p_lightCookie = Shader.PropertyToID("_CookieTex");
        private static int p_indirectCube = Shader.PropertyToID("_environment");
        private static int p_indirectStrength = Shader.PropertyToID("_environmentStrength");

        private ComputeBuffer _lightBuffer;

        private LightRenderer[] _lights;

        private Shadows Shadows { get; set; }

        private OneirosCameraRenderer CameraRenderer { get; set; }

        private Mesh m_directionalLightMesh;
        private Material m_directionalLightMaterial;

        private Mesh m_pointLightMesh;
        private Material m_pointLightMaterial;

        private Mesh m_spotLightMesh;
        private Material m_spotLightMaterial;

        private Mesh m_indirectMesh;
        private Material m_indirectLightMaterial;

        public Lighting(OneirosCameraRenderer cameraRenderer)
        {
            CameraRenderer = cameraRenderer;
            Shadows = new Shadows(cameraRenderer);

            InitializeDirectionalLights();
            InitializePointLights();
            InitializeSpotLights();
            InitializeIndirectLights();
        }

        private void InitializeDirectionalLights() 
        {
            m_directionalLightMesh = Resources.Load<Mesh>("Mesh/DirectionalLight");
            m_directionalLightMaterial = new Material(Shader.Find("LOCAL/LIGHT/Directional Light"));
            m_directionalLightMaterial.SetTexture("_DitherTex", Resources.Load<Texture2D>("Textures/Simple Dithering"));
        }

        private void InitializePointLights()
        {
            m_pointLightMesh = Resources.Load<Mesh>("Mesh/PointLight"); 
            m_pointLightMaterial = new Material(Shader.Find("LOCAL/LIGHT/Point Light"));
        }

        private void InitializeSpotLights()
        {
            m_spotLightMesh = Resources.Load<Mesh>("Mesh/SpotLight");
            m_spotLightMaterial = new Material(Shader.Find("LOCAL/LIGHT/Spot Light"));
        }

        private void InitializeIndirectLights()
        {
            m_indirectMesh = Resources.Load<Mesh>("Mesh/IndirectLight");
            m_indirectLightMaterial = new Material(Shader.Find("LOCAL/LIGHT/Indirect Light"));
        }

        public void Setup()
        {
            Shadows.Setup();
        }

        public void OnBeginRender()
        {
            bool useDebugLighting = false;
            #if UNITY_EDITOR
            if (!Application.isPlaying && (UnityEditor.SceneView.lastActiveSceneView.sceneLighting == false
                || CameraRenderer.Camera.name == "Preview Scene Camera"))
            {
                useDebugLighting = true;
            }
            #endif

            if (useDebugLighting) Shader.DisableKeyword("LIGHTING_ON");
            else Shader.EnableKeyword("LIGHTING_ON");
        }

        public void RenderLights()
        {
            foreach (var light in CameraRenderer.Culling.visibleLights)
            {
                if (light.lightType == LightType.Point) RenderPointLight(light);
                else if (light.lightType == LightType.Spot) RenderSpotLight(light);
                else if (light.lightType == LightType.Directional) RenderDirectionalLight(light);
            }
        }

        public void RenderShadows()
        {
            foreach (var light in CameraRenderer.Culling.visibleLights)
            {
                if (light.lightType == LightType.Directional) RenderDirectionalShadows(light);
            }
        }

        public void RenderReflections()
        {
            foreach (var probe in CameraRenderer.Culling.visibleReflectionProbes)
            {
                RenderIndirectLight(probe); 
            }
        }

        public void RenderGlobalIllumination()
        {
            if (m_indirectMesh == null || m_indirectLightMaterial == null)
                InitializeIndirectLights();

            Matrix4x4 matrix = Matrix4x4.TRS(
                CameraRenderer.Camera.transform.position,
                Quaternion.identity,
                Vector3.one * CameraRenderer.Camera.nearClipPlane * 2
                );

            CameraRenderer.Commands.DrawMesh(m_indirectMesh, matrix, m_indirectLightMaterial, 0, 5);
        }

        private void RenderDirectionalLight(VisibleLight light)
        {
            #if UNITY_EDITOR
            if (light.light != null
                && light.light.lightmapBakeType == LightmapBakeType.Baked
                ) return;
            #endif

            if (m_directionalLightMesh == null || m_directionalLightMaterial == null)
            {
                InitializeDirectionalLights();
            }
            AdditionalLightData data = AdditionalLightData.GetDataOfLight(light.light);
            data.OnRenderLight(CameraRenderer.Commands);

            CameraRenderer.Commands.SetGlobalVector(p_lightColor, light.finalColor);
            CameraRenderer.Commands.SetGlobalFloat(p_lightIntensity, 1f);
            CameraRenderer.Commands.SetGlobalFloat(p_lightRange, light.range);
            CameraRenderer.Commands.DrawMesh(
                m_directionalLightMesh, 
                light.localToWorldMatrix, 
                m_directionalLightMaterial, 
                0, 0);
        }

        private void RenderDirectionalShadows(VisibleLight light)
        {
            #if UNITY_EDITOR
            if (light.light != null
                && light.light.lightmapBakeType == LightmapBakeType.Baked
                ) return;
            #endif

            if (m_directionalLightMesh == null || m_directionalLightMaterial == null)
            {
                InitializeDirectionalLights();
            }
            AdditionalLightData data = AdditionalLightData.GetDataOfLight(light.light);
            data.OnRenderShadows(CameraRenderer);
        }

        private void RenderPointLight(VisibleLight light)
        {
            #if UNITY_EDITOR
            if (light.light.lightmapBakeType == LightmapBakeType.Baked) return;
            #endif

            if (m_pointLightMesh == null || m_pointLightMaterial == null)
            {
                InitializePointLights();
            }
            AdditionalLightData data = AdditionalLightData.GetDataOfLight(light.light);
            data.OnRenderLight(CameraRenderer.Commands);

            Matrix4x4 matrix = Matrix4x4.TRS(
                light.light.transform.position, 
                light.light.transform.rotation, 
                Vector3.one * light.range
                );
            
            CameraRenderer.Commands.SetGlobalVector(p_lightColor, light.finalColor);
            CameraRenderer.Commands.SetGlobalFloat(p_lightIntensity, 1f);
            CameraRenderer.Commands.SetGlobalFloat(p_lightRange, light.range);
            CameraRenderer.Commands.SetGlobalTexture(p_lightCookie, data.pointLightCookie);

            CameraRenderer.Commands.DrawMesh(m_pointLightMesh, matrix, m_pointLightMaterial, 0, 0);
            //CameraRenderer.Commands.DrawMesh(m_pointLightMesh, matrix, m_pointLightMaterial, 0, 1);
            //CameraRenderer.Commands.DrawMesh(m_pointLightMesh, matrix, m_pointLightMaterial, 0, 2);
        }

        private void RenderSpotLight(VisibleLight light)
        {
            #if UNITY_EDITOR
            if (light.light.lightmapBakeType == LightmapBakeType.Baked) return;
            #endif

            if (m_spotLightMesh == null || m_spotLightMaterial == null)
            {
                InitializeSpotLights();
            }
            AdditionalLightData data = AdditionalLightData.GetDataOfLight(light.light);
            data.OnRenderLight(CameraRenderer.Commands);

            float farClipLength = Mathf.Sin(Mathf.Deg2Rad * light.spotAngle * 0.5f) * light.range;

            Matrix4x4 matrix = Matrix4x4.TRS(
                light.light.transform.position,
                light.light.transform.rotation,
                new Vector3(farClipLength * 2, farClipLength * 2, light.range)
                );

            CameraRenderer.Commands.SetGlobalVector(p_lightColor, light.finalColor);
            CameraRenderer.Commands.SetGlobalFloat(p_lightIntensity, 1f);
            CameraRenderer.Commands.SetGlobalFloat(p_lightRange, light.range);
            CameraRenderer.Commands.SetGlobalTexture(p_lightCookie, light.light.cookie);

            CameraRenderer.Commands.DrawMesh(m_spotLightMesh, matrix, m_spotLightMaterial, 0, 0);
            //CameraRenderer.Commands.DrawMesh(m_spotLightMesh, matrix, m_spotLightMaterial, 0, 1);
            //CameraRenderer.Commands.DrawMesh(m_spotLightMesh, matrix, m_spotLightMaterial, 0, 2);
        }

        private void RenderIndirectLight(VisibleReflectionProbe reflectionProbe)
        {
            if (m_indirectMesh == null || m_indirectLightMaterial == null)
            {
                InitializeIndirectLights();
            }

            Matrix4x4 matrix = Matrix4x4.TRS(
                reflectionProbe.reflectionProbe.transform.TransformPoint( reflectionProbe.center ),
                reflectionProbe.reflectionProbe.transform.rotation,
                reflectionProbe.reflectionProbe.size * 0.5f
                );

            CameraRenderer.Commands.SetGlobalTexture(p_indirectCube, reflectionProbe.texture);
            CameraRenderer.Commands.SetGlobalFloat(p_indirectStrength, reflectionProbe.reflectionProbe.intensity);
            CameraRenderer.Commands.DrawMesh( m_indirectMesh, matrix, m_indirectLightMaterial, 0, 0);
            CameraRenderer.Commands.DrawMesh( m_indirectMesh, matrix, m_indirectLightMaterial, 0, 1);
            CameraRenderer.Commands.DrawMesh( m_indirectMesh, matrix, m_indirectLightMaterial, 0, 2);
        }

        public void RenderEditorLights()
        {
            #if UNITY_EDITOR
            if (!Application.isPlaying && (UnityEditor.SceneView.lastActiveSceneView.sceneLighting == false
                || CameraRenderer.Camera.name == "Preview Scene Camera"))
            {
                VisibleLight virtualSun = new VisibleLight();
                virtualSun.localToWorldMatrix = Matrix4x4.Rotate(Quaternion.LookRotation(new Vector3(0.5f, -1, 0.2f), Vector3.up));
                virtualSun.finalColor = Color.white;
                virtualSun.lightType = LightType.Directional;
                RenderDirectionalLight(virtualSun);
            }
            #endif
        }

        public void RenderSky()
        {
            if (m_indirectMesh == null || m_indirectLightMaterial == null)
            {
                InitializeIndirectLights();
            }

            Matrix4x4 matrix = Matrix4x4.TRS( CameraRenderer.Camera.transform.position, 
                CameraRenderer.Camera.transform.rotation,
                CameraRenderer.Camera.farClipPlane * Vector3.one * 0.9f);

            Sky.OnRender(CameraRenderer.Camera, CameraRenderer.Commands, m_indirectMesh, matrix, m_indirectLightMaterial);

            /*
            float strength = Sky.Strength;

            #if UNITY_EDITOR
            if (!Application.isPlaying && (UnityEditor.SceneView.lastActiveSceneView.sceneLighting == false
                || CameraRenderer.Camera.cameraType == CameraType.Preview))
            {
                strength = 1;
            }
            #endif

            CameraRenderer.Commands.SetGlobalTexture(p_indirectCube, Sky.Texture);
            CameraRenderer.Commands.SetGlobalFloat(p_indirectStrength, Sky.Strength);

            if (CameraRenderer.Camera.cameraType != CameraType.Preview)
                CameraRenderer.Commands.DrawMesh(m_indirectMesh, matrix, m_indirectLightMaterial, 0, 3);

            if (CameraRenderer.Camera.clearFlags == CameraClearFlags.Skybox || CameraRenderer.Camera.cameraType == CameraType.Preview)
                CameraRenderer.Commands.DrawMesh(m_indirectMesh, matrix, m_indirectLightMaterial, 0, 4);
            */
        }

        public void OnEndRender()
        {
            Shadows.EndRender();
        }

        /// <summary>
        /// Sets global light buffer data.
        /// </summary>
        /// <param name="commands"></param>
        /// <param name="culling"></param>
        public void SetLightBuffer()
        {
            if (_lightBuffer != null) _lightBuffer.Dispose();
            if (_lights.Length > 0) _lightBuffer = new ComputeBuffer(_lights.Length, LightRenderer.SIZE);
            //CameraRenderer.Commands.SetComputeBufferCounterValue(_lightBuffer, (uint)_lights.Length);
            CameraRenderer.Commands.SetComputeBufferData(_lightBuffer, _lights);
            CameraRenderer.Commands.SetGlobalBuffer(p_lightBufferId, _lightBuffer);
            CameraRenderer.Commands.SetGlobalInt(p_lightCountId, _lights.Length);
            CameraRenderer.RenderContext.ExecuteCommandBuffer(CameraRenderer.Commands);
        }

        /// <summary>
        /// Builds a LightRenderer array of all the visible lights from the culling results
        /// of a camera renderer.
        /// </summary>
        /// <param name="culling"></param>
        /// <returns>LightRenderer array of all the visible lights</returns>
        public LightRenderer[] GetLightRenderers(CullingResults culling)
        {
            List<LightRenderer> renderers = new List<LightRenderer>();
            VisibleLight[] visibleLights = culling.visibleLights.ToArray();
            for (int i = 0; i < visibleLights.Length; i++)
            {
                VisibleLight visibleLight = visibleLights[i];
                LightRenderer lr;
                switch (visibleLight.lightType)
                {
                    case LightType.Spot:
                        break;
                    case LightType.Directional:
                        lr = LightRenderer.FromDirectionalLight(visibleLight.light);
                        lr.shadowId = Shadows.AssignShadowIndex(lr, visibleLight.light, i);
                        renderers.Add(lr);
                        break;
                    case LightType.Point:
                        lr = LightRenderer.FromPointLight(visibleLight.light);
                        renderers.Add(lr);
                        break;
                    case LightType.Area:
                        break;
                    case LightType.Disc:
                        break;
                    default:
                        break;
                }

            }
            return renderers.ToArray();
        }
    }
}