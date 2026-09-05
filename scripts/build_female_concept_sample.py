"""Static, editable light-armour study from female-character-b-v01.png.

Run in Blender 5.1 with --background --factory-startup --python-exit-code 1.
The body and posing skeleton use pinned CC0 MakeHuman asset data. Hair, face
accents, garments, armour and weapon are constructed here as real geometry.
This is an offline art source, not an optimized or animation-ready game unit.
"""
import bpy
import hashlib
import json
import math
import random
import sys
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'blender-assets/sources/makehuman-a8bc2d5'
OUT = ROOT / 'blender-assets/samples/female-light-armour-v01'
OUT.mkdir(parents=True, exist_ok=True)
random.seed(71)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
COL = {}
for name in ['01 Body and posing rig', '02 Face and hair', '03 Cloth and boots',
             '04 Lamellar armour', '05 Belt and sword', '90 Studio']:
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    COL[name[:2]] = c


def relocate(o, group):
    for c in list(o.users_collection):
        c.objects.unlink(o)
    COL[group].objects.link(o)
    return o


def mat(name, color, metal=0., rough=.7):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    return m


skin = mat('Warm skin', (.63, .365, .205), rough=.82)
hair = mat('Ink black hair', (.009, .011, .008), rough=.76)
hair_hi = mat('Muted warm hair ribbons', (.016, .019, .014), rough=.78)
ink = mat('Brows lashes and seams', (.016, .010, .008))
eye_white = mat('Warm ivory eyes', (.82, .75, .58))
iris = mat('Dark hazel iris', (.055, .030, .014), rough=.36)
shine = mat('Eye catchlight', (.98, .86, .65))
lip = mat('Muted terracotta lips', (.35, .105, .065))
teal = mat('Deep teal linen', (.027, .081, .082))
teal_hi = mat('Teal fold highlights', (.045, .105, .105))
teal_dark = mat('Teal seams', (.015, .039, .039))
lining = mat('Ivory collar lining', (.41, .36, .25))
red = mat('Vermilion sash', (.265, .043, .020))
red_hi = mat('Sash woven edge', (.38, .085, .031))
leather = mat('Umber leather', (.091, .045, .020))
leather_hi = mat('Leather wear and straps', (.17, .085, .037))
sole = mat('Dark leather soles', (.026, .021, .015))
bronze = mat('Antique bronze edges', (.33, .205, .073), metal=.62, rough=.55)
bronze_hi = mat('Bronze rivets', (.54, .34, .116), metal=.58, rough=.5)
iron = [mat('Blackened iron %02d' % i, c, metal=.38, rough=.55)
        for i, c in enumerate([(.043, .052, .045), (.054, .060, .049),
                                (.032, .042, .039), (.064, .066, .050)])]


def mesh(name, verts, faces, material, group, smooth=True):
    d = bpy.data.meshes.new(name)
    d.from_pydata(verts, [], faces)
    d.materials.append(material)
    d.update()
    o = bpy.data.objects.new(name, d)
    COL[group].objects.link(o)
    for f in d.polygons:
        f.use_smooth = smooth
    return o


def bevel(o, amount=.002, segments=1):
    mod = o.modifiers.new('Soft manufactured edges', 'BEVEL')
    mod.width = amount
    mod.segments = segments
    return o


def sphere(name, loc, scale, material, group='02', segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=loc)
    o = relocate(bpy.context.object, group)
    o.name = name
    o.scale = scale
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


def curve(name, points, radius, material, group, closed=False, resolution=2):
    d = bpy.data.curves.new(name, 'CURVE')
    d.dimensions = '3D'
    d.resolution_u = 6
    d.bevel_depth = radius
    d.bevel_resolution = min(resolution, 1)
    s = d.splines.new('BEZIER')
    s.bezier_points.add(len(points)-1)
    for p, v in zip(s.bezier_points, points):
        p.co = v
        p.handle_left_type = 'AUTO'
        p.handle_right_type = 'AUTO'
    s.use_cyclic_u = closed
    o = bpy.data.objects.new(name, d)
    COL[group].objects.link(o)
    d.materials.append(material)
    return o


def tube(name, points, radii, material, group, sides=12, flatten=1., caps=True):
    pts = list(map(Vector, points))
    vs = []
    fs = []
    for i, (p, r) in enumerate(zip(pts, radii)):
        t = (pts[min(i+1, len(pts)-1)]-pts[max(0, i-1)]).normalized()
        u = t.cross(Vector((0, 1, 0)))
        if u.length < .01:
            u = t.cross(Vector((1, 0, 0)))
        u.normalize()
        v = t.cross(u).normalized()
        for j in range(sides):
            a = j*math.tau/sides
            vs.append(p + r*(math.cos(a)*u + flatten*math.sin(a)*v))
        if i:
            for j in range(sides):
                fs.append(((i-1)*sides+j, (i-1)*sides+(j+1)%sides,
                           i*sides+(j+1)%sides, i*sides+j))
    if caps:
        fs.extend([tuple(reversed(range(sides))), tuple((len(pts)-1)*sides+j for j in range(sides))])
    return mesh(name, vs, fs, material, group)


def cuboid(name, loc, size, material, group, radius=.002):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = relocate(bpy.context.object, group)
    o.name = name
    o.scale = size
    o.data.materials.append(material)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if radius:
        bevel(o, radius, 2)
    return o


# Preserve body topology, original UVs and the provenance of its macro shape.
raw=[]; faces=[]; face_uv=[]; uv=[]; groups=[]; group=''
for ln in (SRC/'base.obj').read_text(encoding='utf-8').splitlines():
    p=ln.split()
    if not p: continue
    if p[0]=='v': raw.append(Vector(map(float,p[1:4])))
    elif p[0]=='vt': uv.append(tuple(map(float,p[1:3])))
    elif p[0]=='g': group=p[1]
    elif p[0]=='f':
        q=[x.split('/') for x in p[1:]]
        faces.append([int(x[0])-1 for x in q]); face_uv.append([int(x[1])-1 for x in q]); groups.append(group)
targets={'asian-female-young.target':1.,
         'universal-female-young-averagemuscle-averageweight.target':.75,
         'universal-female-young-maxmuscle-averageweight.target':.25}
for filename, amount in targets.items():
    for ln in (SRC/filename).read_text(encoding='utf-8').splitlines():
        p=ln.split()
        if p and not p[0].startswith('#'):
            raw[int(p[0])] += Vector(map(float,p[1:4]))*amount
ids=sorted({v for face,g in zip(faces,groups) if g=='body' for v in face})
lo=min(raw[i].y for i in ids)
unit=1.6/(max(raw[i].y for i in ids)-lo)


def transform(p):
    v=Vector((p.x*unit,-p.z*unit,(p.y-lo)*unit))
    # Follow the visible concept's larger head, compact torso and slender neck.
    t=max(0.,min(1.,(v.z-1.34)/.10));t=t*t*(3-2*t)
    anchor=Vector((0,-.025,1.38))
    v=anchor+(v-anchor)*(1+.19*t)
    if v.z>1.42 and v.y<-.10:
        # Reduce projecting mouth/nose volumes for the quiet, graphic face.
        v.y=-.10+(v.y+.10)*.83
    return v


verts=list(map(transform,raw))
remap={old:new for new,old in enumerate(ids)}
inds=[i for i,g in enumerate(groups) if g=='body']
body=mesh('Body | continuous adult female', [verts[i] for i in ids],
          [[remap[v] for v in faces[i]] for i in inds], skin, '01')
uvlayer=body.data.uv_layers.new(name='MakeHuman UV')
for poly,i in zip(body.data.polygons,inds):
    for loop,idx in zip(poly.loop_indices,face_uv[i]): uvlayer.data[loop].uv=uv[idx]
skel=json.loads((SRC/'default.mhskel').read_text(encoding='utf-8'))
source_weights=json.loads((SRC/'default_weights.mhw').read_text(encoding='utf-8'))['weights']


def joint(name):
    js=skel['joints'][name]
    return sum((verts[i] for i in js),Vector())/len(js)


keep={'root','spine05','spine04','spine03','spine02','spine01','neck01','head'}
for s in ['L','R']:
    keep.update(n+'.'+s for n in ['clavicle','upperarm01','lowerarm01','wrist','upperleg01','lowerleg01','foot'])
    keep.update(f'finger{f}-{n}.{s}' for f in range(1,6) for n in range(1,4))
merge={}
for name in skel['bones']:
    n=name
    while n not in keep: n=skel['bones'][n]['parent'] or 'root'
    merge[name]=n
rd=bpy.data.armatures.new('Female body posing skeleton')
rig=bpy.data.objects.new('Body posing rig | outfit is a static study',rd)
COL['01'].objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name in sorted(keep):
    definition=skel['bones'][name]
    b=rd.edit_bones.new(name);b.head=joint(definition['head']);tail=definition['tail']
    if name=='neck01':tail=skel['bones']['neck03']['tail']
    for pre in ['upperarm','lowerarm','upperleg','lowerleg']:
        if name.startswith(pre+'01.'):tail=skel['bones'][name.replace('01.','02.')]['tail']
    if name.startswith('clavicle.'):tail=skel['bones']['upperarm01.'+name[-1]]['head']
    b.tail=joint(tail)
    plane=skel['planes'].get(definition.get('rotation_plane'))
    if plane:
        a,c,d=(joint(v) for v in plane);normal=(c-a).cross(d-a)
        if normal.length>.00001:b.align_roll(normal.normalized())
for name in keep:
    parent=skel['bones'][name]['parent']
    if parent:rd.edit_bones[name].parent=rd.edit_bones[merge[parent]]
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front=True;rd.display_type='STICK'
weights=[{} for i in ids]
for name, entries in source_weights.items():
    for old,w in entries:
        if old in remap:
            b=weights[remap[old]];n=merge[name];b[n]=b.get(n,0)+w
for i,bucket in enumerate(weights):
    ws=sorted(bucket.items(),key=lambda p:p[1],reverse=True)[:4];total=sum(w for n,w in ws)
    for n,w in ws:
        vg=body.vertex_groups.get(n) or body.vertex_groups.new(name=n)
        vg.add([i],w/total,'REPLACE')
mod=body.modifiers.new('Source skeleton deformation','ARMATURE');mod.object=rig
body.parent=rig
# A reversible visibility mask prevents the preserved anatomical base from poking
# through the fitted wardrobe. Disable this modifier to inspect the complete body.
visible=body.vertex_groups.new(name='Visible skin in this outfit')
visible_ids=[]
for i,old in enumerate(ids):
    hand_weight=sum(w for n,w in weights[i].items() if n.startswith('wrist') or n.startswith('finger'))
    if hand_weight>.08:visible_ids.append(i)
visible.add(visible_ids,1.,'REPLACE')
mask=body.modifiers.new('Hide skin covered by this outfit | reversible','MASK')
mask.vertex_group=visible.name


def pose_direction(name, direction, head=None):
    b=rd.bones[name]
    rotation=(b.tail_local-b.head_local).normalized().rotation_difference(Vector(direction).normalized())
    m=rotation.to_matrix().to_4x4() @ b.matrix_local
    m.translation=Vector(head) if head is not None else b.head_local
    rig.pose.bones[name].matrix=m
    bpy.context.view_layer.update()


for s,sign in [('L',1),('R',-1)]:
    pose_direction('upperarm01.'+s,(sign*.10,.006,-.25))
    elbow=rig.pose.bones['upperarm01.'+s].tail.copy()
    pose_direction('lowerarm01.'+s,(-.055,-.16,-.085) if s=='L' else (-.02,-.055,-.23),elbow)
    wrist=rig.pose.bones['lowerarm01.'+s].tail.copy()
    pose_direction('wrist.'+s,(-.04,.005,-.09) if s=='L' else (-.006,-.015,-.1),wrist)
    for f in range(2,6):
        for seg in range(1,4):
            pb=rig.pose.bones[f'finger{f}-{seg}.{s}'];pb.rotation_mode='XYZ'
            pb.rotation_euler.x=.22 if s=='L' else .10
bpy.context.view_layer.update()

# The concept uses a graphic face. Keep the source body intact under its mask and
# model an independent stylized head with a tapered jaw and a small integrated nose.
head_profile=[(1.389,.012,-.084,.008),(1.405,.040,-.121,.038),
    (1.427,.063,-.143,.060),(1.456,.081,-.155,.077),
    (1.486,.092,-.157,.088),(1.516,.096,-.150,.090),
    (1.548,.096,-.142,.085),(1.580,.090,-.122,.071),
    (1.611,.073,-.090,.053),(1.637,.043,-.050,.027),(1.649,.004,-.021,-.016)]


def head_dimensions(z):
    for a,b in zip(head_profile,head_profile[1:]):
        if z<=b[0]:
            t=max(0.,min(1.,(z-a[0])/(b[0]-a[0])))
            return tuple(a[i]*(1-t)+b[i]*t for i in [1,2,3])
    return head_profile[-1][1:]


def head_point(a,z):
    rx,front,back=head_dimensions(z)
    x=rx*math.sin(a);c=math.cos(a);cy=(front+back)/2
    y=cy-(cy-front)*max(0,c)**.52 if c>=0 else cy+(back-cy)*(-c)
    if c>0:
        nose=.016*math.exp(-(x/.014)**2-((z-1.475)/.015)**2)
        bridge=.006*math.exp(-(x/.010)**2-((z-1.498)/.033)**2)
        y-=nose+bridge
    return Vector((x,y,z))


vs=[];fs=[];levels=39;sides=64
for i in range(levels):
    zz=1.389+i*(1.649-1.389)/(levels-1)
    for j in range(sides):vs.append(head_point(j*math.tau/sides,zz))
    if i:
        for j in range(sides):fs.append(((i-1)*sides+j,(i-1)*sides+(j+1)%sides,i*sides+(j+1)%sides,i*sides+j))
head=mesh('Head | sculpted graphic proportions',vs,fs,skin,'02')
sub=head.modifiers.new('Face surface refinement','SUBSURF');sub.levels=1
tube('Neck | tapered transition',[(0,-.012,1.313),(0,-.014,1.366),(0,-.025,1.426)],
     [.046,.039,.043],skin,'02',24,.82)
for sign in [-1,1]:
    sphere('Ear '+str(sign),(sign*.094,-.018,1.493),(.014,.018,.029),skin,'02',16,10)
    sphere('Ear interior '+str(sign),(sign*.099,-.032,1.493),(.008,.004,.017),lip,'02',12,8)
head_top=1.649
# Continuous cap, with hairline varying around the head instead of cut triangle tips.
vs=[];fs=[]
for i in range(15):
    t=i/14
    for j in range(64):
        a=j*math.tau/64;lower=1.535 if math.cos(a)>.45 else 1.467
        zz=lower+(1.648-lower)*t;p=head_point(a,zz)
        p.x*=1.065;p.y=-.027+(p.y+.027)*1.055;p.z+=.012
        vs.append(p)
    if i:
        for j in range(64):fs.append(((i-1)*64+j,(i-1)*64+(j+1)%64,i*64+(j+1)%64,i*64+j))
scalp=mesh('Hair | continuous shaped cap',vs,fs,hair,'02')

# Catmull-Rom curves with variable-width sections create pointed, overlapping locks.
def catmull(points, values, steps=6):
    ps=list(map(Vector,points));pp=[ps[0]]+ps+[ps[-1]];rr=[values[0]]+values+[values[-1]]
    out=[];radii=[]
    for i in range(1,len(pp)-2):
        for k in range(steps):
            t=k/steps
            p=.5*((2*pp[i])+(-pp[i-1]+pp[i+1])*t+(2*pp[i-1]-5*pp[i]+4*pp[i+1]-pp[i+2])*t*t+(-pp[i-1]+3*pp[i]-3*pp[i+1]+pp[i+2])*t*t*t)
            out.append(p);radii.append(max(.0007,rr[i]*(1-t)+rr[i+1]*t))
    out.append(ps[-1]);radii.append(max(.0007,values[-1]));return out,radii


def lock(name, points, widths, material=hair, flatten=.52):
    ps,rs=catmull(points,widths)
    return tube(name,ps,rs,material,'02',10,flatten)


z=head_top
for n in range(5):
    x=(n-2)*.027
    lock('Swept crown lock %02d'%n,[(x,-.135,z-.08),(x*.9,-.07,z+.006),
         (x*.6,.035,z+.014),(x*.25,.089,z-.012)], [.002,.003,.004,.001],hair_hi if n%3==0 else hair,flatten=.18)
# Side part and diagonal fringe keep the forehead visible and eyes readable.
for n in range(4):
    lock('Parted fringe left %02d'%n,[(.025+n*.008,-.106,z-.018),(-.010-n*.013,-.153,z-.048),
         (-.060-n*.013,-.145,z-.104),(-.068-n*.012,-.133,z-.173)], [.012,.024,.016,.001])
for n in range(3):
    lock('Parted fringe right %02d'%n,[(.026+n*.014,-.106,z-.022),(.063+n*.012,-.13,z-.065),
         (.092+n*.007,-.11,z-.128),(.091+n*.005,-.08,z-.207)], [.017,.021,.017,.001])
for sign in [-1,1]:
    lock('Temple wisp '+str(sign),[(sign*.095,-.078,z-.10),(sign*.098,-.115,z-.17),
         (sign*.101,-.093,z-.238),(sign*.097,-.073,z-.286)],[.013,.012,.008,.001])
base=Vector((.002,.105,z+.015))
for n in range(7):
    a=n*math.tau/7
    dx=math.cos(a)*.022;dy=math.sin(a)*.019
    lock('High ponytail lock %02d'%n,[base+Vector((dx*.5,dy*.5,0)),
         (.008+dx,.14+dy,z+.057),(.025+dx*1.3,.18+dy,z+.016),
         (.042+dx*1.4,.17+dy,z-.115),(.050+dx,.16+dy,z-.246),
         (.060+dx*.8,.11+dy,z-.29-n*.008)],[.014,.025,.027,.024,.016,.001],hair_hi if n%4==0 else hair)
curve('Ponytail red binding',[(.034*math.cos(a),.105+.029*math.sin(a),z+.018) for a in [j*math.tau/24 for j in range(24)]],.007,red,'02',True)
curve('Ponytail cord knot',[(.033,.098,z+.021),(.077,.09,z+.028),(.059,.105,z-.01),(.033,.098,z+.021)],.006,red_hi,'02')

# Project the almond eyes and facial accents onto the new head's frontal envelope.
def face_y(x,z,offset=0.):
    rx,front,back=head_dimensions(z)
    a=math.asin(max(-.999,min(.999,x/rx)))
    return head_point(a,z).y-offset


def face_line(name, xzs, radius, material):
    return curve(name,[(x,face_y(x,z,.0055),z) for x,z in xzs],radius,material,'02')


for s,sign in [('L',1),('R',-1)]:
    ec=joint(skel['bones']['eye.'+s]['head']);ex=ec.x;ez=ec.z+.002
    # Filled curved almond patch. Iris occupies the centre rather than bulging out.
    outline=[(-1,0),(-.65,.42),(-.08,.60),(.60,.44),(1,.07),(.64,-.28),(0,-.35),(-.65,-.24)]
    ex=sign*.036;ez=1.516
    w=.026;h=.020
    boundary=[(ex+sign*xx*w,ez+zz*h) for xx,zz in outline]
    ey=face_y(ex,ez,.003)
    def eye_surface(x,zz,extra=0.):return face_y(x,zz,.003+extra)
    vs=[(ex,ey,ez)]+[(x,eye_surface(x,zz),zz) for x,zz in boundary]
    mesh('Almond eye '+s,vs,[(0,i+1,(i+1)%8+1) for i in range(8)],eye_white,'02')
    # Disc lies along the same facial envelope and remains slightly elliptical.
    vs=[(ex,ey-.001,ez)]
    for j in range(24):
        a=j*math.tau/24;x=ex+.0100*math.cos(a);zz=ez+.001+.008*math.sin(a)
        vs.append((x,eye_surface(x,zz,.001),zz))
    mesh('Iris '+s,vs,[(0,i+1,(i+1)%24+1) for i in range(24)],iris,'02')
    sphere('Eye glint '+s,(ex-.0035,eye_surface(ex-.0035,ez+.004,.003),ez+.004),(.002,.001,.0025),shine,segments=8,rings=4)
    curve('Upper lash '+s,[(x,eye_surface(x,zz,.002),zz) for x,zz in boundary[:5]],.0025,ink,'02')
    curve('Lower outer lash '+s,[(x,eye_surface(x,zz,.002),zz) for x,zz in boundary[4:7]],.001,ink,'02')
    face_line('Brow '+s,[(ex-sign*.024,ez+.021),(ex-sign*.002,ez+.025),(ex+sign*.022,ez+.019)],.0027,ink)
face_line('Soft upper lip',[(-.017,1.444),(-.006,1.446),(0,1.4445),(.006,1.446),(.017,1.444)],.0015,lip)
face_line('Lower lip',[(-.012,1.442),(0,1.439),(.012,1.442)],.0015,lip)

# Garment rings use actual posed limb centres, with larger cloth radii and creases.
def lerp(a,b,t):return Vector(a).lerp(Vector(b),t)


def cloth_limb(name, centres, radii, material, group='03', sides=20, depth=.9):
    ps=list(map(Vector,centres));vs=[];fs=[]
    for i,(p,r) in enumerate(zip(ps,radii)):
        tangent=(ps[min(i+1,len(ps)-1)]-ps[max(0,i-1)]).normalized()
        u=tangent.cross(Vector((0,1,0))).normalized();v=tangent.cross(u).normalized()
        for j in range(sides):
            a=j*math.tau/sides
            rip=1+.065*math.sin(a*5+i*.9)+.035*math.sin(a*8-i*.8)
            vs.append(p+r*rip*(u*math.cos(a)+v*math.sin(a)*depth))
        if i:
            for j in range(sides):fs.append(((i-1)*sides+j,(i-1)*sides+(j+1)%sides,i*sides+(j+1)%sides,i*sides+j))
    return mesh(name,vs,fs,material,group)


def oval_shell(name, profile, material, group, sides=40):
    vs=[];fs=[]
    for i,(z,rx,ry,cy) in enumerate(profile):
        for j in range(sides):
            a=j*math.tau/sides;vs.append((rx*math.sin(a),cy-ry*math.cos(a),z))
        if i:
            for j in range(sides):fs.append(((i-1)*sides+j,(i-1)*sides+(j+1)%sides,i*sides+(j+1)%sides,i*sides+j))
    o=mesh(name,vs,fs,material,group)
    so=o.modifiers.new('Fabric or leather thickness','SOLIDIFY');so.thickness=.003
    return o


shirt=oval_shell('Wrapped teal blouse',[(.87,.137,.095,.00),(.99,.112,.088,-.014),
     (1.11,.151,.119,-.005),(1.24,.162,.105,-.005),(1.28,.169,.086,-.005),
     (1.346,.052,.055,-.012)],teal,'03')
for sign in [-1,1]:
    # Broad flat ribbon bands cross on the sternum; no round necklace-like collar.
    pts=[Vector((sign*.046,-.066,1.348)),Vector((sign*.055,-.113,1.297)),Vector((-sign*.046,-.153,1.247))]
    vs=[]
    for i,p in enumerate(pts):
        d=pts[min(i+1,2)]-pts[max(0,i-1)];u=Vector((-d.z,0,d.x)).normalized()*.014
        vs.extend([p-u,p+u])
    collar=mesh('Flat crossed collar '+str(sign),vs,[(0,1,3,2),(2,3,5,4)],teal_hi,'03')
    so=collar.modifiers.new('Collar thickness','SOLIDIFY');so.thickness=.003
    curve('Collar fine woven edge '+str(sign),[v+Vector((0,-.002,0)) for v in vs[::2]],.0018,lining,'03')
mesh('Skin at open V collar',[(-.040,-.084,1.344),(.040,-.084,1.344),(0,-.140,1.278)],[(0,2,1)],skin,'03')
for s in ['L','R']:
    shoulder=rig.pose.bones['upperarm01.'+s].head.copy()
    elbow=rig.pose.bones['lowerarm01.'+s].head.copy()
    wrist=rig.pose.bones['wrist.'+s].head.copy()
    ps=[lerp(shoulder,elbow,t) for t in [0,.2,.45,.7,.91]]+[elbow]+[lerp(elbow,wrist,t) for t in [.14,.30,.43,.50]]
    rs=[.062,.067,.068,.057,.066,.074,.077,.070,.057,.045]
    cloth_limb('Gathered sleeve '+s,ps,rs,teal)
    cuff=lerp(elbow,wrist,.48)
    tube('Sleeve bound cuff '+s,[lerp(elbow,wrist,t) for t in [.46,.51]], [.050,.047],leather_hi,'03',16)
    tube('Forearm leather guard '+s,[lerp(elbow,wrist,t) for t in [.52,.72,.94]],[.050,.046,.034],leather,'04',12, .86)
    for t in [.56,.88]:
        tube('Bracer strap '+s+str(t),[lerp(elbow,wrist,t-.02),lerp(elbow,wrist,t+.02)],
             [.048 if t<.7 else .038]*2,leather_hi,'04',16,.94)
    # Thin forward ridge is legible at both portrait and sprite sizes.
    curve('Bracer bronze seam '+s,[lerp(elbow,wrist,t)+Vector((0,-.043,0)) for t in [.55,.75,.92]],.0028,bronze,'04')
for s,sign in [('L',1),('R',-1)]:
    hip=rig.pose.bones['upperleg01.'+s].head.copy()
    knee=rig.pose.bones['lowerleg01.'+s].head.copy()
    ankle=rig.pose.bones['foot.'+s].head.copy()
    ps=[hip+Vector((0,0,.09)),hip,lerp(hip,knee,.25),lerp(hip,knee,.55),lerp(hip,knee,.85),
        knee,lerp(knee,ankle,.15),lerp(knee,ankle,.32),lerp(knee,ankle,.43)]
    cloth_limb('Loose trouser leg '+s,ps,[.075,.080,.084,.100,.113,.108,.096,.073,.054],teal,depth=.94)
    xc=ankle.x;yc=ankle.y
    tube('Boot shaft '+s,[(xc,yc,.075),(xc,yc,.13),(xc*.96,yc,.235),(xc*.96,yc,.29)],
         [.060,.052,.059,.067],leather,'03',16,.84)
    foot=sphere('Shaped leather boot '+s,(xc,yc-.060,.055),(.066,.123,.053),leather,'03',20,10)
    sphere('Boot sole '+s,(xc,yc-.063,.017),(.070,.13,.017),sole,'03',20,8)
    cuboid('Boot heel '+s,(xc,yc+.005,.022),(.110,.082,.043),sole,'03')
    for zz in [.092,.18,.265]:
        tube('Boot leather wrap '+s+str(zz),[(xc,yc,zz-.009),(xc,yc,zz+.009)],
             [.064 if zz>.2 else .057]*2,leather_hi,'03',16,.88)
    curve('Boot front seam '+s,[(xc,yc-.052,.26),(xc,yc-.050,.16),(xc,yc-.080,.08),(xc,yc-.169,.052)],.0025,bronze,'03')

# Fitted torso profile and curved individual lamellae, rather than a barrel mesh.
def torso_r(z):
    profile=[(.96,.120,.096),(1.03,.128,.103),(1.10,.144,.122),(1.19,.151,.120),(1.26,.135,.088)]
    for a,b in zip(profile,profile[1:]):
        if z<=b[0]:
            t=max(0.,min(1.,(z-a[0])/(b[0]-a[0])));return a[1]*(1-t)+b[1]*t,a[2]*(1-t)+b[2]*t
    return profile[-1][1:]


def armour_pos(theta,z,padding=.0):
    rx,ry=torso_r(z)
    return Vector(((rx+padding)*math.sin(theta),-.012-(ry+padding)*math.cos(theta),z))


def surface_patch(name, fn, u0,u1,v0,v1,material,group='04',thickness=.003):
    # Rounded corners retain enough silhouette definition for dark layered plates.
    coords=[(.12,0),(.88,0),(1,.12),(1,.88),(.88,1),(.12,1),(0,.88),(0,.12)]
    vs=[fn(u0+(u1-u0)*u,v0+(v1-v0)*v) for u,v in coords]
    vs.append(fn((u0+u1)/2,(v0+v1)/2))
    o=mesh(name,vs,[(8,j,(j+1)%8) for j in range(8)],material,group)
    so=o.modifiers.new('Plate thickness','SOLIDIFY');so.thickness=thickness
    bevel(o,.0012,1)
    return o


oval_shell('Cuirass leather foundation',[(z,*torso_r(z),-.012) for z in [.965,1.03,1.10,1.19,1.25]],leather,'04')
for row in range(4):
    z0=.972+row*.068;z1=z0+.065
    for col in range(20):
        a0=col*math.tau/20+.010;a1=(col+1)*math.tau/20-.010
        surface_patch('Torso lamella %02d %02d'%(row,col),lambda a,z:armour_pos(a,z,.013),a0,a1,z0,z1,iron[(row+col*7)%4])
        mid=(a0+a1)/2;p=armour_pos(mid,z1-.015,.018)
        sphere('Torso bronze rivet',p,(.003,.003,.003),bronze_hi,'04',8,4)
for z in [.969,1.245]:
    curve('Cuirass bound edge', [armour_pos(j*math.tau/64,z,.014) for j in range(64)],.0038,bronze,'04',True)
for sign in [-1,1]:
    pts=[(sign*.115,-.107,1.19),(sign*.124,-.104,1.27),(sign*.12,-.066,1.315),(sign*.118,.07,1.28)]
    curve('Cuirass shoulder leather strap '+str(sign),pts,.012,leather,'04')
    for zz in [1.235,1.265]:
        sphere('Strap stud',(sign*.121,-.118,zz),(.004,.003,.004),bronze_hi,'04',8,4)
    # Three overlapping curved shoulder plates; close to the body, no giant pauldrons.
    s='L' if sign==1 else 'R'
    centre=rig.pose.bones['upperarm01.'+s].head.copy()
    tangent=(rig.pose.bones['upperarm01.'+s].tail-centre).normalized()
    outer=tangent.cross(Vector((0,1,0))).normalized()*sign
    forward=Vector((0,-1,0))
    def shoulder_fn(a,t):
        r=.075+t*.012
        return centre+tangent*(t*.11-.012)+r*(outer*math.cos(a)+forward*math.sin(a))
    cap_verts=[centre-tangent*.035+outer*.006]+[shoulder_fn(-1.25+j*2.5/12,0) for j in range(13)]
    cap=mesh('Shoulder closed crown '+str(sign),cap_verts,[(0,j+1,j+2) for j in range(12)],iron[0],'04')
    so=cap.modifiers.new('Crown plate thickness','SOLIDIFY');so.thickness=.004
    for row in range(3):
        t0=row*.28;t1=t0+.34
        for col in range(5):
            a0=-1.25+col*.5+.01;a1=a0+.475
            surface_patch('Shoulder lamella',shoulder_fn,a0,a1,t0,t1,iron[(row+col)%4])
            p=shoulder_fn((a0+a1)/2,t1-.045)
            sphere('Shoulder rivet',p,(.0035,)*3,bronze_hi,'04',8,4)
        curve('Shoulder bronze border',[shoulder_fn(-1.25+j*2.5/20,t1) for j in range(21)],.0035,bronze,'04')

# Split armour tassets flare over the trousers; separated front and side panels.
def skirt_fn(a,z,pad=.0):
    t=(.94-z)/.39
    rx=.153+.080*min(t/.55,1.);ry=.126+.035*min(t/.45,1.)
    return Vector(((rx+pad)*math.sin(a),-.012-(ry+pad)*math.cos(a),z))


oval_shell('Teal lining under split tassets',[(zz,skirt_fn(math.pi/2,zz).x-.012,
    abs(skirt_fn(0,zz).y+.012)-.012,-.012) for zz in [.94,.90,.86,.82,.78,.70,.60]],teal_dark,'03')
for panel,(a0,a1,zbottom) in enumerate([(-.70,-.08,.60),(.09,.70,.58),(.79,1.56,.53),(-1.56,-.79,.56),(1.66,3.04,.57),(-3.04,-1.66,.57)]):
    surface_patch('Tasset leather backing %02d'%panel,skirt_fn,a0-.015,a1+.015,zbottom-.016,.947,leather)
    rows=6;cols=4 if abs(a1-a0)<1 else 6
    for row in range(rows):
        z0=zbottom+row*(.945-zbottom)/rows;z1=zbottom+(row+1)*(.945-zbottom)/rows-.002
        for col in range(cols):
            left=a0+col*(a1-a0)/cols+.007;right=a0+(col+1)*(a1-a0)/cols-.007
            surface_patch('Skirt lamella %02d %02d %02d'%(panel,row,col),lambda a,z:skirt_fn(a,z,.010),left,right,z0,z1,iron[(row+col+panel)%4])
            p=skirt_fn((left+right)/2,z1-.013,.015)
            sphere('Skirt rivet',p,(.0027,)*3,bronze_hi,'04',8,4)
    for a in [a0,a1]:curve('Tasset vertical binding',[skirt_fn(a,zbottom+t*(.947-zbottom),.008) for t in [0,.25,.5,.75,1]],.0028,bronze,'04')
    curve('Tasset lower binding',[skirt_fn(a0+(a1-a0)*j/20,zbottom,.009) for j in range(21)],.004,bronze,'04')

# Sash and layered waist belt, with long, slightly twisted fabric tails.
oval_shell('Wrapped red waist sash',[(.925,.146,.119,-.012),(.963,.129,.111,-.012),(.993,.126,.109,-.012)],red,'05')
oval_shell('Leather waist belt',[(.949,.147,.126,-.012),(.977,.141,.122,-.012)],leather,'05')
for zz in [.953,.977]:
    curve('Belt red edge',[(.148*math.sin(j*math.tau/48),-.012-.126*math.cos(j*math.tau/48),zz) for j in range(48)],.002,red_hi,'05',True)
cuboid('Antique square belt buckle',(0,-.143,.964),(.052,.015,.035),bronze,'05',.005)
cuboid('Buckle dark recess',(0,-.152,.964),(.033,.008,.021),leather,'05',.003)
cuboid('Buckle tongue',(0,-.159,.964),(.004,.003,.024),bronze_hi,'05',.001)
for xx in [-.088,-.053,.064,.098]:
    sphere('Belt stud',(xx,-.143+abs(xx)*.28,.963),(.004,.003,.004),bronze_hi,'05',8,4)
for i,(xx,width,end) in enumerate([(.053,.032,.565),(.079,.017,.515)]):
    vs=[]
    for j in range(10):
        t=j/9;zz=.981+(.0+end-.981)*t;cx=xx+.014*math.sin(t*3)
        yy=-.166-.045*t+.004*math.sin(t*8)
        vs += [(cx-width/2,yy,zz),(cx+width/2,yy+.006*math.sin(t*5),zz)]
    sash=mesh('Long red sash tail '+str(i),vs,[(2*j,2*j+1,2*j+3,2*j+2) for j in range(9)],red,'05')
    so=sash.modifiers.new('Woven thickness','SOLIDIFY');so.thickness=.002
    for side in [0,1]:curve('Sash stitched border',[Vector(v)+Vector((0,-.001,0)) for v in vs[side::2]],.0015,red_hi,'05')
sphere('Sash knot',(.058,-.179,.949),(.023,.011,.016),red_hi,'05',16,8)

# Sword is a separate assembly, entirely geometric and removable from the body.
sword_root=bpy.data.objects.new('Sword assembly | removable',None);COL['05'].objects.link(sword_root)
start=Vector((.206,-.018,.872));direction=Vector((.69,-.06,-.72)).normalized()
scabbard_end=start+direction*.48
def sword_part(o):o.parent=sword_root;return o
sword_part(tube('Dark leather scabbard',[start,lerp(start,scabbard_end,.85),scabbard_end],[.023,.021,.012],leather,'05',8,.60))
for t in [0,.15,.77,.94]:
    sword_part(tube('Scabbard bronze fitting',[lerp(start,scabbard_end,t),lerp(start,scabbard_end,t+.035)],[.025,.025],bronze,'05',8,.66))
guard=start-direction*.020
o=cuboid('Sword bronze guard',guard,(.095,.029,.022),bronze,'05',.005)
o.rotation_euler=direction.to_track_quat('Z','Y').to_euler();sword_part(o)
grip0=start-direction*.027;grip1=start-direction*.131
sword_part(tube('Leather sword grip',[grip0,grip1],[.017,.016],sole,'05',12,.85))
for i in range(7):
    t=i/7
    sword_part(tube('Sword grip winding',[lerp(grip0,grip1,t),lerp(grip0,grip1,t+.04)],[.018,.018],leather_hi,'05',12,.85))
sword_part(sphere('Sword pommel',grip1,(.024,.018,.024),bronze,'05',12,6))
curve('Leather sword suspension',[(.156,-.036,.962),(.199,-.015,.89),(.224,-.008,.864)],.009,leather_hi,'05')

# Physical geometry remains visible in all views, with contact shadows and studio light.
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new('Warm neutral studio');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.42,.46,.47,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.38
for name,loc,power,size,color in [('Key',(-3,-4,5),360,3.5,(1,.87,.69)),('Fill',(3,-2,3),95,3,(.73,.86,1)),('Rim',(1,3,4),390,2.4,(1,.78,.50))]:
    d=bpy.data.lights.new(name,'AREA');o=bpy.data.objects.new(name,d);COL['90'].objects.link(o)
    o.location=loc;d.energy=power;d.size=size;d.color=color;aim(o,(0,0,.9))
floor=mat('Parchment studio floor',(.39,.345,.267))
cuboid('Ground',(0,0,-.012),(200,200,.018),floor,'90',0)
cd=bpy.data.cameras.new('Concept comparison camera');cam=bpy.data.objects.new(cd.name,cd);COL['90'].objects.link(cam)
scene.camera=cam;cd.type='ORTHO';cd.ortho_scale=1.99
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.render.film_transparent=False


def render(filename, loc=(3,-8,3.05), target=(.015,0,.873), size=(900,1100), scale=1.99):
    cam.location=loc;aim(cam,target);cd.ortho_scale=scale
    scene.render.resolution_x,scene.render.resolution_y=size
    scene.render.filepath=str(OUT/filename)
    bpy.ops.render.render(write_still=True)


bpy.ops.object.select_all(action='DESELECT')
body.select_set(True);bpy.context.view_layer.objects.active=body
# Source keeps a body posing rig; garments explicitly remain static in this study.
scene['asset_status']='STATIC_ART_STUDY_AWAITING_USER_REVIEW'
scene['reference']='blender-assets/concepts/female-character-b-v01.png, middle light armour'
scene['animation_status']='Body posed with rig. Outfit fitting and skinning NOT animation-ready.'
cam.location=(3,-8,3.05);aim(cam,(.015,0,.873))
scene.render.resolution_x=900;scene.render.resolution_y=1100
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'female-light-armour.blend'))
render('model-quarter.png')
render('model-face.png',loc=(2.0,-8,2.3),target=(0,-.015,1.482),size=(850,850),scale=.52)
if '--quick' in sys.argv:
    print('FEMALE_QUICK_RENDER_COMPLETE')
    sys.exit(0)
render('model-front.png',loc=(0,-8,2.2))
render('model-back.png',loc=(-3,8,3.05))
scene.cycles.samples=16;scene.cycles.use_denoising=False
scene.cycles.pixel_filter_type='BOX';scene.cycles.filter_width=.01
scene.render.use_freestyle=True
lines=scene.view_layers[0].freestyle_settings.linesets[0]
lines.select_crease=False;lines.select_material_boundary=False;lines.select_border=True
if lines.linestyle is None:lines.linestyle=bpy.data.linestyles.new('Pixel silhouette')
lines.linestyle.color=(.030,.023,.015);lines.linestyle.thickness=.65
render('model-pixel.png',size=(240,300))
scene.render.use_freestyle=False

# Bake an export-only duplicate: preserve source editability and honestly export a
# static sample without pretending that the unweighted clothing is production-rigged.
export_col=bpy.data.collections.new('EXPORT temporary');scene.collection.children.link(export_col)
deps=bpy.context.evaluated_depsgraph_get();export_objs=[];buckets={}
bpy.ops.object.select_all(action='DESELECT')
for k,c in COL.items():
    if k=='90':continue
    for o in list(c.objects):
        if o.type not in {'MESH','CURVE'}:continue
        d=bpy.data.meshes.new_from_object(o.evaluated_get(deps),depsgraph=deps)
        n=bpy.data.objects.new(o.name,d);export_col.objects.link(n);n.matrix_world=o.matrix_world.copy()
        role='06 Sword' if o.parent==sword_root else k+' '+c.name[3:]
        buckets.setdefault(role,[]).append(n)
for role,objects in buckets.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    joined=bpy.context.object;joined.name=role;export_objs.append(joined)
bpy.ops.object.select_all(action='DESELECT')
for o in export_objs:o.select_set(True)
bpy.context.view_layer.objects.active=export_objs[0]
bpy.ops.export_scene.gltf(filepath=str(OUT/'female-light-armour-static.glb'),export_format='GLB',use_selection=True,export_animations=False)
triangles=0
for o in export_objs:o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
report={'reference':scene['reference'],'blender':bpy.app.version_string,'status':scene['asset_status'],
        'body_source':'MakeHuman CC0 a8bc2d54ff0ac92e78ff71431b1023eda42bf482','body_macro_targets':targets,
        'head_source':'Original parameterized stylized head; original source head preserved behind a reversible mask',
        'source_sha256':{n:hashlib.sha256((SRC/n).read_bytes()).hexdigest() for n in ['base.obj','default.mhskel','default_weights.mhw']+list(targets)},
        'body_vertices':len(body.data.vertices),'body_bones':len(rd.bones),
        'static_export_meshes':len(export_objs),'static_export_triangles':triangles,
        'animation_ready':False,'godot_import':'NOT_YET_VERIFIED','runtime_performance':'NOT_MEASURED',
        'render_origin':'Actual Blender geometry, no image generation or concept texture billboard',
        'pixel_resolution':[240,300]}
(OUT/'build-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('FEMALE_CONCEPT_SAMPLE_BUILT '+json.dumps(report,ensure_ascii=False))
