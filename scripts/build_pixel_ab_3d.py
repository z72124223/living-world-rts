"""A second, genuinely geometric 3D-to-pixel sample for the A/B art review.

Keeps the rejected v01 source untouched. Reproportions evaluated geometry, uses
explicit hue-shifted colour ramps, and renders at native 128 and 256 pixels.
The clothing is still a static study, not a completed skinned game character.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'blender-assets/samples/pixel-pipeline-ab-v01'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'blender-assets/samples/female-light-armour-v01/female-light-armour.blend'))
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene

# Evaluate the source pose once, leaving source skeleton provenance in v01.
# All parts stay separate and editable in this static comparison source.
deps = bpy.context.evaluated_depsgraph_get()
for o in list(scene.objects):
    if o.type not in {'MESH', 'CURVE'} or o.name == 'Ground':
        continue
    world = o.matrix_world.copy()
    d = bpy.data.meshes.new_from_object(o.evaluated_get(deps), depsgraph=deps)
    n = bpy.data.objects.new(o.name + ' | study', d)
    for col in list(o.users_collection):
        col.objects.link(n)
    n.matrix_world = world
    n['source_part'] = o.name
    bpy.data.objects.remove(o, do_unlink=True)
for o in list(scene.objects):
    if o.type == 'ARMATURE':
        bpy.data.objects.remove(o, do_unlink=True)

def smooth(a, b, x):
    t = max(0., min(1., (x-a)/(b-a)))
    return t*t*(3-2*t)

def point(p):
    # A compact upper body and slightly broader shoulders/hips keep the armour
    # silhouette legible. Shorten the long lower legs relative to the concept.
    x, y, z = p
    if z < .32:
        zz = z*.91
    elif z < .96:
        zz = .2912 + (z-.32)*.95
    elif z < 1.35:
        zz = .8992 + (z-.96)*.98
    else:
        zz = 1.2814 + (z-1.35)
    body_w = 1.08 + .055 * math.exp(-((z-1.25)/.18)**2)
    head_blend = smooth(1.35, 1.42, z)
    x *= body_w*(1-head_blend) + 1.01*head_blend
    return Vector((x,y,zz))

for o in scene.objects:
    if o.type != 'MESH' or o.name == 'Ground':
        continue
    name = o.get('source_part', '')
    inv = o.matrix_world.inverted()
    # Smaller eyes and restrained brows avoid the earlier owl-like expression.
    side = 1 if name.endswith(' L') else -1
    eye_part = name.startswith(('Almond eye', 'Iris ', 'Eye glint', 'Upper lash', 'Lower outer lash', 'Brow '))
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        if eye_part:
            cx = side*.036
            p.x = cx + (p.x-cx)*.82
            p.z = 1.516 + (p.z-1.516)*.72
            # Follow the face envelope as the drawn features move inward.
            p.y -= .0007
        if name.startswith('Head |'):
            # Reduce the wide lower cheek while retaining a broad eye plane.
            p.x *= 1 - .08*math.exp(-((p.z-1.446)/.034)**2)
        if name.startswith('High ponytail lock'):
            t = smooth(1.37, 1.67, p.z)
            p.x += .055*(1-t)
            p.y += .015*(1-t)
        if name.startswith('Body |') and p.z < 1.2:
            # Bring the fingertips in; same retained source hand topology.
            pivot = Vector((.205,-.15,1.03)) if p.x>0 else Vector((-.24,-.025,.90))
            p = pivot+(p-pivot)*.91
        v.co = inv @ point(p)
    o.data.update()
    if 'lamella' in name:
        for poly in o.data.polygons:
            poly.use_smooth = False

def lin(n):
    n=n/255
    return n/12.92 if n<=.04045 else ((n+.055)/1.055)**2.4

def rgb(hex_string):
    h=hex_string.lstrip('#')
    return tuple(lin(int(h[i:i+2],16)) for i in (0,2,4))

# Four deliberately chosen tones per material; bright skin, cool iron shadows,
# subdued gold and saturated red remain distinct at small output sizes.
palettes = {
    'skin': ['b97d68','d49b7a','edbd92','ffdaad'],
    'hair': ['151921','24282e','383e43','566067'],
    'cloth': ['1d2938','2b424c','416269','66817e'],
    'cloth_hi': ['283842','405861','627c7c','8ba199'],
    'iron': ['192129','29343b','424d50','67706a'],
    'leather': ['30272b','4a3833','72533d','a07a50'],
    'leather_hi': ['493329','74513a','a17c4e','c59e67'],
    'gold': ['594336','8d6b3f','bf9957','ead08b'],
    'red': ['542a32','863634','b94d3b','e37b4d'],
    'ivory': ['746955','a49677','d5c8a4','f1e5c2'],
}

def palette_for(name):
    if name == 'Warm skin': return palettes['skin']
    if name == 'Ink black hair': return palettes['hair']
    if name == 'Muted warm hair ribbons': return palettes['hair']
    if name.startswith('Blackened iron'): return palettes['iron']
    if name in ('Teal seams',): return ['17252e','263940','394f52','4d6867']
    if name == 'Teal fold highlights': return palettes['cloth_hi']
    if name == 'Deep teal linen': return palettes['cloth']
    if 'Bronze' in name or 'bronze' in name: return palettes['gold']
    if name == 'Umber leather': return palettes['leather']
    if name == 'Leather wear and straps': return palettes['leather_hi']
    if name == 'Dark leather soles': return ['171d25','27272a','423832','625343']
    if name in ('Vermilion sash','Sash woven edge'): return palettes['red']
    if name == 'Ivory collar lining': return palettes['ivory']
    if name == 'Warm ivory eyes': return ['b2947e','d4bea0','ede0c4','fff1d5']
    if name in ('Brows lashes and seams','Dark hazel iris'): return ['242329']*4
    if name == 'Eye catchlight': return ['fff0d1']*4
    if name == 'Muted terracotta lips': return ['9b5b50','b66d59','c68365','d79977']
    return ['ded7c8']*4

for m in list(bpy.data.materials):
    if not m.use_nodes: continue
    tones=palette_for(m.name)
    m.diffuse_color=(*rgb(tones[2]),1)
    n=m.node_tree.nodes; n.clear(); links=m.node_tree.links
    geom=n.new('ShaderNodeNewGeometry')
    dot=n.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT'
    dot.inputs[1].default_value=Vector((-.65,-.85,1.2)).normalized()
    links.new(geom.outputs['Normal'],dot.inputs[0])
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.interpolation='CONSTANT'
    for e in list(ramp.color_ramp.elements)[1:]: ramp.color_ramp.elements.remove(e)
    for i,pos in enumerate((0,.18,.50,.81)):
        e=ramp.color_ramp.elements[0] if i==0 else ramp.color_ramp.elements.new(pos)
        e.position=pos;e.color=(*rgb(tones[i]),1)
    links.new(dot.outputs['Value'],ramp.inputs[0])
    emission=n.new('ShaderNodeEmission');links.new(ramp.outputs['Color'],emission.inputs['Color'])
    output=n.new('ShaderNodeOutputMaterial');links.new(emission.outputs[0],output.inputs['Surface'])
    m['palette_srgb']=','.join(tones)

scene.render.engine='CYCLES'
scene.cycles.samples=4
scene.cycles.use_denoising=False
scene.cycles.pixel_filter_type='BOX'
scene.cycles.filter_width=.01
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
scene.view_settings.exposure=0
scene.view_settings.gamma=1
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.resolution_percentage=100
scene.render.film_transparent=False
scene.world.color=(.1,.1,.1)
scene.render.use_freestyle=True
lines=scene.view_layers[0].freestyle_settings.linesets[0]
lines.select_crease=False
lines.select_material_boundary=False
lines.select_border=False
lines.select_silhouette=True
lines.select_external_contour=True
if lines.linestyle is None:lines.linestyle=bpy.data.linestyles.new('Selective ink silhouette')
lines.linestyle.color=rgb('22232a')
lines.linestyle.thickness=.60

# Small deliberately flat contact shadow, identical background to the 2D brief.
shadow=bpy.data.materials.new('Flat contact shadow')
shadow.diffuse_color=(*rgb('bdb7ab'),1);shadow.use_nodes=True
ns=shadow.node_tree.nodes;ns.clear()
em=ns.new('ShaderNodeEmission');em.inputs[0].default_value=(*rgb('bdb7ab'),1)
op=ns.new('ShaderNodeOutputMaterial');shadow.node_tree.links.new(em.outputs[0],op.inputs[0])
bpy.ops.mesh.primitive_circle_add(vertices=48, radius=1, fill_type='NGON',location=(.035,.01,.001))
disk=bpy.context.object;disk.name='Small flat ground shadow';disk.scale=(.285,.18,1);disk.data.materials.append(shadow)

cam=scene.camera
cam.data.type='ORTHO'
cam.data.ortho_scale=1.85
target=Vector((.025,0,.835))
cam.location=(3.9,-8,3.0)
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
scene['sample_origin']='Actual evaluated 3D geometry rendered in Blender. No generated image applied to model.'
scene['sample_status']='Static A/B art comparison; outfit not rigged; user review pending'
scene['reference']='female-character-b-v01.png, centre light armour'
scene.render.resolution_x=256;scene.render.resolution_y=256
scene.render.filepath=str(OUT/'3d-pixel-256.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'3d-pixel-source.blend'))
bpy.ops.render.render(write_still=True)
scene.render.resolution_x=128;scene.render.resolution_y=128
scene.render.filepath=str(OUT/'3d-pixel-128.png')
bpy.ops.render.render(write_still=True)

# Additional angles substantiate that the sample is a complete volume.
scene.render.resolution_x=256;scene.render.resolution_y=256
for name,loc in [('front',(0,-8,2.8)),('back',(-3.9,8,3.0))]:
    cam.location=loc
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/('3d-'+name+'-256.png'))
    bpy.ops.render.render(write_still=True)

report={'origin':scene['sample_origin'],'blender':bpy.app.version_string,
    'reference':scene['reference'],'source_model':'../female-light-armour-v01/female-light-armour.blend',
    'revision':'Reproportioned geometry, smaller facial features, individually chosen hue-shifted palettes',
    'resolutions':[128,256],'animation_ready':False,'art_approved':False,
    'separate_mesh_objects':sum(o.type=='MESH' for o in scene.objects),
    'rendered_views':['three-quarter','front','back']}
(OUT/'3d-build-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PIXEL_AB_3D_COMPLETE '+json.dumps(report,ensure_ascii=False))
