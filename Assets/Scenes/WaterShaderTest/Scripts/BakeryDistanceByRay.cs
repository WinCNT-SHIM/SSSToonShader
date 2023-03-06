using System;
using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEditor;
using UnityEngine.Windows;
using UnityEngine.Rendering;

public class BakeryDistanceByRay : MonoBehaviour
{
#region Properties
    [SerializeField] [Range(0.001f, 1.0f)] [Tooltip("ここで設定した長さのRayを各頂点から飛ばします。")]
    private float maxDistance = 1.0f;
    [SerializeField] [Tooltip("各頂点から飛ばすRayをDebug用として描画します。")]
    private bool drawDebugRay = false;
    
    [SerializeField] [Tooltip("Bakeした結果を保存するテクスチャのサイズを設定します（横縦比１：１）")]
    private int textureSize = 2048;
    [SerializeField] [Tooltip("テクスチャの保存先を設定します。")]
    private string directoryPath = "";
    [SerializeField] [Tooltip("保存するテクスチャのファイル名を設定します。")]
    private string fileName = "BakeResult";
    [SerializeField] [Tooltip("Bakeテクスチャ作成時に使うShaderを設定します。")]
    private Shader bakeShader;
#endregion

#region Variables
    // 処理時間測定用変数
    private System.Diagnostics.Stopwatch watch;
    // 距離を取る方向を格納する変数
    private List<Vector3> _offsetVector = new List<Vector3>();
    // デプスの距離を取る方向を格納する変数
    private List<Vector3> _offsetVectorDepthDist = new List<Vector3>();
    // GameObjectに付いているCollider(一応ない想定)
    private Collider _attachedCollider;
    // 距離を測るために一時手kにつけたColliderのリスト
    private List<Collider> _temporaryColliderList;
    // GameObjectのMeshの情報
    private Mesh mesh;
    // Texture作成用カメラ
    private Camera cameraForBake;
    // Bakeボタンのフラグ用変数
    private bool isClickedBakeButton;
    // Mesh(のGameObject)に設定されたLayer（処理中一時的に変更し戻すための変数）
    private int preMeshLayer;
    // Mesh(のGameObject)に設定されたMaterial（処理中一時的に変更し戻すための変数）
    private Material preMaterial;
    #endregion

    public void Bake()
    {
        isClickedBakeButton = true;
        
        Debug.Log("Bake処理開始！");
        // 処理時間測定
        watch = new System.Diagnostics.Stopwatch();
        watch.Start();
        
        // 初期化
        Initialize();
        
        // GameObjectのMeshの情報を取得する
        mesh = GetComponent<MeshFilter>().sharedMesh;
        if (mesh == null)
            return;
        
        // GameObjectのMeshの頂点情報(位置)を取得する
        Vector3[] vertices = mesh.vertices;
        for (int i = 0; i < vertices.Length; i++)
            vertices[i] = transform.localToWorldMatrix.MultiplyPoint(vertices[i]);
        
        // カメラの作成時に使うため、水のPlaneの頂点をサイズを取得する
        Bounds bounds = mesh.bounds;

        // Rayとの衝突を測るためにその他GameObjectにColliderを付ける
        AttachColliderToOthers();
        
        // 頂点を位置からRayを飛ばしてその他GameObjectとの距離を計算する
        var finalVertexColor = ComputeDistanceToOthers(ref vertices);

        // Vertex Colorを更新する
        mesh.SetColors(finalVertexColor);

        // 後片付け
        Finish();
        
        // 処理時間測定
        Debug.Log("Bake処理終了！全体の処理時間：" + watch.ElapsedMilliseconds + " ms");
        
        //////////////////////////////////////////////////
        // Texture保存
        //////////////////////////////////////////////////
        Debug.Log("Texture保存処理開始！");
        
        // Texture作成用カメラを生成する
        CreateCameraForBake(bounds);
        
        // 実際にカメラの映像を保存する処理はカメラのレンダリング後に行う
        //（正確にいうとOnEndCameraRendering()というメソッドで行っている）
    }

#region Rayを飛ばして距離を測り、頂点カラーに格納する処理に関連するメソッド
/// <summary>
    /// 処理の初期化
    /// </summary>
    private void Initialize()
    {
        // もしGameObjectにColliderがあったら一時的非活性化する（ない想定）
        _attachedCollider = gameObject.GetComponent<Collider>();
        SwitchOwnCollider(false);
        
        // 距離を取る方向を計算（上下の距離はスキップし、平面上の距離だけ計算する）
        _offsetVector.Add(new Vector3(-1.0f, 0.0f, +0.0f).normalized);
        _offsetVector.Add(new Vector3(-1.0f, 0.0f, +1.0f).normalized);
        _offsetVector.Add(new Vector3(+0.0f, 0.0f, +1.0f).normalized);
        _offsetVector.Add(new Vector3(+1.0f, 0.0f, +1.0f).normalized);
        _offsetVector.Add(new Vector3(+1.0f, 0.0f, +0.0f).normalized);
        _offsetVector.Add(new Vector3(+1.0f, 0.0f, -1.0f).normalized);
        _offsetVector.Add(new Vector3(+0.0f, 0.0f, -1.0f).normalized);
        _offsetVector.Add(new Vector3(-1.0f, 0.0f, -1.0f).normalized);
        
        _offsetVector.Add(new Vector3(-1.0f, 0.0f, +0.5f).normalized);
        _offsetVector.Add(new Vector3(-0.5f, 0.0f, +1.0f).normalized);
        _offsetVector.Add(new Vector3(+0.5f, 0.0f, +1.0f).normalized);
        _offsetVector.Add(new Vector3(+1.0f, 0.0f, +0.5f).normalized);
        _offsetVector.Add(new Vector3(+1.0f, 0.0f, -0.5f).normalized);
        _offsetVector.Add(new Vector3(+0.5f, 0.0f, -1.0f).normalized);
        _offsetVector.Add(new Vector3(-0.5f, 0.0f, -1.0f).normalized);
        _offsetVector.Add(new Vector3(-1.0f, 0.0f, -0.5f).normalized);

        // 距離を測るために一時手kにつけたColliderのリスト
        _temporaryColliderList = new List<Collider>();
    }

    /// <summary>
    /// 処理の最後
    /// </summary>
    private void Finish()
    {
        DetachColliderToOthers();
        _temporaryColliderList.Clear();
        SwitchOwnCollider(true);
    }

    /// <summary>
    /// GameObjectに付いているColliderをOn/Offにする
    /// </summary>
    private void SwitchOwnCollider(bool switchOnOff)
    {
        if (_attachedCollider != null)
            _attachedCollider.enabled = switchOnOff;
    }

    /// <summary>
    /// 同じRootにあるGameObjectにColliderを付ける（すでについている場合を除く）
    /// </summary>
    private void AttachColliderToOthers()
    {
        var parentGameObj = transform.parent;
        for (int i = 0; i < parentGameObj.childCount; i++)
        {
            if (gameObject.transform == parentGameObj.GetChild(i))
                continue;

            var othGameObj = parentGameObj.GetChild(i).gameObject;
            // 距離を計算するGameObjectにColliderが付いているかをチェックする
            if (othGameObj.GetComponent<Collider>() == null)
            {
                // Colliderがない場合はMeshColliderを付ける（最後に削除する予定）
                var comp = othGameObj.AddComponent<MeshCollider>();
                _temporaryColliderList.Add(comp);
            }
        }
    }
    
    /// <summary>
    /// 頂点から他のオブジェクトの頂点への距離を計算し、頂点カラーに格納して返却する
    /// </summary>
    /// <param name="vertices">距離を計算する頂点</param>
    /// <returns>距離を格納した頂点カラー</returns>
    private Color[] ComputeDistanceToOthers(ref Vector3[] vertices)
    {
        Vector4[] tmpDistance = new Vector4[vertices.Length];
        for (int i = 0; i < tmpDistance.Length; i++)
            tmpDistance[i] = new Vector4(0.0f, 0.0f, 0.0f, 0.0f);
        
        for (int i = 0; i < vertices.Length; i++)
        {
            // x, y, zには衝突した表面の法線を足して最後に正規化する。wは衝突時の距離（近いほど、値を１にする）を格納する。
            Vector3 targetVertex = vertices[i];

            foreach (var forward in _offsetVector)
            {
                // デバッグ用のRayを描画する
                if (drawDebugRay)
                    Debug.DrawRay(targetVertex, forward * maxDistance, Color.red, 2.0f);
                
                // Rayを飛ばし衝突したものがあるかチェック
                bool isCollision = Physics.Raycast(targetVertex, forward, out RaycastHit raycastHit, maxDistance);
                if (isCollision)
                {
                    // 衝突した表面の法線を足す
                    tmpDistance[i].x += forward.x;
                    tmpDistance[i].y += forward.y;
                    tmpDistance[i].z += forward.z;
                    
                    // 頂点とその他オブジェクトが近いほど、値を１にする
                    float adjustDistanceValue = 1.0f - raycastHit.distance;
                    if (tmpDistance[i].w < adjustDistanceValue)
                        tmpDistance[i].w = adjustDistanceValue;
                }
                
                // Colliderの裏側も検知するため、Rayを逆方向にしてもう１度距離を測る
                isCollision = Physics.Raycast((Vector3)targetVertex + forward * maxDistance, -forward, out raycastHit, maxDistance);
                if (isCollision)
                {
                    // 衝突した表面の法線を足す
                    tmpDistance[i].x += -forward.x;
                    tmpDistance[i].y += -forward.y;
                    tmpDistance[i].z += -forward.z;
                    
                    // Rayを逆方向にしたため、そのままの距離を格納する（逆方向なので、調整しなくとも近いほど１となる）
                    float adjustDistanceValue = raycastHit.distance;
                    if (tmpDistance[i].w < adjustDistanceValue)
                        tmpDistance[i].w = adjustDistanceValue;
                }
            }

            // x, y, zを正規化し、距離をかけて格納する
            Vector3 tmpVector3 = new Vector3(tmpDistance[i].x, tmpDistance[i].y, tmpDistance[i].z);
            tmpVector3 = tmpVector3.normalized;
            tmpDistance[i].x = tmpVector3.x * tmpDistance[i].w;
            tmpDistance[i].y = tmpVector3.y * tmpDistance[i].w;
            tmpDistance[i].z = tmpVector3.z * tmpDistance[i].w;
        }

        // Vertex Color
        Color[] vertexColor = new Color[vertices.Length];
        // Vertex Colorに距離を格納する
        for (int i = 0; i < vertexColor.Length; i++)
            vertexColor[i] = new Color(tmpDistance[i].x, tmpDistance[i].y, tmpDistance[i].z, tmpDistance[i].w);

        return vertexColor;
    }

    private void DetachColliderToOthers()
    {
        foreach (var tempCollider in _temporaryColliderList)
            Destroy(tempCollider);
    }
#endregion

#region Bakeした結果をテクスチャとして保存する処理に関連するメソッド
    /// <summary>
    /// Texture作成用カメラを生成するメソッド
    /// </summary>
    /// <param name="bounds"></param>
    private void CreateCameraForBake(Bounds bounds)
    {
        // すでにTexture作成用カメラが存在する場合は、一度削除して新しく作成する
        if (!cameraForBake.IsUnityNull())
        {
            DestroyImmediate(cameraForBake.gameObject);
        }
        
        // Texture作成用カメラを作成する
        var goCameraForBake = new GameObject();
        goCameraForBake.name = "CameraForBake";
        cameraForBake = goCameraForBake.AddComponent<Camera>();
        
        // 水の板(Mesh)を、Texture作成用カメラの親に設定し、上から見下ろす形にする
        goCameraForBake.transform.rotation = Quaternion.Euler(new Vector3(90.0f, 0.0f, 0.0f));
        goCameraForBake.transform.SetParent(gameObject.transform, false);
        goCameraForBake.transform.localPosition += new Vector3(0, 0.5f / goCameraForBake.transform.lossyScale.y, 0);
        
        // 他のカメラに埋まらないように設定する
        cameraForBake.depth = -1.0f;
        
        // 遠近は不要のため、OrthographicCameraに変更する
        cameraForBake.orthographic = true;
        // 大きい試錐台は不要のため、狭い範囲に設定する
        cameraForBake.nearClipPlane = 0.0f;
        cameraForBake.farClipPlane  = 1.0f;
        cameraForBake.orthographicSize = Mathf.Max(bounds.size.x, bounds.size.z) / 2.0f;
        var temp = cameraForBake.aspect;

        // Texture作成用カメラの設定を調整する
        cameraForBake.backgroundColor = Color.magenta;          // Debug用背景色を設定する
        //cameraForBake.backgroundColor = Color.black;            // 背景色を黒にする
        cameraForBake.clearFlags = CameraClearFlags.SolidColor;   // 背景色でクリアする
        
        // 新しく作成したカメラと、水の板(Mesh)に一時的にLayerを設定し、水の板だけレンダリングされるようにする
        // (Layerはビルトインの設定であるWaterを使う）
        cameraForBake.cullingMask = LayerMask.GetMask("Water"); // WaterのBit設定を取得し設定
        // 後で元に戻すために、水の板(Mesh)の現在のLayerを取っておく
        preMeshLayer = gameObject.layer;
        // カメラのCullingMaskに合わせてLayerを設定する
        gameObject.layer = LayerMask.NameToLayer("Water"); // Waterの番号を取得し設定
        
        // Texture作成用カメラにセットするRenderTextureを生成
        // (ここに映ったのが最終的に出力される)
        RenderTexture cameraRenderTexture = new RenderTexture(
            textureSize, 
            textureSize, 
            0,                         // No depth/stencil buffer
            RenderTextureFormat.ARGB32,     // Standard colour format
            RenderTextureReadWrite.sRGB     // No sRGB conversions
        );
        var preTargetTexture = cameraForBake.targetTexture;
        cameraForBake.targetTexture = cameraRenderTexture;
    }

    /// <summary>
    /// カメラのRenderTargetをpngファイルに変換して保存するメソッド
    /// </summary>
    /// <param name="cameraForPrint">ここに設定したカメラに映っているのを保存する</param>
    private void SaveBakeResultToTexture(Camera cameraForPrint)
    {
        if (String.IsNullOrEmpty(directoryPath) || !Directory.Exists(directoryPath))
        {
            EditorUtility.DisplayDialog("警告", "正しい保存先を指定してください。", "OK");
            return;
        }
        
        // 現在のRenderTargetにTexture作成用カメラのRenderTextureを設定する（Graphics.SetRenderTargetと同じ動き）
        RenderTexture.active = cameraForPrint.targetTexture;
        
        // 現在のRenderTarget(Screen、またはRenderTexture)からPixelを読み取り、Texture2Dに書き込む
        Texture2D outputTex = new Texture2D(textureSize, textureSize, TextureFormat.ARGB32, false);
        outputTex.ReadPixels(
            new Rect(0, 0, textureSize, textureSize),   // Capture the whole texture
            0, 0,                                                 // Write starting at the top-left texel
            false                                           // No mipmaps
        );

        // pngのバイトに変換する
        var pngByte = outputTex.EncodeToPNG();

        // pngのバイトを保存先に保存する
        string filePath = directoryPath + "/" + fileName + ".png";
        File.WriteAllBytes(filePath, pngByte);
        // 新しく作成したファイルを直ちに表示させる
        AssetDatabase.Refresh();    
        
        // 後片付け
        RenderTexture.active = null;
        DestroyImmediate(outputTex);    // Destroyはゲーム中しか動作しないので、代わりにDestroyImmediateを使う
    }
#endregion

    void Start()
    {
        RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;
        RenderPipelineManager.endCameraRendering += OnEndCameraRendering;
    }

    void Update() { }
    
    void OnBeginCameraRendering(ScriptableRenderContext context, Camera camera)
    {
        if (!isClickedBakeButton)
        {
            return;
        }
        else if (cameraForBake.Equals(camera))
        {
            // 現在のマテリアルを一時保存し、テクスチャ保存のためのシェーダーを装備させる
            Material currentMat = gameObject.GetComponent<MeshRenderer>().material;
            preMaterial = new Material(currentMat.shader);
            preMaterial.CopyPropertiesFromMaterial(currentMat);
            gameObject.GetComponent<MeshRenderer>().material.shader = bakeShader;
        }
    }    
    void OnEndCameraRendering(ScriptableRenderContext context, Camera camera)
    {
        if (!isClickedBakeButton)
        {
            return;
        }
        else if (cameraForBake.Equals(camera))
        {
            // カメラの映像をpngファイルとして保存する
            SaveBakeResultToTexture(cameraForBake);
            
            // BakeボタンのクリックのフラグをOffに変更
            isClickedBakeButton = false;
            // 後で元に戻すために、水の板(Mesh)の現在のLayerを取っておく
            gameObject.layer = preMeshLayer;
            // 元のマテリアルに戻す
            gameObject.GetComponent<MeshRenderer>().material = preMaterial;
            
            // 処理時間測定
            watch.Stop();
            Debug.Log("Texture保存処理終了！全体の処理時間：" + watch.ElapsedMilliseconds + " ms");
        }
    }

    void OnDestroy()
    {
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
        RenderPipelineManager.endCameraRendering -= OnEndCameraRendering;
        Destroy(cameraForBake);
    }
}

/// <summary>
/// コンポーネントに「Bake Depth」というボタンを表示させるためのEditor
/// 拡張性は必要ないと判断したため、簡単に実装
/// </summary>
[CustomEditor(typeof(BakeryDistanceByRay))]
public class BakeryDistanceByRayButton : Editor
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        BakeryDistanceByRay comp = (BakeryDistanceByRay)target;
        if (GUILayout.Button("Bake"))
        {
            if (!Application.isPlaying)
            {
                bool res1 = EditorUtility.DisplayDialog("警告", "Play Modeで実行してください。", "OK");
            }
            else
            {
                comp.Bake();
            }
        }
    }
}
