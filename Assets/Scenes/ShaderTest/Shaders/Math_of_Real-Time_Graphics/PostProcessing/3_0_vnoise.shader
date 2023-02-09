Shader "Sample/Math_of_Real-Time_Graphics/3_0_vnoise"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Gray("Gray", Range(0,1)) = 1
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Cull Off
            ZWrite Off
            ZTest Always
            
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
                float4 _MainTex_ST;
                float _Gray;
            CBUFFER_END
//////////////////////////////////////////////////
/// 変数
//////////////////////////////////////////////////
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
//////////////////////////////////////////////////
/// 関数
//////////////////////////////////////////////////
            /// Hash化
            uint uhash11(uint n)
            {
                uint3 k = uint3(0x456789abu, 0x6789ab45u, 0x89ab4567u);
                uint3 u = uint3(1, 2, 3);
                
                n ^= (n << 1);
                n ^= (n >> 1);
                n *= k.x;
                n ^= (n << 1);
                return n * k.x;
            }
                
            uint2 uhash22(uint2 n)
            {
                uint3 k = uint3(0x456789abu, 0x6789ab45u, 0x89ab4567u);
                uint3 u = uint3(1, 2, 3);
                
                n ^= (n.yx << u.xy);
                n ^= (n.yx >> u.xy);
                n *= k.xy;
                n ^= (n.yx << u.xy);
                return n * k.xy;
            }
            uint3 uhash33(uint3 n)
            {
                uint3 k = uint3(0x456789abu, 0x6789ab45u, 0x89ab4567u);
                uint3 u = uint3(1, 2, 3);
                
                n ^= (n.yzx << u);
                n ^= (n.yzx >> u);
                n *= k;
                n ^= (n.yzx << u);
                return n * k;
            }

            
            float hash11(float p)
            {
                uint n = asuint(p);
                return float(uhash11(n) / float(UINT_MAX));
            }
            float2 hash22(float2 p){
                uint2 n = asuint(p);
                return float2(uhash22(n)) / UINT_MAX;
            }
            float3 hash33(float3 p){
                uint3 n = asuint(p);
                return float3(uhash33(n)) / UINT_MAX;
            }
            float hash21(float2 p){
                uint2 n = asuint(p);
                return float(uhash22(n).x) / float(UINT_MAX);
                //nesting approach
                //return float(uhash11(n.x+uhash11(n.y)) / float(UINT_MAX)
            }
            float hash31(float3 p){
                uint3 n = asuint(p);
                return float(uhash33(n).x) / float(UINT_MAX);
                //nesting approach
                //return float(uhash11(n.x+uhash11(n.y+uhash11(n.z))) / float(UINT_MAX)
            }

            /// 値ノイズ（Value-Noise）2 in, 1 out
            float vnoise21(float2 p)
            {
                float2 n = floor(p);
                float v[2][2];

                for(int j = 0; j < 2; j++)
                    for(int i = 0; i < 2; i++)
                        v[j][i] = hash21(n + float2(i,j));
                
                float2 f = frac(p);
                f = f * f * (3.f - 2.f * f); // エルミート補間

                return lerp(lerp(v[0][0], v[0][1], f[0]), lerp(v[1][0], v[1][1], f[0]), f[1]);
            }

            /// 値ノイズ（Value-Noise）3 in, 1 out
            float vnoise31(float3 p)
            {
                float3 n = floor(p);
                float v[2][2][2];
                
                for (int k = 0; k < 2; k++ )
                    for (int j = 0; j < 2; j++ )
                        for (int i = 0; i < 2; i++)
                            v[k][j][i] = hash31(n + float3(i, j, k));

                float3 f = frac(p);
                f = f * f * (3.0 - 2.0 * f); // Hermite interpolation
                float w[2];

                // 底面と上面での補間
                for (int i = 0; i < 2; i++)
                    w[i] = lerp(lerp(v[i][0][0], v[i][0][1], f[0]), lerp(v[i][1][0], v[i][1][1], f[0]), f[1]);

                // 底面と上面を高さで補間
                return lerp(w[0], w[1], f[2]);
            }

            /// 値ノイズ（Value-Noise）3 in, 3 out
            float3 vnoise33(float3 p)
            {
                float3 n = floor(p);
                float3 v[2][2][2];
                
                for (int k = 0; k < 2; k++ )
                    for (int j = 0; j < 2; j++ )
                        for (int i = 0; i < 2; i++)
                            v[k][j][i] = hash33(n + float3(i, j, k));

                float3 f = frac(p);
                //f = f * f * (3.0 - 2.0 * f); // Hermite interpolation
                float3 w[2];

                // 底面と上面での補間
                for (int i = 0; i < 2; i++)
                    w[i] = lerp(lerp(v[i][0][0], v[i][0][1], f[0]), lerp(v[i][1][0], v[i][1][1], f[0]), f[1]);

                // 底面と上面を高さで補間
                return lerp(w[0], w[1], f[2]);
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
                //float4 fMainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.UV);
                half4 fragColor = half4(0, 0, 0, 1);

                float time = _Time.y;
                float2 pos = IN.UV;
                pos = 10.0 * pos + time;    // [0,10]区間にスケールして移動
                
                //fragColor.rgb = vnoise21(pos);
                //fragColor.rgb = vnoise31(float3(pos, time));
                fragColor.rgb = vnoise33(float3(pos, time));
                
                fragColor.a = 1.0;
                return fragColor;
            }
            ENDHLSL
        }
    }
}