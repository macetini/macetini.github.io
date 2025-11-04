using UnityEngine;

[RequireComponent(typeof(Renderer))]
public class ForceShieldController : MonoBehaviour
{
    private static readonly int HitsCountID = Shader.PropertyToID("_HitsCount");
    private static readonly int HitsRadiusID = Shader.PropertyToID("_HitsRadius");
    private static readonly int HitsPositionID = Shader.PropertyToID("_HitsObjectPosition");
    private static readonly int HitsIntensityID = Shader.PropertyToID("_HitsIntensity");

    private const int MAX_HITS_COUNT = 10;

    private readonly Vector4[] _hitsObjectPosition = new Vector4[MAX_HITS_COUNT];
    private readonly float[] _hitsDuration = new float[MAX_HITS_COUNT];
    private readonly float[] _hitRadius = new float[MAX_HITS_COUNT];
    private readonly float[] _hitsTimer = new float[MAX_HITS_COUNT];
    private readonly float[] _hitsIntensity = new float[MAX_HITS_COUNT];

    private Renderer _renderer;
    private MaterialPropertyBlock _mpb;
    private int _hitsCount;

    public void AddHit(Vector3 worldPosition, float duration, float radius)
    {
        int id = GetFreeHitId();

        _hitsObjectPosition[id] = transform.InverseTransformPoint(worldPosition);

        _hitsDuration[id] = Mathf.Max(0.001f, duration);
        _hitRadius[id] = Mathf.Max(0f, radius);

        // 3. Reset the timer
        _hitsTimer[id] = 0f;
    }

    int GetFreeHitId()
    {
        if (_hitsCount < MAX_HITS_COUNT)
        {
            _hitsCount++;
            return _hitsCount - 1;
        }
        else
        {
            float minDuration = float.MaxValue;
            int minId = 0;
            for (int i = 0; i < MAX_HITS_COUNT; i++)
            {
                if (_hitsDuration[i] < minDuration)
                {
                    minDuration = _hitsDuration[i];
                    minId = i;
                }
            }
            return minId;
        }
    }

    public void ClearAllHits()
    {
        _hitsCount = 0;
        SendHitsToRenderer();
    }

    void Awake()
    {
        _renderer = GetComponent<Renderer>();
        _mpb = new MaterialPropertyBlock();
    }

    void Update()
    {
        UpdateHitsLifeTime();
        SendHitsToRenderer();
    }

    void UpdateHitsLifeTime()
    {
        for (int i = 0; i < _hitsCount;)
        {
            _hitsTimer[i] += Time.deltaTime;
            if (_hitsTimer[i] > _hitsDuration[i])
            {
                SwapWithLast(i);
            }
            else
            {
                i++;
            }
        }
    }

    void SwapWithLast(int id)
    {
        int idLast = _hitsCount - 1;
        if (id != idLast)
        {
            _hitsObjectPosition[id] = _hitsObjectPosition[idLast];
            _hitsDuration[id] = _hitsDuration[idLast];
            _hitsTimer[id] = _hitsTimer[idLast];
            _hitRadius[id] = _hitRadius[idLast];
        }
        _hitsCount--;
    }

    void SendHitsToRenderer()
    {
        _renderer.GetPropertyBlock(_mpb);

        _mpb.SetFloatArray(HitsRadiusID, _hitRadius);
        _mpb.SetVectorArray(HitsPositionID, _hitsObjectPosition);

        _mpb.SetInt(HitsCountID, _hitsCount);

        for (int i = 0; i < _hitsCount; i++)
        {
            if (_hitsDuration[i] > 0f)
            {
                _hitsIntensity[i] = 1 - Mathf.Clamp01(_hitsTimer[i] / _hitsDuration[i]);
            }
        }
        _mpb.SetFloatArray(HitsIntensityID, _hitsIntensity);

        _renderer.SetPropertyBlock(_mpb);
    }
}