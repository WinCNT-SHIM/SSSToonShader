Shader "Sample/Math_of_Real-Time_Graphics/2_1_binary"
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
                half4 finalColor = half4(0, 0, 0, 1);
                
                float2 pos = IN.UV;
                pos *= float2(32.0, 9.0);


                uint a[9] = {
                    uint(_Time.y),
                    0xbu,
                    9u,
                    0xbu ^ 9u,
                    0xffffffffu,
                    0xffffffffu + uint(_Time.y),
                    asuint(floor(_Time.y)),
                    asuint(-floor(_Time.y)),
                    asuint(11.5625)
                };

                if (frac(pos.x) < 0.1) {
                    if (floor(pos.x) == 1.0) {
                        finalColor = float4(1.0, 0.0, 0.0, 1.0);
                    } else if (floor(pos.x) == 9.0) {
                        finalColor = float4(0.0, 1.0, 0.0, 1.0);
                    } else {
                        finalColor = float4(0.5, 0.5, 0.5, 1.0);
                    }
                } else if (frac(pos.y) < 0.1) {
                    finalColor = float4(0.5, 0.5, 0.5, 1.0);
                } else {
                    uint b = a[int(pos.y)]; 
                    b = (b << uint(pos.x)) >> 31;
                    finalColor = float4(float3(b, b, b), 1.0); 
                }
                
                return finalColor;
            }
            ENDHLSL
        }
    }
}