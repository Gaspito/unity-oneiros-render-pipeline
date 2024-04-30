using UnityEngine;
using System.Collections;

namespace Oneiros.Rendering
{
    public struct LightRenderer
    {
        public int type;
        public Vector3 position;
        public Vector3 direction;
        public Vector3 color;
        public float sqrRange;
        public float intensity;
        public int shadowId;

        public static LightRenderer FromDirectionalLight(Light light)
        {
            LightRenderer l = new LightRenderer();
            l.type = 0;
            l.position = Vector3.zero;
            l.direction = light.transform.forward;
            l.color = new Vector3( light.color.r, light.color.g, light.color.b);
            l.sqrRange = 1;
            l.intensity = light.intensity;
            l.shadowId = -1;
            return l;
        }

        public static LightRenderer FromPointLight(Light light)
        {
            LightRenderer l = new LightRenderer();
            l.type = 1;
            l.position = light.transform.position;
            l.direction = Vector3.one;
            l.color = new Vector3(light.color.r, light.color.g, light.color.b);
            l.sqrRange = light.range;// * light.range;
            l.intensity = light.intensity;
            l.shadowId = -1;
            return l;
        }

        public const int SIZE = sizeof(float) * 3 * 3 + sizeof(float) * 2 + sizeof(int) * 2;
    }
}