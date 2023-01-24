Shader "SSSToonShader/URPToonShaderBasic"
{
    Properties
    {
       _BaseMap ("BaseMap", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
    }
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or a pass is executed.
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Opaque"
        }
        
        Pass
        {
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM
            // 頂点シェーダの名前を定義する
            #pragma vertex vert
            // フラグメントシェーダーの名前を定義する
            #pragma fragment frag
            
            // The Core.hlsl file contains definitions of frequently used HLSL macros and functions,
            // and also contains #include references to other HLSL files
            // (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 normal       : TEXCOORD1;
                float3 lightDir     : TEXCOORD2;
            };

            // 変数
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            // Constant Buffer
            // SRP Batcher の互換性を確保するため、MaterialのすべてのPropertiesを単一の「CBUFFER」ブロック内で
            // 「UnityPerMaterial」という名前で宣言する必要がある（Texture, Samplerは除く）
            CBUFFER_START(UnityPerMaterial)
                // TilingとOffsetのためにTexture名_STの変数を宣言する
                float4 _BaseMap_ST;
                float4 _BaseColor;
                half _Var;
            CBUFFER_END

            //関数
            void BlackOffset(inout half3 color, in half var)
            {
                color -= var;
                color = saturate(color / (1 - var));
            }
            
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);    // TextureName + _ST
                OUT.normal = TransformObjectToWorldNormal(IN.normalOS);
                OUT.lightDir = normalize(_MainLightPosition.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Normal値の正規化
                IN.normal = normalize(IN.normal);
                
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                color *= _BaseColor;

                // N dot L
                float NdotL = saturate(dot(IN.normal, IN.lightDir));
                half3 ambient = SampleSH(IN.normal);    // SH == Spherical Harmonics
                half3 lighting = NdotL * _MainLightColor.rgb + ambient;
                color.rgb *= lighting;
                
                return color;
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
