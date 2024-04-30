#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.Linq;
using Oneiros.Rendering;

//sorts transform bone indexes in skinned mesh renderers so that we can swap skinned meshes at runtime
public class AssetPostProcessorReorderBones : AssetPostprocessor
{
    void OnPostprocessModel(GameObject g)
    {
        SkinnedMeshRenderer[] skinnedMeshes = g.GetComponentsInChildren<SkinnedMeshRenderer>();

        if (skinnedMeshes.Length > 0)
        {
            Transform root = skinnedMeshes[0].rootBone.parent;
            Debug.Log(root.name);
            Rig rig = root.gameObject.AddComponent<Rig>();
            rig.SetBones(skinnedMeshes[0].bones);
            rig.SetBindPoses(skinnedMeshes[0].sharedMesh.bindposes);

            foreach (var i in skinnedMeshes)
            {
                Replace(i, rig);
            }
        }
    }

    void Replace(SkinnedMeshRenderer skin, Rig rig)
    {
        GameObject obj = skin.gameObject;
        Transform[] bones = skin.bones;
        Mesh sharedMesh = skin.sharedMesh;
        Material sharedMaterial = skin.sharedMaterial;

        Component.DestroyImmediate(skin);

        MeshFilter filter = obj.AddComponent<MeshFilter>();
        filter.sharedMesh = sharedMesh;
        MeshRenderer mesh = obj.AddComponent<MeshRenderer>();
        mesh.sharedMaterial = sharedMaterial;
        RiggedMesh riggedMesh = obj.AddComponent<RiggedMesh>();
        riggedMesh.rig = rig;

        Debug.Log("Rigged mesh " + obj.name + " successfully");
    }

    void Process(SkinnedMeshRenderer rend)
    {
        Debug.Log("Reimported mesh " + rend.name + " successfully");

        //list of bones
        List<Transform> tList = rend.bones.ToList();

        //sort alphabetically
        tList.Sort(CompareTransform);

        //record bone index mappings (richardf advice)
        //build a Dictionary<int, int> that records the old bone index => new bone index mappings,
        //then run through every vertex and just do boneIndexN = dict[boneIndexN] for each weight on each vertex.
        Dictionary<int, int> remap = new Dictionary<int, int>();
        for (int i = 0; i < rend.bones.Length; i++)
        {
            remap[i] = tList.IndexOf(rend.bones[i]);
        }

        //remap bone weight indexes
        BoneWeight[] bw = rend.sharedMesh.boneWeights;
        for (int i = 0; i < bw.Length; i++)
        {
            bw[i].boneIndex0 = remap[bw[i].boneIndex0];
            bw[i].boneIndex1 = remap[bw[i].boneIndex1];
            bw[i].boneIndex2 = remap[bw[i].boneIndex2];
            bw[i].boneIndex3 = remap[bw[i].boneIndex3];
        }

        //remap bindposes
        Matrix4x4[] bp = new Matrix4x4[rend.sharedMesh.bindposes.Length];
        for (int i = 0; i < bp.Length; i++)
        {
            bp[remap[i]] = rend.sharedMesh.bindposes[i];
        }

        //assign new data
        rend.bones = tList.ToArray();
        rend.sharedMesh.boneWeights = bw;
        rend.sharedMesh.bindposes = bp;
    }

    private static int CompareTransform(Transform A, Transform B)
    {
        return A.name.CompareTo(B.name);
    }
}
#endif