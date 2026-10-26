-- Native Aseprite source plus actual triangulated, weighted Godot geometry.
-- Neutral unclothed mannequin: no garment, painted suit, or sexual detail.
local root=assert(app.params.root)
local pc=app.pixelColor
local bones=dofile(root..'/scripts/rig_landmarks.lua')
local function json(v)
 if type(v)=='table' then
  local a={};if #v>0 then for _,x in ipairs(v) do a[#a+1]=json(x) end return '['..table.concat(a,',')..']' end
  for k,x in pairs(v) do a[#a+1]=json(k)..':'..json(x) end return '{'..table.concat(a,',')..'}'
 elseif type(v)=='string' then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"')..'"'
 elseif type(v)=='boolean' then return v and 'true' or 'false' else return tostring(v) end
end
local function write(p,v)local f=assert(io.open(p,'w'));f:write(json(v));f:close() end
local meshes={}
local function strip(name,rows,horizontal)
 local m={name=name,vertices={},weights={},triangles={}}
 for i,row in ipairs(rows) do
  local nx,ny=1,0
  if not horizontal then
   local p,q=rows[math.max(1,i-1)],rows[math.min(#rows,i+1)]
   local dx,dy=q[1]-p[1],q[2]-p[2];local d=math.sqrt(dx*dx+dy*dy);nx,ny=dy/d,-dx/d
  end
  for col=0,4 do
   local t=(col-2)/2
   m.vertices[#m.vertices+1]={row[1]+nx*row[3]*t,row[2]+ny*row[3]*t}
   m.weights[#m.weights+1]=row[4]
  end
 end
 for row=0,#rows-2 do for col=0,3 do
  local a=row*5+col;local b=a+1;local c=a+5;local d=c+1
  m.triangles[#m.triangles+1]={a,b,c};m.triangles[#m.triangles+1]={b,d,c}
 end end
 meshes[#meshes+1]=m
end
strip('far_leg',{
 {107,121,8,{hips=.65,far_thigh=.35}},
 {107,128,9,{hips=.15,far_thigh=.85}},
 {106,138,9,{far_thigh=1}}, {107,153,7,{far_thigh=1}},
 {108,164,4.8,{far_thigh=.75,far_shin=.25}},
 {108,167,4.5,{far_thigh=.5,far_shin=.5}},
 {108,171,5,{far_thigh=.2,far_shin=.8}},
 {108,182,6.3,{far_shin=1}}, {107,197,4.6,{far_shin=1}},
 {106,210,3.1,{far_shin=.8,far_foot=.2}},
 {106,213,3.0,{far_shin=.5,far_foot=.5}},
 {103,218,4.3,{far_foot=1}}, {96,223,4.4,{far_foot=1}},
 {89,225,2.2,{far_foot=1}},
})
strip('far_arm',{
 {105,63,5.8,{torso=.55,far_upper_arm=.45}},
 {103,69,5.5,{far_upper_arm=1}}, {100,82,4.7,{far_upper_arm=1}},
 {98,90,3.5,{far_upper_arm=.8,far_forearm=.2}},
 {97,93,3.4,{far_upper_arm=.5,far_forearm=.5}},
 {96,97,3.8,{far_upper_arm=.2,far_forearm=.8}},
 {95,107,4,{far_forearm=1}}, {92,117,2.6,{far_forearm=1}},
 {92,120,2.6,{far_forearm=.5,far_hand=.5}},
 {91,125,3.2,{far_hand=1}}, {91,130,2.8,{far_hand=1}},
 {91,133,1.6,{far_hand=1}},
})
strip('near_leg',{
 {132,121,8.5,{hips=.65,near_thigh=.35}},
 {132,128,9.5,{hips=.15,near_thigh=.85}},
 {133,141,9,{near_thigh=1}}, {137,157,6.7,{near_thigh=1}},
 {139,165,4.7,{near_thigh=.8,near_shin=.2}},
 {139,169,4.4,{near_thigh=.5,near_shin=.5}},
 {140,173,4.8,{near_thigh=.2,near_shin=.8}},
 {144,184,6.4,{near_shin=1}}, {147,201,4.6,{near_shin=1}},
 {148,215,3.3,{near_shin=.8,near_foot=.2}},
 {148,219,3.3,{near_shin=.5,near_foot=.5}},
 {148,225,4.0,{near_foot=1}}, {145,232,4.6,{near_foot=1}},
 {144,236,2.8,{near_foot=1}},
})
strip('torso_pelvis',{
 {119,51,4.1,{head=.5,torso=.5}}, {120,56,4.8,{torso=1}},
 {120,60,10,{torso=1}}, {122,64,17,{torso=1}},
 {120,71,17,{torso=1}}, {119,80,16,{torso=1}},
 {118,88,13.5,{torso=.85,hips=.15}},
 {119,96,12,{torso=.5,hips=.5}},
 {120,104,13.8,{torso=.15,hips=.85}},
 {121,112,17.2,{hips=1}}, {121,120,19.3,{hips=1}},
 {121,124,18.5,{hips=1}}, {119,129,7.5,{hips=1}},
},true)
strip('near_arm',{
 {138,63,6,{torso=.6,near_upper_arm=.4}},
 {141,68,6.3,{near_upper_arm=1}}, {147,77,5.8,{near_upper_arm=1}},
 {152,85,4.2,{near_upper_arm=.8,near_forearm=.2}},
 {155,90,4.0,{near_upper_arm=.5,near_forearm=.5}},
 {153,94,4.3,{near_upper_arm=.2,near_forearm=.8}},
 {148,101,4.1,{near_forearm=1}},
 {144,105,2.7,{near_forearm=.8,hand=.2}},
 {142,107,2.7,{near_forearm=.5,hand=.5}},
 {137,110,3.6,{hand=1}}, {132,112,3.1,{hand=1}},
 {130,113,1.6,{hand=1}},
})
strip('head',{
 {119,23,3,{head=1}}, {120,26,8,{head=1}},
 {119,32,10.6,{head=1}}, {118,39,11.3,{head=1}},
 {118,46,8.8,{head=1}}, {118,51,4.6,{head=1}},
 {119,53,2,{head=1}},
},true)
local function rgba(r,g,b)return pc.rgba(r,g,b,255) end
local function line(im,a,b,c)
 local n=math.ceil(math.max(math.abs(b[1]-a[1]),math.abs(b[2]-a[2])))
 for i=0,n do local t=n==0 and 0 or i/n;local x=math.floor(a[1]+(b[1]-a[1])*t+.5);local y=math.floor(a[2]+(b[2]-a[2])*t+.5)
  if x>=0 and x<256 and y>=0 and y<256 then im:drawPixel(x,y,c) end
 end
end
local sprite=Sprite(256,256,ColorMode.RGB);sprite:deleteLayer(sprite.layers[1])
local allwire=Image(256,256);local surface=Image(256,256)
for _,m in ipairs(meshes) do
 local lay=sprite:newLayer();lay.name=m.name;lay.data=json{mesh=m.name,source='authored neutral body geometry; no garment'}
 local im=Image(256,256)
 for _,tri in ipairs(m.triangles) do
  local a,b,c=m.vertices[tri[1]+1],m.vertices[tri[2]+1],m.vertices[tri[3]+1]
  local minx=math.max(0,math.floor(math.min(a[1],b[1],c[1])));local maxx=math.min(255,math.ceil(math.max(a[1],b[1],c[1])))
  local miny=math.max(0,math.floor(math.min(a[2],b[2],c[2])));local maxy=math.min(255,math.ceil(math.max(a[2],b[2],c[2])))
  local function cross(p,q,x,y)return (q[1]-p[1])*(y-p[2])-(q[2]-p[2])*(x-p[1]) end
  for y=miny,maxy do for x=minx,maxx do
   local d,e,f=cross(a,b,x+.5,y+.5),cross(b,c,x+.5,y+.5),cross(c,a,x+.5,y+.5)
   if (d>=0 and e>=0 and f>=0) or (d<=0 and e<=0 and f<=0) then
    local col=rgba(145,164,169);im:drawPixel(x,y,col);surface:drawPixel(x,y,col)
   end
  end end
  line(allwire,a,b,rgba(71,104,116));line(allwire,b,c,rgba(71,104,116));line(allwire,c,a,rgba(71,104,116))
 end
 sprite:newCel(lay,1,im,Point(0,0))
end
local wirelayer=sprite:newLayer();wirelayer.name='Mesh triangles';sprite:newCel(wirelayer,1,allwire,Point(0,0))
local joints=Image(256,256)
for _,b in ipairs(bones) do if not b.accessory then
 line(joints,b.at,b.tip,rgba(80,238,194))
 for y=b.at[2]-1,b.at[2]+1 do for x=b.at[1]-1,b.at[1]+1 do joints:drawPixel(x,y,rgba(255,208,99)) end end
end end
local sklayer=sprite:newLayer();sklayer.name='Corrected rest joints';sprite:newCel(sklayer,1,joints,Point(0,0))
sprite:saveAs(root..'/pixel-assets/aseprite/female-body-mesh-v02.aseprite')
surface:saveAs(root..'/godot-client/assets/body-mesh-rest.png')
allwire:saveAs(root..'/godot-client/assets/body-mesh-wire.png')
local result={meshes=meshes,kind='neutral unclothed featureless 2D mannequin',coordinate_space='256x256 reference canvas',body_shape='reconstructed estimate; not anatomical ground truth',garments=false}
write(root..'/godot-client/assets/body-mesh.json',result)
local check=Sprite{fromFile=root..'/pixel-assets/aseprite/female-body-mesh-v02.aseprite'}
assert(#check.layers==8 and #check.frames==1)
-- Retain the approved face/hair only; the source layer included a collar.
local head=Image{fromFile=root..'/godot-client/assets/parts/head_hair.png'}
for y=54,255 do for x=0,255 do
 if x<131 or y>60 then head:drawPixel(x,y,0) end
end end
head:saveAs(root..'/godot-client/assets/body-head.png')
print('ASEPRITE_BODY_MESH_READY layers='..#check.layers..' mesh_parts='..#meshes)
