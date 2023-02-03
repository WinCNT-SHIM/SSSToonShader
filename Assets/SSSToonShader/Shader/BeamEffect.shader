Shader "Example/BeamEffect"
{
    Properties
    {
        [Header(Texture)][Space(10)]
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        _BaseMap("Base Map", 2D) = "white" {}
        _MaskMap("Mask Map", 2D) = "white" {}
        
        [Header(Speed)][Space(10)]
        _SpeedX("Speed Axis X", float) = 0.0
        _SpeedY("Speed Axis Y", float) = 0.0
    }

    HLSLINCLUDE

    //Particle shaders rely on "write" to CB syntax which is not supported by DXC
    #pragma never_use_dxc

    ENDHLSL
    
    SubShader
    {
        Tags { "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "GreenBeamEffect"
            
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag
            
            // 変数
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MaskMap);
            SAMPLER(sampler_MaskMap);
            // 定数バッファー
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                //half4 _EmissionColor;
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

                float Time_Time = _Time.y;
                float Time_SineTime = _SinTime.w;
                float Time_CosineTime = _CosTime.w;
                float Time_DeltaTime = unity_DeltaTime.x;
                float Time_SmoothDelta = unity_DeltaTime.z;

                float2 _Tweak_UV = IN.UV;
                _Tweak_UV.x += _Time.y * _SpeedX;
                _Tweak_UV.y += _Time.y * _SpeedY;
                
                OUT.UV = TRANSFORM_TEX(_Tweak_UV, _BaseMap);
                OUT.MaskUV = IN.UV;
                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 _FinalColor = half4(0, 0, 0, 0);
                // Base Mapのサンプリング
                const half4 _TexColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.UV);
                // Mask Mapのサンプリング
                const half _MaskVar = SAMPLE_TEXTURE2D(_MaskMap, sampler_BaseMap, IN.MaskUV).r;

                
                _FinalColor = _TexColor * _BaseColor;
                _FinalColor *= _MaskVar;
                return _FinalColor;
            }
            ENDHLSL
        }
    }
}