Shader "Sample/Math_of_Real-Time_Graphics/2_2_hash1d_PP"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Gray("Gray", Range(0,1)) = 1
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Cull Off
            ZWrite Off
            ZTest Always
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 UV           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 UV           : TEXCOORD0;
            };
//////////////////////////////////////////////////
/// Constant Buffer
//////////////////////////////////////////////////
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _Gray;
            CBUFFER_END
//////////////////////////////////////////////////
/// 変数
//////////////////////////////////////////////////
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
//////////////////////////////////////////////////
/// 関数
//////////////////////////////////////////////////
            uint uhash11(uint n)
            {
                uint k = 0x456789abu;
                
                n ^= (n << 1);
                n ^= (n >> 1);
                n *= k;
                n ^= (n << 1);
                return n * k;
            }

            float hash11(float p)
            {
                uint n = asuint(p);
                return float(uhash11(n) / float(UINT_MAX));
            }

//////////////////////////////////////////////////
/// Vertext & Fragment Shader
//////////////////////////////////////////////////
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.UV = IN.UV;
                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //float4 fMainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.UV);
                
                half4 fragColor = half4(0, 0, 0, 1);
                
                float time = floor(_Time.y * 60.0);
                
                float2 pos = IN.UV;
                pos.x *= _ScreenParams.x;
                pos.y *= _ScreenParams.y;
                pos += time;
                
                fragColor.rgb = hash11(pos.x);
                fragColor.a = 1.0;
                
                return fragColor;
            }
            ENDHLSL
        }
    }
}