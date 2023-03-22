using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Serialization;

public class SampleSpriteAnimationScript : MonoBehaviour
{
    public Color tintColor = Color.white;
    public Texture spriteSheet;
    public int column = 1;
    public int row = 1;
    public float fPS = 1.0f;
    [Range(0.0f, 1.0f)] public float uVEdgePadding = 1.0f;

    public bool playOnStart = false;
    public bool loop = true;
    public bool reverse = false;

    // 内部変数
    private int _maxFrameIndex = 0;
    private int _playingIndex = 0;
    private bool _isPlaying = false;
    private float _deltaTime = 0.0f;

    private MeshRenderer _spriteAnimationRenderer;
    private Material _spriteAnimationMaterial = null;

    // .shaderファイルのPropertyのIDを取得しておくための変数
    private int _propTintColor;
    private int _propSpriteSheet;
    private int _propColumn;
    private int _propRow;
    private int _propFps;
    private int _propPadding;
    private int _propPlayingIndex;

    // Start is called before the first frame update
    void Start()
    {
        _spriteAnimationRenderer = gameObject.GetComponent<MeshRenderer>();
        _spriteAnimationMaterial = _spriteAnimationRenderer.material;

        // サンプルのため、SpriteAnimationのシェーダーに切り替える
        // (最初からスクリプトとマテリアルを付けていたら特に何の処理もしない)
        var spriteAnimationShader = Shader.Find("Example/SpriteAnimation");
        if (_spriteAnimationRenderer.material.shader != spriteAnimationShader)
        {
            _spriteAnimationMaterial = new Material(spriteAnimationShader);
            _spriteAnimationRenderer.material = _spriteAnimationMaterial;
            Debug.Log("SpriteAnimationにシェーダーに切り替えました。");
        }
        
        // マテリアル（シェーダー）のPropertyのIDを取得する
        GetMaterialPropertyID();

        // マテリアル（シェーダー）のPropertyに値を設定する
        SetMaterialPropertyValue();
        
        // スプライトアニメーションの最大フレイム数を計算する（0からスタート）
        _maxFrameIndex = column * row - 1;
        
        // 再生モードになったらアニメーションを再生するフラグ
        if (playOnStart)
            _isPlaying = true;
    }

    // Update is called once per frame
    void Update()
    {
        // 再生するフレイムが最大フレイム数を超えた場合
        if (_maxFrameIndex < _playingIndex)
        {
            // Loopする場合は再生するフレイムを初期化する
            if (loop)
            {
                _isPlaying = true;
                _playingIndex = 0;
                
            }
            // Loopしない場合は再生フラグをOffにする
            else
            {
                _isPlaying = false;
                return;
            }
        }

        // 再生フラグがOffだったら、処理を行わない
        if (!_isPlaying)
            return;

        // スプライトシートの指定のインデクスを表示させる
        PlaySpriteAnimation(_playingIndex);

        if (_deltaTime < (1.0 / fPS))
        {
            _deltaTime += Time.deltaTime;
        }
        else
        {
            _deltaTime = 0.0f;
            _playingIndex++;
        }
    }

    void OnValidate()
    {
        SetMaterialPropertyValue();
    }

    public void PlayOrPause()
    {
        _isPlaying = !_isPlaying;
    }
    
    public void PlaySpriteAnimation(int playingIndex)
    {
        if (reverse)
        {
            _spriteAnimationMaterial.SetFloat(_propPlayingIndex, (_maxFrameIndex - playingIndex));
        }
        else
        {
            _spriteAnimationMaterial.SetFloat(_propPlayingIndex, playingIndex);
        }
    }

    private void GetMaterialPropertyID()
    {
        // マテリアル（シェーダー）のPropertyのID取得する
        _propTintColor = Shader.PropertyToID("_BaseColor");
        _propSpriteSheet = Shader.PropertyToID("_SpriteSheet");
        _propColumn = Shader.PropertyToID("_Column");
        _propRow = Shader.PropertyToID("_Row");
        _propFps = Shader.PropertyToID("_Fps");
        _propPadding = Shader.PropertyToID("_Padding");
        _propPlayingIndex = Shader.PropertyToID("_PlayingIndex");
    }

    /// <summary>
    /// マテリアル（シェーダー）のPropertyに値を設定する
    /// </summary>
    private void SetMaterialPropertyValue()
    {
        if (_spriteAnimationMaterial == null)
            return;
        
        _spriteAnimationMaterial.SetColor(_propTintColor, tintColor);
        _spriteAnimationMaterial.SetTexture(_propSpriteSheet, spriteSheet);
        _spriteAnimationMaterial.SetFloat(_propColumn, column);
        _spriteAnimationMaterial.SetFloat(_propRow, row);
        _spriteAnimationMaterial.SetFloat(_propFps, fPS);
        _spriteAnimationMaterial.SetFloat(_propPadding, uVEdgePadding);
        _spriteAnimationMaterial.SetFloat(_propPlayingIndex, _playingIndex);
    }
}


/// <summary>
/// コンポーネントにボタンを表示させるため、簡単に実装
/// </summary>
[CustomEditor(typeof(SampleSpriteAnimationScript))]
public class SampleSpriteAnimationScriptButton : Editor
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        SampleSpriteAnimationScript comp = (SampleSpriteAnimationScript)target;
        if (GUILayout.Button("Play/Pause"))
        {
            if (!Application.isPlaying)
            {
                bool res1 = EditorUtility.DisplayDialog("警告", "再生モードで実行してください。", "OK");
            }
            else
            {
                comp.PlayOrPause();
            }
        }
    }
}
