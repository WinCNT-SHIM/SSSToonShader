using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ImageEffectAllowedInSceneView] // シーンビューカメラにレンダリングを可能にする
[ExecuteInEditMode] // インスタンスをEdit Modeで実行（ゲームを実行しなくても適用できる）
[RequireComponent(typeof(Camera))]  // Componentを自動的に追加する
public class PostProcessingOnCamera : MonoBehaviour
{
    [SerializeField]
    private Material m_PostProcessingMat = null;

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (m_PostProcessingMat == null)
            return;
        
        // Material(にあるShader)を適用してRenderTargetをBlitする
        Graphics.Blit(src, dest, m_PostProcessingMat);
    }
}
