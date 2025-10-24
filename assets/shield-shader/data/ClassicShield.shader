Shader "Custom/ClassicShield"
{
    Properties
    {
        [Header(Feature Toggles)]
        [Space]
        [Toggle(_ENABLE_HIDE_FRONT_FACE)] _HideFrontFace ("Hide Front Face", Float) = 0 // Toggle to hide front faces
        [Toggle(_ENABLE_HIDE_BACK_FACE)] _HideBackFace ("Hide Back Face", Float) = 0 // Toggle to hide back faces

        [Header(Shield Main Colors)]
        [Space]
        [HDR] _Color("Dominant", Color) = (0, 1, 0, 0.5) // Base Shield Color
        [HDR] _GlowColor("Hue", Color) = (1, 1, 1, 1) // Intersection Glow Color
        _GlowColorIntensity("Luminosity", Range(1, 15)) = 4 // How intense the intersection glow is
        _FadeLength("Segue", Range(0, 2)) = 0.15 // How smooth the intersection glow fades

        [Header(Hit Settings)]
        [Space]
        _HitForceMultiplier("Magnitude", Range(0, 1.0)) = 0.15 // How much the shield deforms on hit
        [HDR] _HitColor("Tint", Color) = (1, 1, 1, 1) // Hit Color
        _HitColorIntensity("Saturation", Range(0.0, 5.0)) = 1 // Hit Color Intensity
        _HitAlfaIntensity("Opacity", Range(0.0, 5.0)) = 1 // Hit Alpha Intensity
        _HitEffectBorder("Outline", Range(0.01, 1.0)) = 0.25 // Width of the hit effect border

        [Header(Fresnel Settings)]
        [Space]
        [HDR] _FresnelColor("Rim", Color) = (1, 1, 1, 1) // Fresnel Color
        _FresnelTex("Mask", 2D) = "white" {} // Fresnel Pattern Texture
        _WorldScaleFactor("Tiling", Range(0.1, 5.0)) = 1.0 // World Scale Tiling Factor
        _FresnelExponent("Falloff", Range(0, 20)) = 1 // Fresnel Exponent
        _ScrollSpeedU("Offset", Range(0, 10)) = 1 // U Scroll Speed
        _ScrollSpeedV("Rate", Range(0, 10)) = 1 // V Scroll Speed

        [Header(Distortion Settings)]
        [Space]
        [Toggle(_ENABLE_LERP_DISTORTION)] _LerpDistortion ("Blend Distortion", Float) = 0 // Toggle to hide front faces
        [Toggle(_ENABLE_SUPERSEDED_DISTORTION)] _SetDistortion ("Superseded Distortion", Float) = 0 // Toggle to hide back faces
        [Toggle(_ENABLE_ADD_DISTORTION)] _AddDistortion ("Add Distortion", Float) = 1 // Toggle to hide back faces

        [NoScaleOffset] _DistortionTex("Distortion Mask", 2D) = "bump" {} // A normal map or grayscale texture
        _DistortionStrength("Strength", Range(0.0, 5)) = 0.05
        _DistortionScrollSpeed("Scroll Rate", Range(0.0, 5.0)) = 1.0
    }

    SubShader
    {
        Lighting Off
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Tags{ "RenderType" = "Transparent" "Queue" = "Transparent"}

        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            // Include the keyword definitions
            #pragma shader_feature _ENABLE_HIDE_FRONT_FACE
            #pragma shader_feature _ENABLE_HIDE_BACK_FACE

            #pragma shader_feature _ENABLE_LERP_DISTORTION
            #pragma shader_feature _ENABLE_SUPERSEDED_DISTORTION
            #pragma shader_feature _ENABLE_ADD_DISTORTION

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0; // Fresnel UV (Scaled / Scrolled)
                float2 uvOriginal : TEXCOORD1; // Original UV (for independent Distortion)
                float3 objectPosition : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
                float3 worldNormal : NORMAL;
                float4 vertex : SV_POSITION; // Clip space position needed for screen UV
                float4 screenPos : TEXCOORD4;
            };

            fixed4 _Color;
            fixed3 _GlowColor;
            float _GlowColorIntensity;
            float _FadeLength;

            int _HitsCount = 0;
            float _HitsRadius[10];
            float3 _HitsObjectPosition[10];
            float _HitsIntensity[10];

            fixed3 _HitColor;
            fixed _HitForceMultiplier;
            float _HitEffectBorder;
            float _HitColorIntensity;
            float _HitAlfaIntensity;

            float3 _FresnelColor;
            float _FresnelExponent;
            sampler2D _FresnelTex;
            float4 _FresnelTex_ST;
            float _WorldScaleFactor;
            fixed _ScrollSpeedU;
            fixed _ScrollSpeedV;

            sampler2D _DistortionTex;
            float4 _DistortionTex_ST;
            float _DistortionStrength;
            float _DistortionScrollSpeed;

            sampler2D _CameraDepthTexture;

            sampler2D _CameraOpaqueTexture;
            float4 _CameraOpaqueTexture_TexelSize;

            float GetColorRing(float intensity, float radius, float dist)
            {
                float currentRadius = lerp(0, radius, 1.0 - intensity);
                return intensity * (1.0 - smoothstep(currentRadius, currentRadius + _HitEffectBorder, dist) - (1.0 - smoothstep(currentRadius - _HitEffectBorder, currentRadius, dist)));
            }

            float GetHitColorFactor(float3 objectPosition)
            {
                float factor = 0.0;

                for (int i = 0; i < _HitsCount; i ++)
                {
                    float distanceToHit = distance(objectPosition, _HitsObjectPosition[i]);
                    factor += GetColorRing(_HitsIntensity[i], _HitsRadius[i], distanceToHit);
                }

                factor = saturate(factor);

                return factor;
            }

            float GetHitAlphaFactor(float3 objectPosition)
            {
                float factor = 0.0;

                for (int i = 0; i < _HitsCount; i ++)
                {
                    float distanceToHit = distance(objectPosition, _HitsObjectPosition[i]);
                    //Alpha circle
                    float currentRadius = lerp(0, _HitsRadius[i] - _HitEffectBorder, 1.0 - _HitsIntensity[i]);
                    factor += _HitsIntensity[i] * (1.0 - smoothstep(0, currentRadius, distanceToHit));
                }

                factor = saturate(factor * _HitAlfaIntensity);

                return factor;
            }

            v2f vert(appdata v)
            {
                float3 objectPosition = v.vertex;
                objectPosition += v.normal * _HitForceMultiplier * GetHitColorFactor(objectPosition);

                v2f o;
                o.vertex = UnityObjectToClipPos(objectPosition);

                o.screenPos = ComputeScreenPos(o.vertex);

                // Fresnel UV (with scaling and scrolling)
                o.uv = TRANSFORM_TEX(v.uv, _FresnelTex);
                o.uv.x += _Time.x * _ScrollSpeedU;
                o.uv.y += _Time.x * _ScrollSpeedV;
                o.uv /= _WorldScaleFactor;

                // Original UV for independent distortion texture mapping
                o.uvOriginal = TRANSFORM_TEX(v.uv, _DistortionTex);

                o.objectPosition = objectPosition;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.viewDir = ObjSpaceViewDir(v.vertex);

                return o;
            }

            float GetGlowBorder(float4 viewPos)
            {
                float2 screenUV = viewPos.xy / _ScreenParams.xy;
                float screenDepth = Linear01Depth(tex2D(_CameraDepthTexture, screenUV));


                float diff = screenDepth - Linear01Depth(viewPos.z);

                float intersect = 1.0 - smoothstep(0, _ProjectionParams.w * _FadeLength, diff);

                return pow(intersect, _GlowColorIntensity);
            }

            fixed4 frag(v2f i, fixed face : VFACE) : SV_Target
            {
                #ifdef _ENABLE_HIDE_FRONT_FACE
                if(face > 0) discard;
                #endif

                #ifdef _ENABLE_HIDE_BACK_FACE
                if(face < 0) discard;
                #endif

                // Base Shield Color and Intersection Glow
                float glowBorder = GetGlowBorder(i.vertex);
                // Initialize color with base color blended with intersection glow color
                fixed4 col = fixed4(lerp(_Color.rgb, _GlowColor, glowBorder), saturate(glowBorder + _Color.a));

                // Hit Effect Factors
                float colorFactor = GetHitColorFactor(i.objectPosition);
                float alphaFactor = GetHitAlphaFactor(i.objectPosition);
                float finalFactor = saturate(colorFactor + alphaFactor);

                // Apply Hit Color (Additive Glow)
                col.rgb += _HitColorIntensity * _HitColor.rgb * finalFactor;
                // Apply Hit Hole Mask (Alpha Reduction)
                col.a *= 1.0 - saturate(alphaFactor * _HitAlfaIntensity);

                // - -- FRESNEL EFFECT START -- -

                // Fresnel Pattern Masking
                fixed4 fresnelTexture = tex2D(_FresnelTex, i.uv);
                float patternMask = fresnelTexture.r;
                // Apply pattern to the base shield color
                col.a *= patternMask;
                //
                // Fresnel Edge Glow
                float fresnel = dot(i.worldNormal, i.viewDir);
                fresnel = saturate(1 - fresnel);
                fresnel = pow(fresnel, _FresnelExponent);
                //
                // Calculate Fresnel Color, modulated by the pattern mask
                float3 fresnelColor = fresnel * patternMask * _FresnelColor;
                //
                // Add Fresnel Color to the total Emission color (reduced where hit is active)
                col.rgb += fresnelColor * (1.0 - finalFactor);
                //
                // - -- FRESNEL EFFECT END -- -

                // - -- DISTORTION EFFECT START -- -

                // Use i.uv for the distortion map, but apply a separate scroll rate for variety
                float2 distortionUV = i.uvOriginal;
                distortionUV += _Time.x * _DistortionScrollSpeed; // Add independent time - based scrolling

                // Sample the distortion texture (UnpackNormal assumes a normal map; remove UnpackNormal for a grayscale map)
                float3 distortionSample = UnpackNormal(tex2D(_DistortionTex, distortionUV)).rgb;

                // Calculate the offset vector
                float2 offset = (distortionSample.rg - 0.5) * _DistortionStrength;

                // Calculate screen UV coordinates
                float2 screenUV = i.screenPos.xy / i.screenPos.w;

                // Apply the distortion offset, scaled by screen texel size for screen - space movement
                float2 distortedUV = screenUV + offset * _CameraOpaqueTexture_TexelSize.xy * 2.0; // * 2.0 for a stronger visual effect

                // Sample the background from the camera opaque texture using the distorted UVs
                fixed4 background = tex2D(_CameraOpaqueTexture, distortedUV);

                #ifdef _ENABLE_LERP_DISTORTION
                col.rgb = lerp(background.rgb, col.rgb, col.a);
                #endif
                #ifdef _ENABLE_SUPERSEDED_DISTORTION
                col.rgb = background.rgb;
                #endif
                #ifdef _ENABLE_ADD_DISTORTION
                col.rgb += background.rgb;
                #endif

                // - -- DISTORTION EFFECT END -- -

                return col;
            }

            ENDCG
        }
    }
}