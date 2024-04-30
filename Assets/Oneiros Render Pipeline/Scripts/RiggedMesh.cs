using UnityEngine;
using System.Collections;
using System.Collections.Generic;

namespace Oneiros.Rendering
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(MeshRenderer))]
    [AddComponentMenu("Rendering/Rigged Mesh Renderer")]
    public class RiggedMesh : MonoBehaviour
    {
        public Rig rig;

        private MeshRenderer m_renderer;

        public MeshRenderer Renderer
        {
            get
            {
                if (m_renderer == null)
                {
                    m_renderer = GetComponent<MeshRenderer>();
                }
                return m_renderer;
            }
        }

        private void OnBecameVisible()
        {
            if (rig == null) return;
            rig.activeRiggedMeshCount++;
        }

        private void OnBecameInvisible()
        {
            if (rig == null) return;
            rig.activeRiggedMeshCount--;
        }

        private void OnEnable()
        {
            if (rig == null) return;
            rig.OnRigUpdate -= UpdateMaterial;
            rig.OnRigUpdate += UpdateMaterial;
        }

        private void OnDisable()
        {
            if (rig == null) return;
            rig.OnRigUpdate -= UpdateMaterial;
        }

        private void OnDestroy()
        {
            if (rig == null) return;
            rig.OnRigUpdate -= UpdateMaterial;
        }

        public void UpdateMaterial()
        {
            Renderer.SetPropertyBlock(rig.PropertyBlock);
        }
    }
}