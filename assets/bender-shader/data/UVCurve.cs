using UnityEngine;
using System.Collections.Generic;
using Assets.Scripts.Bezier;
using System.Linq;
using UnityEditor;

namespace Assets.Scripts.UV
{
    // [ExecuteAlways] is helpful for editor-time visualization, but uncomment only if required.
    public class UVCurve : MonoBehaviour
    {
        // --- PUBLIC INSPECTOR PROPERTIES ---

        [Tooltip("The BezierSpline component that defines the curve.")]
        public BezierSpline Spline;

        [Tooltip("Prefab containing the UVItem script to be instantiated along the spline.")]
        public UVItem ItemPrefab;

        [Tooltip("Container for the UVItem objects to be instantiated along the spline.")]
        public GameObject ItemsContainer;

        [Tooltip("Number of items to generate when using the fixed count method.")]
        public int ItemCount = 10;

        // --- PRIVATE/MANAGED FIELDS ---

        private readonly List<UVItem> uvItems = new();

        public List<MeshRenderer> ItemsRenderers => uvItems
                .Where(item => item != null)
                .SelectMany(item => item.renderers)
                .Where(renderer => renderer != null)
                .ToList();

        public MaterialPropertyBlock PropertyBlock { get; private set; }

        private Vector4[] splineVectorArray;

        private static readonly int splinePointsID = Shader.PropertyToID("_SplinePoints");
        private static readonly int splineLengthID = Shader.PropertyToID("_SplineLength");
        private static readonly int splinePointsCountID = Shader.PropertyToID("_SplinePointsCount");

        // --- Standard Unity Callbacks ---

        void Awake()
        {
            InitializeRenderingData();
        }

        void Start()
        {
            GenerateUVItems();
        }

        private void InitializeRenderingData()
        {
            PropertyBlock ??= new MaterialPropertyBlock();
        }

        void OnValidate()
        {
            if (Spline != null)
            {
                // Ensure data is prepared for editor visualization
                UpdateSplinePoints();
            }
        }

        void Update()
        {
            if (Spline != null)
            {
                // Call every frame in Play mode to ensure dynamic updates
                UpdateSplinePoints();
            }
        }

        
        /// <summary>
        /// Generates a list of UV items along the Bezier spline using the prefabricated UV item.
        /// </summary>
        /// <remarks>
        /// This method is intended for use in the editor and can be called through the Unity context menu.
        /// It will throw exceptions if the required components, prefabs, or data are not properly set.
        /// </remarks>
        [ContextMenu("Generate UV Items")]
        public void GenerateUVItems()
        {
            if (ItemPrefab == null)
            {
                throw new System.Exception("UV Item Prefab not assigned!");
            }
            if (ItemsContainer == null)
            {
                throw new System.Exception("Items Container not assigned!");
            }

            float splineLength = Spline.SplineLength;
            if (Spline == null || splineLength <= 0f)
            {
                throw new System.Exception("Spline not initialized or zero length.");
            }

            if (!ItemPrefab.TryGetComponent<UVItem>(out var prefabItem))
            {
                throw new System.Exception("UV Item Prefab is missing the UVItem component.");
            }

            // Ensure size is calculated and saved on the prefab asset            
            float itemSize = prefabItem.itemSize;
            if (itemSize <= 0.001f)
            {
                throw new System.Exception("Calculated item size is zero or too small. Check UVItem.CalculateItemSize().");
            }

            ClearUVItems();

            for (int i = 0; i < ItemCount; i++)
            {
#if UNITY_EDITOR
                UVItem newItem = (UVItem)PrefabUtility.InstantiatePrefab(ItemPrefab, ItemsContainer.transform);
#else
                UVItem newItem = Instantiate(ItemPrefab, ItemsContainer.transform);
#endif                                
                newItem.gameObject.name = $"UVItem_{i}";

                // Set item's Z-position for shader deformation
                // The mesh's local Z-position is what the shader reads as 'distance'
                // The X/Y positions should usually be 0 relative to the parent UVCurve.
                float distance = i * itemSize;
                newItem.transform.position = new Vector3(0f, 0f, distance);

                uvItems.Add(newItem);
            }

            // Initialize/update data after item generation
            UpdateSplinePoints();
            Debug.Log($"Generated {uvItems.Count} UVItems.", this);
        }

        /// <summary>
        /// Coordinates the full update cycle: prepare data, transfer to GPU, and apply to renderers.
        /// </summary>
        [ContextMenu("Update Spline Points")]
        internal void UpdateSplinePoints()
        {
            // Initialize the property block
            InitializeRenderingData();
            // Prepare and validate CPU data
            PrepareSplineData();
            // Transfer data from CPU to MaterialPropertyBlock
            TransferDataToPropertyBlock();
            // Apply the block to all renderers
            ApplyPropertyBlockToItems();
        }

        // -------------------------------------------------------------------------

        /// <summary>
        /// Validates the spline state and updates the CPU-side splineVectorArray.
        /// </summary>
        /// <returns>True if data is valid and prepared; otherwise, false.</returns>
        private void PrepareSplineData()
        {
            if (Spline == null || Spline.ControlPointCount < 4)
            {
                throw new System.Exception("Spline not initialized, or spline has insufficient control points (min 4 required).");
            }

            int count = Spline.ControlPointCount;

            // Ensure the array is correctly sized
            if (splineVectorArray == null || splineVectorArray.Length != count)
            {
                splineVectorArray = new Vector4[count];
            }

            // Populate the array with current World Space positions
            for (int i = 0; i < count; i++)
            {
                splineVectorArray[i] = Spline.GetControlPoint(i);
            }

            if (splineVectorArray.Length == 0)
            {
                throw new System.Exception("Spline point array is empty after preparation! Cannot deform geometry.");
            }
        }

        /// <summary>
        /// Transfers all calculated spline data to the MaterialPropertyBlock.
        /// </summary>
        private void TransferDataToPropertyBlock()
        {
            // Set scalar values
            PropertyBlock.SetFloat(splineLengthID, Spline.SplineLength);
            PropertyBlock.SetInt(splinePointsCountID, Spline.ControlPointCount);

            // Set the main VectorArray
            PropertyBlock.SetVectorArray(splinePointsID, splineVectorArray);
        }

        /// <summary>
        /// Iterates through all UV items and applies the property block to every renderer.
        /// </summary>
        private void ApplyPropertyBlockToItems()
        {
            var allRenderers = uvItems
                .Where(item => item != null && item.renderers != null)
                .SelectMany(item => item.renderers)
                .Where(renderer => renderer != null);

            foreach (var renderer in allRenderers)
            {
                renderer.SetPropertyBlock(PropertyBlock);
            }
        }

        /// <summary>
        /// Approximates the number of UV items required to cover the entire spline length, 
        /// based on the item size of the UV item prefab.
        /// </summary>
        /// <remarks>
        /// This method is useful for quickly estimating the required number of UV items without having to
        /// manually measure the spline length or manually calculate the item count.
        /// It is recommended to use this method in the editor before running the game.
        /// </remarks>
        [ContextMenu("Approximate Item Count")]
        public void ApproximateItemCount()
        {
            ItemCount = Mathf.CeilToInt(Spline.SplineLength / ItemPrefab.itemSize) + 1;
        }

        [ContextMenu("Clear UV Items")]
        public void ClearUVItems()
        {
            foreach (var item in uvItems)
            {
                if (item != null)
                {
                    // Use appropriate Destroy method based on context
#if UNITY_EDITOR
                    DestroyImmediate(item.gameObject);
#else
                    Destroy(item.gameObject);
#endif      
                }
            }
            uvItems.Clear();
        }
    }
}