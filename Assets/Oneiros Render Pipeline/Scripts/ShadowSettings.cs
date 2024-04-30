using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Oneiros.Rendering
{
    /// <summary>
    /// Describes how shadows should be rendered.
    /// </summary>
    [System.Serializable]
    public class ShadowSettings
    {
        /// <summary>
        /// Available texture sizes.
        /// </summary>
        public enum TextureSize : int { _256 = 256, _512 = 512, _1024 = 1024, _2048 = 2024 }

        /// <summary>
        /// Describes how directional shadows should be rendered.
        /// </summary>
        [System.Serializable]
        public class Directional
        {
            /// <summary>
            /// The maximum distance at which objects will be rendered.
            /// </summary>
            [Min(0f)]
            public float maxDistance = 1000;

            /// <summary>
            /// The size of the shadow atlas.
            /// </summary>
            public TextureSize atlasSize = TextureSize._1024;

            /// <summary>
            /// How many cascade shadows will be rendered.
            /// </summary>
            [Range(1, 4)]
            public int cascadeCount = 2;
        }

        /// <summary>
        /// Settings for directional.
        /// </summary>
        public Directional directional;
    }
}