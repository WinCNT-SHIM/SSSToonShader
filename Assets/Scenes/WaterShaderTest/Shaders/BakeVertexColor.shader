Shader "DebugShader/BakeVertexColor"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _Roate ("Roate", float) = 0.0
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
                float2 UV           : TEXCOORD0;
                float4 vertexColor  : COLOR0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 UV           : TEXCOORD0;
                float4 vertexColor  : COLOR0;
                float3 positionOS   : TEXCOORD1;
            };

/// 変数
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

/// 定数変数（Constant Buffer）
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;     
                float _Roate;
            CBUFFER_END

///関数
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.UV = TRANSFORM_TEX(IN.UV, _MainTex);
                OUT.vertexColor = IN.vertexColor;
                
                float4 positionOS = IN.positionOS;
                
                // World Space Scale Matrix
                float4x4 scaleMatrix;
                float4 sx = float4(UNITY_MATRIX_M._m00, UNITY_MATRIX_M._m10, UNITY_MATRIX_M._m20, 0);
                float4 sy = float4(UNITY_MATRIX_M._m01, UNITY_MATRIX_M._m11, UNITY_MATRIX_M._m21, 0);
                float4 sz = float4(UNITY_MATRIX_M._m02, UNITY_MATRIX_M._m12, UNITY_MATRIX_M._m22, 0);
                float scaleX = length(sx);
                float scaleY = length(sy);
                float scaleZ = length(sz);
                scaleMatrix[0] = float4(scaleX, 0, 0, 0);
                scaleMatrix[1] = float4(0, scaleY, 0, 0);
                scaleMatrix[2] = float4(0, 0, scaleZ, 0);
                scaleMatrix[3] = float4(0, 0, 0, 1);

                scaleMatrix[0] = float4(1, 0, 0, 0);
                scaleMatrix[1] = float4(0, 1, 0, 0);
                scaleMatrix[2] = float4(0, 0, 1, 0);
                scaleMatrix[3] = float4(0, 0, 0, 1);

                // World Space Rotate Matrix
                float4x4 rotationMatrix;
                rotationMatrix[0] = float4(UNITY_MATRIX_M._m00 / scaleX, UNITY_MATRIX_M._m01 / scaleY, UNITY_MATRIX_M._m02 / scaleZ, 0);
                rotationMatrix[1] = float4(UNITY_MATRIX_M._m10 / scaleX, UNITY_MATRIX_M._m11 / scaleY, UNITY_MATRIX_M._m12 / scaleZ, 0);
                rotationMatrix[2] = float4(UNITY_MATRIX_M._m20 / scaleX, UNITY_MATRIX_M._m21 / scaleY, UNITY_MATRIX_M._m22 / scaleZ, 0);
                rotationMatrix[3] = float4(0, 0, 0, 1);

                // PlaneのUVに合わせるためY軸に180度回転
                float4x4 adjustRotate;
                adjustRotate[0] = float4(cos(PI),   0,      -sin(PI),   0);
                adjustRotate[1] = float4(0,         0,      0,          0);
                adjustRotate[2] = float4(sin(PI),   0,      cos(PI),    0);
                adjustRotate[3] = float4(0,         0,      0,          1);
                rotationMatrix = mul(rotationMatrix, adjustRotate);
                
                // World Space Translate Matrix
                float4x4 moveMatrix;
                moveMatrix[0] = float4(1, 0, 0, UNITY_MATRIX_M._m03);
                moveMatrix[1] = float4(0, 1, 0, UNITY_MATRIX_M._m13);
                moveMatrix[2] = float4(0, 0, 1, UNITY_MATRIX_M._m23);
                moveMatrix[3] = float4(0, 0, 0, UNITY_MATRIX_M._m33);
                
                float4x4 modelMatrix = mul(mul(moveMatrix, rotationMatrix), scaleMatrix);
                
                float4 positionWS = mul(modelMatrix, float4(positionOS.xyz, 1));
                float4 positionVS = mul(UNITY_MATRIX_V, positionWS);
                float4 positionCS = mul(UNITY_MATRIX_P, positionVS);
                OUT.positionHCS = positionCS;
                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 finalColor = 0.0;
                //color.rgb = pow(color.rgb, 1/2.2); // Gamma Correction
                
                finalColor = half4(IN.vertexColor);
                //finalColor = abs(finalColor);
                finalColor = (finalColor + 1.0f) * 0.5f;
                finalColor.a = 1.0f;
                
                //finalColor.rg = IN.UV;
                //finalColor.b = 0.0f;
                
                return finalColor;
            }
            ENDHLSL
        }
    }
}
