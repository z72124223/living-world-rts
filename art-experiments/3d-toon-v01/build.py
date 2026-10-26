"""Actual geometry/material experiment. Run in Blender 5.1. No generative images.
Writes only beside this script. Input model is loaded read-only from the source tree.
"""
import bpy, math, json, hashlib, time
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
SOURCE = Path('C:/Users/f7212/OneDrive/文件/遊戲開發/blender-assets/samples/body-pixel-v02/body-rig.blend')
start = time.time()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
scene.frame_set(1)
# Normal-based cel shading is deliberately deterministic; no light-dependent trick.
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.threads_mode='FIXED';scene.render.threads=8
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=False
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
scene.view_settings.exposure=0;scene.view_settings.gamma=1
scene.world.color=(.65,.65,.65)
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.72,.70,.65,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.8
scene.render.use_freestyle=True
fs=scene.view_layers[0].freestyle_settings
ls=fs.linesets[0] if len(fs.linesets) else fs.linesets.new('Ink contours')
if ls.linestyle is None:ls.linestyle=bpy.data.linestyles.new('Ink contours')
ls.select_silhouette=True;ls.select_border=True;ls.select_crease=False
ls.linestyle.color=(.035,.042,.044)
ls.linestyle.thickness=1.15
rig=bpy.data.objects['02_Rig'];rig.animation_data_clear()
for p in rig.pose.bones:p.rotation_quaternion=(1,0,0,0);p.rotation_euler=(0,0,0)
for n in ['Topknot','03_Scalp']:
    o=bpy.data.objects.get(n)
    if o:bpy.data.objects.remove(o,do_unlink=True)
for o in list(bpy.data.objects):
    if o.type in {'LIGHT','CAMERA'}:bpy.data.objects.remove(o,do_unlink=True)

def mat(name,base,ink=False,texture=False):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*base,1)
    n=m.node_tree.nodes;n.clear();links=m.node_tree.links
    output=n.new('ShaderNodeOutputMaterial');output.location=(740,0)
    em=n.new('ShaderNodeEmission');em.location=(540,0);links.new(em.outputs[0],output.inputs['Surface'])
    if ink:em.inputs['Color'].default_value=(*base,1);return m
    geo=n.new('ShaderNodeNewGeometry');geo.location=(-700,40)
    dot=n.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT';dot.location=(-500,40)
    dot.inputs[1].default_value=Vector((-.5,-.7,.85)).normalized();links.new(geo.outputs['Normal'],dot.inputs[0])
    ramp=n.new('ShaderNodeValToRGB');ramp.name='Three painted value bands';ramp.location=(-300,70)
    ramp.color_ramp.interpolation='CONSTANT'
    ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
    for k,(pos,mul) in enumerate([(0,.53),(.15,.80),(.58,1)]):
        e=ramp.color_ramp.elements[0] if k==0 else ramp.color_ramp.elements.new(pos)
        e.position=pos;e.color=tuple(c*mul for c in base)+(1,)
    links.new(dot.outputs['Value'],ramp.inputs[0])
    if texture:
        tex=n.new('ShaderNodeTexImage');tex.name='Packed 512px cloth texture';tex.location=(-200,-180);tex.image=cloth_image
        mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.location=(260,0)
        links.new(ramp.outputs[0],mix.inputs[1]);links.new(tex.outputs['Color'],mix.inputs[2]);links.new(mix.outputs[0],em.inputs[0])
    else:links.new(ramp.outputs[0],em.inputs[0])
    return m

# Actual UV image texture, generated deterministically from restrained textile marks.
import numpy as np
rng=np.random.default_rng(90209)
a=np.ones((512,512,4),dtype=np.float32)
u,v=np.meshgrid(np.arange(512),np.arange(512))
val=.97+.011*np.sin(u*.67)+.007*np.sin(v*1.1)+rng.normal(0,.005,(512,512))
a[:,:,:3]=val[:,:,None];a[:,:,3]=1
cloth_image=bpy.data.images.new('Cloth brush grain 512',width=512,height=512,alpha=True)
cloth_image.pixels.foreach_set(a.ravel());cloth_image.filepath_raw=str(OUT/'cloth-grain.png');cloth_image.file_format='PNG';cloth_image.save();cloth_image.pack()
skin=mat('Skin | three flat values',(.73,.48,.29))
jacket=mat('Jacket | teal textile + cel',(.125,.235,.23),texture=True)
rib=mat('Ribbed cuffs | dark teal',(.075,.145,.145),texture=True)
tee=mat('T shirt | warm ivory',(.71,.68,.54),texture=True)
pants=mat('Trousers | charcoal textile',(.095,.115,.125),texture=True)
shoe=mat('Sneakers | muted canvas',(.31,.34,.33),texture=True)
sole=mat('Sneakers | rubber sole',(.61,.62,.56))
hair=mat('Hair | ink',(.045,.054,.061))
ink=mat('Drawn seam geometry',(.025,.039,.04),True)
eye=mat('Eye whites',(.76,.72,.6),True);iris=mat('Eyes dark',(.025,.03,.035),True)
body=bpy.data.objects['01_Body_Continuous'];body.data.materials.clear();body.data.materials.append(skin)
full_mesh=body.data.copy()
original_weights=[[(body.vertex_groups[g.group].name,g.weight) for g in v.groups] for v in body.data.vertices]

def mesh(name,verts,faces,material):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);scene.collection.objects.link(o);me.materials.append(material)
    for f in me.polygons:f.use_smooth=True
    uv=me.uv_layers.new(name='Surface UV')
    for f in me.polygons:
        for li in f.loop_indices:
            p=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(p.x*1.7+.5,p.z*.6)
    return o

def bind(o,bone):
    g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
    mo=o.modifiers.new('Shared original skeleton','ARMATURE');mo.object=rig

def loft(name,rings,material,n=32):
    vv=[]
    for z,x,y,rx,ry in rings:
        for i in range(n):
            an=2*math.pi*i/n;vv.append((x+rx*math.cos(an),y+ry*math.sin(an),z))
    ff=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(rings)-1) for i in range(n)]
    ff+=[tuple(reversed(range(n))),tuple((len(rings)-1)*n+i for i in range(n))]
    return mesh(name,vv,ff,material)

def tube(name,points,radii,material,n=24):
    vv=[]
    for j,p in enumerate(points):
        p=Vector(p);direction=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(j-1,0)])
        direction.normalize();ax=direction.cross(Vector((0,1,0))).normalized();ay=direction.cross(ax).normalized()
        for i in range(n):
            a=2*math.pi*i/n;vv.append(p+ax*math.cos(a)*radii[j]+ay*math.sin(a)*radii[j])
    ff=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(points)-1) for i in range(n)]
    ff.extend([tuple(reversed(range(n))),tuple((len(points)-1)*n+i for i in range(n))])
    return mesh(name,vv,ff,material)

def curve(name,points,material=ink,width=.0015):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=width;cu.bevel_resolution=2
    sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
    for p,co in zip(sp.points,points):p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu);scene.collection.objects.link(ob);cu.materials.append(material);return ob

# Skin under opaque clothing is removed. The underlying source stays untouched.
import bmesh
bm=bmesh.new();bm.from_mesh(body.data)
kill=[]
for f in bm.faces:
    c=f.calc_center_median()
    hands=abs(c.x)>.515 and c.z<1.14
    if c.z<1.51 and not hands:kill.append(f)
bmesh.ops.delete(bm,geom=kill,context='FACES');bm.to_mesh(body.data);bm.free()

# Loose modern clothing has its own silhouette, not painted-on skin.
o=loft('Jacket torso',[(1.00,0,.018,.20,.12),(1.05,0,.018,.216,.135),(1.20,0,.025,.238,.148),(1.37,0,.015,.255,.145),(1.44,0,.002,.235,.13),(1.50,0,-.01,.100,.080)],jacket)
bind(o,'spine01')
o=loft('Jacket waist rib',[(.99,0,.018,.20,.124),(1.035,0,.018,.211,.131)],rib);bind(o,'spine05')
# Ivory shirt visible between unzipped fronts, built as a 3D surface strip.
vv=[(-.055,-.122,1.036),(.055,-.122,1.036),(-.064,-.15,1.20),(.064,-.15,1.20),(-.055,-.139,1.37),(.055,-.139,1.37),(-.045,-.087,1.49),(.045,-.087,1.49)]
shirt=mesh('T shirt visible panel',vv,[(0,1,3,2),(2,3,5,4),(4,5,7,6)],tee);bind(shirt,'spine01')
for sign,side in [(1,'L'),(-1,'R')]:
    sh=Vector(rig.data.bones['upperarm01.'+side].head_local)
    el=Vector(rig.data.bones['lowerarm01.'+side].head_local)
    wr=Vector(rig.data.bones['wrist.'+side].head_local)
    sleeve=tube('Jacket sleeve '+side,[sh,sh.lerp(el,.18),el,el.lerp(wr,.6),wr],[.10,.10,.083,.071,.052],jacket)
    # Nearest bone blend allows inspection of the original arm rig, not a full animation acceptance.
    g1=sleeve.vertex_groups.new(name='upperarm01.'+side);g2=sleeve.vertex_groups.new(name='lowerarm01.'+side)
    for vert in sleeve.data.vertices:
        t=max(0,min(1,(vert.co-sh).length/(wr-sh).length));w=max(0,min(1,(t-.32)/.35));g1.add([vert.index],1-w,'REPLACE');g2.add([vert.index],w,'REPLACE')
    mod=sleeve.modifiers.new('Shared skeleton','ARMATURE');mod.object=rig
    cuff=tube('Wrist rib '+side,[el.lerp(wr,.9),wr.lerp(el,-.02)],[.055,.053],rib);bind(cuff,'lowerarm01.'+side)
    leg=loft('Trouser leg '+side,[(.095,sign*.211,-.003,.074,.081),(.14,sign*.206,0,.078,.083),(.39,sign*.18,.008,.094,.09),(.52,sign*.165,.006,.108,.106),(.77,sign*.136,.02,.123,.125),(.98,sign*.10,.02,.137,.139)],pants)
    bind(leg,'upperleg01.'+side)
    curve('Trouser seam '+side,[(sign*.29,.014,.13),(sign*.274,.01,.4),(sign*.272,.01,.55),(sign*.264,.013,.78)],width=.001)
    # Sole/upper are closed meshes, visible from front, rear and high camera.
    sx=sign*.211
    for name,center,scale,ma in [('Sole',(sx,-.072,.029),(.093,.172,.028),sole),('Canvas',(sx,-.057,.068),(.084,.153,.055),shoe)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=center)
        ob=bpy.context.object;ob.name=name+' '+side;ob.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        ob.data.materials.append(ma)
        for p in ob.data.polygons:p.use_smooth=True
    for j in range(4):
        y=-.07-j*.025;z=.111-j*.006
        curve('Shoe lace '+side+str(j),[(sx-.044,y,z),(sx+.044,y-.012,z)],sole,.0024)
    curve('Jacket front opening '+side,[(sign*.057,-.128,1.04),(sign*.067,-.153,1.2),(sign*.059,-.143,1.37),(sign*.046,-.091,1.49)],width=.002)
    curve('Pocket '+side,[(sign*.118,-.128,1.08),(sign*.157,-.112,1.17)],width=.002)
    collar=mesh('Collar '+side,[(sign*.046,-.092,1.492),(sign*.098,-.075,1.502),(sign*.15,-.095,1.449),(sign*.071,-.139,1.423)],[(0,1,2,3)],rib);bind(collar,'spine01')
hip=loft('Trouser hips',[(.86,0,.02,.20,.135),(1.01,0,.017,.203,.132)],pants);bind(hip,'spine05')

# Replace the first blocked-out clothes with connected fitted cloth surfaces.
# These are real meshes from the same anatomical base, smoothed and expanded.
for ob in list(scene.objects):
    if ob.name.startswith(('Jacket','T shirt','Collar','Pocket','Trouser')):
        bpy.data.objects.remove(ob,do_unlink=True)

def garment(name,predicate,material,inflation):
    selected=[]
    for f in full_mesh.polygons:
        c=sum((full_mesh.vertices[i].co for i in f.vertices),Vector())/len(f.vertices)
        if predicate(c):selected.append(f)
    ids=sorted({i for f in selected for i in f.vertices});remap={old:new for new,old in enumerate(ids)}
    vv=[]
    for idx in ids:
        p=full_mesh.vertices[idx].co.copy();p+=full_mesh.vertices[idx].normal*inflation
        vv.append(p)
    ob=mesh(name,vv,[[remap[i] for i in f.vertices] for f in selected],material)
    for old,new in remap.items():
        for group,w in original_weights[old]:
            g=ob.vertex_groups.get(group) or ob.vertex_groups.new(name=group);g.add([new],w,'REPLACE')
    sm=ob.modifiers.new('Cloth relax','SMOOTH');sm.factor=1.3;sm.iterations=12
    solid=ob.modifiers.new('Cloth thickness','SOLIDIFY');solid.thickness=.006;solid.offset=0
    ar=ob.modifiers.new('Inherited skeleton weights','ARMATURE');ar.object=rig
    return ob

coat=garment('Connected jacket',lambda c:(1.015<c.z<1.515 and abs(c.x)<.245) or (abs(c.x)>=.245 and abs(c.x)<.529 and c.z>1.115),jacket,.023)
trousers=garment('Connected trousers',lambda c:.095<c.z<1.035 and abs(c.x)<.39,pants,.035)
neck=loft('Finished rib collar',[(1.49,0,-.031,.086,.071),(1.54,0,-.031,.079,.072)],rib);bind(neck,'neck01')
hem=loft('Finished waist rib',[(1.009,0,.017,.19,.127),(1.048,0,.017,.191,.131)],rib);bind(hem,'spine05')
# Find the garment front from its actual coordinates rather than screen projection.
def front(x,z):
    candidates=[v.co.y for v in coat.data.vertices if abs(v.co.z-z)<.025 and abs(v.co.x-x)<.025]
    return (min(candidates) if candidates else -.125)-.007
zip_points=[(0,front(0,z),z) for z in np.linspace(1.05,1.47,14)]
curve('Centre zipper fabric',zip_points,tee,.004)
curve('Centre zipper line',[(.006,y-.001,z) for x,y,z in zip_points],ink,.0012)
for s in [-1,1]:
    points=[(s*x,front(s*x,z),z) for x,z in [( .10,1.075),(.125,1.105),(.145,1.14)]]
    curve('Pocket seam '+str(s),points,ink,.002)

# A separate short hair shell with actual volume; no image billboard.
headverts=[v.co.copy() for v in body.data.vertices]
hvv=[];hff=[];remap={}
for f in body.data.polygons:
    co=sum((body.data.vertices[i].co for i in f.vertices),Vector())/len(f.vertices)
    threshold=1.745 if co.y<-.08 else (1.69 if abs(co.x)>.07 else 1.66)
    if co.z<threshold:continue
    face=[]
    for idx in f.vertices:
        if idx not in remap:
            p=body.data.vertices[idx].co.copy();center=Vector((0,-.032,1.717));p=center+(p-center)*1.06
            remap[idx]=len(hvv);hvv.append(p)
        face.append(remap[idx])
    hff.append(face)
haircap=mesh('Short hair cap',hvv,hff,hair);bind(haircap,'head')
for i in range(7):
    x=-.079+i*.024
    v=[(x-.025,-.064,1.805),(x+.025,-.078,1.80),(x+.019,-.147,1.76),(x-.007,-.157,1.72+(i%3)*.012),(x-.03,-.115,1.762),(x-.01,-.04,1.834)]
    f=[(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5),(0,4,3,2,1)]
    ob=mesh('Hair fringe '+str(i),v,f,hair);bind(ob,'head')
for o in bpy.data.objects:
    if o.name.startswith('Eye.'):o.data.materials.clear();o.data.materials.append(eye)
    if o.name.startswith('Iris.'):o.data.materials.clear();o.data.materials.append(iris)
for s in [-1,1]:
    curve('Eyebrow '+str(s),[(s*.026,-.151,1.724),(s*.046,-.145,1.733),(s*.068,-.129,1.729)],hair,.004)

# Neutral study ground; no painted background to disguise geometry.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.008));ground=bpy.context.object;ground.name='Neutral studio floor'
gm=bpy.data.materials.new('Studio matte');gm.diffuse_color=(.61,.62,.60,1);gm.use_nodes=True
gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.61,.62,.60,1);gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1;ground.data.materials.append(gm)
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.light_add(type='AREA',location=(-3,-4,6));key=bpy.context.object;key.data.energy=450;key.data.shape='DISK';key.data.size=5;aim(key,(0,0,1))
bpy.ops.object.camera_add(location=(3,-7,2.9));camera=bpy.context.object;camera.name='Preview camera';camera.data.type='ORTHO';camera.data.ortho_scale=2.15;aim(camera,(0,-.01,.92));scene.camera=camera
objects=[o for o in scene.objects if o.type in {'MESH','CURVE'} and o!=ground]
normal_mats={o.name:list(o.data.materials) for o in objects}
clay=bpy.data.materials.new('Clay only');clay.diffuse_color=(.44,.46,.47,1);clay.use_nodes=True
clay.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.44,.46,.47,1)
clay.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.84

def render(name,pos,size=(660,880),clay_only=False):
    for o in objects:
        o.data.materials.clear()
        for m in ([clay] if clay_only else normal_mats[o.name]):o.data.materials.append(m)
    scene.render.use_freestyle=not clay_only
    camera.location=pos;aim(camera,(0,-.02,.92));camera.data.ortho_scale=2.15
    scene.render.resolution_x,scene.render.resolution_y=size
    scene.render.filepath=str(OUT/name)
    bpy.ops.render.render(write_still=True)

render('01-clay.png',(3,-7,2.8),clay_only=True)
render('02-toon-front.png',(3,-7,2.8))
render('03-toon-back.png',(-3,7,2.8))
render('04-toon-side.png',(7,-1,2.8))
render('05-rts.png',(4,-6,6),(256,256))
render('06-rts-96.png',(4,-6,6),(96,96))
camera.location=(3,-7,2.8);aim(camera,(0,-.02,.92));scene.render.resolution_x=660;scene.render.resolution_y=880
scene.render.filepath=str(OUT/'02-toon-front.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'model.blend'))
triangles=0
deps=bpy.context.evaluated_depsgraph_get()
for o in objects:
    ev=o.evaluated_get(deps);me=ev.to_mesh();me.calc_loop_triangles();triangles+=len(me.loop_triangles);ev.to_mesh_clear()
report={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'blender':bpy.app.version_string,'renderer':scene.render.engine,'samples':scene.cycles.samples,'asset_objects':len(objects),'evaluated_triangles':triangles,'new_cloth_texture':[512,512],'rendered_views':6,'same_mesh_gray_and_color':True,'generative_image_used':False,'source_game_modified':False,'animation_verified':False,'engine_performance_verified':False,'seconds':round(time.time()-start,1),'task_ref':'aa097cb47f9e7584477d3b23051c0f52cb61edb42cf0769b273672139971d598'}
(OUT/'build-report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print('REAL_3D_PREVIEW_COMPLETE',json.dumps(report,ensure_ascii=False))
