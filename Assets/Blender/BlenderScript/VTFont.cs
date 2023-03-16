using System;
using UnityEngine;

public class VTFont : ScriptableObject
{
    public string Header;
    public int Version;
    public float LineHeight;
    public VTFont_Glyph[] Glyphs;
}

[Serializable]
public class VTFont_Glyph
{
    public char Character;
    public Vector2 Min;
    public Vector2 Max;
    public ushort[] Indices;
    public Vector4[] Verticles;
}