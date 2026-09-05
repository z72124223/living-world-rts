"""Rebuild the rejected foundation from pinned CC0 MakeHuman asset data.

Blender 5.1: --background --factory-startup --python scripts/build_body_pixel_revision.py
Produces an editable connected body, rig, and real pixel-resolution renders.
No MakeHuman application code is imported or executed.
"""
import bpy
import json
import math
import hashlib
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'blender-assets/sources/makehuman-a8bc2d5'
OUT=ROOT/'blender-assets/samples/body-pixel-v02'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
bpy.context.preferences.filepaths.save_version=0

# Load face groups separately so body and optional scalp stay editable; helper meshes
# and skeletal joint marker cubes do not become visible body geometry.
raw=[]; faces=[]; groups=[]; group=''; uvs=[]; face_uvs=[]
for line in (SOURCE/'base.obj').read_text(encoding='utf-8').splitlines():
    fields=line.split()
    if not fields: continue
    if fields[0]=='v': raw.append(Vector(map(float,fields[1:4])))
    elif fields[0]=='vt': uvs.append(tuple(map(float,fields[1:3])))
    elif fields[0]=='g': group=fields[1]
    elif fields[0]=='f':
        face=[t.split('/') for t in fields[1:]]
        faces.append([int(t[0])-1 for t in face]); groups.append(group)
        face_uvs.append([int(t[1])-1 for t in face])

TARGETS={'asian-male-young.target':1.0,
         'universal-male-young-averagemuscle-averageweight.target':.1,
         'universal-male-young-maxmuscle-averageweight.target':.9}
for filename,strength in TARGETS.items():
    for line in (SOURCE/filename).read_text(encoding='utf-8').splitlines():
        if line.strip() and not line.startswith('#'):
            parts=line.split()
            raw[int(parts[0])]+=Vector(map(float,parts[1:4]))*strength
body_ids={idx for face,g in zip(faces,groups) if g=='body' for idx in face}
lowest=min(raw[i].y for i in body_ids)
scale=1.8/(max(raw[i].y for i in body_ids)-lowest)


def transform(p):
    v=Vector((p.x*scale*1.06,-p.z*scale,(p.y-lowest)*scale))
    # A modest head proportion adjustment suits the B reference at small sprite size.
    t=max(0,min(1,(v.z-1.49)/.15)); t=t*t*(3-2*t)
    anchor=Vector((0,-.015,1.60))
    return anchor+(v-anchor)*(1+.10*t)


vertices=[transform(v) for v in raw]
skel=json.loads((SOURCE/'default.mhskel').read_text(encoding='utf-8'))
source_weights=json.loads((SOURCE/'default_weights.mhw').read_text(encoding='utf-8'))['weights']


def joint(name):
    ids=skel['joints'][name]
    return sum((vertices[i] for i in ids),Vector())/len(ids)


def material(name,color):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*color,1)
    m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.82
    return m


clay=material('Body | warm neutral clay',(.40,.255,.145))
hair_mat=material('Hair | ink brown',(.018,.012,.009))
eye_mat=material('Eye | ivory',(.34,.29,.19))
iris_mat=material('Eye | dark brown',(.018,.011,.008))
assets=bpy.data.collections.new('BODY AND RIG | editable')
scene.collection.children.link(assets)
stage=bpy.data.collections.new('PREVIEW | excluded from GLB')
scene.collection.children.link(stage)


def create_group(name,group_names,mat,predicate=None):
    indices=[i for i,g in enumerate(groups) if g in group_names and
             (predicate is None or predicate(sum((vertices[v] for v in faces[i]),Vector())/len(faces[i])))]
    old_ids=sorted({v for i in indices for v in faces[i]})
    remap={old:new for new,old in enumerate(old_ids)}
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([vertices[i] for i in old_ids],[],[[remap[v] for v in faces[i]] for i in indices])
    mesh.update()
    mesh.materials.append(mat)
    layer=mesh.uv_layers.new(name='UVMap')
    for polygon,index in zip(mesh.polygons,indices):
        polygon.use_smooth=True
        for loop,uv in zip(polygon.loop_indices,face_uvs[index]):
            layer.data[loop].uv=uvs[uv]
    obj=bpy.data.objects.new(name,mesh); assets.objects.link(obj)
    return obj,remap


body,remap=create_group('01_Body_Continuous',{'body'},clay)
head_top=max(vertices[i].z for i in body_ids)
def scalp_region(v):
    cutoff=head_top-.075
    if abs(v.x)>.068:cutoff=head_top-.13
    if v.y>.012:cutoff=head_top-.19
    return v.z>cutoff
hair,hair_remap=create_group('03_Scalp',{'body'},hair_mat,scalp_region)
head_centre=Vector((0,-.025,head_top-.11))
for v in hair.data.vertices:v.co=head_centre+(v.co-head_centre)*1.022

# Collapse facial controls, twist subdivisions and toe chains into a smaller art rig.
# Retain finger bones for believable future grips; this is an offline sprite source rig.
keep={'root','spine05','spine04','spine03','spine02','spine01','neck01','head'}
for side in ['L','R']:
    keep.update(base+'.'+side for base in ['clavicle','upperarm01','lowerarm01','wrist','upperleg01','lowerleg01','foot'])
    keep.update(f'finger{finger}-{segment}.{side}' for finger in range(1,6) for segment in range(1,4))
merge={}
for name in skel['bones']:
    current=name
    while current not in keep:
        current=skel['bones'][current]['parent']
        if current is None: current='root'
    merge[name]=current
rig_data=bpy.data.armatures.new('Humanoid foundation')
rig=bpy.data.objects.new('02_Rig',rig_data); assets.objects.link(rig)
bpy.context.view_layer.objects.active=rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name in sorted(keep):
    definition=skel['bones'][name]
    b=rig_data.edit_bones.new(name)
    b.head=joint(definition['head'])
    tail=definition['tail']
    if name=='neck01': tail=skel['bones']['neck03']['tail']
    for prefix in ['upperarm','lowerarm','upperleg','lowerleg']:
        if name.startswith(prefix+'01.'):
            tail=skel['bones'][name.replace('01.','02.')]['tail']
    if name.startswith('clavicle.'):
        tail=skel['bones']['upperarm01.'+name[-1]]['head']
    b.tail=joint(tail)
    plane=skel['planes'].get(definition.get('rotation_plane'))
    if plane:
        a,c,d=(joint(v) for v in plane)
        normal=(c-a).cross(d-a)
        if normal.length>.00001: b.align_roll(normal.normalized())
for name in sorted(keep):
    parent=skel['bones'][name]['parent']
    if parent:
        b=rig_data.edit_bones[name]; b.parent=rig_data.edit_bones[merge[parent]]
        b.use_connect=(b.head-b.parent.tail).length<.0001
bpy.ops.object.mode_set(mode='OBJECT'); rig.select_set(False)
rig.show_in_front=True; rig_data.display_type='STICK'

weights=[{} for _ in body.data.vertices]
for name,entries in source_weights.items():
    target=merge[name]
    for old,w in entries:
        if old in remap:
            bucket=weights[remap[old]]; bucket[target]=bucket.get(target,0)+w
for idx,bucket in enumerate(weights):
    strongest=sorted(bucket.items(),key=lambda item:item[1],reverse=True)[:4]
    total=sum(w for _,w in strongest)
    assert total>0,idx
    for name,w in strongest:
        vg=body.vertex_groups.get(name) or body.vertex_groups.new(name=name)
        vg.add([idx],w/total,'REPLACE')
body.parent=rig
arm=body.modifiers.new('Shared body deformation','ARMATURE'); arm.object=rig
hair.parent=rig
vg=hair.vertex_groups.new(name='head'); vg.add(list(range(len(hair.data.vertices))),1,'REPLACE')
arm=hair.modifiers.new('Follow head','ARMATURE'); arm.object=rig


def move_collection(obj,collection):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    collection.objects.link(obj)


def attach_head(obj):
    obj.parent=rig
    group=obj.vertex_groups.new(name='head')
    group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
    mod=obj.modifiers.new('Follow head','ARMATURE');mod.object=rig


for side in ['L','R']:
    eye=skel['bones']['eye.'+side]
    centre=joint(eye['head']); direction=(joint(eye['tail'])-centre).normalized()
    for label,rad,location,mat in [('Eye',.0145,centre,eye_mat),('Iris',.0055,centre+direction*.0125,iris_mat)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=rad,location=location)
        obj=bpy.context.object;obj.name=label+'.'+side;move_collection(obj,assets)
        obj.data.materials.append(mat)
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        for poly in obj.data.polygons: poly.use_smooth=True
        attach_head(obj)
# A modest knot keeps the ancient character reference without obscuring base anatomy.
top=max(v.co.z for v in body.data.vertices)
bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,radius=1,location=(0,.025,top+.02))
knot=bpy.context.object;knot.name='Topknot';knot.scale=(.038,.033,.04)
move_collection(knot,assets);knot.data.materials.append(hair_mat)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);attach_head(knot)

for pose in rig.pose.bones: pose.rotation_mode='XYZ'
for frame in [1,25,49]:
    for pose in rig.pose.bones:
        pose.rotation_euler=(0,0,0)
        if frame==25 and pose.name=='lowerarm01.L': pose.rotation_euler.x=.5
        if frame==25 and pose.name=='head': pose.rotation_euler.y=.10
        pose.keyframe_insert(data_path='rotation_euler',frame=frame,group=pose.name)
rig.animation_data.action.name='Foundation_Rig_Check'
scene.frame_start=1;scene.frame_end=49;scene.render.fps=24;scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in assets.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'body-rig.glb'),export_format='GLB',use_selection=True,
                         export_animations=True,export_animation_mode='ACTIONS')
bpy.ops.object.select_all(action='DESELECT')

# A continuous surface is the critical correction to v01's disconnected limb solids.
adj=[[] for _ in body.data.vertices]
for edge in body.data.edges:
    a,b=edge.vertices;adj[a].append(b);adj[b].append(a)
visited=set();components=[]
for start in range(len(adj)):
    if start in visited:continue
    todo=[start];visited.add(start);size=0
    while todo:
        u=todo.pop();size+=1
        for v in adj[u]:
            if v not in visited:visited.add(v);todo.append(v)
    components.append(size)
body.data.calc_loop_triangles()
def evaluated(frame):
    scene.frame_set(frame);bpy.context.view_layer.update()
    obj=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [v.co.copy() for v in obj.data.vertices]
a,b=evaluated(1),evaluated(25)
movement=max((v-w).length for v,w in zip(a,b))
assert movement>.02
assert all(abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in body.data.vertices)
scene.frame_set(1)
report={'source':'MakeHuman CC0 assets, commit a8bc2d54ff0ac92e78ff71431b1023eda42bf482',
        'blender':bpy.app.version_string,'body_vertices':len(body.data.vertices),
        'body_triangles':len(body.data.loop_triangles),'body_connected_components':sorted(components,reverse=True),
        'rig_bones':len(rig.data.bones),'max_vertex_influences':4,'pose_displacement_m':movement,
        'sprite_resolution':[192,224],'review_status':'AWAITING_USER_REVIEW',
        'wardrobe':'NOT_REBUILT_IN_THIS_FOUNDATION_REVISION','runtime_performance':'NOT_MEASURED',
        'source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.iterdir() if p.is_file()}}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

scene.world=bpy.data.worlds.new('Neutral studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.40,.45,.50,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5


def aim(obj,target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def light(name,location,energy,size):
    data=bpy.data.lights.new(name,'AREA');obj=bpy.data.objects.new(name,data);stage.objects.link(obj)
    obj.location=location;data.energy=energy;data.shape='DISK';data.size=size;aim(obj,(0,0,.9))


light('Key',(-3,-4,6),420,4);light('Fill',(4,-1,3),160,3);light('Rim',(0,3,5),450,3)
camdata=bpy.data.cameras.new('Fixed orthographic camera');cam=bpy.data.objects.new('Fixed orthographic camera',camdata)
stage.objects.link(cam);scene.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=2.12
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA';scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'


def render(name,location,resolution):
    cam.location=location;aim(cam,(0,0,.91))
    scene.render.resolution_x,scene.render.resolution_y=resolution
    scene.render.filepath=str(OUT/name);bpy.ops.render.render(write_still=True)


render('body-clay-quarter.png',(4,-8,3.6),(850,1000))
scene.frame_set(25);render('body-clay-pose.png',(4,-8,3.6),(850,1000));scene.frame_set(1)
# Keep the source inspectable in ordinary clay shading, alongside the pixel material.


def pixel_skin():
    m=bpy.data.materials.new('B direction | five-step warm skin')
    m.use_nodes=True;nodes=m.node_tree.nodes;nodes.clear();links=m.node_tree.links
    geometry=nodes.new('ShaderNodeNewGeometry')
    dot=nodes.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT'
    dot.inputs[1].default_value=Vector((-.5,-.7,.65)).normalized()
    links.new(geometry.outputs['Normal'],dot.inputs[0])
    ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.interpolation='CONSTANT'
    levels=[(-.2,(.07,.034,.016)),(.0,(.17,.078,.025)),(.27,(.35,.17,.06)),
            (.54,(.57,.32,.13)),(.78,(.78,.52,.25))]
    # DOT values remapped to 0..1 before the stepped ramp.
    multiply=nodes.new('ShaderNodeMath');multiply.operation='MULTIPLY_ADD'
    multiply.inputs[1].default_value=.5;multiply.inputs[2].default_value=.5
    links.new(dot.outputs['Value'],multiply.inputs[0])
    for e in list(ramp.color_ramp.elements)[1:]:ramp.color_ramp.elements.remove(e)
    for index,(threshold,color) in enumerate(levels):
        e=ramp.color_ramp.elements[0] if index==0 else ramp.color_ramp.elements.new((threshold+1)/2)
        e.position=(threshold+1)/2;e.color=(*color,1)
    links.new(multiply.outputs[0],ramp.inputs[0])
    emission=nodes.new('ShaderNodeEmission');links.new(ramp.outputs['Color'],emission.inputs['Color'])
    output=nodes.new('ShaderNodeOutputMaterial');links.new(emission.outputs[0],output.inputs['Surface'])
    return m


pixel=pixel_skin()
rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'body-rig.blend'))
body.data.materials[0]=pixel
scene.view_settings.view_transform='Standard'
scene.cycles.samples=8;scene.cycles.use_denoising=False
scene.cycles.pixel_filter_type='BOX';scene.cycles.filter_width=.01
scene.render.use_freestyle=True
lineset=scene.view_layers[0].freestyle_settings.linesets[0]
lineset.select_crease=False
lineset.select_silhouette=True
lineset.select_border=True
lineset.select_material_boundary=False
if lineset.linestyle is None:lineset.linestyle=bpy.data.linestyles.new('Pixel silhouette')
lineset.linestyle.color=(.055,.032,.012)
lineset.linestyle.thickness=.65
for name,location in [('pixel-front.png',(0,-8,2.9)),('pixel-quarter.png',(4,-8,3.6)),('pixel-side.png',(8,0,2.9))]:
    render(name,location,(192,224))
cam.location=(4,-8,3.6);aim(cam,(0,0,.91))
scene.render.filepath=str(OUT/'pixel-quarter.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'pixel-source.blend'))

# Render the true rig as thin lines placed over its body, instead of an unrelated
# floating stick figure. Body is clay; diagnostic bones are explicitly presentation-only.
body.data.materials[0]=clay;scene.view_settings.view_transform='AgX'
scene.render.use_freestyle=False
scene.cycles.samples=16;scene.cycles.use_denoising=True
bone_mat=material('Diagnostic joints | bronze',(.75,.35,.035))
bone_mat.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value=(.6,.22,.01,1)
bone_mat.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value=.5
for b in rig.data.bones:
    if b.name.startswith('finger'):continue
    h,t=b.head_local.copy(),b.tail_local.copy()
    h.y=-.30;t.y=-.30
    curve=bpy.data.curves.new('Rig line '+b.name,'CURVE');curve.dimensions='3D';curve.bevel_depth=.0035;curve.bevel_resolution=1
    spline=curve.splines.new('POLY');spline.points.add(1)
    spline.points[0].co=(*h,1);spline.points[1].co=(*t,1)
    obj=bpy.data.objects.new(curve.name,curve);stage.objects.link(obj);curve.materials.append(bone_mat)
    for pos in [h,t]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.009,location=pos)
        obj=bpy.context.object;move_collection(obj,stage);obj.data.materials.append(bone_mat)
render('rig-overlay.png',(0,-8,.91),(850,1000))

# A separate print-like scene presents the actual sprites at exactly 3x size.
# Image textures use nearest sampling; no AI repainting or synthetic mock screenshot.
board=bpy.data.scenes.new('Pixel review board')
bpy.context.window.scene=board
board.render.engine='CYCLES';board.cycles.samples=1;board.cycles.use_denoising=False
board.cycles.pixel_filter_type='BOX';board.cycles.filter_width=.01
board.render.resolution_x=1800;board.render.resolution_y=1000;board.render.resolution_percentage=100
board.render.image_settings.file_format='PNG';board.view_settings.view_transform='Standard'
bcdata=bpy.data.cameras.new('Board camera');bc=bpy.data.objects.new('Board camera',bcdata)
board.collection.objects.link(bc);bcdata.type='ORTHO';bcdata.ortho_scale=1800
bc.location=(900,500,100);bc.rotation_euler=(0,0,0);board.camera=bc


def emission_mat(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.node_tree.nodes.clear()
    out=m.node_tree.nodes.new('ShaderNodeOutputMaterial');em=m.node_tree.nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value=(*color,1);m.node_tree.links.new(em.outputs[0],out.inputs[0])
    return m


def board_plane(name,x,y,width,height,mat,z=0):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([(x,y,z),(x+width,y,z),(x+width,y+height,z),(x,y+height,z)],[],[(0,1,2,3)])
    layer=mesh.uv_layers.new()
    for d,uv in zip(layer.data,[(0,0),(1,0),(1,1),(0,1)]):d.uv=uv
    obj=bpy.data.objects.new(name,mesh);board.collection.objects.link(obj);mesh.materials.append(mat)


board_plane('Paper',0,0,1800,1000,emission_mat('Paper',(.83,.79,.70)))
font=bpy.data.fonts.load('C:/Windows/Fonts/msjh.ttc')
ink=emission_mat('Ink',(.021,.029,.032))


def label(text,x,y,size):
    data=bpy.data.curves.new(text,'FONT');data.body=text;data.font=font;data.size=size
    data.align_x='CENTER';data.align_y='CENTER'
    obj=bpy.data.objects.new(text,data);board.collection.objects.link(obj);obj.location=(x,y,2)
    data.materials.append(ink)


label('B 像素方向｜人體基底修正',900,940,40)
label('實際 Blender 輸出・192 × 224 像素・整數 3 倍放大',900,890,20)
for x,filename,title in [(18,'pixel-front.png','正面'),(612,'pixel-quarter.png','斜側面'),(1206,'pixel-side.png','側面')]:
    m=bpy.data.materials.new(filename);m.use_nodes=True;n=m.node_tree.nodes;n.clear();links=m.node_tree.links
    tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/filename));tex.interpolation='Closest'
    em=n.new('ShaderNodeEmission');links.new(tex.outputs['Color'],em.inputs['Color'])
    transparent=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader')
    links.new(tex.outputs['Alpha'],mix.inputs[0]);links.new(transparent.outputs[0],mix.inputs[1]);links.new(em.outputs[0],mix.inputs[2])
    out=n.new('ShaderNodeOutputMaterial');links.new(mix.outputs[0],out.inputs[0])
    board_plane(filename,x,184,576,672,m,1)
    label(title,x+288,145,28)
label('本輪只修人體與骨架；衣甲待基底確認後重製。',900,80,22)
label('底模來源：MakeHuman CC0 資產・比例／骨架／像素輸出由本專案調整・待美術審核',900,36,16)
board.render.filepath=str(OUT/'pixel-review.png');bpy.ops.render.render(write_still=True)
print('BODY_PIXEL_REVISION_OK '+json.dumps(report))
