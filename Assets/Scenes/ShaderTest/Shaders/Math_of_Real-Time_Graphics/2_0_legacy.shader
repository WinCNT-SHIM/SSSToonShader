Shader "Sample/Math_of_Real-Time_Graphics/2_0_legacy"
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
/// 関数
//////////////////////////////////////////////////
            /// sinを使ったLegacy乱数生成関数
            /// 1 in, 1 out
            float fracSin11(float x)
            {
                return frac(1000.0 * sin(x));
            }
            
            /// sinを使ったLegacy乱数生成関数
            /// 1 in, 1 out
            float fracSin21(float2 xy)
            {
                return frac(sin(dot(xy, float2(12.9898, 78.233))) * 43758.5453123);
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
                float2 UV = IN.UV;
                half4 finalColor = half4(0, 0, 0, 1);
                
                int channel = int(UV.x * 2.0);
                UV += floor(_Time.y * 20.0);

                if (channel == 0)
                    finalColor = fracSin11(UV.x);
                else
                    finalColor = fracSin21(UV);
                                
                return finalColor;
            }
            ENDHLSL
        }
    }
}