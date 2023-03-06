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
                //OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                //OUT.positionHCS.z = OUT.positionHCS.w;
                //OUT.positionHCS.xy = IN.positionOS.xy;
                //OUT.positionHCS.zw = IN.positionOS.zz;
                
                //OUT.UV = IN.UV;
                OUT.UV = TRANSFORM_TEX(IN.UV, _MainTex);
                
                OUT.vertexColor = IN.vertexColor;
                //OUT.positionOS = IN.positionOS.xyw;
                //const float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                //OUT.positionOS = ComputeScreenPos(OUT.positionHCS);


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

                // rotationMatrix[1][1] = cos(_Roate);
                // rotationMatrix[1][2] = -sin(_Roate);
                // rotationMatrix[2][1] = sin(_Roate);
                // rotationMatrix[2][2] = cos(_Roate);

                float4x4 moveMatrix;
                // World Space Translate Matrix
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
                half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.UV);
                color.rgb = pow(color.rgb, 1/2.2); // Gamma Correction
                finalColor.rgb = color.rgb;
                finalColor.a = 1.0f;
                //return finalColor;
                
                finalColor = half4(IN.vertexColor);
                finalColor = abs(finalColor);
                finalColor.a = 1.0f;
                return finalColor;

                finalColor.rgb = half3(0.0f, 0.0f, 0.0f);
                //float2 uv = IN.positionOS.xy / IN.positionOS.z * 0.5 + 0.5;
                //finalColor.rg = uv;
                
                // float2 pos;
                // pos = IN.UV;
                finalColor.rgb = half3(0.0f, 0.0f, 0.0f);
                finalColor.rg = IN.UV;
                
                finalColor.a = 1.0f;
                return finalColor;
            }
            ENDHLSL
        }
    }
}
