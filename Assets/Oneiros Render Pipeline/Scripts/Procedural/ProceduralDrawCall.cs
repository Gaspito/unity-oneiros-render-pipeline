using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering;

namespace Oneiros.Rendering
{
    /// <summary>
    /// Handles rendrering instances of a same mesh procedurally.
    /// </summary>
    public class ProceduralDrawCall
    {
        /// <summary>
        /// The mesh to be rendered several times.
        /// </summary>
        public Mesh mesh;

        /// <summary>
        /// The material used to render the mesh.
        /// </summary>
        public Material material;

        /// <summary>
        /// How many instances of the mesh will be rendered.
        /// </summary>
        public int count;

        /// <summary>
        /// Index used to filter when to render this procedural instance.
        /// </summary>
        public int renderLayer;

        /// <summary>
        /// The bounds used to cull procedural draw calls.
        /// </summary>
        public Bounds bounds;

        /// <summary>
        /// Adds a command to draw procedural mesh instances to the buffer.
        /// </summary>
        private void Draw(CommandBuffer commandBuffer)
        {
            commandBuffer.DrawMeshInstancedProcedural(mesh, 0, material, 0, count);
        }

        /// <summary>
        /// Contains all the draw calls.
        /// </summary>
        private static List<ProceduralDrawCall> m_allDrawCalls = new List<ProceduralDrawCall>();

        /// <summary>
        /// Array from which each entry corresponds to a draw call and wether it should be drawn or skipped.
        /// </summary>
        private static bool[] m_cullingResults;

        /// <summary>
        /// Fills the culling results array with wether a draw call is culled or not.
        /// </summary>
        public static void CullAll(Camera camera)
        {
            m_cullingResults = new bool[m_allDrawCalls.Count];

            Plane[] cullingPlanes = GeometryUtility.CalculateFrustumPlanes(camera);

            for (int i = 0; i < m_allDrawCalls.Count; i++)
            {
                m_cullingResults[i] = GeometryUtility.TestPlanesAABB(cullingPlanes, m_allDrawCalls[i].bounds);
            }
        }

        /// <summary>
        /// Adds commands to draw all procedural draw calls.
        /// Only calls set to the same layer as supplied are drawn.
        /// </summary>
        public static void DrawAll(CommandBuffer commandBuffer, int renderLayer)
        {
            for (int i = 0; i < m_allDrawCalls.Count; i++)
            {
                if (m_cullingResults[i] && m_allDrawCalls[i].renderLayer == renderLayer)
                    m_allDrawCalls[i].Draw(commandBuffer);
            }
        }

        public ProceduralDrawCall(Mesh mesh, Material material, int count, int renderLayer, Bounds bounds)
        {
            this.mesh = mesh;
            this.material = material;
            this.count = count;
            this.renderLayer = renderLayer;
            this.bounds = bounds;
            m_allDrawCalls.Add(this);
        }

        /// <summary>
        /// Removes the instance from the global list. It won't get rendered then.
        /// </summary>
        public void Release()
        {
            m_allDrawCalls.Remove(this);
        }
    }
}