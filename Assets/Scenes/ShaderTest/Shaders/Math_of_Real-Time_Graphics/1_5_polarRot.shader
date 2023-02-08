Shader "Sample/Math_of_Real-Time_Graphics/1_5_polarRot"
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
            float atan2My(float y, float x)
            {
                if (x == 0.0)
                    return sign(y) * PI / 2.0;
                else
                    return atan2(y, x);
            }

            float2 xy2polar(float2 xy)
            {
                return float2(atan2(xy.y, xy.x), length(xy));
            }

            float2 polar2xy(float2 polar)
            {
                return polar.y * float2(cos(polar.x), sin(polar.x));
            }

            float3 tex(float2 st)   // s: 偏角, t: 動径
            {
                float time = _Time.y * 0.5;

                float3 circle = float3(0.5 * polar2xy(float2(time, 0.5)) + 0.5, 1.0);
                
                float3 col3[3] = 
                {
                    circle.rgb,
                    circle.gbr,
                    circle.brg
                };

                st.x = st.x / PI + 1.0;
                st.x += time;
                    
                int idx = int(st.x);
                
                float3 retCol = lerp(col3[idx % 2], col3[(idx + 1) % 2], frac(st.x));

                return lerp(col3[2], retCol, st.y);
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
                //UV.y = 1.0 - UV.y;
                //return float4(IN.UV, 0.0, 1.0);
                
                half4 finalColor = half4(0, 0, 0, 1);               

                UV = 2.0 * UV - 1.0;    // -1 ~ 1に変換
                UV = xy2polar(UV);

                finalColor.rgb = tex(UV);
                
                return finalColor;
            }
            ENDHLSL
        }
    }
}