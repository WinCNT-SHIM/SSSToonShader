// https://light11.hatenadiary.com/entry/2021/08/03/202047
using System;
using UnityEngine;
using UnityEngine.Rendering;

[Serializable]
[VolumeComponentMenu("Custom Effect")]
public class CustomPostProcessVolume : VolumeComponent // VolumeComponentを継承する
{
    //public bool IsActive() => tintColor != Color.white;
    public bool IsActive()
    {
        return true;
    }


// Volumeコンポーネントで設定できる値にはXxxParameterクラスを使う
    //public ColorParameter tintColor = new ColorParameter(Color.white);
}