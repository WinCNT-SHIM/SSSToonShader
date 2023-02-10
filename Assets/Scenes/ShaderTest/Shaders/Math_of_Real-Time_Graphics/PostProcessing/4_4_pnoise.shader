Shader "Sample/Math_of_Real-Time_Graphics/4_4_pnoise"
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
                //f = f * f * (3.f - 2.f * f); // エルミート補間
                f = f * f * f * (10.0 - 15.0 * f + 6.0 * f * f); //quintic Hermite interpolation

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

            /// Gradient
            float2 grad(float2 p)
            {
                float eps = 0.001;
                return 0.5 * (float2(
                        vnoise21(p + float2(eps, 0.0)) - vnoise21(p - float2(eps, 0.0)),
                        vnoise21(p + float2(0.0, eps)) - vnoise21(p - float2(0.0, eps))
                )) / eps;
            }
            
            /// returns 3D value noise and its 3 derivatives
            float4 noised(float3 x)
            {
                float3 p = floor(x);
                float3 w = frac(x);

                float3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
                float3 du = 30.0*w*w*(w*(w-2.0)+1.0);

                float a = hash31( p+float3(0,0,0) );
                float b = hash31( p+float3(1,0,0) );
                float c = hash31( p+float3(0,1,0) );
                float d = hash31( p+float3(1,1,0) );
                float e = hash31( p+float3(0,0,1) );
                float f = hash31( p+float3(1,0,1) );
                float g = hash31( p+float3(0,1,1) );
                float h = hash31( p+float3(1,1,1) );

                float k0 =   a;
                float k1 =   b - a;
                float k2 =   c - a;
                float k3 =   e - a;
                float k4 =   a - b - c + d;
                float k5 =   a - c - e + g;
                float k6 =   a - b - e + f;
                float k7 = - a + b + c - d + e - f - g + h;

                return float4(
                    -1.0+2.0*(k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z),
                    2.0* du * float3(
                        k1 + k4*u.y + k6*u.z + k7*u.y*u.z,
                        k2 + k5*u.z + k4*u.x + k7*u.z*u.x,
                        k3 + k6*u.x + k5*u.y + k7*u.x*u.y )
                    );
            }

            
            /// 勾配ノイズ（Gradient-Noise）2 in, 1 out
            float gnoise21(float2 p)
            {
                float2 n = floor(p);
                float2 f = frac(p);
                float v[2][2];

                for(int j = 0; j < 2; j++)
                    for(int i = 0; i < 2; i++)
                    {
                        float2 g = normalize(2.0 * hash22(n + float2(i,j)) - 1.0f);
                        v[j][i] = dot(g, f - float2(i,j));
                    }
                //f = f * f * (3.f - 2.f * f); // エルミート補間
                f = f * f * f * (10.0 - 15.0 * f + 6.0 * f * f); //quintic Hermite interpolation

                return 0.5 * lerp(lerp(v[0][0], v[0][1], f[0]), lerp(v[1][0], v[1][1], f[0]), f[1]) + 0.5;
            }
            /// 勾配ノイズ（Gradient-Noise）3 in, 1 out
            float gnoise31(float3 p)
            {
                float3 n = floor(p);
                float3 f = frac(p);
                float v[2][2][2];
                
                for (int k = 0; k < 2; k++ )
                    for (int j = 0; j < 2; j++ )
                        for (int i = 0; i < 2; i++)
                        {
                            float3 g = normalize(2.0 * hash33(n + float3(i,j,k)) - 1.0f);
                            v[k][j][i] = dot(g, f - float3(i,j,k));
                        }

                //f = f * f * (3.0 - 2.0 * f); // Hermite interpolation
                f = f * f * f * (10.0 - 15.0 * f + 6.0 * f * f); //quintic Hermite interpolation
                
                float w[2];
                // 底面と上面での補間
                for (int i = 0; i < 2; i++)
                    w[i] = lerp(lerp(v[i][0][0], v[i][0][1], f[0]), lerp(v[i][1][0], v[i][1][1], f[0]), f[1]);

                // 底面と上面を高さで補間
                return 0.5 * lerp(w[0], w[1], f[2]) + 0.5;
            }

            //begin rot
            float2 rot2(float2 p, float t)
            {
                t *= PI;
                return float2(cos(t) * p.x -sin(t) * p.y, sin(t) * p.x + cos(t) * p.y);
            }
            float3 rotX(float3 p, float t)
            {
                return float3(p.x, rot2(p.yz, t));
            }
            float3 rotY(float3 p, float t)
            {
                return float3(p.y, rot2(p.zx, t)).zxy;
            }
            float3 rotZ(float3 p, float t)
            {
                return float3(rot2(p.xy, t), p.z);
            }
            //end rot

            float rotNoise21(float2 p, float ang){
                float2 n = floor(p);
                float2 f = frac(p);
                float v[2][2];

                for(int j = 0; j < 2; j++)
                    for(int i = 0; i < 2; i++)
                    {
                        float2 g = normalize(2.0 * hash22(n + float2(i,j)) - 1.0f);
                        g = rot2(g, ang);
                        v[j][i] = dot(g, f - float2(i,j));
                    }
                
                f = f * f * f * (10.0 - 15.0 * f + 6.0 * f * f);
                return 0.5 * lerp(lerp(v[0][0], v[0][1], f[0]), lerp(v[1][0], v[1][1], f[0]), f[1]) + 0.5;
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

                float2 pos;
                pos.x = IN.UV.x * _ScreenParams.x / min(_ScreenParams.x, _ScreenParams.y);
                pos.y = IN.UV.y * _ScreenParams.y / min(_ScreenParams.x, _ScreenParams.y);
                //pos = IN.UV;
                
                int channel = int(IN.UV.x * 2.0);
                
                pos = 10.0 * pos + time;    // [0,10]区間にスケールして移動
                
                //fragColor.rgb = vnoise21(pos);
                //fragColor.rgb = vnoise31(float3(pos, time));
                //fragColor.rgb = vnoise33(float3(pos, time));
                //fragColor.rgb = dot(float2(1.0, 1.0), grad(pos));
                //fragColor.rgb = noised(float3(pos, time)).x;
                //fragColor.rgb = gnoise21(pos);
                //fragColor.rgb = vnoise21(pos);

                if(channel < 1)//left
                {
                    //fragColor = gnoise21(pos);
                    fragColor = gnoise31(float3(pos, time));
                }
                else
                {
                    //fragColor = gnoise31(float3(pos, time));
                    fragColor = rotNoise21(pos, time);                    
                }
                
                fragColor.a = 1.0;
                return fragColor;
            }
            ENDHLSL
        }
    }
}