Shader "DebugShader/Gray"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
    }
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or a pass is executed.
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
        }
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };

/// 変数
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

/// 定数変数（Constant Buffer）
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
            CBUFFER_END

///関数
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 finalColor = 0.0;
                
                half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                //color.rgb = pow(color.rgb, 1/2.2);  // Gamma Correction
                //finalColor.rgb = color.rgb;
                //finalColor.rgb = dot(color.rgb, float3(0.3, 0.59, 0.11));
                //finalColor = color;
                finalColor = color * 2.0f - 1.0f;
                finalColor.a = color.a;
                //finalColor = abs(finalColor);
                finalColor.a = 1.0f;
                
                return finalColor;
            }
            ENDHLSL
        }
    }
}
