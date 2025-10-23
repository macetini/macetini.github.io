Shader "Custom/LitGesternWave"
{
    Properties
    {
        [Header(Feature Toggles)]
        [Toggle(_ENABLE_PLANAR_REF_ON)] _EnablePlanarRef ("Enable Planar Reflection", Float) = 1
        [Toggle(_ENABLE_SKYBOX_REF_ON)] _EnableSkyboxRef ("Enable Skybox Reflection", Float) = 1
        [Toggle(_ENABLE_COLOR_SURFACE_ON)] _EnableColorSurface ("Enable Color Surface (No Reflection)", Float) = 1
        [Toggle(_ENABLE_SSS_ON)] _EnableSSS ("Enable Subsurface Scattering", Float) = 1
        [Toggle(_ENABLE_FOAM_ON)] _EnableFoam ("Enable Foam (Depth-Based)", Float) = 1
        [Toggle(_ENABLE_GLITTER_ON)] _EnableGlitter ("Enable Sun Glitter", Float) = 1

        [HDR] _WaveColor ("Wave Color", Color) = (1, 1, 1, 1)

        _Glossiness ("Smoothness", Range(0, 1)) = 0.5
        _Metallic ("Metallic", Range(0, 1)) = 0.0

        [Header(First Wave)]

        _Wavelength1 ("Wavelength Wave A", Float) = 10
        _Amplitude1 ("Amplitude Wave A", Float) = 1
        _Speed1 ("Speed Wave A", Float) = 1
        _Steepness1 ("Steepness Wave A", Range(0, 1)) = 0.5
        _Direction1 ("Direction Wave A (2D)", Vector) = (1, 0, 0, 0)

        [Header(Second Wave)]

        _Wavelength2 ("Wavelength Wave B", Float) = 10
        _Amplitude2 ("Amplitude Wave B", Float) = 1
        _Speed2 ("Speed Wave B", Float) = 1
        _Steepness2 ("Steepness Wave B", Range(0, 1)) = 0.5
        _Direction2 ("Direction Wave B (2D)", Vector) = (1, 0, 0, 0)

        [Header(Surface Blending and Absorption)]
        // Color of the water itself, tinting the refracted scene
        [HDR] _WaterAbsorptionColor ("Absorption Color", Color) = (0.0, 0.3, 0.4, 1.0)
        // Rate of light decay in water (controls visibility distance)
        _WaterAbsorptionRate ("Absorption Rate", Range(0.01, 1.0)) = 0.2

        _DistortionFactor("Distortion Factor", Range(0, 1.0)) = 0.3

        [Header(Sun Glitter)]

        _GlintMask("Flicker Noise (Grayscale)", 2D) = "white" {}
        _GlintMaskTiling("Mask Tiling", Range(1, 10)) = 5.0
        // Overall brightness of the glint effect
        _GlitterIntensity("Intensity", Range(0.0, 5.0)) = 1.0
        // Controls the tightness of the highlight (the exponent of the power function)
        // Higher value = smaller, sharper glint
        _GlitterSharpness("Sharpness (Size)", Range(100.0, 3000.0)) = 500.0
        // Controls how much the wave normals break up and scatter the glint (our renamed _NormalStrength)
        _GlintChoppiness("Glint Choppiness (Scatter)", Range(0.0, 2.0)) = 0.5

        [Header(Subsurface Scattering)]

        // The color light scatters as it penetrates the water volume
        [HDR] _SSColor ("SSS Color (Absorption)", Color) = (0.0, 0.4, 0.5, 1.0)
        // Overall intensity multiplier for the SSS glow
        _SSScale ("SSS Intensity Scale", Range(0.0, 5.0)) = 1.0
        // Controls the sharpness / falloff of the glow (the exponent)
        _SSPower ("SSS Sharpness (Power)", Range(1.0, 64.0)) = 4.0
        // Controls how far the SSS lobe 'wraps' into the shadow area
        _SSDiffusion ("SSS Diffusion (Wrap)", Range(0.0, 1.0)) = 0.5

        [Header(Foam)]
        _FoamColor ("Foam Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _FoamTex ("Foam Texture (Mask)", 2D) = "white" {}
        _FoamTiling ("Foam Texture Tiling", Range(1.0, 20.0)) = 5.0
        _FoamMaxDistance ("Foam Max Distance", Range(0.01, 50.0)) = 0.5
        _FoamSharpness ("Foam Sharpness", Range(1.0, 50.0)) = 10.0

        [Header(Maps)]

        [NoScaleOffset] _NormalMap1("Normal Map 1", 2D) = "white" {}
        [NoScaleOffset] _DuDvMap1("Normal Map 1 Distortion", 2D) = "white" {}

        [NoScaleOffset] _NormalMap2("Normal Map 2", 2D) = "white" {}
        [NoScaleOffset] _DuDvMap2("Normal Map 2 Distortion", 2D) = "white" {}

        _NormalMapScrollSpeed ("Normal Map Scroll Speed", Vector) = (1, 1, 1, 1)

        [Header(Reflection)]
        [NoScaleOffset] _ReflectionTex ("Planar Reflection Texture", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard alpha vertex:vert
        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        // Include the keyword definitions
        #pragma shader_feature _ENABLE_PLANAR_REF_ON
        #pragma shader_feature _ENABLE_SKYBOX_REF_ON
        #pragma shader_feature _ENABLE_COLOR_SURFACE_ON
        #pragma shader_feature _ENABLE_SSS_ON
        #pragma shader_feature _ENABLE_FOAM_ON
        #pragma shader_feature _ENABLE_GLITTER_ON

        #include "UnityCG.cginc"
        #include "UnityStandardBRDF.cginc"

        struct Input
        {
            float2 uv_Base;
            float3 worldPos;
            float4 screenPos;

            INTERNAL_DATA
        };

        struct WaveInfo
        {
            half wavelength; // (W)
            half amplitude; // (A)
            half speed; // (phi)
            half2 direction; // (D)
            half Steepness; // (Q)
        };

        struct TangentSpace
        {
            half3 normal;
            half3 binormal;
            half3 tangent;
        };

        struct SurfaceDataVectors
        {
            // Set Up
            float4 screenPos;
            float3 worldPos;
            half3x3 tangentSpaceMatrix;

            // Calculated

            // Sampled from Textures
            // UVs for lighting normals and distortion maps
            half4 normalMapCoords;
            half3 combinedTangentNormal; // Combined tangent space normal for lighting

            half4 duDvMapCoords;
            half3 combinedDuDvNormal;
            half3 distortionVector;

            half3 worldNormal;
            half3 worldViewDir;
            half3 lightDir;

            half3 finalNormal;
            half3 reflectionVector;
            half viewDotNormal;
        };


        half4 _WaveColor;
        half _Glossiness;
        half _Metallic;

        half _Wavelength1, _Amplitude1, _Speed1, _Steepness1;
        half _Wavelength2, _Amplitude2, _Speed2, _Steepness2;

        half _DistortionFactor;

        sampler2D _GlintMask;
        sampler sampler_GlintMask;

        half3 _WaterAbsorptionColor;
        half _WaterAbsorptionRate;

        // GLITTER / GLINT
        float _GlintMaskTiling;
        half _GlitterIntensity;
        float _GlitterSharpness;
        half _GlintChoppiness;

        // SUBSURFACE SCATTERING (SSS)
        half3 _SSColor;
        half _SSScale;
        half _SSPower;
        half _SSDiffusion;

        // FOAM
        half4 _FoamColor;
        half _FoamTiling;
        half _FoamMaxDistance;
        half _FoamSharpness;

        sampler2D _FoamTex;
        sampler sampler_FoamTex;

        float _Distortion;

        half4 _Direction1, _Direction2;
        half4 _NormalMapScrollSpeed;

        sampler2D _NormalMap1;
        sampler sampler_NormalMap1;

        sampler2D _NormalMap2;
        sampler sampler_NormalMap2;

        sampler2D _DuDvMap1;
        sampler sampler_DuDvMap1;

        sampler2D _DuDvMap2;
        sampler sampler_DuDvMap2;

        uniform sampler2D _ReflectionTex;
        uniform sampler sampler_ReflectionTex;

        sampler2D _CameraOpaqueTexture;
        sampler2D _CameraDepthTexture;

        half4 _CameraDepthTexture_TexelSize;

        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_INSTANCING_BUFFER_END(Props)

        half3 CalculateGesternWave(WaveInfo wave, inout TangentSpace tangentSpace, half3 p, half t)
        {
            half w = sqrt(9.81 * ((2 * 3.14159) / wave.wavelength));
            half PHI_t = wave.speed * w * t;
            half2 D = normalize(wave.direction.xy);
            half Q = wave.Steepness / (w * wave.amplitude * 2);

            half f1 = w * dot (D, p.xz) + PHI_t;
            half S = sin(f1);
            half C = cos(f1);

            half WA = w * wave.amplitude;
            half WAS = WA * S;
            half WAC = WA * C;

            tangentSpace.binormal += half3
            (
            Q * (D.x * D.x) * WAS,
            D.x * WAC,
            Q * (D.x * D.y) * WAS
            );

            tangentSpace.tangent += half3
            (
            Q * (D.x * D.y) * WAS,
            D.y * WAC,
            Q * (D.y * D.y) * WAS
            );

            tangentSpace.normal += half3
            (
            D.x * WAC,
            Q * WAS,
            D.y * WAC
            );

            half f3 = cos(f1);
            half f4 = Q * wave.amplitude * f3;

            return half3
            (
            f4 * D.x, // X
            wave.amplitude * sin(f1), // Y
            f4 * D.y // Z
            );
        }

        void vert (inout appdata_full v, out Input o)
        {
            WaveInfo wave1 = {_Wavelength1, _Amplitude1, _Speed1, _Direction1.xy, _Steepness1};
            WaveInfo wave2 = {_Wavelength2, _Amplitude2, _Speed2, _Direction2.xy, _Steepness2};

            TangentSpace tangentSpace = { half3(0, 0, 0), half3(0, 0, 0), half3(0, 0, 0) };

            half3 vertexPosition = v.vertex.xyz;
            float time = _Time.y;

            vertexPosition += CalculateGesternWave(wave1, tangentSpace, vertexPosition, time);
            vertexPosition += CalculateGesternWave(wave2, tangentSpace, vertexPosition, time);

            v.vertex.xyz = vertexPosition;

            // Initialize all members of 'o' to zero / default first
            UNITY_INITIALIZE_OUTPUT(Input, o);

            // Assign the custom values from the vertex shader calculations
            o.uv_Base = v.texcoord.xy;
            o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz; // Need worldPos for view dir and reflection
            o.screenPos = ComputeScreenPos(UnityObjectToClipPos(v.vertex));
        }

        half3 CalculateDistortionNormal(half3x3 tangentSpaceMatrix, half4 duDvMapCoords)
        {
            half3 duDvMap1 = UnpackNormal(tex2D(_DuDvMap1, duDvMapCoords.xy));
            half3 duDvMap2 = UnpackNormal(tex2D(_DuDvMap2, duDvMapCoords.zw));

            half3 duDVMapSum = duDvMap1 + duDvMap2;

            // Transform the combined tangent space DuDv map into a world space direction vector
            half3 combinedDuDvNormal = normalize(mul(tangentSpaceMatrix, duDVMapSum));

            return combinedDuDvNormal;
        }

        SurfaceDataVectors CalculateSetupVectors(Input input)
        {
            float time = _Time.y;

            // Return struct
            SurfaceDataVectors setupVectors;
            //

            // Set Up
            setupVectors.screenPos = input.screenPos;
            setupVectors.worldPos = input.worldPos;
            //

            // UVs for the actual lighting normal maps
            // We use a slightly faster scroll speed or a different tiling factor (0.5 here)
            // to make the two sets of maps look slightly different
            setupVectors.normalMapCoords.xy = input.uv_Base.xy + _NormalMapScrollSpeed.xy * time * 0.5;
            setupVectors.normalMapCoords.zw = input.uv_Base.xy + _NormalMapScrollSpeed.zw * time * 0.5;
            //

            // UVs for DuDv distortion maps
            setupVectors.duDvMapCoords.xy = input.uv_Base.xy + _NormalMapScrollSpeed.xy * time;
            setupVectors.duDvMapCoords.zw = input.uv_Base.xy + _NormalMapScrollSpeed.zw * time;
            //

            // -- CALCULATE TBN BASIS VECTORS START (Based on Gerstner Waves) --
            // ddx / ddy calculate the vector change in X and Y screen space directions (local derivatives)
            half3 worldTangent = normalize(ddx(input.worldPos));
            half3 worldBinormal = normalize(ddy(input.worldPos));
            half3 geometricWorldNormal = normalize(cross(worldTangent, worldBinormal)); // Gerstner Wave Normal
            //

            // Re - orthogonalize T and B relative to the correct geometric normal
            worldBinormal = normalize(cross(geometricWorldNormal, worldTangent));
            worldTangent = normalize(cross(worldBinormal, geometricWorldNormal));

            // Build the TBN matrix for applying normal map details
            setupVectors.tangentSpaceMatrix = half3x3(worldTangent, worldBinormal, geometricWorldNormal);
            // -- CALCULATE TBN BASIS VECTORS END --

            // Distortion Calculation (Uses DuDv maps and is used for refraction)
            setupVectors.combinedDuDvNormal = CalculateDistortionNormal(setupVectors.tangentSpaceMatrix, setupVectors.duDvMapCoords);
            setupVectors.distortionVector = setupVectors.combinedDuDvNormal * _DistortionFactor;
            //

            // Calculate the Gerstner Wave vector normals (assuming flat base plane)
            setupVectors.worldNormal = geometricWorldNormal;
            setupVectors.worldViewDir = normalize(UnityWorldSpaceViewDir(input.worldPos));
            setupVectors.lightDir = normalize(_WorldSpaceLightPos0.xyz);
            //

            // Calculate the final, combined TANGENT SPACE normal vector for the surface lighting
            half3 normalMap1 = UnpackNormal(tex2D(_NormalMap1, setupVectors.normalMapCoords.xy));
            half3 normalMap2 = UnpackNormal(tex2D(_NormalMap2, setupVectors.normalMapCoords.zw));

            // Combine both normal maps in tangent space
            setupVectors.combinedTangentNormal = normalMap1 + normalMap2;
            //

            // The Final Distorted World Normal (Used for ALL lighting / reflection)
            // Transform the combined tangent space normal to world space
            half3 worldSpaceCombinedNormal = normalize(mul(setupVectors.tangentSpaceMatrix, setupVectors.combinedTangentNormal));

            // Blend the base Gerstner normal (worldNormal) with the high - frequency normal map detail (worldSpaceCombinedNormal),
            // weighted by _GlintChoppiness (which acts as a normal strength factor)
            setupVectors.finalNormal = normalize(setupVectors.worldNormal + (worldSpaceCombinedNormal * _GlintChoppiness));
            //

            // The Shared Reflection Vector (Calculated once)
            setupVectors.reflectionVector = reflect(- setupVectors.worldViewDir, setupVectors.finalNormal);
            setupVectors.viewDotNormal = dot(setupVectors.worldViewDir, setupVectors.finalNormal);
            //

            return setupVectors;
        }

        half3 CalculatePlanarReflection(SurfaceDataVectors setupVectors)
        {
            // Calculate the clip - space position
            // This gives us the screen coordinates of the current fragment,
            // which corresponds to the texture coordinates of the planar reflection.
            float4 clipPos = UnityObjectToClipPos(float4(setupVectors.worldPos, 1.0));

            // Convert to normalized screen coordinates [0, 1]
            half2 screenUV = clipPos.xy / clipPos.w; // Perspective division (NDC)

            // Convert from [ - 1, 1] range (NDC) to [0, 1] UV range
            half2 reflUV = screenUV * 0.5 + 0.5;

            // This vector (setupVectors.distortionVector) already contains the sum of both maps,
            // transformed to world space, and scaled by _DistortionFactor.
            half3 combinedWorldDistortion = setupVectors.distortionVector;

            // We use the XY components for the UV offset. The 0.1 is an arbitrary strength multiplier
            // to control how much the reflection map is distorted relative to the main refraction effect.
            reflUV += combinedWorldDistortion.xy * 0.1;

            // Sample the dynamic planar reflection texture
            half3 reflectedSceneColor = tex2D(_ReflectionTex, reflUV).rgb;

            return reflectedSceneColor;
        }

        half3 CalculateSkyBoxReflection(SurfaceDataVectors setupVectors)
        {
            half4 skyData = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, setupVectors.reflectionVector);
            half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR);

            // Reflection Factor (Fresnel - now correctly uses finalNormal)
            half reflectionFactor = pow(1.0 - saturate(setupVectors.viewDotNormal), 5.0); // Fresnel
            reflectionFactor = saturate(reflectionFactor + 0.5); // Boost base reflection
            half3 reflectedColor = lerp(_WaveColor.rgb, skyColor, reflectionFactor);

            return reflectedColor;
        }

        half3 GetBaseSurfaceColor(SurfaceDataVectors setupVectors, half3 reflectionColor)
        {
            // Now _WaveColor is the primary base color, no need for redundant texture sampling.
            half3 baseWaterColor = _WaveColor.rgb;

            // -- - TEXTURE SURFACE CHECK -- -
            #ifdef _ENABLE_COLOR_SURFACE_ON
            // If pure texture mode is on, return the tinted wave color directly.
            return baseWaterColor;
            #else
            // Otherwise, use Fresnel to blend the base color with the reflection color.
            half reflectionFactor = pow(1.0 - saturate(setupVectors.viewDotNormal), 5.0); // Standard Fresnel
            half3 blendedColor = lerp(baseWaterColor, reflectionColor, reflectionFactor);
            return blendedColor;
            #endif
        }

        half3 CalculateGlitter(SurfaceDataVectors setupVectors)
        {
            // Calculate the alignment with the light direction using the final reflection vector
            half lightDotRefl = max(0, dot(setupVectors.lightDir, setupVectors.reflectionVector));

            // Calculate the base glint factor (sharp specular highlight)
            float sharpness = _GlitterSharpness;
            half sunGlitterFactor = pow(lightDotRefl, sharpness);

            // Add a subtle mask for breakup (flicker)
            half textureMask = tex2D(_GlintMask, setupVectors.normalMapCoords.xy * _GlintMaskTiling).r;
            sunGlitterFactor *= (textureMask * 0.5 + 0.5);

            // Calculate the Fresnel factor for view - angle scattering
            half fresnelFactor = pow(1.0 - setupVectors.viewDotNormal, 5.0); // Reuses viewDotNormal

            // Apply Fresnel, Intensity, and Light Color
            half finalGlitterFactor = sunGlitterFactor * fresnelFactor * _GlitterIntensity;
            half3 glitter = finalGlitterFactor * _LightColor0.rgb;

            return glitter;
        }

        half3 CalculateSubsurfaceScattering(SurfaceDataVectors setupVectors)
        {
            // Calculate NdotL using the final distorted normal
            half NdotL = dot(setupVectors.finalNormal, setupVectors.lightDir);

            // 1. Calculate the 'Transmission' lobe
            half SSS_Lobe = pow(saturate(- NdotL + _SSDiffusion), _SSPower); // SSS Lobe (light wrapped around)

            // 2. Apply SSS properties
            half3 subsurfaceScatter = SSS_Lobe * _SSColor.rgb * _SSScale;

            return subsurfaceScatter;
        }

        half2 AlignWithGrabTexel (half2 uv)
        {
            #if UNITY_UV_STARTS_AT_TOP
            if (_CameraDepthTexture_TexelSize.y < 0)
            {
                uv.y = 1 - uv.y;
            }
            #endif

            return (floor(uv * _CameraDepthTexture_TexelSize.zw) + 0.5) * abs(_CameraDepthTexture_TexelSize.xy);
        }

        half3 CalculateFoam(half3 finalColor, float finalDepthDifference, half2 uv_final)
        {
            // 1. Calculate Foam Factor based on distance to background
            // Foam factor is high (near 1) when finalDepthDifference is small.
            // _FoamMaxDistance controls the width of the foam band.
            half foamFactor = 1.0 - saturate(finalDepthDifference / _FoamMaxDistance);

            // 2. Sharpen the edge and apply texture mask
            foamFactor = pow(foamFactor, _FoamSharpness);

            // Use the final UV for the foam mask texture
            half foamTexMask = tex2D(_FoamTex, uv_final * _FoamTiling).r;
            foamFactor *= foamTexMask;

            half3 colorWithFoam = lerp(finalColor, _FoamColor.rgb, foamFactor);

            return colorWithFoam;
        }

        half3 CalculateDepthAbsorptionAndBlending(half3 waterFragment, float finalDepthDifference, half2 uv_final)
        {
            // Sample the refracted scene color
            half3 underwaterColor = tex2D(_CameraOpaqueTexture, uv_final).rgb;

            float absorptionRate = max(0.001, _WaterAbsorptionRate);
            float extinction = exp(- finalDepthDifference * absorptionRate); // Exponential decay (1 = clear, 0 = opaque)

            // Blend water color into the refracted scene color based on depth
            half3 absorbedUnderwaterColor = lerp(_WaterAbsorptionColor.rgb, underwaterColor, extinction);

            // Final blending towards surface reflection (waterFragment)
            half3 finalColor = lerp(absorbedUnderwaterColor, waterFragment, 1.0 - extinction);

            return finalColor;
        }

        half2 CalculateCorrectedUV(SurfaceDataVectors setupVectors, float surfaceDepth)
        {
            half3 distortionVector = setupVectors.distortionVector;

            // Apply camera aspect / resolution scaling for distortion correction
            distortionVector.y *= _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);

            // -- - 1st Pass : Initial Distortion & Artifact Correction -- -
            half2 uv_initial = AlignWithGrabTexel((setupVectors.screenPos.xy + distortionVector.xy) / setupVectors.screenPos.w);
            float backgroundDepth_initial = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv_initial));

            // Calculate difference for correction
            float depthDifference_initial = backgroundDepth_initial - surfaceDepth;

            // Artifact Correction : Reduce distortion near background geometry
            // This value (100.0) is the sharpness of the cutoff.
            distortionVector *= saturate(depthDifference_initial * 100.0);

            // -- - 2nd Pass : Final Corrected Sampling -- -
            half2 uv_final = AlignWithGrabTexel((setupVectors.screenPos.xy + distortionVector.xy) / setupVectors.screenPos.w);

            return uv_final;
        }

        half3 CalculateEmission(SurfaceDataVectors setupVectors, half3 waterFragment)
        {
            // Use floats for depth for maximum precision
            float surfaceDepth = UNITY_Z_0_FAR_FROM_CLIPSPACE(setupVectors.screenPos.z);

            // -- - 2nd Pass : Final Corrected Sampling -- -
            half2 uv_final = CalculateCorrectedUV(setupVectors, surfaceDepth);

            // Recalculate depth / difference with corrected UV
            float backgroundDepth_final = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv_final));
            float finalDepthDifference = backgroundDepth_final - surfaceDepth; // True distance to background
            //

            // -- - DEPTH ABSORPTION & BLENDING (Underwater Fog) START -- -
            half3 finalColor = CalculateDepthAbsorptionAndBlending(waterFragment, finalDepthDifference, uv_final);
            // -- - DEPTH ABSORPTION & BLENDING (Underwater Fog) END -- -

            // -- - FOAM CONDITIONAL BLOCK -- -
            #ifdef _ENABLE_FOAM_ON
            finalColor = CalculateFoam(finalColor, finalDepthDifference, uv_final);
            #endif
            // -- - END FOAM -- -

            return finalColor;
        }

        // -- - FRAGMENT SHADER (SURFACE) FUNCTION -- -
        void surf (Input input, inout SurfaceOutputStandard o)
        {
            SurfaceDataVectors setupVectors = CalculateSetupVectors(input);

            half3 skyReflection = 0;

            // -- - REFLECTION CONDITIONAL BLOCK -- -
            #ifdef _ENABLE_PLANAR_REF_ON
            skyReflection = CalculatePlanarReflection(setupVectors);
            #endif
            // -- - END REFLECTION -- -

            #ifdef _ENABLE_SKYBOX_REF_ON
            skyReflection = CalculateSkyBoxReflection(setupVectors);
            #endif

            //half3 baseSurfaceModification = CalculateBaseSurfaceModification(setupVectors, skyReflection);
            // 2. Calculate the Base Surface Color (Texture - only OR Fresnel blended reflection)
            half3 baseSurfaceColor = GetBaseSurfaceColor(setupVectors, skyReflection);


            // -- - GLITTER CONDITIONAL BLOCK -- -
            half3 glitter = 0;
            #ifdef _ENABLE_GLITTER_ON
            glitter = CalculateGlitter(setupVectors);
            #endif
            // -- - END GLITTER -- -

            // -- - SSS CONDITIONAL BLOCK -- -
            half3 subsurfaceScatter = 0;
            #ifdef _ENABLE_SSS_ON
            subsurfaceScatter = CalculateSubsurfaceScattering(setupVectors);
            #endif
            // -- - END SSS -- -

            // Get the final calculated water color (Reflection + Glitter + SSS)
            half3 waterFragment = saturate(baseSurfaceColor + glitter + subsurfaceScatter);

            // Combine everything : Refraction + Absorption + Final Color + Foam
            half3 emission = CalculateEmission(setupVectors, waterFragment);

            // -- 3. APPLY OUTPUT PROPERTIES (PBR) --

            // Set to near black to let Emission drive the look (Water is mostly reflection / refraction)
            o.Albedo = half3(0.01, 0.01, 0.01);
            // The final color drives emission for the reflective look
            o.Emission = emission;
            // Pass the final Normal (Gerstner + DuDv) calculated earlier in CalculateSetupVectors
            o.Normal = setupVectors.finalNormal; // <- -- Use the already calculated normal

            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            // Water opacity is driven by the depth factor in SurfaceColor, so Alpha should be 1
            o.Alpha = 1.0;
        }
        ENDCG
    }
    FallBack "Diffuse"
}