// Source : https://www.shadertoy.com/view/4scGWj
/* Simplex code license
 * This work is licensed under a 
 * Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License
 * http://creativecommons.org/licenses/by-nc-sa/3.0/
 *  - You must attribute the work in the source code 
 *    (link to https://www.shadertoy.com/view/XsX3zB).
 *  - You may not use this work for commercial purposes.
 *  - You may distribute a derivative work only under the same license.
 */
Shader "Example/LightningTest"
{
    Properties
    {
        _BaseMap("Albedo", 2D) = "white" {}
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType"="Transparent"
            "RenderPipeline"="UniversalPipeline"
        }

        Pass
        {
            //Blend One One
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

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.UV = IN.UV;
                return OUT;
            }

            float3 random3(float3 c)
            {
				float j = 4096.0*sin(dot(c,float3(17.0, 59.4, 15.0)));
				float3 r;
				r.z = frac(512.0*j);
				j *= .125;
				r.x = frac(512.0*j);
				j *= .125;
				r.y = frac(512.0*j);
				return r-0.5;
			}

			/* skew constants for 3d simplex functions */
			const float F3 =  0.3333333;
			const float G3 =  0.1666667;

			/* 3d simplex noise */
			float simplex3d(float3 p)
            {
				 /* calculate s and x */
				 float3 s = floor(p + dot(p, float3(F3, F3, F3)));
				 float3 x = p - s + dot(s, float3(G3, G3, G3));
				 
				 /* calculate i1 and i2 */
				 float3 e = step(float3(0.0, 0.0, 0.0), x - x.yzx);
				 float3 i1 = e*(1.0 - e.zxy);
				 float3 i2 = 1.0 - e.zxy*(1.0 - e);
	 				
				 /* x1, x2, x3 */
				 float3 x1 = x - i1 + G3;
				 float3 x2 = x - i2 + 2.0*G3;
				 float3 x3 = x - 1.0 + 3.0*G3;
				 
				 /* 2. find four surflets and store them in d */
				 float4 w, d;
				 
				 /* calculate surflet weights */
				 w.x = dot(x, x);
				 w.y = dot(x1, x1);
				 w.z = dot(x2, x2);
				 w.w = dot(x3, x3);
				 
				 /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
				 w = max(0.6 - w, 0.0);
				 
				 /* calculate surflet components */
				 d.x = dot(random3(s), x);
				 d.y = dot(random3(s + i1), x1);
				 d.z = dot(random3(s + i2), x2);
				 d.w = dot(random3(s + 1.0), x3);
				 
				 /* multiply d by w^4 */
				 w *= w;
				 w *= w;
				 d *= w;
				 
				 /* 3. return the sum of the four surflets */
				 return dot(d, float4(52.0, 52.0, 52.0, 52.0));
			}

			float noise(float3 m)
            {
			    return   0.5333333*simplex3d(m)
						+0.2666667*simplex3d(2.0*m)
						+0.1333333*simplex3d(4.0*m)
						+0.0666667*simplex3d(8.0*m);
			}
            
            // The fragment shader definition.
            half4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.UV;    
                uv = uv * 2. -1.;

                float2 p = IN.UV;
                
                float3 p3 = float3(p, _Time.y * 0.4);

                float intensity = noise(float3(p3*12.0+12.0));
                              
                float t = clamp((uv.x * -uv.x * 0.16) + 0.15, 0., 1.0);
                float y = abs(intensity * -t + uv.y);
                float g = pow(y, 0.2);
                
                float3 col = float3(1.70, 1.48, 1.78);
                //float3 col = float3(0.70, 0.48, 0.78);
                col = col * -g + col;
				col = col * col;
				col = col * col;
                
                half4 fragColor;
                fragColor.rgb = col;
                fragColor.w = 1.0;
                
                return fragColor;
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}