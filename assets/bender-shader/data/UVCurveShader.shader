Shader "Custom/UVCurveShader"
{
    Properties
    {
        [Header(Base Map)]
        _MainTex("Base (RGB)", 2D) = "white" {}
        _Color("Main Color", Color) = (1, 1, 1, 1)

        [Header(Spline Data)]
        _SplineLength("Spline World Length", Float) = 1.0
        _SplineProgress("Spline Progress (0-1)", Range(0.0, 1.0)) = 0.0
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Geometry" }
        LOD 100
        Cull Off

        Pass
        {
            Name "Shadeless" // Changed name to reflect new lighting
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ LIGHTMAP_ON
            // We include the shadow macro but IGNORE the result in frag to ensure URP compiles correctly
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS

            // URP Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // Needed for GetMainLight()
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"

            // 3. Define CBUFFERS and Textures
            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            half4 _Color;
            float _SplineLength;
            float _SplineProgress;
            CBUFFER_END

            CBUFFER_START(SplineData)
            int _SplinePointsCount;
            float4 _SplinePoints[999];
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            // 4. Custom Spline Math Functions (Unchanged)

            float4 GetFirstDerivative(float4 p0, float4 p1, float4 p2, float4 p3, float t)
            {
                t = saturate(t);
                float oneMinusT = 1.0 - t;

                return
                3.0 * oneMinusT * oneMinusT * (p1 - p0) +
                6.0 * oneMinusT * t * (p2 - p1) +
                3.0 * t * t * (p3 - p2);
            }

            float4 GetVelocity(float t)
            {
                int i;

                if (t >= 1.0)
                {
                    t = 1.0;
                    i = _SplinePointsCount - 4;
                }
                else
                {
                    t = saturate(t) * ((_SplinePointsCount - 1.0) / 3.0);
                    i = (int)t;
                    t -= i;
                    i *= 3;
                }

                return GetFirstDerivative(_SplinePoints[i], _SplinePoints[i + 1], _SplinePoints[i + 2], _SplinePoints[i + 3], t);
            }

            float4 GetTangent(float t)
            {
                return normalize(GetVelocity(t));
            }

            float4 GetBinormal(float t)
            {
                float4 tangent = GetTangent(t);
                float4 vectorUp = float4(0.0, 1.0, 0.0, 0.0);

                return float4(normalize(cross(vectorUp.xyz, tangent.xyz)), 0.0);
            }

            float4 GetNormal(float t)
            {
                float4 tangent = GetTangent(t);
                float4 binormal = GetBinormal(t);

                return float4(normalize(cross(tangent.xyz, binormal.xyz)), 0.0);
            }

            float4 GetPoint(float4 p0, float4 p1, float4 p2, float4 p3, float t)
            {
                float oneMinusT = 1.0 - saturate(t);

                return
                oneMinusT * oneMinusT * oneMinusT * p0 +
                3.0 * oneMinusT * oneMinusT * t * p1 +
                3.0 * oneMinusT * t * t * p2 +
                t * t * t * p3;
            }

            float4 GetPointAlongSpline(float t)
            {
                int i;

                if (t >= 1.0)
                {
                    t = 1.0;
                    i = _SplinePointsCount - 4;
                }
                else
                {
                    t = saturate(t) * ((_SplinePointsCount - 1.0) / 3.0);
                    i = (int)t;
                    t -= i;
                    i *= 3;
                }

                return GetPoint(_SplinePoints[i], _SplinePoints[i + 1], _SplinePoints[i + 2], _SplinePoints[i + 3], t);
            }

            // Manual Spherical Harmonics (SH) Calculation (Unchanged)
            float3 CustomShadeSH9(float3 normal)
            {
                float3 result = unity_SHAr.xyz * normal.x + unity_SHAg.xyz * normal.y + unity_SHAb.xyz * normal.z;

                float3 normal_pow2 = normal * normal;
                float4 temp = unity_SHBr.xyzw * normal.x + unity_SHBg.xyzw * normal.y + unity_SHBb.xyzw * normal.z;

                result += temp.xyz;
                result += temp.w * (normal_pow2.x - normal_pow2.y);
                result += unity_SHC.xyz * (2.0 * normal_pow2.z - normal_pow2.x - normal_pow2.y);

                return result;
            }

            // 5. Define Structs for data flow

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float4 uv : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 uv2 : TEXCOORD2;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half3 positionWS : TEXCOORD1;
                half3 normalWS : NORMAL;
                half4 tangentWS : TEXCOORD2;

                // GI data
                float2 lightmapUV : TEXCOORD3;
                half3 vertexSH : TEXCOORD4;
            };

            // 6. Vertex Shader (vert) - The Deformation Logic (Unchanged from your paste)

            Varyings vert(Attributes input)
            {
                Varyings output;

                // 1. Transform vertex to World Space
                float4 worldPoint = mul(unity_ObjectToWorld, input.positionOS);

                // NOTE : worldNormal is not transformed here in this version, it's calculated later

                // 2. Perform Spline Math (Deformation)
                float t = worldPoint.z / _SplineLength;
                float4 splinePoint = GetPointAlongSpline(t);

                float4 distanceBinormal = GetBinormal(t);
                half dotBinormal = dot(float4(0.0, 0.0, 1.0, 0.0), distanceBinormal);

                float angle = - asin(dotBinormal);

                float4 projectedPoint = float4(worldPoint.x, 0.0, 0.0, worldPoint.w);

                // Y - axis Rotation Matrix
                float4x4 transMatrix = float4x4(
                cos(angle), 0.0, sin(angle), splinePoint.x,
                0.0, 1.0, 0.0, worldPoint.y + splinePoint.y,
                - sin(angle), 0.0, cos(angle), splinePoint.z,
                0.0, 0.0, 0.0, 1.0);

                worldPoint = mul(transMatrix, projectedPoint);

                // Apply 'SplineProgress' (offset)
                float4 progressPoint = GetPointAlongSpline(_SplineProgress);
                worldPoint -= progressPoint;

                // Apply rotational offsets based on progress
                // Rotation around X axis
                float4 progressNormal = GetNormal(_SplineProgress);
                float4 forward = float4(0.0, 0.0, 1.0, 0.0);
                float dotNormal = dot(forward, - progressNormal);
                float angleX = asin(dotNormal);

                float4x4 transMatrix_X = float4x4(
                1.0, 0.0, 0.0, 0.0,
                0.0, cos(angleX), - sin(angleX), 0.0,
                0.0, sin(angleX), cos(angleX), 0.0,
                0.0, 0.0, 0.0, 1.0
                );

                worldPoint = mul(transMatrix_X, worldPoint);

                // Rotation around Y axis
                float4 progressBinormal = GetBinormal(_SplineProgress);
                float dotProgressBinormal = dot(float4(0.0, 0.0, 1.0, 0.0), progressBinormal);

                float angleY = asin(dotProgressBinormal);

                float4x4 transMatrix_Y = float4x4(
                cos(angleY), 0.0, sin(angleY), 0.0,
                0.0, 1.0, 0.0, 0.0,
                - sin(angleY), 0.0, cos(angleY), 0.0,
                0.0, 0.0, 0.0, 1.0
                );

                worldPoint = mul(transMatrix_Y, worldPoint);
                // END OF DEFORMATION

                // 3. Assign Outputs (in World Space for URP)
                output.uv = TRANSFORM_TEX(input.uv.xy, _MainTex);
                output.positionWS = (half3)worldPoint.xyz;

                // Normals and Tangents based on the curve's orientation at 't'
                float3 newTangent = GetTangent(t).xyz;
                float3 newNormal = GetNormal(t).xyz;

                output.normalWS = (half3)normalize(newNormal);
                output.tangentWS = (half4)float4(normalize(newTangent), input.tangentOS.w);

                // GI DATA SETUP
                output.lightmapUV = input.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;

                #ifdef LIGHTMAP_ON
                output.vertexSH = 0.0h; // Use lightmap if enabled
                #else
                output.vertexSH = (half3)CustomShadeSH9(output.normalWS);
                #endif

                // 4. Final Clip Space Transformation
                output.positionCS = TransformWorldToHClip(output.positionWS);

                return output;
            }

            // 7. Fragment Shader (frag) - Shadeless Lighting Logic (NEW)

            half4 frag(Varyings input) : SV_Target
            {
                // 1. Get Albedo Color
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _Color;

                // 2. Get Main Light data
                Light mainLight = GetMainLight();

                // 3. Direct Lighting : Simple Lambertian (N dot L, clamped, NO shadows)
                // Since GetMainLight() returns 0 for shadows / attenuation by default in this context,
                // we are explicitly ignoring the attenuation / shadow factors it might include.
                half NdotL = saturate(dot(input.normalWS, mainLight.direction));

                // Direct Light Contribution
                half3 directLight = mainLight.color * NdotL;

                // 4. Ambient Light (from SH or Lightmap)
                half3 ambientLight;

                #ifdef LIGHTMAP_ON
                // Read lightmap and multiply by its color
                ambientLight = SampleLightmap(input.lightmapUV, input.normalWS, unity_AmbientLightColor.rgb);
                #else
                // Use Spherical Harmonics (SH) calculated in the vertex shader
                ambientLight = input.vertexSH;
                #endif

                // 5. Final Color : Albedo * (Direct + Ambient)
                half3 finalColor = albedo.rgb * (directLight + ambientLight);

                return half4(finalColor, albedo.a);
            }

            ENDHLSL
        }
    }
}