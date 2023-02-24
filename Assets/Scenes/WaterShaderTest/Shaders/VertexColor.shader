Shader "DebugShader/VertexColor"
{
    Properties
    {
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
                float4 vertexColor  : COLOR0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float4 vertexColor  : COLOR0;
            };

/// 変数

/// 定数変数（Constant Buffer）
            CBUFFER_START(UnityPerMaterial)
            CBUFFER_END

///関数
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.vertexColor = IN.vertexColor;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 finalColor = 0.0;
                finalColor = half4(IN.vertexColor);

                //float len = length(IN.vertexColor.rgb);
                //finalColor.rgb = len;
                
                finalColor.a = 1.0f;
                return finalColor;
            }
            ENDHLSL
        }
    }
}
