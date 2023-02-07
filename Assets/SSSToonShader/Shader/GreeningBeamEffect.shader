Shader "Example/GreeningBeamEffect"
{
    Properties
    {
        [Header(Texture)][Space(10)]
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        _BaseMap("Base Map", 2D) = "white" {}
        _MaskMap("Mask Map", 2D) = "white" {}
        
        [Header(Emissive)][Space(10)]
        [HDR]_EmissionColor("Emission Color", Color) = (1,1,1,1)
        _EmissionMap("Emission Map", 2D) = "white" {}
        
        [Header(Speed)][Space(10)]
        _SpeedX("Speed Axis X", float) = 0.0
        _SpeedY("Speed Axis Y", float) = 0.0
    }
    
    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType"="Transparent"
            "RenderPipeline"="UniversalPipeline"
        }

        Pass
        {
            Name "GreeningBeamEffect"

            Blend SrcAlpha DstAlpha
            ZWrite Off
            Cull Off
            
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag
            
            // 変数
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MaskMap);
            SAMPLER(sampler_MaskMap);
            TEXTURE2D(_EmissionMap);
            
            // 定数バッファー
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                float4 _EmissionMap_ST;
                half4 _EmissionColor;
                float _SpeedX;
                float _SpeedY;
            CBUFFER_END
            
            struct Attributes
            {
                float4 PositionOS   : POSITION;
                float2 UV           : TEXCOORD0;
                float2 MaskUV       : TEXCOORD1;
            };

            struct Varyings
            {
                float4 PositionHCS  : SV_POSITION;
                float2 UV           : TEXCOORD0;
                float2 MaskUV       : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                OUT.PositionHCS = TransformObjectToHClip(IN.PositionOS.xyz);

                // Base MapのTiling, Offsetを適用
                float2 _Tweak_UV = TRANSFORM_TEX(IN.UV, _BaseMap);
                // TimeによってUVをスクロールする（UVは0~1なので、小数点のみで加算する）
                _Tweak_UV.x += frac(_Time.y * _SpeedX);
                _Tweak_UV.y += frac(_Time.y * _SpeedY);

                // 調整したUVを渡す
                OUT.UV = _Tweak_UV;
                // Mask用MapのUVはそのままにする（Tiling, Offsetは無視）
                OUT.MaskUV = IN.UV;
                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 _FinalColor = half4(0.0, 0.0, 0.0, 1.0);
                // Base Mapのサンプリング
                const half4 _BaseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.UV);
                // Mask Mapのサンプリング
                const half4 _MaskVar = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, IN.MaskUV);
                // Emission Mapのサンプリング（UVはBase Mapと同様）
                const half4 _EmissionTex = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, IN.UV);

                // ビームのBase Color設定
                _FinalColor = _BaseTex * _BaseColor;
                // Emission適用
                _FinalColor += _EmissionTex * _EmissionColor;
                // Mask適用
                _FinalColor *= _MaskVar;
                
                return _FinalColor;
            }
            ENDHLSL
        }
    }
}