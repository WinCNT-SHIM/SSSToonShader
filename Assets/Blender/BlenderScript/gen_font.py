import bpy
import bmesh
import array
import io
from pathlib import Path
import sys
import os
import math

# CMDで、以下のように引数を入力して実行する
# "blender.exe"のパス --python "このスクリプトのパス" -- "C:\Windows\Fonts\対象フォント" "保存のパス" "フォント化したい文字を保存した.txtファイルのパス"（複数の.txtファイル設定可能）
# ex) "C:\Program Files\Blender Foundation\Blender 3.4\blender.exe" --background --python "C:\Users\SHIM\Documents\GitHub\kurama\Assets\VTMesh\Editor\gen_font.py" -- "C:\Windows\Fonts\BIZ-UDGothicB.ttc" "C:\blender\Test2.vtff" "C:\blender\TextText.txt"
# ※ --の後に半角スペース必須！
argv = sys.argv
try:
    index = argv.index("--") + 1
except ValueError:
    index = len(argv)

# 「-- 」以降の引数を取得
argv = argv[index:]
texts = argv[2:]
font_curve = bpy.data.curves.new(type="FONT", name="Font Curve")

# フォントファイルをロードする
#font = bpy.data.fonts.load(filepath="C:\\WINDOWS\\Fonts\\BIZ-UDGothicB.ttc")
font = bpy.data.fonts.load(filepath=os.path.abspath(argv[0]))

# Font Curveのセット
font_curve.font = font
font_curve.offset = 0.00001
font_obj = bpy.data.objects.new(name="Font Object", object_data=font_curve)
font_obj.data.resolution_u = 4
# font_obj.data.extrude = 0.05
bm = bmesh.new()

# Outline用Fontを設定
font_curve_outline = bpy.data.curves.new(type="FONT", name="Font Curve Outline")
font_curve_outline.font = font
font_curve_outline.offset = 0.001
font_obj_outline = bpy.data.objects.new(name="Font Object Outline", object_data=font_curve_outline)
font_obj_outline.data.resolution_u = 4
bm_outline = bmesh.new()

# 文字のモデルデータ（以降、字体データ）を解析し、VertexとIndexをバイナリ化する関数
def gen(target_char):
    
    # 字体のMeshを生成
    font_curve.body = target_char
    
    me = font_obj.to_mesh()
    bm.clear()
    bm.from_mesh(me)
    # 字体のMeshのFaceを三角面化する
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(me)

    # Outline用の字体のMeshを生成
    font_curve_outline.body = target_char
    me_outline = font_obj_outline.to_mesh()
    bm_outline.clear()
    bm_outline.from_mesh(me_outline)
    # 字体のMeshのFaceを三角面化する
    bmesh.ops.triangulate(bm_outline, faces=bm_outline.faces[:])
    bm_outline.to_mesh(me_outline)

    # バイナリを書き出すためのバッファー
    fw = io.BytesIO()

    verts = []
    indices = []
    
    if(len(me.polygons) == 0):
        return
    if(len(me.vertices) == 0):
        return
    
    for poly in me.polygons:
        if(poly.loop_total != 3):
            print("Error %s", target_char)
            return
        vi1 = me.loops[poly.loop_start].vertex_index
        vi2 = me.loops[poly.loop_start+2].vertex_index
        vi3 = me.loops[poly.loop_start+1].vertex_index
        
        indices.append(vi1)
        indices.append(vi2)
        indices.append(vi3)

    # 文字の頂点の最大最小の値を取得する（coはcoordinates）
    v_min_x = min(me.vertices, key=lambda x: x.co.x).co.x
    v_min_y = min(me.vertices, key=lambda x: x.co.y).co.y
    v_max_x = max(me.vertices, key=lambda x: x.co.x).co.x
    v_max_y = max(me.vertices, key=lambda x: x.co.y).co.y

    # 字体とOutline用のMeshの数に差がある場合はエラーとする（ない想定）
    if(len(me.vertices) - len(me_outline.vertices) != 0):
        print("Error Making Outline %s", target_char)
        return

    # 文字の頂点の情報を２Byteの数字にマッピングして格納する（65535は2Byteの最大値）
    # また、zにはOutlineを作成するための角度を計算して格納する
    # ※ Unityなどで取り込むときは、アンパックする処理が必要
    for i, v in enumerate(me.vertices):
        vx = round((me.vertices[i].co.x-v_min_x)/(v_max_x-v_min_x)*65535)
        vy = round((me.vertices[i].co.y-v_min_y)/(v_max_y-v_min_y)*65535)
        verts.append(vx)
        verts.append(vy)
        
        # Outline用のベクター
        x2outline = me_outline.vertices[i].co.x - me.vertices[i].co.x
        y2outline = me_outline.vertices[i].co.y - me.vertices[i].co.y
        # Outline用のベクターへの角度を計算する
        outline_angle_rad = math.atan2(y2outline, x2outline)
        # x軸から反時計回りの角度になるように調整する
        if(outline_angle_rad < 0):
            outline_angle_rad = 2*math.pi+outline_angle_rad
        #print(i, " : ", math.degrees(outline_angle_rad), "rad : ", outline_angle_rad)

        # 頂点の情報と同じくマッピングして格納する
        outline_angle_rad = round(outline_angle_rad/(2*math.pi)*65535)
        verts.append(outline_angle_rad)

    array.array("f", [v_min_x, v_min_y]).tofile(fw)
    array.array("f", [v_max_x, v_max_y]).tofile(fw)
    array.array("H", [len(indices)]).tofile(fw)
    array.array("H", indices).tofile(fw)
    array.array("H", [len(verts)]).tofile(fw)
    array.array("H", verts).tofile(fw)
    result = fw.getvalue()
    fw.close()
    return result
    

# 引数で設定した.txtファイルの中身を読み取る
txt = ""
for tpath in texts:
    print(tpath)
    txt += Path(os.path.abspath(tpath)).read_text()

font_dict = {}
font_file = io.FileIO(os.path.abspath(argv[1]), "wb")

# VTFFファイルのヘッダー情報を書き出す
array.array("b", b'VTFF').tofile(font_file) # VTFF
array.array("H", [1]).tofile(font_file)     # Version

# 文字と、字体データのバイナリを合わせて格納する
for c in txt:
    data = gen(c)
    if(data is not None):
        font_dict[ord(c)] = data

# 字体データの数を書き出す
array.array("H", [len(font_dict)]).tofile(font_file)

# 字体データの各々のバイナリのサイズを書く領域を書く方する
# 「index」のサイズ４＋「index+l」のサイズ４＝８
index = 9 + len(font_dict) * 8

# 字体データを書き出す
for dc in font_dict:
    # 字体データのバイナリのサイズを計算する（+2は文字（UTF-16LE）のため）
    l = len(font_dict[dc]) + 2
    array.array("I", [index, index+l]).tofile(font_file)
    index += l
print(font_file.tell())

# 字体データを書き出す
for dc in font_dict:
    array.array("H", [dc]).tofile(font_file)    # 文字（UTF-16LE）
    font_file.write(font_dict[dc])              # 字体データのバイナリ
    
font_file.close()

bm.free()