using UnityEngine;

namespace Assets.Scripts.Generators.Zone
{
    public class SubZone
    {
        public static readonly float ZONE_SIZE_RATIO = 1.25f;
        public static readonly float ZONE_SPLIT_VALUE = 0.5f;

        public SubZone left, right;

        public Rect rect;

        public SubZone(Rect mRect)
        {
            rect = mRect;
        }

        public bool Split(float minZoneSize, float maxZoneSize)
        {
            if (!IsLeaf()) return false;

            bool splitH;

            if (rect.width / rect.height >= ZONE_SIZE_RATIO)
            {
                splitH = false;
            }
            else if (rect.height / rect.width >= ZONE_SIZE_RATIO)
            {
                splitH = true;
            }
            else
            {
                splitH = Random.Range(0.0f, 1.0f) > ZONE_SPLIT_VALUE;
            }

            if (Mathf.Min(rect.height, rect.width) * ZONE_SPLIT_VALUE < minZoneSize) return false;

            float splitBorder = splitH ? rect.width - minZoneSize : rect.height - minZoneSize;
            int split = (int)Random.Range(minZoneSize, splitBorder);

            if (splitH)
            {
                left = new SubZone(new Rect(rect.x, rect.y, rect.width, split));
                right = new SubZone(new Rect(rect.x, rect.y + split, rect.width, rect.height - split));
            }
            else
            {
                left = new SubZone(new Rect(rect.x, rect.y, split, rect.height));
                right = new SubZone(new Rect(rect.x + split, rect.y, rect.width - split, rect.height));
            }

            return true;
        }

        public bool IsLeaf()
        {
            return left == null && right == null;
        }
    }
}