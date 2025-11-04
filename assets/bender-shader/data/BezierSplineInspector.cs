using Assets.Scripts.Bezier;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(BezierSpline))]
public class BezierSplineInspector : Editor
{
    private BezierSpline spline;
    private Transform handleTransform;
    private Quaternion handleRotation;

    private const float worldVectorsScale = 1f;
    private const int stepsPerCurve = 10;

    private const float handleSize = 0.1f;
    private const float pickSize = 0.1f;

    private int selectedIndex = -1;

    // Use a private property to get the selected control point's mode (for cleaner GUI code)
    private BezierControlPointMode SelectedPointMode => spline.GetControlPointMode(selectedIndex);

    private static readonly Color[] modeColors = {
        Color.white,
        Color.yellow,
        Color.cyan
    };

    private void OnSceneGUI()
    {
        // 1. Setup (Runs every frame, but initialization is concise)
        spline = target as BezierSpline;
        handleTransform = spline.transform;
        // Determine rotation based on global/local tool setting
        handleRotation = Tools.pivotRotation == PivotRotation.Local ? handleTransform.rotation : Quaternion.identity;

        // 2. Draw Spline and Control Points
        Vector3 p0 = ShowPoint(0);
        for (int i = 1; i < spline.ControlPointCount; i += 3)
        {
            Vector3 p1 = ShowPoint(i);
            Vector3 p2 = ShowPoint(i + 1);
            Vector3 p3 = ShowPoint(i + 2);

            Handles.color = Color.gray;
            Handles.DrawLine(p0, p1);
            Handles.DrawLine(p2, p3);

            // Draw the curve segment
            Handles.DrawBezier(p0, p3, p1, p2, Color.white, null, 2f);

            p0 = p3;
        }

        // 3. Draw World Vectors (Optimized to reuse calculations)
        ShowWorldVectors();
    }

    // ---------------------------------------------------------------- //

    /// <summary>
    /// Draws the Tangent, Binormal, and Normal vectors along the spline.
    /// This is optimized by only calling the spline methods once per step.
    /// </summary>
    private void ShowWorldVectors()
    {
        // Cache total steps to avoid repeated multiplication and division
        int steps = stepsPerCurve * spline.CurveCount;
        float totalSteps = steps;

        for (int i = 0; i <= steps; i++)
        {
            float t = i / totalSteps;

            // Calculate all necessary vectors once per step
            Vector3 point = spline.GetPoint(t);
            Vector3 tangent = spline.GetTangent(t); // Calls GetVelocity
            Vector3 binormal = spline.GetBinormal(t); // Calls GetTangent
            Vector3 normal = spline.GetNormal(t); // Calls GetTangent and GetBinormal

            // Draw Tangent (Red)
            Handles.color = Color.red;
            Handles.DrawLine(point, point + tangent * worldVectorsScale);

            // Draw Binormal (Blue)
            Handles.color = Color.blue;
            Handles.DrawLine(point, point + binormal * worldVectorsScale);

            // Draw Normal (Green)
            Handles.color = Color.green;
            Handles.DrawLine(point, point + normal * worldVectorsScale);
        }
    }

    // ---------------------------------------------------------------- //

    private Vector3 ShowPoint(int index)
    {
        // Convert local control point to world space
        Vector3 point = handleTransform.TransformPoint(spline.GetControlPoint(index));

        // Calculate size based on distance from camera
        float size = HandleUtility.GetHandleSize(point);

        // Make the first point larger
        if (index == 0)
        {
            size *= 2f;
        }

        // Set color based on the point mode
        Handles.color = modeColors[(int)spline.GetControlPointMode(index)];

        // Button/Selection Logic
        if (Handles.Button(point, handleRotation, size * handleSize, size * pickSize, Handles.CubeHandleCap))
        {
            selectedIndex = index;
            Repaint();
        }

        // Handle Movement Logic (Only for selected point)
        if (selectedIndex == index)
        {
            EditorGUI.BeginChangeCheck();
            Vector3 newPoint = Handles.DoPositionHandle(point, handleRotation);
            if (EditorGUI.EndChangeCheck())
            {
                // Use centralized setter for clean Undo/Dirty logic
                SetControlPointAndMarkDirty(
                    index,
                    handleTransform.InverseTransformPoint(newPoint),
                    "Move Point (Scene)"
                );
            }
            point = newPoint; // Update local variable for subsequent drawing in OnSceneGUI loop
        }

        return point;
    }

    // ---------------------------------------------------------------- //

    public override void OnInspectorGUI()
    {
        // Show default fields (like isLooped) first
        DrawDefaultInspector();

        if (selectedIndex >= 0 && selectedIndex < spline.ControlPointCount)
        {
            DrawSelectedPointInspector();
        }

        // Add Curve Button
        if (GUILayout.Button("Add New Point"))
        {
            Undo.RecordObject(spline, "Add Point");
            spline.AddCurve();
            EditorUtility.SetDirty(spline);
            // After adding a curve, usually the last point is selected
            selectedIndex = spline.ControlPointCount - 1;
        }

         // Add Curve Button
        if (GUILayout.Button("Remove Last Point"))
        {
            Undo.RecordObject(spline, "Remove Last Point");
            spline.RemoveCurve();
            EditorUtility.SetDirty(spline);
            // After adding a curve, usually the last point is selected
            selectedIndex = spline.ControlPointCount - 1;
        }

        if (GUILayout.Button("Reset Spline")) // ⬅️ THIS LINE IS ADDED
        {
            Undo.RecordObject(spline, "Reset Spline"); // Record before resetting
            spline.Reset();
            EditorUtility.SetDirty(spline);
            selectedIndex = -1; // Deselect the point after reset
        }
    }

    // ---------------------------------------------------------------- //

    private void DrawSelectedPointInspector()
    {
        GUILayout.Label("Selected Point");

        // --- Position Field ---
        EditorGUI.BeginChangeCheck();
        Vector3 point = EditorGUILayout.Vector3Field("Position", spline.GetControlPoint(selectedIndex));
        if (EditorGUI.EndChangeCheck())
        {
            // Use centralized setter
            SetControlPointAndMarkDirty(selectedIndex, point, "Move Point (Inspector)");
        }

        // --- Mode Enum Field ---
        EditorGUI.BeginChangeCheck();
        // Use the SelectedPointMode property for clear access to the current mode
        BezierControlPointMode mode = (BezierControlPointMode)EditorGUILayout.EnumPopup("Mode", SelectedPointMode);
        if (EditorGUI.EndChangeCheck())
        {
            // Use centralized setter
            SetControlPointModeAndMarkDirty(selectedIndex, mode, "Change Point Mode");
        }
    }

    // ---------------------------------------------------------------- //

    // --- Centralized Undo/Dirty Helpers (Optimization for Maintenance) ---

    /// <summary>
    /// Records an undo step, sets the new control point position, and marks the object dirty.
    /// </summary>
    private void SetControlPointAndMarkDirty(int index, Vector3 newPosition, string undoName)
    {
        Undo.RecordObject(spline, undoName);
        spline.SetControlPoint(index, newPosition);
        EditorUtility.SetDirty(spline);
    }

    /// <summary>
    /// Records an undo step, sets the new control point mode, and marks the object dirty.
    /// </summary>
    private void SetControlPointModeAndMarkDirty(int index, BezierControlPointMode mode, string undoName)
    {
        Undo.RecordObject(spline, undoName);
        spline.SetControlPointMode(index, mode);
        EditorUtility.SetDirty(spline);
    }
}