using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;

public static class TesselParticleMesh
{
    [MenuItem("Assets/Create/Tessel Particle Mesh")]
    public static void CreateMesh()
    {
        Mesh mesh = new Mesh();
        mesh.vertices = new Vector3[]
        {
            new Vector3(-0.5f, 0, -0.5f),
            new Vector3(-0.5f, 0, 1),
            new Vector3(1, 0, 1)
        };
        mesh.uv = new Vector2[]
        {
            new Vector2(0, 0),
            new Vector2(0, 0),
            new Vector2(1, 0)
        };
        mesh.triangles = new int[] { 0, 1, 2 };
        mesh.bounds = new Bounds(new Vector3(0.5f, 0.5f, 0.5f), new Vector3(2, 2, 2));
        mesh.UploadMeshData(false);
        string path = EditorUtility.SaveFilePanelInProject("Save Mesh", "New Particle Mesh", "asset", "", "");
        if (path.Length == 0) return;
        ProjectWindowUtil.CreateAsset(mesh, path);
    }
}
#endif
