using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class BakeryDistanceByRay : MonoBehaviour
{
#region Properties
    [SerializeField] [Range(0.001f, 1.0f)] [Tooltip("各頂点から、ここで設定した距離以内にある兄弟のGameObjectについて探索します。")]
    private float maxDistance = 1.0f;
    
    [SerializeField] [Tooltip("各頂点から飛ばすRayをDebug用として描画する。")]
    private bool drawDebugRay = false;
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
#endregion

    public void Bake()
    {
        Debug.Log("処理開始！");
        // 処理時間測定
        System.Diagnostics.Stopwatch watch = new System.Diagnostics.Stopwatch();
        watch.Start();
        
        // 初期化
        Initialize();
        
        // GameObjectのMeshの情報を取得する
        Mesh mesh = GetComponent<MeshFilter>().sharedMesh;
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
        watch.Stop();
        Debug.Log("処理終了！処理時間：" + watch.ElapsedMilliseconds + " ms");
    }

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
