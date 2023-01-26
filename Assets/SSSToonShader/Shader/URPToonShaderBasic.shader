Shader "SSSToonShader/URPToonShaderBasic"
{
    Properties
    {
        _BaseMap ("BaseMap", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
        
        _ShadowColor ("ShadowColor", Float ) = 0
        _ShadowColor1 ("ShadowColor1", Color) = (1,1,1,1)
        _ShadowColor2 ("ShadowColor2", Color) = (1,1,1,1)
        _ShadowPower1 ("ShadowPower1", Range(0, 1.0)) = 0.5
        _ShadowPower2 ("ShadowPower2", Range(0, 1.0)) = 0
        
        [HDR] _SpecularColor ("SpecularColor", Color) = (1,1,1,1)
        _SpecularPower ("SpecularPower", Float) = 10.0
        
        _RimColor ("RimColor", Color) = (1,1,1,1)
        _RimPower ("RimPower", Range(0, 1.0)) = 0.7
        _RimThreshold ("RimThreshold", Range(0, 1.0)) = 0.1
    }
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or a pass is executed.
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Opaque"
        }
        
        Pass
        {
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM
            // 頂点シェーダの名前を定義する
            #pragma vertex vert
            // フラグメントシェーダーの名前を定義する
            #pragma fragment frag
            
            // The Core.hlsl file contains definitions of frequently used HLSL macros and functions,
            // and also contains #include references to other HLSL files
            // (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 normal       : TEXCOORD1;
                float3 lightDir     : TEXCOORD2;
                float3 viewDir      : TEXCOORD3;
            };

/// 変数
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            //UNITY_LIGHT_ATTENUATION(Attn);

/// 定数変数（Constant Buffer）
            // SRP Batcher の互換性を確保するため、MaterialのすべてのPropertiesを単一の「CBUFFER」ブロック内で
            // 「UnityPerMaterial」という名前で宣言する必要がある（Texture, Samplerは除く）
            CBUFFER_START(UnityPerMaterial)
                // TilingとOffsetのためにTexture名_STの変数を宣言する
                float4 _BaseMap_ST;
                //float4 _ShadowMap_1st_ST;
            
                half4 _BaseColor;
                half4 _ShadowColor1;
                half4 _ShadowColor2;
                half4 _SpecularColor;
                half4 _RimColor;

                half _ShadowPower1;     
                half _ShadowPower2;     
                half _SpecularPower;    
                half _RimPower;
                half _RimThreshold;
                half _Padding2; // 68Byte?
                half _Padding3; // 70Byte?
                half _Padding4; // 72Byte?
            CBUFFER_END

///関数
            void BlackOffset(inout half3 color, in half var)
            {
                color -= var;
                color = saturate(color / (1 - var));
            }
            
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);    // TextureName + _ST
                OUT.normal = TransformObjectToWorldNormal(IN.normalOS);
                OUT.lightDir = normalize(_MainLightPosition.xyz);
                
                const float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.viewDir = normalize(_WorldSpaceCameraPos.xyz - positionWS);
                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Normal値の正規化
                IN.normal = normalize(IN.normal);
                
                half4 finalColor = { 0.5, 0.5, 0.5, 1.0 };
                finalColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);

/// Lighting
/// Three Tone Shading
                // Half Lambert
                float halfLambert = 0.5 * dot(IN.normal, IN.lightDir) + 0.5;
                
                // エッジを柔らかくするための変数、とりあえず実数値（必要に応じてPropertyにする）
                const float  _ToonFeather_BaseAnd1st = 0.0001; // Base Colorと1影のエッジ
                const float  _ToonFeather_1stAnd2nd = 0.0001;  // 1影、2影のエッジ
                // Mapで影の落ち具合を調整するための変数、とりあえず実数値（必要に応じてPropertyにする）
                const float3  _ShadowMap_1st = { 1.0, 1.0, 1.0 };
                const float3  _ShadowMap_2nd = { 1.0, 1.0, 1.0 };

                // システムシャドウのレベル調整するための変数（デフォルトは0で、±0.5の範囲）
                // 必要に応じてPropertyにする
                const float _SystemShadowsLevel_var = 0.0;

                // Base Colorと1影の境界を作るための閾値を計算する
                // ここでHalf-LambertをX軸にするStep(Smoothstep)のような形を作る
                const float _FinalShadowMask = saturate(
                    1.0
                    + (
                        (lerp(halfLambert, halfLambert * saturate(_SystemShadowsLevel_var), _SystemShadowsLevel_var) - (_ShadowPower1 - _ToonFeather_BaseAnd1st))
                        * ((1.0 - _ShadowMap_1st.rgb).r - 1.0)
                    )
                    / _ToonFeather_BaseAnd1st
                );

                // Base Colorと1影と2影を決定する
                // １．まずは1影と2影を決める。
                // 　　上と同じくHalf-LambertをX軸にするStep(Smoothstep)のような形を作り、それを閾値として1影と2影をLerpさせる
                // ２．1影と2影の色が決まったら、Base Colorとそれを上で計算した閾値を利用してLerpさせる
                // 要するに、Half-Lambertの値が1(光を多く受ける)に近いほど、逆に閾値は0に(近く)なり、
                // Base Color => 1影 => 2影の色になる    
                const half4 _FinalBaseColor = lerp(
                    _BaseColor,
                    lerp(
                        _ShadowColor1,
                        _ShadowColor2,
                        saturate(
                            1.0
                            + ((halfLambert - (_ShadowPower2 -_ToonFeather_1stAnd2nd)) * ((1.0 - _ShadowMap_2nd.rgb).r - 1.0))
                            / _ToonFeather_1stAnd2nd
                        )
                    ),
                    _FinalShadowMask
                );
                
                finalColor.rgb = _FinalBaseColor.rgb;

/// Specular
                // Tutorial
                float specularIntensity = pow(halfLambert, _SpecularPower);
                specularIntensity  = smoothstep(0.005, 0.01, specularIntensity);
                
                finalColor.rgb += (_SpecularColor * specularIntensity).rgb;

/// Rim Light
                // Tutorial
                _RimPower = 1 - _RimPower;
                float rimDot = 1 - dot(IN.normal, IN.viewDir);
                float rimIntensity = rimDot * pow(halfLambert, _RimThreshold);
                rimIntensity = smoothstep(_RimPower - 0.01, _RimPower + 0.01, rimIntensity);
                float4 rim = rimIntensity * _RimColor;
                finalColor += rim;
                
                return finalColor;
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
