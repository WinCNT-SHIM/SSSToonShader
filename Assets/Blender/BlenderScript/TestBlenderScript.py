import bpy                  #
import bmesh
import array
import io
from pathlib import Path
import sys
import os

print("Start")
font_curve = bpy.data.curves.new(type="FONT", name="Font Curve")

font = bpy.data.fonts.load(filepath="C:\\WINDOWS\\Fonts\\BIZ-UDGothicB.ttc")
font_curve.font = font
font_curve.offset = 0.00001
font_obj = bpy.data.objects.new(name="Font Object", object_data=font_curve)
font_obj.data.resolution_u = 4
bm = bmesh.new()


tmpPath = "C:\\blender\\ScrpitTest.vtff"
font_file = io.FileIO(os.path.abspath(tmpPath), "wb")
array.array("b", b'VTFF').tofile(font_file)
array.array("H", [1]).tofile(font_file)


font_curve.body = "あ"
me = font_obj.to_mesh()
bm.clear()
bm.from_mesh(me)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.to_mesh(me)


fw = io.BytesIO()
# arr = array.array("b", [1, 2]).tofile(fw)
# arr = array.array("b", [3, 4]).tofile(fw)
# print(fw.getvalue())

# font_dict = {}
# font_dict[0] = fw.getvalue()
# print(len(font_dict[0]))

verts = []
indices = []

for poly in me.polygons:
    vi1 = me.loops[poly.loop_start].vertex_index
    vi2 = me.loops[poly.loop_start+2].vertex_index
    vi3 = me.loops[poly.loop_start+1].vertex_index
    
    indices.append(vi1)
    indices.append(vi2)
    indices.append(vi3)

v_min_x = min(me.vertices, key=lambda x: x.co.x).co.x
v_min_y = min(me.vertices, key=lambda x: x.co.y).co.y
v_max_x = max(me.vertices, key=lambda x: x.co.x).co.x
v_max_y = max(me.vertices, key=lambda x: x.co.y).co.y


for v in me.vertices:
    vx = round((v.co.x-v_min_x)/(v_max_x-v_min_x)*65535)
    vy = round((v.co.y-v_min_y)/(v_max_y-v_min_y)*65535)
    verts.append(vx)
    verts.append(vy)

array.array("f", [v_min_x, v_min_y]).tofile(fw)
print(len(fw.getvalue()))
array.array("f", [v_max_x, v_max_y]).tofile(fw)
print(len(fw.getvalue()))
array.array("H", [len(indices)]).tofile(fw)
print(len(fw.getvalue()))
array.array("H", indices).tofile(fw)
print(len(fw.getvalue()))
array.array("H", [len(verts)]).tofile(fw)
print(len(fw.getvalue()))
array.array("H", verts).tofile(fw)
print(len(fw.getvalue()))
result = fw.getvalue()

print(result)
print(len(result))

print("End\n")