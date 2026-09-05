"""Render the actual female Blender geometry with stepped lighting and pixel sampling."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'blender-assets/samples/female-light-armour-v01'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'female-light-armour.blend'))
scene=bpy.context.scene
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
scene.cycles.samples=12
scene.cycles.use_denoising=False
scene.cycles.pixel_filter_type='BOX'
scene.cycles.filter_width=.01

# Material colours remain editable. The lighting bands are part of the Blender
# scene, not a repaint or an image substituted for the geometry.
for m in list(bpy.data.materials):
    if not m.use_nodes:continue
    color=tuple(m.diffuse_color[:3])
    ground=m.name=='Parchment studio floor'
    if ground:color=(.74,.675,.57)
    n=m.node_tree.nodes;n.clear();links=m.node_tree.links
    geo=n.new('ShaderNodeNewGeometry')
    dot=n.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT'
    dot.inputs[1].default_value=Vector((-.60,-.75,.85)).normalized()
    links.new(geo.outputs['Normal'],dot.inputs[0])
    remap=n.new('ShaderNodeMath');remap.operation='MULTIPLY_ADD'
    remap.inputs[1].default_value=.5;remap.inputs[2].default_value=.5
    links.new(dot.outputs['Value'],remap.inputs[0])
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.interpolation='CONSTANT'
    for e in list(ramp.color_ramp.elements)[1:]:ramp.color_ramp.elements.remove(e)
    for i,(pos,factor) in enumerate([(0,.30),(.37,.48),(.57,.72),(.76,1.03),(.91,1.30)]):
        e=ramp.color_ramp.elements[0] if i==0 else ramp.color_ramp.elements.new(pos)
        e.position=pos;e.color=(*(min(1.,c*(1. if ground else factor)) for c in color),1)
    links.new(remap.outputs[0],ramp.inputs[0])
    ao=n.new('ShaderNodeAmbientOcclusion');ao.inputs['Distance'].default_value=.18 if ground else .045
    ao.samples=8
    mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.55
    links.new(ramp.outputs['Color'],mix.inputs[1]);links.new(ao.outputs['Color'],mix.inputs[2])
    em=n.new('ShaderNodeEmission');links.new(mix.outputs[0],em.inputs['Color'])
    out=n.new('ShaderNodeOutputMaterial');links.new(em.outputs[0],out.inputs['Surface'])

scene.camera.location=(3,-8,3.05)
scene.camera.rotation_euler=(Vector((.015,0,.873))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.ortho_scale=1.92
scene.render.use_freestyle=True
lines=scene.view_layers[0].freestyle_settings.linesets[0]
lines.select_crease=False;lines.select_material_boundary=False;lines.select_border=False
lines.select_silhouette=True
if lines.linestyle is None:lines.linestyle=bpy.data.linestyles.new('Dark pixel contours')
lines.linestyle.color=(.028,.022,.014);lines.linestyle.thickness=.62
scene.render.resolution_x=270;scene.render.resolution_y=340
scene.render.filepath=str(OUT/'model-pixel.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'female-pixel-source.blend'))
bpy.ops.render.render(write_still=True)
scene.render.resolution_x=96;scene.render.resolution_y=128
scene.render.filepath=str(OUT/'game-scale-preview.png')
bpy.ops.render.render(write_still=True)

# Separate orthographic presentation scene, using the unmodified reference image
# through cropped UVs and the actual model render with exact 2x nearest sampling.
board=bpy.data.scenes.new('Concept and actual model comparison')
bpy.context.window.scene=board
board.render.engine='CYCLES';board.cycles.samples=1
board.cycles.use_denoising=False;board.cycles.pixel_filter_type='BOX';board.cycles.filter_width=.01
board.view_settings.view_transform='Standard'
board.render.resolution_x=1280;board.render.resolution_y=900;board.render.resolution_percentage=100
board.render.image_settings.file_format='PNG'
d=bpy.data.cameras.new('Board camera');cam=bpy.data.objects.new(d.name,d);board.collection.objects.link(cam)
cam.location=(640,450,100);d.type='ORTHO';d.ortho_scale=1280;board.camera=cam


def emission(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear()
    em=n.new('ShaderNodeEmission');em.inputs['Color'].default_value=(*color,1)
    out=n.new('ShaderNodeOutputMaterial');m.node_tree.links.new(em.outputs[0],out.inputs[0]);return m


def plane(name,x,y,w,h,material,uv=(0,0,1,1),z=0):
    d=bpy.data.meshes.new(name)
    d.from_pydata([(x,y,z),(x+w,y,z),(x+w,y+h,z),(x,y+h,z)],[],[(0,1,2,3)])
    u=d.uv_layers.new()
    a,b,c,e=uv
    for p,q in zip(u.data,[(a,b),(c,b),(c,e),(a,e)]):p.uv=q
    o=bpy.data.objects.new(name,d);board.collection.objects.link(o);d.materials.append(material)


def image_material(name,path):
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear()
    tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path));tex.interpolation='Closest'
    em=n.new('ShaderNodeEmission');out=n.new('ShaderNodeOutputMaterial')
    m.node_tree.links.new(tex.outputs['Color'],em.inputs[0]);m.node_tree.links.new(em.outputs[0],out.inputs[0]);return m


paper=emission('Paper',(.83,.79,.70));ink=emission('Caption ink',(.055,.033,.018))
plane('Paper',0,0,1280,900,paper)
font=bpy.data.fonts.load('C:/Windows/Fonts/msjh.ttc')
def label(text,x,y,size):
    d=bpy.data.curves.new(text,'FONT');d.body=text;d.font=font;d.size=size;d.align_x='CENTER';d.align_y='CENTER'
    o=bpy.data.objects.new(text,d);board.collection.objects.link(o);o.location=(x,y,3);d.materials.append(ink)


label('女性輕甲｜概念圖與實際模型',640,856,34)
label('概念圖參考',312,805,22)
label('Blender 實際像素渲染',919,805,22)
ref=ROOT/'blender-assets/concepts/female-character-b-v01.png'
plane('Reference centre crop',147,125,330,660,image_material('Reference',ref),
      (612/1536,(1024-756)/1024,942/1536,(1024-96)/1024),1)
plane('Actual model at 2x',650,99,540,680,image_material('Actual render',OUT/'model-pixel.png'),z=1)
label('靜態造型樣品 · 右圖為真實模型輸出，尚待美術確認',640,55,20)
label('可編輯 Blender 原檔與 GLB 另存於同一資料夾',640,24,15)
board.render.filepath=str(OUT/'concept-model-comparison.png')
bpy.ops.render.render(write_still=True)
print('FEMALE_PIXEL_REVIEW_COMPLETE')
report_path=OUT/'build-report.json'
report=json.loads(report_path.read_text(encoding='utf-8'))
report['pixel_resolution']=[270,340]
report['game_scale_preview_resolution']=[96,128]
report['pixel_materials']='Five lighting bands, ambient occlusion, hard pixel sampling and silhouette contours'
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
