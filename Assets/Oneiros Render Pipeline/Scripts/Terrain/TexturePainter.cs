using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;

public class TexturePainter : EditorWindow
{
    public delegate void OnPaintDelegate(RenderTexture result);
    public delegate void OnCustomGUIDelegate();
    public delegate void OnCloseDelegate();

    /// <summary>
    /// The texture that will be painted on.
    /// </summary>
    public RenderTexture target;

    /// <summary>
    /// The collider used to know what pixel is being painted on.
    /// </summary>
    public Collider collider;

    public Texture2D brushTexture;
    public Color brushColor = Color.white;
    public float brushSize = 20;
    public Material brushMat;

    public enum BrushCombineMode:int { Mix=0, Add=1, Multiply=2}
    public BrushCombineMode brushMode = BrushCombineMode.Mix;

    /// <summary>
    /// Called whenever a stroke was painted on the target texture.
    /// </summary>
    public OnPaintDelegate onPaint;

    /// <summary>
    /// Called on window gui to implement custom controls.
    /// </summary>
    public OnCustomGUIDelegate onCustomGui;

    /// <summary>
    /// Called when the window is closed, to clean up.
    /// </summary>
    public OnCloseDelegate onClose;

    private bool DoesBrushHitSurface(SceneView sceneView, out Vector3 position, out Vector3 normal, out Vector2 uv)
    {
        Vector2 mousePos = Event.current.mousePosition;
        Camera camera = sceneView.camera;
        mousePos.y = camera.pixelHeight - mousePos.y;
        Ray pointerRay = camera.ScreenPointToRay(mousePos);
        if (collider.Raycast(pointerRay, out RaycastHit hit, 1000f))
        {
            position = hit.point;
            uv = hit.textureCoord;
            normal = hit.normal;
            return true;
        }
        else
        {
            position = Vector3.zero;
            normal = Vector3.zero;
            uv = Vector2.zero;
            return false;
        }
    }

    private void DrawBrushGizmo(Vector3 position, Vector3 normal)
    {
        Handles.color = Color.white;
        Handles.DrawWireDisc(position, normal, 1);
        Handles.DrawLine(position, position + normal * 1);
        Handles.color = Color.white;
    }

    private void Paint(Vector2 uv)
    {
        brushMat.SetColor("_BrushColor", brushColor);
        brushMat.SetTexture("_BrushTex", brushTexture);

        float brushSizeInUvSpace = brushSize / target.width;

        Vector4 brushRect = new Vector4();
        brushRect.x = uv.x - brushSizeInUvSpace * 0.5f;
        brushRect.y = uv.y - brushSizeInUvSpace * 0.5f;
        brushRect.z = brushRect.x + brushSizeInUvSpace;
        brushRect.w = brushRect.y + brushSizeInUvSpace;

        brushMat.SetVector("_BrushRect", brushRect);
        Graphics.Blit(brushTexture, target, brushMat, (int)brushMode);
        onPaint?.Invoke(target);

        Repaint();
    }

    private void OnSceneGUI(SceneView sceneView)
    {
        // raycast collider to get brush position and uv.
        if (DoesBrushHitSurface(sceneView, out Vector3 brushPosition, out Vector3 brushNormal, out Vector2 brushCoords))
        {
            DrawBrushGizmo(brushPosition, brushNormal);
            // if click, apply brush to target at uv.
            Event e = Event.current;
            if (e.type == EventType.Layout)
            {
                HandleUtility.AddDefaultControl(0);
            }
            else if (e.type == EventType.MouseDown || e.type == EventType.MouseDrag)
            {
                if (e.button == 0)
                {
                    Paint(brushCoords);
                    e.Use();
                }
            }
        }
        sceneView.Repaint();
    }

    private void OnGUI()
    {
        if (target)
            GUILayout.Label(target, GUILayout.ExpandHeight(true), GUILayout.ExpandWidth(true));
        GUILayout.Space(20);

        GUILayout.Label("Brush", EditorStyles.boldLabel);

        GUILayout.BeginHorizontal();
        GUILayout.Label("Texture");
        brushTexture = (Texture2D) EditorGUILayout.ObjectField(brushTexture, typeof(Texture2D), false);
        GUILayout.EndHorizontal();

        GUILayout.BeginHorizontal();
        GUILayout.Label("Color");
        brushColor = EditorGUILayout.ColorField(brushColor);
        GUILayout.EndHorizontal();

        GUILayout.BeginHorizontal();
        GUILayout.Label("Size");
        brushSize = EditorGUILayout.Slider(brushSize, 1, 200);
        GUILayout.EndHorizontal();

        GUILayout.BeginHorizontal();
        GUILayout.Label("Blend Mode");
        brushMode = (BrushCombineMode) EditorGUILayout.EnumPopup(brushMode);
        GUILayout.EndHorizontal();

        GUILayout.Space(30);

        onCustomGui?.Invoke();
    }

    private void OnEnable()
    {
        SceneView.duringSceneGui -= OnSceneGUI;
        SceneView.duringSceneGui += OnSceneGUI;

        brushMat = new Material(Shader.Find("Hidden/BrushBlit"));
    }

    private void OnDisable()
    {
        SceneView.duringSceneGui -= OnSceneGUI;
        target?.Release();

        onClose?.Invoke();
    }

    public static Texture2D RenderToTexture(RenderTexture render)
    {
        Texture2D dest = new Texture2D(render.width, render.height, TextureFormat.ARGB32, false);
        RenderTexture.active = render;
        dest.ReadPixels(new Rect(0, 0, render.width, render.height), 0, 0);
        dest.Apply();
        RenderTexture.active = null;
        render.Release();
        return dest;
    }
}
#endif