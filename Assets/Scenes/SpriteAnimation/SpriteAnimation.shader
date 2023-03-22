Shader "Example/SpriteAnimation"
{
    Properties
    {
        [HideInInspector] [MainColor] _BaseColor("Tint Color", Color) = (1,1,1,1)
        [HideInInspector] _SpriteSheet("Sprite Sheet", 2D) = "white" {}
        // セルの列数
        [HideInInspector] _Column("Column", int) = 1
        // セルの行数
	    [HideInInspector] _Row("Row", int) = 1
        // UV Edge Padding
        [HideInInspector] _Padding("UV Edge Padding", range(0.0, 1.0)) = 1.0
        // 現在再生しているインデクス
	    [HideInInspector] _PlayingIndex("Playing Index", int) = 1.0
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
            Name "SpriteAnimation"
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off
            
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag
            
            // 変数
            TEXTURE2D(_SpriteSheet);
            SAMPLER(sampler_SpriteSheet);
            
            // 定数バッファー
            CBUFFER_START(UnityPerMaterial)
                float4 _SpriteSheet_ST;
                float4 _SpriteSheet_TexelSize;
                half4 _BaseColor;

                uint _Row;
                uint _Column;
                uint _PlayingIndex;
            
                float _Padding;
            CBUFFER_END
            
            struct Attributes
            {
                float4 PositionOS   : POSITION;
                float2 UV           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 PositionHCS  : SV_POSITION;
                float2 UV           : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                OUT.PositionHCS = TransformObjectToHClip(IN.PositionOS.xyz);

                // 1つのセルのみ出るように調整
                const float2 col_row = float2(_Column, _Row);

                // UV Edge Padding
                const float2 max_col_row = float2(1.0, 1.0) / float2(_Column, _Row);
                float2 cell = IN.UV / col_row;
                cell = cell * (max_col_row - _SpriteSheet_TexelSize.xy * _Padding) / max_col_row;
                
                const uint index = _PlayingIndex;
                //列のインデックス
                uint column_index = index % _Column;
                //行のインデックス
                uint row_index = _Row - (index /_Column) % _Row - 1;

                // UV Edge Padding
                const float2 offset = (float2(column_index, row_index) / col_row) + (_SpriteSheet_TexelSize.xy * (0.5 * _Padding));
                
                OUT.UV = cell + offset;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                const half4 _BaseTex = SAMPLE_TEXTURE2D(_SpriteSheet, sampler_SpriteSheet, IN.UV);
                half4 _FinalColor = _BaseTex * _BaseColor;
                return _FinalColor;
            }
            ENDHLSL
        }
    }
}