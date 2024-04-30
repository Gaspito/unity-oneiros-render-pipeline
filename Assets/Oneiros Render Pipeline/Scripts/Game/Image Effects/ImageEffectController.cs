using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Oneiros.Rendering.ImageEffects
{
    [AddComponentMenu("Effects/Image Effect Controller")]
    public class ImageEffectController : MonoBehaviour
    {
        public bool applyOnStart = true;

        public PostProcess[] effects;

        public void ApplyEffects()
        {
            foreach (var i in effects)
            {
                i.Register();
            }
        }

        public void RemoveEffects()
        {
            foreach (var i in effects)
            {
                i.Unregister();
            }
        }

        private void OnDisable()
        {
            RemoveEffects();
        }

        private void OnEnable()
        {
            if (applyOnStart)
            {
                ApplyEffects();
            }
        }
    }
}