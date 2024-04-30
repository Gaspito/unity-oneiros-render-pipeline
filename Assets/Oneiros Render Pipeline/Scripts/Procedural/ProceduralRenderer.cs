using UnityEngine;
using System.Collections;

namespace Oneiros.Rendering
{
    /// <summary>
    /// Renders instances of mesh, configured by a compute shader.
    /// </summary>
    public class ProceduralRenderer : MonoBehaviour
    {
        /// <summary>
        /// Helper struct used to keep track of the data composition in the compute buffer.
        /// </summary>
        [System.Serializable]
        private struct BufferInventory
        {
            [Min(0)] public int boolCount;
            [Min(0)] public int intCount;
            [Min(0)] public int floatCount;
            [Min(0)] public int vector2Count;
            [Min(0)] public int vector3Count;
            [Min(0)] public int vector4Count;
        }

        /// <summary>
        /// The mesh to be drawn.
        /// </summary>
        [SerializeField, Header("Drawing")]
        private Mesh m_mesh;

        /// <summary>
        /// The material to use when drawing instances.
        /// </summary>
        [SerializeField]
        private Material m_material;

        /// <summary>
        /// How many instances are drawn. This should always be the maximum value.
        /// </summary>
        [SerializeField]
        private int m_instanceCount;

        /// <summary>
        /// The index of the layer to render to.
        /// </summary>
        [SerializeField]
        private int m_renderLayer;

        /// <summary>
        /// Defines the area which will be drawn to. If the area is not visible,
        /// then the drawing can be skipped.
        /// </summary>
        [SerializeField]
        private Bounds m_bounds;

        /// <summary>
        /// If true, time will be sent as a shader property.
        /// </summary>
        [SerializeField, Header("Extra Parameters")]
        private bool m_sendTimeParameter = true;

        /// <summary>
        /// How fast the time property will increment.
        /// </summary>
        [SerializeField]
        private float m_timeSpeed = 1;

        /// <summary>
        /// Time after which the time property will loop, going back to value zero.
        /// The opposit looping effect also exits: bellow zero, the value warps to this variable.
        /// </summary>
        [SerializeField]
        private float m_timeLoop = 10;

        /// <summary>
        /// The compute shader used to configure instances.
        /// </summary>
        [SerializeField, Header("Procedural")]
        private ComputeShader m_computeShader;

        /// <summary>
        /// The name of the kernel to use to configure instances.
        /// </summary>
        [SerializeField]
        private string m_kernelName;

        /// <summary>
        /// The number of threads to be dispatched in each dimensions.
        /// </summary>
        [SerializeField]
        private Vector3Int m_dispatchThreads = new Vector3Int(1, 1, 1);

        /// <summary>
        /// How often the procedural part is refreshed, in seconds.
        /// 0 means it is refreshed every frame.
        /// </summary>
        [SerializeField, Min(0)]
        private float m_refreshFrequency;

        /// <summary>
        /// The name of the buffer in shaders.
        /// </summary>
        [SerializeField]
        private string m_bufferName;

        /// <summary>
        /// Used to compute the size of an element of the compute buffer.
        /// </summary>
        [SerializeField]
        private BufferInventory m_bufferInventory;

        /// <summary>
        /// The index of the kernel to dispatch.
        /// </summary>
        private int m_kernel;

        /// <summary>
        /// The index used to reference the number of instances in shaders.
        /// </summary>
        private int m_countPropertyId;

        /// <summary>
        /// The index used to reference the compute buffer in shaders.
        /// </summary>
        private int m_bufferPropertyId;

        /// <summary>
        /// The index used to reference the time property in shaders.
        /// </summary>
        private int m_timePropertyId;

        /// <summary>
        /// The index used to reference the transform matrix property in shaders;
        /// </summary>
        private int m_transformPropertyId;

        /// <summary>
        /// The value of time to be passed to the compute shader. 
        /// </summary>
        private float m_timeValue;

        /// <summary>
        /// The buffer output of the compute shader.
        /// </summary>
        private ComputeBuffer m_outputBuffer;

        /// <summary>
        /// The size of one element of the buffer, in bytes.
        /// </summary>
        private int m_bufferElementSize;

        /// <summary>
        /// Representation of the draw call given to the render pipeline.
        /// </summary>
        private ProceduralDrawCall m_drawCall;

        private void OnEnable()
        {
            m_material = Instantiate(m_material);
            m_kernel = m_computeShader.FindKernel(m_kernelName);
            m_countPropertyId = Shader.PropertyToID("_InstanceCount");
            m_timePropertyId = Shader.PropertyToID("_Time");
            m_transformPropertyId = Shader.PropertyToID("_localToWorld");
            m_bufferPropertyId = Shader.PropertyToID(m_bufferName);
            m_dispatchThreads = new Vector3Int(Mathf.Max(0, m_dispatchThreads.x),
                Mathf.Max(0, m_dispatchThreads.y), Mathf.Max(0, m_dispatchThreads.z));

            m_bufferElementSize = 0;
            m_bufferElementSize += m_bufferInventory.boolCount * sizeof(bool);
            m_bufferElementSize += m_bufferInventory.intCount * sizeof(int);
            m_bufferElementSize += m_bufferInventory.floatCount * sizeof(float);
            m_bufferElementSize += m_bufferInventory.vector2Count * sizeof(float) * 2;
            m_bufferElementSize += m_bufferInventory.vector3Count * sizeof(float) * 3;
            m_bufferElementSize += m_bufferInventory.vector4Count * sizeof(float) * 4;

            m_outputBuffer = new ComputeBuffer(m_instanceCount, m_bufferElementSize);

            m_material.SetInt(m_countPropertyId, m_instanceCount);

            m_drawCall = new ProceduralDrawCall(m_mesh, m_material, m_instanceCount, m_renderLayer, CalculateBounds(m_bounds));

            InvokeRepeating("UpdateGPU", 0, m_refreshFrequency);
        }

        private Bounds CalculateBounds(Bounds localBounds)
        {
            return new Bounds(transform.position + localBounds.center,
                new Vector3(transform.lossyScale.x * localBounds.size.x,
                transform.lossyScale.y * localBounds.size.y,
                transform.lossyScale.z * localBounds.size.z));
        }

        private void UpdateTimeProperty()
        {
            if (m_sendTimeParameter)
            {
                float deltaTime = (m_refreshFrequency > 0) ? m_refreshFrequency : Time.deltaTime;
                m_timeValue += deltaTime * m_timeSpeed;
                if (m_timeValue >= m_timeLoop)
                {
                    m_timeValue -= m_timeLoop;
                }
                else if (m_timeValue < 0)
                {
                    m_timeValue += m_timeLoop;
                }
                m_computeShader.SetFloat(m_timePropertyId, m_timeValue);
            }
        }

        private void UpdateGPU()
        {
            UpdateTimeProperty();

            m_drawCall.bounds = CalculateBounds(m_bounds);

            m_computeShader.SetMatrix(m_transformPropertyId, transform.localToWorldMatrix);
            m_computeShader.SetInt(m_countPropertyId, m_instanceCount);
            m_computeShader.SetBuffer(m_kernel, m_bufferPropertyId, m_outputBuffer);
            m_computeShader.Dispatch(m_kernel, m_dispatchThreads.x, m_dispatchThreads.y, m_dispatchThreads.z);
            m_material.SetBuffer(m_bufferPropertyId, m_outputBuffer);
        }

        private void OnDisable()
        {
            CancelInvoke();
            m_outputBuffer.Release();
            m_outputBuffer = null;
            m_drawCall.Release();
        }

        private void OnDrawGizmosSelected()
        {
            Gizmos.color = new Color(0, 0.8f, 0.2f, 0.5f);
            Bounds globalBounds = CalculateBounds(m_bounds);
            Gizmos.DrawWireCube(globalBounds.center, globalBounds.size);
        }
    }
}