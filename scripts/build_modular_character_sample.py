"""Build an original editable art prototype; run with Blender 5.1 --background.

No downloaded meshes, texture files, gameplay simulation, or damage rules.
Coordinates: metres, Z up, character faces -Y. All five modules stay separate.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'blender-assets' / 'samples' / 'modular-character-v01'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0


def material(name, color, metallic=0.0, roughness=0.72):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    return m


PALETTE = [
    material('Skin | warm clay', (0.52, 0.285, 0.155)),
    material('Hair | ink', (0.025, 0.032, 0.036)),
    material('Cloth | indigo', (0.035, 0.105, 0.14)),
    material('Cloth | shadow indigo', (0.025, 0.065, 0.087)),
    material('Trim | unbleached linen', (0.55, 0.46, 0.29)),
    material('Leather | oxblood', (0.21, 0.065, 0.038)),
    material('Armor | patinated iron', (0.12, 0.17, 0.16), 0.55, 0.5),
    material('Armor | bronze trim', (0.47, 0.29, 0.095), 0.65, 0.4),
    material('Wood | ash', (0.235, 0.115, 0.04)),
    material('Steel | spear blade', (0.43, 0.52, 0.52), 0.75, 0.3),
    material('Sash | vermilion', (0.47, 0.055, 0.025)),
    material('Eyes | linen white', (0.72, 0.66, 0.48)),
]

asset_collection = bpy.data.collections.new('CHARACTER | five editable modules')
scene.collection.children.link(asset_collection)
stage_collection = bpy.data.collections.new('PRESENTATION | not exported')
scene.collection.children.link(stage_collection)


class MeshBuilder:
    def __init__(self):
        self.vertices, self.faces, self.materials, self.weights = [], [], [], []

    def add(self, vertices, faces, mat=0, weights=None):
        offset = len(self.vertices)
        self.vertices.extend(tuple(v) for v in vertices)
        self.faces.extend(tuple(i + offset for i in f) for f in faces)
        self.materials.extend([mat] * len(faces))
        for v in vertices:
            self.weights.append(weights(Vector(v)) if callable(weights) else (weights or {'Chest': 1.0}))

    def loft(self, rings, n=12, mat=0, weights=None, caps=True):
        # rings = (centre x,y,z, radius x,y); faceted horizontal contours.
        verts = [(x + rx * math.cos(2 * math.pi * i / n),
                  y + ry * math.sin(2 * math.pi * i / n), z)
                 for x, y, z, rx, ry in rings for i in range(n)]
        faces = [(r*n+i, r*n+(i+1)%n, (r+1)*n+(i+1)%n, (r+1)*n+i)
                 for r in range(len(rings)-1) for i in range(n)]
        if caps:
            faces.extend([tuple(reversed(range(n))), tuple((len(rings)-1)*n+i for i in range(n))])
        self.add(verts, faces, mat, weights)

    def tube(self, start, end, profile, n=10, mat=0, weights=None):
        a, b = Vector(start), Vector(end)
        axis = (b-a).normalized()
        u = Vector((0, 1, 0))
        if abs(axis.dot(u)) > .95:
            u = Vector((1, 0, 0))
        u = axis.cross(u).normalized()
        v = axis.cross(u).normalized()
        verts = [a + (b-a)*t + u*(r1*math.cos(2*math.pi*i/n)) + v*(r2*math.sin(2*math.pi*i/n))
                 for t, r1, r2 in profile for i in range(n)]
        faces = [(j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i)
                 for j in range(len(profile)-1) for i in range(n)]
        faces += [tuple(reversed(range(n))), tuple((len(profile)-1)*n+i for i in range(n))]
        self.add(verts, faces, mat, weights)

    def box(self, center, size, mat=0, weights=None, rotation=0):
        cx, cy, cz = center
        sx, sy, sz = (x/2 for x in size)
        c, s = math.cos(rotation), math.sin(rotation)
        verts = [(cx+x*c-y*s, cy+x*s+y*c, cz+z)
                 for x,y,z in [(-sx,-sy,-sz),(sx,-sy,-sz),(sx,sy,-sz),(-sx,sy,-sz),
                               (-sx,-sy,sz),(sx,-sy,sz),(sx,sy,sz),(-sx,sy,sz)]]
        faces = [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        self.add(verts, faces, mat, weights)

    def object(self, name, collection=asset_collection):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        for m in PALETTE:
            mesh.materials.append(m)
        for p, idx in zip(mesh.polygons, self.materials):
            p.material_index = idx
        for i, weights in enumerate(self.weights):
            for bone, weight in weights.items():
                if weight > 0:
                    group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
                    group.add([i], weight, 'REPLACE')
        # Recalculate outward normals after all disconnected low-poly islands exist.
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        obj.select_set(False)
        return obj


def blend_height(v, low, high, za, zb):
    t = max(0, min(1, (v.z-za)/(zb-za)))
    return {low: 1-t, high: t}


def torso_weights(v):
    if v.z < 1.06:
        return blend_height(v, 'Pelvis', 'Spine', .92, 1.07)
    return blend_height(v, 'Spine', 'Chest', 1.07, 1.32)


JOINTS = {}
for sign, side in [(1, 'R'), (-1, 'L')]:
    JOINTS[side] = {
        'shoulder': Vector((sign*.275, 0, 1.47)),
        'elbow': Vector((sign*.427, -.016, 1.19)),
        'wrist': Vector((sign*.545, -.060, .955)),
        'hand': Vector((sign*.575, -.075, .865)),
        'hip': Vector((sign*.127, .012, .91)),
        'knee': Vector((sign*.155, -.010, .515)),
        'ankle': Vector((sign*.168, .003, .11)),
    }

rig_data = bpy.data.armatures.new('Shared humanoid | 22 bones')
rig = bpy.data.objects.new('02_Rig', rig_data)
asset_collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')


def bone(name, head, tail, parent=None, deform=True):
    b = rig_data.edit_bones.new(name)
    b.head, b.tail = head, tail
    b.use_deform = deform
    if parent:
        b.parent = rig_data.edit_bones[parent]
    return b


bone('Root', (0,0,0), (0,0,.18), deform=False)
bone('Pelvis', (0,0,.87), (0,0,1.035), 'Root')
bone('Spine', (0,0,1.035), (0,0,1.25), 'Pelvis')
bone('Chest', (0,0,1.25), (0,0,1.51), 'Spine')
bone('Neck', (0,0,1.51), (0,0,1.60), 'Chest')
bone('Head', (0,0,1.60), (0,0,1.83), 'Neck')
for side, j in JOINTS.items():
    bone('Clavicle.'+side, (0,0,1.48), j['shoulder'], 'Chest')
    bone('UpperArm.'+side, j['shoulder'], j['elbow'], 'Clavicle.'+side)
    bone('Forearm.'+side, j['elbow'], j['wrist'], 'UpperArm.'+side)
    bone('Hand.'+side, j['wrist'], j['hand'], 'Forearm.'+side)
    bone('Thigh.'+side, j['hip'], j['knee'], 'Pelvis')
    bone('Shin.'+side, j['knee'], j['ankle'], 'Thigh.'+side)
    bone('Foot.'+side, j['ankle'], (j['ankle'].x,-.145,.065), 'Shin.'+side)
    bone('Toe.'+side, (j['ankle'].x,-.145,.065), (j['ankle'].x,-.22,.065), 'Foot.'+side)
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front = True
rig_data.display_type = 'OCTAHEDRAL'
rig.select_set(False)


def arm_weights(v, side):
    return blend_height(v, 'Forearm.'+side, 'UpperArm.'+side, 1.13, 1.25)


def leg_weights(v, side):
    if v.z >= .82:
        return blend_height(v, 'Thigh.'+side, 'Pelvis', .83, .95)
    return blend_height(v, 'Shin.'+side, 'Thigh.'+side, .46, .57)


body = MeshBuilder()
body.loft([(0,.025,.82,.17,.125),(0,.024,.92,.224,.140),(0,.02,1.04,.193,.125),
           (0,.012,1.13,.198,.128),(0,.005,1.29,.254,.150),(0,0,1.42,.283,.158),
           (0,0,1.49,.247,.130),(0,0,1.535,.105,.077)], weights=torso_weights)
body.loft([(0,0,1.51,.073,.066),(0,0,1.61,.071,.066)], n=10, weights={'Neck':1})
body.loft([(0,-.020,1.575,.055,.057),(0,-.023,1.607,.092,.076),
           (0,-.016,1.656,.115,.098),(0,-.002,1.715,.125,.112),
           (0,.003,1.77,.12,.110),(0,.006,1.82,.082,.08),(0,.005,1.834,.025,.025)],
          n=12, weights={'Head':1})
# A deliberately simplified adult base; no anatomical interior or genital detail.
for side, j in JOINTS.items():
    s = 1 if side == 'R' else -1
    body.loft([(s*.27,0,1.375,.059,.069),(s*.27,0,1.46,.106,.108),
               (s*.255,0,1.525,.06,.066),(s*.25,0,1.536,.018,.024)],
              n=10,weights={'UpperArm.'+side:1})
    body.tube(j['shoulder'],j['elbow'],[(0,.104,.107),(.2,.101,.104),(.55,.088,.095),(1,.064,.072)],
              weights=lambda v, side=side: arm_weights(v,side))
    body.tube(j['elbow'],j['wrist'],[(0,.064,.072),(.28,.079,.075),(.62,.064,.062),(1,.043,.043)],
              weights=lambda v, side=side: arm_weights(v,side))
    body.tube(j['wrist'],j['hand'],[(0,.045,.042),(.35,.05,.048),(.8,.05,.045),(1,.035,.033)],
              n=8,weights={'Hand.'+side:1})
    # Thumb block follows the hand. Individual finger rigs are outside this sample.
    body.tube((s*.538,-.099,.926),(s*.565,-.12,.887),[(0,.022,.023),(1,.024,.023)],
              n=6,weights={'Hand.'+side:1})
    body.tube(j['hip'],j['knee'],[(0,.109,.119),(.22,.124,.127),(.65,.10,.103),(1,.068,.077)],
              weights=lambda v, side=side: leg_weights(v,side))
    body.tube(j['knee'],j['ankle'],[(0,.068,.077),(.30,.084,.086),(.70,.059,.064),(1,.038,.043)],
              weights=lambda v, side=side: leg_weights(v,side))
    x=j['ankle'].x
    body.loft([(x,-.065,.022,.064,.140),(x,-.062,.072,.064,.14),(x,-.027,.12,.043,.085)],
              n=8,weights={'Foot.'+side:1})
    body.tube((s*.119,.006,1.666),(s*.135,.006,1.72),[(0,.021,.028),(1,.019,.026)],
              n=6,weights={'Head':1})
    body.box((s*.053,-.109,1.707),(.038,.013,.012),11,{'Head':1})
    body.box((s*.05,-.117,1.706),(.012,.009,.013),1,{'Head':1})
    body.box((s*.05,-.113,1.730),(.054,.018,.012),1,{'Head':1},rotation=s*.08)
body.add([(-.023,-.112,1.719),(.023,-.112,1.719),(-.021,-.12,1.671),(.021,-.12,1.671),
          (0,-.153,1.675)],[(0,1,4),(0,4,2),(1,3,4),(2,4,3),(0,2,3,1)],weights={'Head':1})
body.box((0,-.11,1.638),(.052,.007,.007),5,{'Head':1})
# Hair cap, side locks, topknot, and its woven red tie.
body.loft([(0,.007,1.766,.124,.112),(0,.009,1.814,.104,.104),
           (0,.012,1.842,.052,.052)],n=12,mat=1,weights={'Head':1})
body.loft([(0,.033,1.83,.040,.040),(0,.033,1.91,.047,.046),(0,.033,1.93,.028,.03)],
          n=8,mat=1,weights={'Head':1})
body.loft([(0,.033,1.844,.044,.044),(0,.033,1.865,.045,.045)],n=8,mat=10,weights={'Head':1})
for s in [-1,1]:
    body.box((s*.116,.012,1.748),(.020,.10,.045),1,{'Head':1})
body_obj = body.object('01_Body')
body_obj['module'] = 'Unclothed adult base, simplified hands and anatomy'

clothes = MeshBuilder()
# Generous tunic clearance and deliberately open hem/collar for replaceable clothing.
clothes.loft([(0,.022,.755,.320,.220),(0,.022,.90,.290,.20),
              (0,.022,.99,.245,.17),
              (0,.012,1.06,.214,.15),(0,0,1.28,.277,.176),
              (0,0,1.43,.30,.182),(0,0,1.50,.27,.153),(0,0,1.553,.093,.093)],
             mat=2,weights=torso_weights,caps=False)
# Hem trim, sleeves, linen cuffs, cloth trousers and independent boot geometry in clothes module.
clothes.loft([(0,.022,.755,.323,.223),(0,.022,.783,.317,.22)],mat=4,weights={'Pelvis':1},caps=False)
for side,j in JOINTS.items():
    s = 1 if side == 'R' else -1
    clothes.loft([(s*.27,0,1.365,.074,.082),(s*.27,0,1.465,.134,.133),
                  (s*.255,0,1.54,.093,.096),(s*.25,0,1.559,.025,.034)],
                 n=10,mat=2,weights={'UpperArm.'+side:1})
    clothes.tube(j['shoulder'],j['elbow'],[(0,.118,.122),(.27,.12,.123),(.65,.103,.114),(1,.088,.098)],
                 mat=2,weights=lambda v,side=side:arm_weights(v,side))
    clothes.tube(j['elbow'],j['wrist'],[(0,.088,.098),(.38,.096,.094),(.84,.063,.061),(.9,.060,.060)],
                 mat=2,weights=lambda v,side=side:arm_weights(v,side))
    clothes.tube(j['elbow'],j['wrist'],[(.84,.066,.065),(.94,.059,.059)],mat=4,
                 weights={'Forearm.'+side:1})
    clothes.tube(j['hip'],j['knee'],[(0,.125,.133),(.30,.142,.14),(.65,.134,.127),(1,.098,.100)],
                 mat=3,weights=lambda v,side=side:leg_weights(v,side))
    clothes.tube(j['knee'],j['ankle'],[(0,.098,.100),(.37,.093,.103),(.57,.083,.08)],
                 mat=3,weights=lambda v,side=side:leg_weights(v,side))
    x=j['ankle'].x
    clothes.loft([(x,0,.094,.057,.065),(x,.004,.19,.060,.070),(x,0,.33,.082,.085)],
                 mat=5,n=10,weights={'Shin.'+side:1},caps=False)
    clothes.loft([(x,-.065,.010,.073,.153),(x,-.065,.065,.075,.151),(x,-.025,.125,.06,.10)],
                 mat=5,n=10,weights={'Foot.'+side:1})
    for z in [.16,.21,.26,.31]:
        r=.057+(z-.10)*.095
        clothes.loft([(x,0,z,r+.006,r+.019),(x,0,z+.014,r+.008,r+.020)],
                     n=10,mat=4,weights={'Shin.'+side:1},caps=False)
# Raised crossed collar bands, above armor neckline.
clothes.tube((-.085,-.063,1.557),(.085,-.183,1.393),[(0,.017,.016),(1,.02,.016)],n=4,mat=4,weights={'Chest':1})
clothes.tube((.085,-.063,1.557),(-.085,-.183,1.393),[(0,.017,.016),(1,.02,.016)],n=4,mat=4,weights={'Chest':1})
clothes.loft([(0,.015,1.015,.234,.177),(0,.015,1.087,.237,.18)],mat=10,weights=torso_weights)
clothes.box((.068,-.179,1.05),(.085,.035,.07),5,{'Spine':1})
clothes.box((.068,-.199,1.05),(.046,.009,.037),7,{'Spine':1})
clothes.add([(.018,-.185,1.028),(.097,-.185,1.025),(.13,-.201,.73),(.035,-.211,.70)],
            [(0,1,2,3)],10,{'Pelvis':1})
clothes_obj = clothes.object('03_Clothes')

armor = MeshBuilder()
# Closed thickness at upper/lower edges, open neck/arm apertures; includes front and back.
outer=[(0,.006,1.115,.251,.191),(0,.006,1.29,.295,.203),(0,.006,1.475,.29,.194)]
inner=[(x,y,z,rx-.009,ry-.009) for x,y,z,rx,ry in outer]
armor.loft(outer+list(reversed(inner)),n=16,mat=5,weights={'Chest':1},caps=False)
# Four rows of iron lamellae, 16 pieces around the chest, with bronze fastening marks.
for row in range(4):
    z=1.147+row*.079
    rx=.257+(z-1.115)/.175*.044 if z<1.29 else .301-(z-1.29)*.03
    ry=.209
    for col in range(16):
        theta=2*math.pi*col/16
        x=rx*math.cos(theta)
        y=.006+ry*math.sin(theta)
        # Box local y points outward; normal and tangent follow ellipse.
        angle=math.atan2(ry*math.cos(theta),-rx*math.sin(theta))
        armor.box((x,y,z),(.082,.018,.072),6,{'Chest':1},rotation=angle)
        nx,ny=-math.sin(angle),math.cos(angle)
        armor.box((x+nx*.012,y+ny*.012,z+.023),(.022,.006,.007),7,{'Chest':1},rotation=angle)
for z,rx,ry in [(1.107,.254,.20),(1.478,.301,.211)]:
    armor.loft([(0,.006,z,rx,ry),(0,.006,z+.016,rx,ry)],n=16,mat=7,weights={'Chest':1},caps=False)
for s in [-1,1]:
    armor.tube((s*.199,-.166,1.448),(s*.199,-.025,1.525),[(0,.035,.014),(1,.035,.014)],
               n=4,mat=5,weights={'Chest':1})
    armor.tube((s*.199,-.025,1.525),(s*.199,.171,1.449),[(0,.035,.014),(1,.035,.014)],
               n=4,mat=5,weights={'Chest':1})
    armor.box((s*.199,-.156,1.49),(.047,.018,.035),7,{'Chest':1})
armor_obj=armor.object('04_ChestArmor')

weapon=MeshBuilder()
sx,sy=.575,-.105
weapon.tube((sx,sy,.09),(sx,sy,2.115),[(0,.015,.015),(.55,.018,.018),(1,.014,.014)],n=8,mat=8)
weapon.tube((sx,sy,2.08),(sx,sy,2.19),[(0,.024,.024),(1,.020,.020)],n=8,mat=7)
weapon.tube((sx,sy,.08),(sx,sy,.19),[(0,.008,.008),(1,.019,.019)],n=8,mat=9)
# Four-sided diamond blade; functional silhouette without texture maps.
weapon.add([(sx,sy,2.49),(sx-.066,sy,2.245),(sx,sy-.017,2.245),(sx+.066,sy,2.245),
            (sx,sy+.017,2.245),(sx,sy,2.13)],
           [(0,1,2),(0,2,3),(0,3,4),(0,4,1),(5,2,1),(5,3,2),(5,4,3),(5,1,4)],9)
for z in [.835,.862,.889,.916,.943,.97]:
    weapon.tube((sx,sy,z),(sx,sy,z+.018),[(0,.021,.021),(1,.021,.021)],n=8,mat=5)
weapon.tube((sx,sy,2.02),(sx,sy,2.074),[(0,.027,.027),(1,.027,.027)],n=8,mat=10)
for dx,dy in [(-.02,-.025),(.02,-.014),(.008,.015)]:
    weapon.add([(sx+dx,sy+dy,2.035),(sx+dx+.02,sy+dy,2.027),
                (sx+dx+.045,sy+dy-.02,1.88),(sx+dx+.018,sy+dy-.024,1.895)],[(0,1,2,3)],10)
weapon_obj=weapon.object('05_Weapon_Spear')
# Rigid prop attachment. Rest-space transform must be preserved for export.
bpy.context.view_layer.update()
rest_world=weapon_obj.matrix_world.copy()
weapon_obj.parent=rig
weapon_obj.parent_type='BONE'
weapon_obj.parent_bone='Hand.R'
bpy.context.view_layer.update()
weapon_obj.matrix_world=rest_world
weapon_obj.vertex_groups.clear()

for obj in [body_obj,clothes_obj,armor_obj]:
    obj.parent=rig
    modifier=obj.modifiers.new('Shared skeleton deformation','ARMATURE')
    modifier.object=rig
    modifier.use_deform_preserve_volume=False

# Small rig check: two reversible poses rather than promising a finished animation set.
for p in rig.pose.bones:
    p.rotation_mode='XYZ'
POSES={1:{}, 25:{'UpperArm.L':(.18,0,.12),'Forearm.L':(.38,0,0),
                'Head':(0,.08,0),'Forearm.R':(.075,0,0)},
       49:{'UpperArm.L':(-.08,0,-.05),'Forearm.L':(.12,0,0),'Head':(0,-.08,0)},73:{}}
for frame, values in POSES.items():
    for p in rig.pose.bones:
        p.rotation_euler=values.get(p.name,(0,0,0))
        p.keyframe_insert(data_path='rotation_euler', frame=frame, group=p.name)
rig.animation_data.action.name='Rig_Check_3s'
scene.frame_start,scene.frame_end=1,73
scene.render.fps=24
scene.frame_set(1)
bpy.context.view_layer.update()

# Export only the actual character modules, with their shared rig and test action.
bpy.ops.object.select_all(action='DESELECT')
for obj in asset_collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'character.glb'),export_format='GLB',
    use_selection=True,export_animations=True,export_animation_mode='ACTIONS',
    export_skins=True,export_yup=True,export_apply=False)
bpy.ops.object.select_all(action='DESELECT')


def evaluated_points(obj,frame):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [evaluated.matrix_world@v.co for v in evaluated.data.vertices]


stats={'blender':bpy.app.version_string,'units':'metres','up':'Z','forward':'-Y',
       'skeleton_bones':len(rig.data.bones),'modules':{},'checks':{},
       'runtime_performance':'NOT_MEASURED','damage_gameplay':'NOT_IMPLEMENTED'}
for obj in [body_obj,clothes_obj,armor_obj,weapon_obj]:
    obj.data.calc_loop_triangles()
    stats['modules'][obj.name]={'vertices':len(obj.data.vertices),'triangles':len(obj.data.loop_triangles),
        'used_materials':len(set(p.material_index for p in obj.data.polygons))}
    if obj!=weapon_obj:
        assert all(abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in obj.data.vertices),obj.name
        assert obj.modifiers[0].object==rig
stats['checks']['all_skinned_vertices_normalized']=True
stats['checks']['one_shared_skeleton']=True
stats['checks']['weapon_parent']='Hand.R'
for obj in [body_obj,clothes_obj,weapon_obj]:
    a,b=evaluated_points(obj,1),evaluated_points(obj,25)
    delta=max((x-y).length for x,y in zip(a,b))
    assert delta>.001,(obj.name,delta)
    stats['checks'][obj.name+'_pose_displacement_m']=round(delta,6)
stats['total_triangles']=sum(m['triangles'] for m in stats['modules'].values())
stats['glb_bytes']=(OUT/'character.glb').stat().st_size
(OUT/'build-report.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
scene.frame_set(1)

# Presentation scene: warm paper backdrop, soft studio light, deliberate orthographic views.
paper=material('Stage | sand',(.60,.55,.43))
plinth=material('Stage | limestone',(.32,.34,.29))
ink=material('Type | charcoal',(.008,.02,.022))
ink.node_tree.nodes.clear()
ink_out=ink.node_tree.nodes.new('ShaderNodeOutputMaterial')
ink_emission=ink.node_tree.nodes.new('ShaderNodeEmission')
ink_emission.inputs['Color'].default_value=(.008,.02,.022,1)
ink.node_tree.links.new(ink_emission.outputs[0],ink_out.inputs['Surface'])
teal=material('Rig display | turquoise',(.025,.47,.43),.2,.5)
scene.world=bpy.data.worlds.new('Studio ambience')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.72,.80,.88,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.4


def stage_link(obj):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    stage_collection.objects.link(obj)
    return obj


def ground():
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.065))
    obj=stage_link(bpy.context.object)
    obj.name='Studio floor'
    obj.data.materials.append(paper)


def platform(x,y,r=.88):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=r,depth=.055,location=(x,y,-.032))
    obj=stage_link(bpy.context.object)
    obj.name='Display plinth'
    obj.data.materials.append(plinth)


def aim(obj,point):
    obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()


def light(name,location,power,size,point=(0,0,1)):
    data=bpy.data.lights.new(name,'AREA')
    obj=bpy.data.objects.new(name,data)
    stage_collection.objects.link(obj)
    obj.location=location
    data.energy=power
    data.shape='DISK'
    data.size=size
    aim(obj,point)


ground()
light('Key softbox',(-3,-4,7),700,5)
light('Cool fill',(4,-1,4),360,4)
light('Rim',(0,4,6),950,3)
camera_data=bpy.data.cameras.new('Sample orthographic camera')
camera=bpy.data.objects.new('Sample orthographic camera',camera_data)
stage_collection.objects.link(camera)
camera_data.type='ORTHO'
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.image_settings.file_format='PNG'
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'


def configure_camera(location,target,scale,width,height):
    camera.location=location
    aim(camera,target)
    camera_data.ortho_scale=scale
    scene.render.resolution_x,scene.render.resolution_y=width,height


def render(filename):
    scene.render.filepath=str(OUT/filename)
    bpy.ops.render.render(write_still=True)


platform(0,0,.86)
configure_camera((4,-7,3.8),(0,0,1.18),3.25,1200,1400)
render('assembled.png')
scene.frame_set(25)
render('pose-check.png')
scene.frame_set(1)

# Save the source with presentation camera, all four mesh modules, and the genuine rig.
for area in bpy.context.screen.areas if bpy.context.screen else []:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'character.blend'))

# Exploded catalogue: create display copies only AFTER saving/exporting the source.
# The turquoise renderable skeleton derives directly from edit-bone head/tail data.
for obj in asset_collection.objects:
    obj.hide_render=True
for obj in list(stage_collection.objects):
    if obj.name.startswith('Display plinth'):
        obj.hide_render=True


def display_copy(source,x):
    evaluated=source.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=bpy.data.meshes.new_from_object(evaluated)
    obj=bpy.data.objects.new('Display '+source.name,mesh)
    stage_collection.objects.link(obj)
    obj.matrix_world=source.matrix_world.copy()
    obj.location.x+=x
    return obj


xs=[-3.1,-1.55,0,1.55,3.1]
display_copy(body_obj,xs[0])
display_copy(clothes_obj,xs[2])
display_copy(armor_obj,xs[3])
display_copy(weapon_obj,xs[4]-.575)
skel=MeshBuilder()
for b in rig.data.bones:
    if not b.use_deform:
        continue
    h,t=b.head_local.copy(),b.tail_local.copy()
    h.x+=xs[1];t.x+=xs[1]
    skel.tube(h,t,[(0,.009,.009),(.25,.032,.032),(1,.005,.005)],n=4)
skel_obj=skel.object('Display actual skeleton',stage_collection)
skel_obj.data.materials.clear()
skel_obj.data.materials.append(teal)
for p in skel_obj.data.polygons:
    p.material_index=0
for x in xs:
    platform(x,0,.63)

font_path=Path('C:/Windows/Fonts/msjh.ttc')
font=bpy.data.fonts.load(str(font_path)) if font_path.exists() else None
configure_camera((0,-12,5.4),(0,0,1.20),8.1,2100,1050)


def text_in_camera(name,text,x,y,size):
    data=bpy.data.curves.new(name,'FONT')
    data.body=text
    data.size=size
    data.align_x='CENTER'
    data.align_y='CENTER'
    if font:
        data.font=font
    obj=bpy.data.objects.new(name,data)
    stage_collection.objects.link(obj)
    data.materials.append(ink)
    q=camera.rotation_euler.to_quaternion()
    # A fixed camera-space layout prevents perspective skew of labels.
    obj.location=camera.location+q@Vector((x,y,-10))
    obj.rotation_euler=camera.rotation_euler


text_in_camera('Title','分件角色樣品  /  01',0,1.72,.18)
text_in_camera('Subtitle','Blender 實際模型・同一套骨架・衣物與裝備可獨立替換',0,1.41,.075)
for x,label,detail in zip(xs,['人體','骨架','衣服','胸甲','武器'],
                           ['簡化成年人體基底','22 根骨骼／共用動作','上衣・長褲・腰帶・靴','前後護甲／肩帶','長槍／固定於右手']):
    text_in_camera(label,label,x,-1.52,.15)
    text_in_camera(label+' detail',detail,x,-1.74,.07)
text_in_camera('Footer','原創低面數試作  |  尚未定案的美術風格  |  未實作傷害功能',0,-1.94,.065)
render('modules.png')
print('SAMPLE_BUILD_OK '+json.dumps(stats,ensure_ascii=False))
