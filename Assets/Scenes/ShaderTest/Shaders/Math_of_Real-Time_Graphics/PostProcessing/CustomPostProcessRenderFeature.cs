//https://light11.hatenadiary.com/entry/2021/08/03/202047
using System;
using UnityEngine;
using UnityEngine.Rendering.Universal;

[Serializable]
public class CustomPostProcessRenderFeature : ScriptableRendererFeature
{
    [SerializeField] private Shader _shader;
    [SerializeField] private PostprocessTiming _timing = PostprocessTiming.AfterOpaque;
    [SerializeField] private bool _applyToSceneView = true;

    private CustomPostProcessRenderPass _postProcessPass;

    public override void Create()
    {
        _postProcessPass = new CustomPostProcessRenderPass(_applyToSceneView, _shader);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        _postProcessPass.Setup(renderer.cameraColorTarget, _timing);
        renderer.EnqueuePass(_postProcessPass);
    }
}