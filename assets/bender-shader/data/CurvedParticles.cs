using Assets.Scripts.Bezier;
using UnityEngine;

namespace Assets.Scripts.Particles
{
    // Uncomment order to enable editor functionality. 
    // Comment Out if editor functionality is needed    
    [ExecuteInEditMode]
    [RequireComponent(typeof(ParticleSystem))]
    public class CurvedParticles : MonoBehaviour
    {
        public BezierSpline spline;
        public float pull = 5.0f;

        private float splineLength;

        private ParticleSystem particleSystemInternal;
        private ParticleSystem.Particle[] particles;

        void Awake()
        {
            particleSystemInternal = GetComponent<ParticleSystem>();
        }

        void Start()
        {
            Init();
        }

        internal void Init()
        {
            if (particleSystemInternal == null)
            {
                particleSystemInternal = GetComponent<ParticleSystem>();
            }

            if (particles == null || particles.Length < particleSystemInternal.main.maxParticles)
            {
                particles = new ParticleSystem.Particle[particleSystemInternal.main.maxParticles];
            }

            if (spline != null)
            {
                splineLength = spline.SplineLength;
            }
        }

        void LateUpdate()
        {
            // GetParticles is allocation free because we reuse the m_Particles buffer between updates
            int aliveParticlesCount = particleSystemInternal.GetParticles(particles);
            // Change only the particles that are alive
            for (int i = 0; i < aliveParticlesCount; i++)
            {
                ParticleSystem.Particle particle = particles[i];
                float elapsedTime = particle.startLifetime - particle.remainingLifetime;
                float normalizedLifetime = elapsedTime / particle.startLifetime;
                Vector3 curvePoint = spline.GetPoint(normalizedLifetime);

                Vector3 particlePosition = particle.position;
                particles[i].position = Vector3.Lerp(particlePosition, curvePoint, Time.fixedDeltaTime * pull);

            }

            // Apply the particle changes to the Particle System
            particleSystemInternal.SetParticles(particles, aliveParticlesCount);
        }

        private void OnDrawGizmos()
        {
            if (spline == null) return;

            Init();

            int aliveParticlesCount = particleSystemInternal.GetParticles(particles);
            for (int i = 0; i < aliveParticlesCount; i++)
            {

                ParticleSystem.Particle particle = particles[i];
                float elapsedTime = particle.startLifetime - particle.remainingLifetime;
                float normalizedLifetime = elapsedTime / particle.startLifetime;
                Vector3 curvePoint = spline.GetPoint(normalizedLifetime);

                Vector3 particlePosition = particle.position;

                Gizmos.color = Color.green;
                Gizmos.DrawWireSphere(curvePoint, 0.25f);

                Gizmos.color = Color.gray;
                Gizmos.DrawLine(particlePosition, curvePoint);
            }
        }
    }
}