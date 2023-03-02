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
    
    [SerializeField]
    private Texture texture;
    [SerializeField]
    private Material bakeMaterial;
    [SerializeField]
    private RenderTexture currentRenderTexture;
#endregion

#region Variables
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
#endregion

    public void Bake()
    {
        isClickedBakeButton = true;
        
        Debug.Log("Bake処理開始！");
        // 処理時間測定
        System.Diagnostics.Stopwatch watch = new System.Diagnostics.Stopwatch();
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
        
        // Rayとの衝突を測るためにその他GameObjectにColliderを付ける
        AttachColliderToOthers();
        
        // 頂点を位置からRayを飛ばしてその他GameObjectとの距離を計算する
        var finalVertexColor = ComputeDistanceToOthers(ref vertices);

        // Vertex Colorを更新する
        mesh.SetColors(finalVertexColor);

        // 最後の片づけ
        Finish();
        
        // 処理時間測定
        Debug.Log("Bake処理終了！全体の処理時間：" + watch.ElapsedMilliseconds + " ms");
        
        
        //////////////////////////////////////////////////
        // Texture保存
        //////////////////////////////////////////////////
        Debug.Log("Texture保存処理開始！");
        
        
        // すでにTexture作成用カメラが存在する場合は、一度削除して新しく作成する
        if (!cameraForBake.IsUnityNull())
        {
            DestroyImmediate(cameraForBake.gameObject);
        }
        
        // Texture作成用カメラを作成する
        var goCameraForBake = new GameObject();
        goCameraForBake.name = "CameraForBake";
        cameraForBake = goCameraForBake.AddComponent<Camera>();
        
        // Texture作成用カメラの設定を調整する
        cameraForBake.backgroundColor = Color.cyan;            // Debug用背景色
        //cameraForBake.backgroundColor = Color.black;            // 背景色を黒にする
        cameraForBake.clearFlags = CameraClearFlags.SolidColor;   // 背景色でクリアする
        

        var preTargetTexture = cameraForBake.targetTexture;
        cameraForBake.targetTexture = currentRenderTexture;
        //goCameraForBake.transform.position.Set(0.0f, 0.0f, -10.0f);
        goCameraForBake.transform.position += new Vector3(0.0f, 0.0f, -2.0f);

        // Bakeした結果をpngファイルに変換して保存する
        //SaveBakeResultToTexture();
        
        
        // // Texture作成用カメラを削除
        // DestroyImmediate(goCameraForBake);
        
        watch.Stop();
        Debug.Log("Texture保存処理終了！全体の処理時間：" + watch.ElapsedMilliseconds + " ms");
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
            tmpDistance[i].x = tmpVector3.x;
            tmpDistance[i].y = tmpVector3.y;
            tmpDistance[i].z = tmpVector3.z;
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
    private void SaveBakeResultToTexture()
    {
        if (String.IsNullOrEmpty(directoryPath) || !Directory.Exists(directoryPath))
        {
            Debug.Log("正しい保存先を指定してください。");
            return;
        }
        
        //var currentRenderTexture = RenderTexture.active;
        //var currentRenderTexture = Camera.main.targetTexture;
        
        //RenderTexture renderTexture = RenderTexture.GetTemporary(textureSize, textureSize);
        //Camera.main.targetTexture = renderTexture;
        //var currentRenderTexture = Camera.main.targetTexture;
        //var preTargetTexture = Camera.main.targetTexture; 
        //Camera.main.targetTexture = currentRenderTexture;
        //RenderTexture.active = currentRenderTexture;

        //Graphics.Blit(null, currentRenderTexture);
        
        RenderTexture buffer = new RenderTexture(
            textureSize, 
            textureSize, 
            0,                         // No depth/stencil buffer
            RenderTextureFormat.ARGB32,     // Standard colour format
            //RenderTextureReadWrite.Linear   // No sRGB conversions
            RenderTextureReadWrite.sRGB     // No sRGB conversions
        );
        // シェーダーを使ってSourceをDestにコピーする
        //Graphics.Blit(currentRenderTexture, buffer, bakeMaterial);
        //Graphics.Blit(currentRenderTexture, buffer);
        Graphics.Blit(currentRenderTexture, buffer);
        
        // 現在のRenderTargetにRenderTextureを設定する（Graphics.SetRenderTargetと同様）
        RenderTexture.active = buffer;
        
        Texture2D outputTex = new Texture2D(textureSize, textureSize, TextureFormat.ARGB32, false);
        // 現在のRenderTarget(Screen、またはRenderTexture)からPixelを読み取り、Texture2Dに書き込む
        outputTex.ReadPixels(
            new Rect(0, 0, textureSize, textureSize),   // Capture the whole texture
            0, 0,                                                 // Write starting at the top-left texel
            false                                           // No mipmaps
        );

        var pngByte = outputTex.EncodeToPNG();

        string filePath = directoryPath + "/" + fileName + ".png";
        
        File.WriteAllBytes(filePath, pngByte);
        // 新しく作成したファイルを直ちに表示させる
        AssetDatabase.Refresh();    
        
        // 変数の片づけ
        //Camera.main.targetTexture = preTargetTexture;
        RenderTexture.active = null;
        DestroyImmediate(outputTex);    // Destroyはゲーム中しか動作しないので、代わりにDestroyImmediateを使う
    }
#endregion

    void Start()
    {
        RenderPipelineManager.endCameraRendering += OnEndCameraRendering;
    }

    // Update is called once per frame
    void Update()
    {
        
    }
    
    void OnEndCameraRendering(ScriptableRenderContext context, Camera camera)
    {
        if (!isClickedBakeButton)
        {
            return;
        }
        else if (cameraForBake.Equals(camera))
        {
            
            SaveBakeResultToTexture();
            isClickedBakeButton = false;
        }
    }
    
    void OnRenderObject()
    {
        if ((cameraForBake == null) || (cameraForBake.cullingMask & (1 << gameObject.layer)) == 0)
        {
            return;
        }
        if (mesh != null)
        {
            bakeMaterial.SetPass(0);
            //Graphics.DrawMeshNow(mesh, Vector3.zero, Quaternion.identity);
            Graphics.DrawMeshNow(
                mesh,
                Vector3.zero,
                Quaternion.Euler(new Vector3(-90.0f, 0.0f, 0.0f))
            );
        }
    }
    
    void OnDestroy()
    {
        RenderPipelineManager.endCameraRendering -= OnEndCameraRendering;
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
            comp.Bake();
    }
}
