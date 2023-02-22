Shader "DebugShader/Depth"
{
    Properties
    {
    }
    SubShader
    {
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION0;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 positionWS   : POSITION1;
                float2 uv           : TEXCOORD0;
            };

/// 変数
            //TEXTURE2D(_CameraDepthTexture);
            //SAMPLER(sampler_CameraDepthTexture);

/// 定数変数（Constant Buffer）
            CBUFFER_START(UnityPerMaterial)
            CBUFFER_END

///関数
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 深度バッファのサンプリング用の UV 座標を算出するために
                // ピクセル位置をレンダーターゲットの解像度(_ScaledScreenParams)で除算
                float2 UV = IN.positionHCS.xy / _ScaledScreenParams.xy;
                
                half4 finalColor;
                finalColor.rgb = 1.0 - IN.positionHCS.zzz;
                //finalColor.rgb = IN.positionHCS.zzz;
                finalColor.a = 1.0f;
                return finalColor;
                
                // カメラ深度テクスチャから深度をサンプリングします。
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(UV);
                #else
                    // Zを OpenGLの NDC([-1, 1])に一致するよう調整
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif
                finalColor.rgb = depth;

                // ファークリップ面の付近の色を黒に
                // 設定します。
                #if UNITY_REVERSED_Z
                    // D3DなどのREVERSED_Zがあるプラットフォームの場合
                    if(depth < 0.0001)
                        finalColor = half4(0,0,0,1);
                #else
                    // OpenGLなどのREVERSED_Zがないプラットフォームの場合
                    if(depth > 0.9999)
                        finalColor = half4(0,0,0,1);
                #endif
                
                return finalColor;
            }
            ENDHLSL
        }
    }
}
