Shader "Sample/Math_of_Real-Time_Graphics/2_2_hash1d"
{
    Properties
    {
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Cull Off
            
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
            CBUFFER_END
            
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
                //OUT.UV.x += (_Time.y * 0.000075);
                //OUT.UV.y += (_Time.y * 0.000075);
                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 fragColor = half4(0, 0, 0, 1);

                float time = floor(_Time.y * 60.0);
                
                //float2 pos = IN.UV + time;
                float2 pos = IN.UV;
                //pos.x *= _ScreenParams.x;
                //pos.y *= _ScreenParams.y;
                
                fragColor.rgb = hash11(pos.x);
                fragColor.a = 1.0;
                
                return fragColor;
            }
            ENDHLSL
        }
    }
}