using UnityEngine;
using System.Collections;
using System.Collections.Generic;

namespace Oneiros.Rendering
{
    ///<summary>
	/// Handles sending Rig data to the gpu for skinning.
	/// Only Rigged Meshes can use this data.
	///</summary>
    [AddComponentMenu("Rendering/Rig"), ExecuteInEditMode]
    public class Rig : MonoBehaviour
    {
		/// <summary>
		/// Defines a bone's position and rotation at a certain time.
		/// </summary>
		[System.Serializable]
		public struct BonePose
        {
			public Vector3 position;
			public Quaternion rotation;

			public const int SIZE = sizeof(float) * (3 + 4);
        }

		///<summary>
		/// All the bones of this rig. This should not be edited.
		///</summary>
        [SerializeField, HideInInspector]
        private Transform[] m_bones;

		///<summary>
		/// The bind poses of the bones. The difference between a bindpose
		/// and the current state of a bone is applied to the vertices to animate them.
		///</summary>
        [SerializeField, HideInInspector]
        private BonePose[] m_bindPoses;

		///<summary>
		/// Property block applied to all rigged meshes linked to this rig.
		/// It contains only the index offset used to get data in shaders.
		///</summary>
        public MaterialPropertyBlock PropertyBlock { get; private set; }
		
		///<summary>
		/// Used by rigged meshes to update their property block.
		///</summary>
        public event System.Action OnRigUpdate;

		/// <summary>
		/// Used to decide wether the buffer should be updated or not.
		/// </summary>
		public int activeRiggedMeshCount = 0;
		
		///<summary>
		/// The index offset of this rig in the global buffer.
		///</summary>
		[SerializeField]
		private int m_bufferOffset;

		// shader properties, used to indentify data in the GPU.
        private static readonly int m_bufferOffsetId = Shader.PropertyToID("_RigOffsetId");
        private static readonly int m_bonesShaderId = Shader.PropertyToID("_RigBonesBuffer");
        private static readonly int m_bindPosesShaderId = Shader.PropertyToID("_RigPosesBuffer");

		///<summary>
		/// Buffer of all the transform matrices of every bone of every rig.
		///</summary>
        private static ComputeBuffer m_bonesBuffer;
		
		///<summary>
		/// Buffer of all the bindposes matrices of every rig.
		///</summary>
        private static ComputeBuffer m_posesBuffer;

		///<summary>
		/// Color used to draw bones in the editor view.
		///</summary>
        private static readonly Color m_boneColor = new Color(0, 1, 0.2f, 1);

		///<summary>
		/// List of all the rigs currently active in the scene.
		///</summary>
        private static List<Rig> m_allRigs = new List<Rig>();
		
		///<summary>
		/// Sum of all the bones of every rig currently active in the scene.
		///</summary>
		private static int m_allBonesCount;

		///<summary>
		/// If false, indicates that all buffers should be rebuilt.
		///</summary>
        private static bool m_bufferIsCreated = false;
		
		///<summary>
		/// If true, indicates that the bones buffer should be updated.
		///</summary>
        private static bool m_bufferIsDirty = true;
		
		///<summary>
		/// Counts all the bones of every rig and assigns an index offset to every rig.
		///</summary>
		private static void UpdateBoneCountAndOffset()
        {
            m_allBonesCount = 0;
            foreach (var i in m_allRigs)
            {
				i.m_bufferOffset = m_allBonesCount;
				i.AssignOffset();
                m_allBonesCount += i.m_bones.Length;
            }
        }

		///<summary>
		/// Create the global buffers for bindposes and bones if needed.
		///</summary>
        private static void CreateBuffers()
        {
            if (m_bufferIsCreated) return;

            if (m_bonesBuffer != null) m_bonesBuffer.Release();
            if (m_posesBuffer != null) m_posesBuffer.Release();

            UpdateBoneCountAndOffset();
			
            m_bonesBuffer = new ComputeBuffer(m_allBonesCount, BonePose.SIZE);
            m_posesBuffer = new ComputeBuffer(m_allBonesCount, BonePose.SIZE);
			
			UpdatePosesBuffer();

            m_bufferIsCreated = true;
            m_bufferIsDirty = true;
        }
		
		///<summary>
		/// Updates the value of every bind pose matrix in the bindposes buffer.
		///</summary>
		private static void UpdatePosesBuffer()
		{
			BonePose[] buffer = new BonePose[m_allBonesCount];
			foreach (Rig rig in m_allRigs)
			{
				rig.UpdateSelfToPosesBuffer(ref buffer);
			}
			m_posesBuffer.SetData(buffer);
			Shader.SetGlobalBuffer(m_bindPosesShaderId, m_posesBuffer);
		}

		///<summary>
		/// Updates the value of every bone matrix in the bones buffer.
		///</summary>
        private static void UpdateBonesBuffer()
        {
            if (!m_bufferIsDirty) return;

			BonePose[] buffer = new BonePose[m_allBonesCount];
			foreach (Rig rig in m_allRigs)
			{
				rig.UpdateSelfToBonesBuffer(ref buffer);
			}
			m_bonesBuffer.SetData(buffer);
			Shader.SetGlobalBuffer(m_bonesShaderId, m_bonesBuffer);

            m_bufferIsDirty = false;
        }
		
		///<summary>
		/// Force a rebuild of the global buffers. This is useful if a rig is spawned or destroyed.
		///</summary>
		private static void RebuildBuffers()
		{
			m_bufferIsCreated = false;
			m_bufferIsDirty = true;
		}
		
		///<summary>
		/// Sets the values of the given buffer to the bone matrices of this rig, using the index offset.
		///</summary>
		private void UpdateSelfToBonesBuffer(ref BonePose[] buffer)
		{
			//Debug.Log("[Rig] Building bones array");
			for (int i = 0; i < m_bones.Length; i++)
			{
				//Debug.Log("\tBone "+i.ToString()+" : "+m_bones[i].name);
				buffer[m_bufferOffset + i] = new BonePose()
				{
					position = m_bones[i].position,
					rotation = m_bones[i].rotation
				};
			}
			//Debug.Log("[Rig] Bones array built");
		}

		///<summary>
		/// Sets the values of the given buffer to the bindpose matrices of this rig, using the index offset.
		///</summary>
		private void UpdateSelfToPosesBuffer(ref BonePose[] buffer)
		{
			for (int i = 0; i < m_bindPoses.Length; i++)
			{
				buffer[m_bufferOffset + i] = m_bindPoses[i];
			}
		}
		
		private void ReleaseUnusedBuffer()
		{
			if (m_allRigs.Count == 0)
			{
				if (m_bonesBuffer != null)
                {
					m_bonesBuffer.Release();
					m_bonesBuffer = null;
				}
				if (m_posesBuffer != null)
				{
					m_posesBuffer.Release();
					m_posesBuffer = null;
				}
				m_bufferIsCreated = false;
			}
		}
		
		///<summary>
		/// Registers this rig as active and force a rebuild of the global buffers to include it.
		///</summary>
		private void RegisterSelf()
		{
			if (m_allRigs.Contains(this)) return;
			m_allRigs.Add(this);
			RebuildBuffers();
		}		
		
		///<summary>
		/// Removes this rig from the list of active rigs and forces a rebuild of the global buffers to exclude it.
		///</summary>
		private void UnRegisterSelf()
		{
			if (!m_allRigs.Contains(this)) return;
			m_allRigs.Remove(this);
			RebuildBuffers();
			ReleaseUnusedBuffer();
		}
		
		///<summary>
		/// Sets the value of the index offset to the property block and invoke all rigged meshes to apply it.
		///</summary>
		private void AssignOffset()
		{
			PropertyBlock.SetInt(m_bufferOffsetId, m_bufferOffset);
			OnRigUpdate?.Invoke();
		}
		
        private void OnEnable()
        {
            RegisterSelf();
			PropertyBlock = new MaterialPropertyBlock();
        }
		
		private void OnDisable()
		{
			UnRegisterSelf();
			PropertyBlock = null;
		}
		
		private void OnDestroy()
		{
			UnRegisterSelf();
			PropertyBlock = null;
		}

		///<summary>
		/// Sets the value of all bindposes of this rig to the given array.
		///</summary>
		public void SetBindPoses(Matrix4x4[] poses)
		{
			m_bindPoses = new BonePose[poses.Length];
			for (int i = 0; i < poses.Length; i++)
			{
				m_bindPoses[i] = new BonePose() 
				{ 
					position = poses[i].MultiplyPoint(Vector3.zero), 
					rotation = poses[i].rotation
				};
            }
        }

		///<summary>
		/// Sets the value of all bones of this rig to the given array.
		///</summary>
        public void SetBones(Transform[] bones)
        {
            m_bones = bones;
        }

		///<summary>
		/// Returns true if no rigged mesh is active.
		///</summary>
        private bool AreRenderersCulled()
        {
			return activeRiggedMeshCount == 0;
            ///return OnRigUpdate == null;
        }
		
		///<summary>
		/// If at least one rigged mesh is active, demands an update of the bones buffer this frame.
		///</summary>
		private void Update()
		{
			if (AreRenderersCulled()) return;
			
			m_bufferIsDirty = true;
		}

		///<summary>
		/// If at least one rigged mesh is active and an update of the bones buffer was demanded, performs said update.
		/// If buffers need to be recreated, performs this as well.
		///</summary>
        private void LateUpdate()
        {
            if (AreRenderersCulled()) return;

			CreateBuffers();
            UpdateBonesBuffer();
        }

        private void OnDrawGizmosSelected()
        {
            Matrix4x4 matrix = Gizmos.matrix;
            Gizmos.color = m_boneColor;

            for (int i = 0; i < m_bones.Length; i++)
            {
                Transform bone = m_bones[i];
                float size = 0.2f;
                Gizmos.matrix = Matrix4x4.TRS(bone.position, bone.rotation, Vector3.one * size);
                Vector3 head = Vector3.zero;
                Vector3 tail = Vector3.up;
                Gizmos.DrawLine(head, tail);
                Gizmos.DrawWireSphere(head, 0.3f);
                Gizmos.DrawWireSphere(tail, 0.1f);
            }

            Gizmos.matrix = matrix;
        }
    }
}