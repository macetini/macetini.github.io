using Assets.Scripts.UV;
using UnityEngine;

namespace Assets.Scripts.Controllers
{
    // [ExecuteInEditMode] // Uncomment if editor functionality is needed
    public class CurveController : MonoBehaviour
    {
        // Editor Variables
        public UVCurve Curve;
        public Transform CurveOrigin;
        public float Duration = 5f;
        private static readonly int SplineProgressId = Shader.PropertyToID("_SplineProgress");

        // Runtime variables
        private MaterialPropertyBlock materialPropertyBlock;
        private float moveProgress;
        private float currentDirection = 1f;

        // CRITICAL CONSTANT: Safety buffer to prevent the shader math from collapsing at t=0
        private const float MIN_PROGRESS_SAFETY = 0.0001f;

        // Gizmo Constants
        private const float GizmoLineHeight = 0.5f;
        private const float GizmoSphereRadius = 0.03f;

        void Awake()
        {
            materialPropertyBlock = Curve.PropertyBlock;
        }

        void Start()
        {
            if (Curve == null)
            {
                throw new System.Exception("Curve not assigned!");
            }

            UpdateCurveMaterialBlock();
        }

        [ContextMenu("Reset Progress")]
        public void ResetProgress()
        {
            moveProgress = 0f;
            currentDirection = 1f;
            UpdateCurveMaterialBlock();
        }

        void Update()
        {
            if (Curve == null) return;

            // Calculate the intended progress
            moveProgress += Time.deltaTime / Duration * currentDirection;
            UpdateCurveMaterialBlock();
        }

        protected void UpdateCurveMaterialBlock()
        {
            materialPropertyBlock ??= Curve.PropertyBlock;

            // 2. CHECK FOR REVERSAL: If progress hits the start (0) or end (1), flip the direction.
            if (moveProgress >= 1f)
            {
                moveProgress = 1f;
                currentDirection = -1f; // Reverse direction
            }
            else if (moveProgress <= 0f)
            {
                moveProgress = 0f;
                currentDirection = 1f; // Go forward
            }

            // 3. Clamp the progress to the MinProgressSafety value
            float clampedProgress = Mathf.Max(moveProgress, MIN_PROGRESS_SAFETY);

            // 4. Set the dynamic progress value on the Material Property Block
            materialPropertyBlock.SetFloat(SplineProgressId, clampedProgress);
        }

        void OnDrawGizmos()
        {
            if (CurveOrigin != null)
            {
                MarkOriginPosition();
            }
        }

        internal void MarkOriginPosition()
        {
            Gizmos.color = Color.green;
            Vector3 position = CurveOrigin.position;

            Vector3 lineTop = new(position.x, position.y + GizmoLineHeight, position.z);
            Vector3 lineBottom = new(position.x, position.y, position.z);

            Gizmos.DrawLine(lineTop, lineBottom);

            Vector3 sphereTop = new(position.x, position.y + GizmoLineHeight, position.z);
            Gizmos.DrawSphere(sphereTop, GizmoSphereRadius);
        }
    }
}