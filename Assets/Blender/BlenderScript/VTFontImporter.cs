using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor.AssetImporters;
using UnityEngine;

[ScriptedImporter(1, "vtff")]
public class VTFontImporter : ScriptedImporter
{
    public override void OnImportAsset(AssetImportContext ctx)
    {
        using var fs = new FileStream(ctx.assetPath, FileMode.Open);
        using var reader = new BinaryReader(fs);
        var font = ScriptableObject.CreateInstance<VTFont>();
        font.Header = new string(reader.ReadChars(4));
        font.Version = reader.ReadUInt16();
        var glyphCount = reader.ReadUInt16();
        Debug.Log(glyphCount);
        var glyphs = new List<VTFont_Glyph>(glyphCount);
        var sizes = new List<uint>();
        for (var i = 0; i < glyphCount; i++)
        {
            var start = reader.ReadUInt32();
            var end = reader.ReadUInt32();
            sizes.Add(end - start);
        }

        Debug.Log(reader.BaseStream.Position);
        for (var i = 0; i < glyphCount; i++)
        {
            if (sizes[i] == 0)
            {
                continue;
            }

            var glyph = new VTFont_Glyph();
            glyph.Character = (char) reader.ReadUInt16();
            glyph.Min = new Vector2(
                reader.ReadSingle(),
                reader.ReadSingle()
            );
            glyph.Max = new Vector2(
                reader.ReadSingle(),
                reader.ReadSingle()
            );
            var indexCount = reader.ReadUInt16();
            glyph.Indices = Enumerable.Range(0, indexCount).Select((_) => reader.ReadUInt16()).ToArray();
            // vertexには３つの情報（字体モデルデータのx座標、y座標、Outline用角度）があるため、３で割る
            var vertexCount = (int) reader.ReadUInt16() / 3;
            glyph.Verticles = Enumerable.Range(0, vertexCount).Select((_) =>
            {
                var pos = Vector2.Scale(
                    new Vector2(
                        reader.ReadUInt16(),    // 字体モデルデータのx座標
                        reader.ReadUInt16()     // 字体モデルデータのy座標
                    ),
                    (glyph.Max - glyph.Min) / ushort.MaxValue) + glyph.Min;

                // Outline用角度を取得する
                var radAngle = reader.ReadUInt16() * (2 * Mathf.PI) / ushort.MaxValue;
                
                return new Vector4(pos.x, pos.y, radAngle, 0);
            }).ToArray();

            for (var i1 = 0; i1 < glyph.Verticles.Length; i1++)
            {
                var vert = glyph.Verticles[i1];

                var normals = new List<Vector2>();
                foreach (var values in glyph.Indices.Select((v, i) => (v, i)).GroupBy(v => v.i / 3))
                {
                    if (values.All(v => v.v != i1))
                    {
                        continue;
                    }

                    var vs = values.Where(v => v.v != i1);
                    var v1p = glyph.Verticles[vs.ElementAt(0).v];
                    var v2p = glyph.Verticles[vs.ElementAt(1).v];
                    normals.Add(new Vector2(vert.x - v1p.x, vert.y - v1p.y) + new Vector2(vert.x - v2p.x, vert.y - v2p.y));
                }

                if (normals.Count > 0)
                {
                    //vert.z = normals.Average(v => v.x);
                    //vert.w = normals.Average(v => v.y);
                    glyph.Verticles[i1] = vert;
                }
            }

            glyphs.Add(glyph);
        }
        font.Glyphs = glyphs.ToArray();
        font.LineHeight = glyphs.Select(glyph => glyph.Max.y - glyph.Min.y).Max() * 1.5f;

        ctx.AddObjectToAsset("Main", font);
        ctx.SetMainObject(font);
    }
}