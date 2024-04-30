using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Oneiros.Rendering
{
    /// <summary>
    /// Fixes the culling problem where meshes with special effects have bounds
    /// too small and get culled when the special effect shoulds still be visible.
    /// This component creates a copy of the mesh and overrides it's bounds.
    /// </summary>
    [ExecuteInEditMode]
    [AddComponentMenu("Rendering/Bounds Override")]
    public class BoundsOverride : MonoBehaviour
    {
        /// <summary>
        /// Dictionary used to avoid instanciating the same mesh multiple times for the same result.
        /// Overrides of the same mesh and bounds can use the same override mesh.
        /// </summary>
        private static Dictionary<string, BoundsOverride> activeOverrides = new Dictionary<string, BoundsOverride>();

        [SerializeField]
        private string m_identifier;

        /// <summary>
        /// The bounds that will override the ones of the renderer.
        /// </summary>
        [SerializeField]
        private Bounds m_bounds;

        /// <summary>
        /// The mesh filter attached to the same gameobject.
        /// </summary>
        private MeshFilter m_filter;

        /// <summary>
        /// The copy of the mesh with correct bounds.
        /// </summary>
        private Mesh m_meshCopy;

        /// <summary>
        /// The bounds currently used.
        /// </summary>
        public Bounds Bounds { get; private set; }

        /// <summary>
        /// Returns true if the bounds of the renderer need updating.
        /// </summary>
        public bool HasChanged => m_bounds != Bounds;

        private void Awake()
        {
            m_filter = GetComponent<MeshFilter>();
        }

        private void OnEnable()
        {
            if (!activeOverrides.ContainsKey(m_identifier))
            {
                activeOverrides.Add(m_identifier, this);
                m_meshCopy = Instantiate(m_filter.sharedMesh);
            }
        }

        private void OnDisable()
        {
            if (activeOverrides.ContainsKey(m_identifier) && activeOverrides[m_identifier] == this)
            {
                activeOverrides.Remove(m_identifier);
            }
        }

        private BoundsOverride GetActiveOverride(string id)
        {
            if (activeOverrides.ContainsKey(id)) return activeOverrides[id];
            else
            {
                activeOverrides.Add(id, this);
                m_meshCopy = Instantiate(m_filter.sharedMesh);
                return this;
            }
        }

        private void UpdateOverride(BoundsOverride activeOverride, Bounds bounds)
        {
            activeOverride.m_bounds = bounds;
            activeOverride.m_meshCopy.bounds = bounds;
            activeOverride.m_filter.mesh = m_meshCopy;
            activeOverride.Bounds = bounds;
        }

        public void UpdateSelf(BoundsOverride activeOverride)
        {
            m_bounds = activeOverride.Bounds;
            m_filter.mesh = activeOverride.m_meshCopy;
            Bounds = m_bounds;
        }

        private void FixedUpdate()
        {
            if (HasChanged)
            {
                BoundsOverride activeOverride = GetActiveOverride(m_identifier);
                UpdateOverride(activeOverride, m_bounds);
                UpdateSelf(activeOverride);
            }
        }

        private void OnDrawGizmosSelected()
        {
            Gizmos.color = Color.green;
            Gizmos.DrawWireCube(transform.TransformPoint(m_bounds.center), transform.TransformVector(m_bounds.size));
        }
    }
}