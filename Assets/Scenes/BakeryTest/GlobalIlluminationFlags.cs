using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GlobalIlluminationFlags : MonoBehaviour
{
    public MaterialGlobalIlluminationFlags flag = MaterialGlobalIlluminationFlags.AnyEmissive;

    void OnEnable()
    {
        SetFlags();
    }
    
    void OnValidate()
    {
        SetFlags();
    }

    private void SetFlags()
    {
        var rend = GetComponent<Renderer>();
        if (rend && rend.sharedMaterial)
        {
            rend.sharedMaterial.globalIlluminationFlags = flag;
        }
    }
}
