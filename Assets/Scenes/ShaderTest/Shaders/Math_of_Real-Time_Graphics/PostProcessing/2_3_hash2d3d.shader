Shader "Sample/Math_of_Real-Time_Graphics/2_3_hash2d3d"
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

                //vec2 pos = fragCoord.xy + time;
                float time = floor(_Time.y * 60.0);
                uint2 pos;;
                pos.x = IN.UV.x * _ScreenParams.x;
                pos.y = IN.UV.y * _ScreenParams.y;
                pos += time;

                int2 channel = int2(IN.UV * 2.0);
                
                if (channel[0] == 0){ //left
                    if (channel[1] == 0){
                        fragColor.rgb = hash21(pos);
                    } else {
                        fragColor.rgb = float3(hash22(pos), 1.0);
                    }
                } else {    //right
                    if (channel[1] == 0){
                        fragColor.rgb = hash31(float3(pos, time));
                    } else {
                        fragColor.rgb = hash33(float3(pos, time));
                    }
                }
                fragColor.a = 1.0;
                return fragColor;
            }
            ENDHLSL
        }
    }
}