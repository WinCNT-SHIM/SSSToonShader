Shader "SSSToonShader/URPToonShaderBasic"
{
    Properties
    {
        [Header(Base)]
        _BaseMap ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        [Space(10)]
        _ShadowColor1 ("Shadow Color1", Color) = (1,1,1,1)
        _ShadowColor2 ("Shadow Color2", Color) = (1,1,1,1)
        _ShadowPower1 ("Shadow Power1", Range(0, 1.0)) = 0.5
        _ShadowPower2 ("Shadow Power2", Range(0, 1.0)) = 0
        
        [Space(10)][Header(Specular Light)]
        [HDR] _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        _SpecularPower ("Specular Power", Range(0, 1.0)) = 0.5
        
        [Space(10)][Header(Rim Light)]
        _RimColor ("Rim Color", Color) = (1,1,1,1)
        _RimPower ("Rim Power", Range(0, 1.0)) = 0.1
        _RimThreshold ("Rim Threshold", Range(0.0001, 1)) = 0.0001
        
        _RimHorizonOffset ("Rim Horizon Offset", Range(-1, 1)) = 0
        _RimVerticalOffset ("Rim Vertical Offset", Range(-1, 1)) = 0
        
        [Space(15)][Header(Emission)]
        [HDR] _EmissionColor ("EmissionColor", Color) = (0, 0, 0, 1)
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float2 lightmapUV   : TEXCOORD1;
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
            
                half4 _EmissionColor;
            
                half _ShadowPower1;     
                half _ShadowPower2;     
                half _SpecularPower;    
                half _RimPower;
                half _RimThreshold;
                half _RimHorizonOffset;
                half _RimVerticalOffset;
                //half _Padding4; // 72Byte?
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
                // 正規化
                IN.normal = normalize(IN.normal);
                IN.viewDir = normalize(IN.viewDir);

                // メインライト情報を取得
                Light _MainLight = GetMainLight();
                
                half4 _FinalColor = { 0.5, 0.5, 0.5, 1.0 }; // Grey
                _FinalColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);

/// Lighting
/// Three Tone Shading
                // Half Lambert
                const float _HalfLambert = 0.5 * dot(IN.normal, IN.lightDir) + 0.5;
                
                // エッジを柔らかくするための変数、とりあえず実数値（必要に応じてPropertyにする）
                const float  _ToonFeatherBaseTo1st = 0.0001; // Base Colorと1影のエッジ
                const float  _ToonFeather1stTo2nd = 0.0001;  // 1影、2影のエッジ
                // Mapで影の落ち具合を調整するための変数、とりあえず実数値（必要に応じてPropertyにする）
                const float3  _ShadowMap1st = { 1.0, 1.0, 1.0 };
                const float3  _ShadowMap2nd = { 1.0, 1.0, 1.0 };
                // システム陰影のレベル調整するための変数。デフォルトは0で、範囲は±0.5、（必要に応じてPropertyにする）
                const float _SysShadowsLevel = 0.0;

                // Base Colorと1影の境界を作るための閾値を計算する
                // ここでHalf-LambertをX軸にするStep(Smoothstep)のような形を作る
                const float _FinalShadowMask = saturate(
                    (
                        _ShadowPower1
                        - lerp(_HalfLambert, _HalfLambert * saturate(_SysShadowsLevel), _SysShadowsLevel) * _ShadowMap1st.r
                    )
                    / _ToonFeatherBaseTo1st
                );

                // Base Colorと1影と2影を決定する
                // １．まずは1影と2影を決める。
                // 　　上と同じくHalf-LambertをX軸にするStep(Smoothstep)のような形を作り、それを閾値として1影と2影をLerpさせる
                // ２．1影と2影の色が決まったら、Base Colorとそれを上で計算した閾値を利用してLerpさせる
                // 要するに、Half-Lambertの値が1(光を多く受ける)に近いほど、逆に閾値は0に(近く)なり、
                // Base Color => 1影 => 2影の色になる
                const float _Shadow1And2Mask = saturate((_ShadowPower2 - _HalfLambert * _ShadowMap2nd.r) / _ToonFeather1stTo2nd);
                
                const half4 _FinalBaseColor = lerp(
                    _BaseColor,
                    lerp(
                        _ShadowColor1,
                        _ShadowColor2,
                        _Shadow1And2Mask
                    ),
                    _FinalShadowMask
                );

                // Base Colorの設定
                _FinalColor.rgb = _FinalBaseColor.rgb;

/// Specular
                // Half-Angle Vector
                const float3 _HalfDir = normalize(IN.lightDir + IN.viewDir); 
                const float _HalfNdotH = 0.5 * dot(IN.normal, _HalfDir) + 0.5;
                
                // Specluarの境界をくっきりにするか、ぼやけるか決める変数（必要に応じてPropertyにする）
                // 0 : ぼやける, 1 : くっきり
                const bool _IsHighColorToSpecular = true;
                // Specular ColorにMain LightColorを混ぜるかを決める変数
                const bool _UseMainLightColorForSpec = true;
                // MapでSpecularを調整するための変数、とりあえず実数値（必要に応じてPropertyにする）
                const float3  _HighColorMaskMap = { 1.0, 1.0, 1.0 };

                // Half NdotHをX軸にしたStep(Smoothstep)のような形を作る
                // Half NdotHが1に(つまり、0度に)近くなるほど、正反対に近くなるため、Specularが強くなる
                // Specular Powerでどの角度で正反対にするかを調整できる
                const float _HighColorMask =
                    saturate(_HighColorMaskMap.g)
                    * lerp(
                        pow(abs(_HalfNdotH), exp2(lerp(11, 1, _SpecularPower))),    // Specluarの境界をぼやける
                        1.0 - step(_HalfNdotH, 1.0 - pow(_SpecularPower, 5)),       // Specluarの境界をくっきりにする
                        _IsHighColorToSpecular
                    );

                // 上で計算した閾値を使用し、Specular Colorを調整する(設定に応じてとMain Light Colorを混ぜる)
                const float3 _HighColorOnly = lerp(_SpecularColor.rgb, _SpecularColor.rgb * _MainLight.color.rgb, _UseMainLightColorForSpec) * _HighColorMask;
                
                // Base ColorにSpecularを足す
                half3 _FinalHighColor =
                    lerp(
                        saturate(_FinalBaseColor.rgb - _HighColorMask),
                        _FinalBaseColor.rgb,
                        lerp(0.0, 1.0, _IsHighColorToSpecular)
                    )
                    + _HighColorOnly.rgb;

                // Specularを足す
                _FinalColor.rgb += _FinalHighColor.rgb;
                
/// Rim Light
                // Rim ColorにMain LightColorを混ぜるかを決める変数（必要に応じてPropertyにする）
                const bool _UseRim = true;
                // Rim ColorにMain LightColorを混ぜるかを決める変数（必要に応じてPropertyにする）
                const bool _UseMainLightColorForRim = false;
                // MapでRim Lightを調整するための変数、とりあえず実数値（必要に応じてPropertyにする）
                const float3  _RimMaskMap = { 1.0, 1.0, 1.0 };
                // Rim Lightの境界をくっきりにするか、ぼやけるか決める変数（必要に応じてPropertyにする）
                // 0 : ぼやける, 1 : くっきり
                const float _RimFeatherOff = 0.0f;
                // システムリムライトのレベル調整するための変数。デフォルトは0で、範囲は±0.5、（必要に応じてPropertyにする）
                const float _SysRimMaskLevel = 0.0;
                // 光源方向リムマスクのレベルを調整するための変数。デフォルトは0で、範囲は±0.5、（必要に応じてPropertyにする）
                const float _SysLightDirMaskLevelForRim = 0.0;
                
                // Rim Lightの角度を調整する
                float3 _RimViewFix = IN.viewDir;
	            float3 _HorizonBias = UNITY_MATRIX_V[0].xyz;
	            float3 _VerticalBias = UNITY_MATRIX_V[1].xyz;
	            _RimViewFix = -_RimHorizonOffset  * _HorizonBias  + (1 - abs(_RimHorizonOffset))  * _RimViewFix;
	            _RimViewFix = -_RimVerticalOffset * _VerticalBias + (1 - abs(_RimVerticalOffset)) * _RimViewFix;
                
                // Rim Colorを調整する。
                _RimColor.rgb = lerp(_RimColor.rgb, _RimColor.rgb * _MainLight.color.rgb, _UseMainLightColorForRim);
                
                // （1.0 - NormalとViewを内積）で輪郭周りを抽出する
                float _RimDot = saturate(1.0 - dot(IN.normal, _RimViewFix));
                // Rim LightのPowerを調整する（マジックナンバーを使う）
                _RimPower = pow(abs(_RimDot), exp2(lerp(3.0, 0.0, _RimPower)));
                // Rim Lightをマスクする範囲を調整する
                float _RimInsideMask = saturate(lerp( (0.0 + ( (_RimPower - _RimThreshold) * (1.0 - 0.0) ) / (1.0 - _RimThreshold)), step(_RimThreshold, _RimPower), _RimFeatherOff ));
                
                // 閾値調整、RimThresholdが1の場合はRim Lightを消す
                _RimInsideMask = lerp(_RimInsideMask, 0.0, step(1.0, _RimThreshold));

                // Rim LightがHalf-Lambertによってマスクされるように調整する（つまり陰が強くなるほどRim Lightが弱くなる）
                const half3 _LightDirMaskOnForRim = _RimColor.rgb * saturate(_RimInsideMask - ((1.0 - _HalfLambert) + _SysLightDirMaskLevelForRim));
                
                // 最終的なRim Lightを計算する
                float3 _FinalRim = saturate((_RimMaskMap.g + _SysRimMaskLevel)) * _LightDirMaskOnForRim;

                // Rim Lightを足す
                _FinalColor.rgb = lerp(_FinalColor.rgb, (_FinalColor.rgb + _FinalRim.rgb), _UseRim);

/// Emission
                float3 emissive = _BaseColor.a * _EmissionColor.rgb;
                _FinalColor.rgb += emissive; 
                
                return _FinalColor;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "META"
            Tags {"LightMode"="Meta"}
            Cull Off
            
            HLSLPROGRAM
            #include"UnityStandardMeta.cginc"

            #pragma vertex vert_meta
            #pragma fragment frag_meta_Toon
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature ___ _DETAIL_MULX2

            CBUFFER_START(UnityPerMaterial)
            sampler2D _BaseMap;
            half4 _BaseColor;
            CBUFFER_END
            
            float4 frag_meta_Toon(v2f_meta i): SV_Target
            {
                UnityMetaInput o;
                UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);

                half4 c = tex2D(_BaseMap, i.uv);
                o.Albedo = half3(c.rgb * _BaseColor.rgb);
                //o.Emission = Emission(i.uv.xy);
                o.Emission = _EmissionColor;
                return UnityMetaFragment(o);
            }
            ENDHLSL
        }
        //UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
