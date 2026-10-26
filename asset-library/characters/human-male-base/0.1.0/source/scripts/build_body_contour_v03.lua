-- Aseprite authors a neutral body contour master, then exports meshes from
-- that exact master. No independently guessed widths in the downstream rig.
-- Female v03 is user-approved; male v01 is a new review sample.
local root=assert(app.params.root)
local pc=app.pixelColor
local W,H=256,256
local base=root..'/pixel-assets/'
local out=root..'/godot-client/assets/'
local male=app.params.character=='male'
local prefix=male and 'male-body-v01' or 'body-v03'
local source=male and 'male-rig-reference-v01.png' or 'female-rig-unitard-v02.png'
local native=male and 'male-body-contour-v01.aseprite' or 'female-body-contour-v03.aseprite'
local headfile=male and 'male-body-head.png' or 'body-head.png'
local function json(v)
 if type(v)=='table' then
  local a={};if #v>0 then for _,x in ipairs(v) do a[#a+1]=json(x) end return '['..table.concat(a,',')..']' end
  for k,x in pairs(v) do a[#a+1]=json(k)..':'..json(x) end return '{'..table.concat(a,',')..'}'
 elseif type(v)=='string' then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"')..'"'
 elseif type(v)=='boolean' then return v and 'true' or 'false' else return tostring(v) end
end
local function write(p,v)local f=assert(io.open(p,'w'));f:write(json(v));f:close() end
local function inside(x,y,poly)
 local yes=false;local j=#poly
 for i=1,#poly do local a,b=poly[i],poly[j]
  if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then yes=not yes end;j=i
 end;return yes
end
local ref=Image{fromFile=base..'sources/'..source}
local silhouette={}
for y=0,H-1 do for x=0,W-1 do
 local sx,sy=math.floor((x+.5)*5),math.floor((y+.5)*5)
 local on=false
 if sx<ref.width and sy<ref.height then
  local c=ref:getPixel(sx,sy);local r,g,b=pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)
  on=pc.rgbaA(c)>127 and not(math.min(r,g,b)>210 and math.max(r,g,b)-math.min(r,g,b)<12)
 end
 -- The existing image supplies a proportion guide, not a nude truth mask.
 -- No fabric pixels are copied: the neutral body master is painted below.
 if male then
  if y<44 then on=false end
 elseif y<53 or (y<61 and x>130+(y-53)*2) then on=false end
 -- Bare-foot contour draft, anchored at the existing ankles. This contour
 -- replaces the guide's footwear silhouette explicitly.
 if not male then
  if y>=214 and x<122 then on=inside(x+.5,y+.5,{{102,213},{111,213},{111,218},{107,222},{100,225},{94,228},{88,228},{86,226},{89,223},{96,220},{101,216}}) end
  if y>=220 and x>=122 then on=inside(x+.5,y+.5,{{143,219},{151,219},{153,224},{153,230},{151,235},{147,238},{142,239},{139,237},{139,233},{141,229},{143,225}}) end
 end
 silhouette[y*W+x]=on
end end
local nearpoly={{134,58},{148,58},{164,83},{164,97},{149,109},{142,114},{132,114},{126,112},{126,104},{137,101},{145,99},{149,92},{141,78},{133,69}}
local farpoly={{105,60},{108,69},{104,86},{102,101},{98,116},{98,135},{87,138},{84,126},{90,101},{93,74},{98,62}}
if male then
 nearpoly={{142,48},{158,50},{171,82},{169,94},{152,108},{142,115},{130,115},{127,110},{127,103},{139,99},{150,99},{155,85},{146,73},{141,64}}
 farpoly={{100,51},{105,61},{103,77},{101,88},{99,104},{92,121},{93,142},{79,142},{79,126},{84,111},{89,96},{91,74},{94,58}}
end
local pieces={}
local function piece(name,condition)
 local mask={};for y=0,H-1 do for x=0,W-1 do mask[y*W+x]=silhouette[y*W+x] and condition(x+.5,y+.5) end end
 local p={name=name,mask=mask};pieces[#pieces+1]=p;return p
end
piece('far_leg',function(x,y)return y>=122 and x<120 end)
piece('near_leg',function(x,y)return y>=122 and x>=120 end)
piece('far_arm',function(x,y)return inside(x,y,farpoly) end)
local torso=piece('torso_pelvis',function(x,y)return y<139 and not inside(x,y,farpoly) and not inside(x,y,nearpoly) end)
-- Fill the small occluded waist area underneath the resting hand, so the
-- hand can move away without leaving a hand-shaped hole in the torso.
for y=male and 100 or 103,male and 115 or 113 do
 for x=male and 127 or 125,male and 142 or 134 do
  if silhouette[y*W+x] then torso.mask[y*W+x]=true end
 end
end
piece('near_arm',function(x,y)return inside(x,y,nearpoly) end)
local edited_master=nil
if app.params.from_master=='true' then
 edited_master=Sprite{fromFile=base..'aseprite/'..native}
 silhouette={}
 for _,p in ipairs(pieces) do
  local found=nil;for _,l in ipairs(edited_master.layers) do if l.name==p.name then found=l end end
  assert(found,'Body master layer missing: '..p.name)
  local cel=found:cel(1);assert(cel,'Body master cel missing: '..p.name)
  p.native_image=Image(W,H);p.native_image:drawImage(cel.image,cel.position)
  for y=0,H-1 do for x=0,W-1 do
   local on=pc.rgbaA(p.native_image:getPixel(x,y))>127
   p.mask[y*W+x]=on;if on then silhouette[y*W+x]=true end
  end end
 end
end
local function clamp(v)return math.max(0,math.min(1,v)) end
local function mix(a,b,t)
 t=clamp(t);if t<=0 then return {[a]=1} elseif t>=1 then return {[b]=1} end
 return {[a]=1-t,[b]=t}
end
local function weights(name,x,y)
 if male then
  if name=='torso_pelvis' then
   if y<51 then return mix('head','torso',(y-44)/7) end
   return mix('torso','hips',(y-88)/26)
  elseif name=='far_leg' or name=='near_leg' then
   local side=name=='far_leg' and 'far' or 'near'
   local knee=side=='far' and 167 or 168;local ankle=side=='far' and 218 or 222
   if y<138 then return mix('hips',side..'_thigh',(y-123)/15)
   elseif y<knee+5 then return mix(side..'_thigh',side..'_shin',(y-knee+5)/10)
   else return mix(side..'_shin',side..'_foot',(y-ankle+4)/8) end
  elseif name=='far_arm' then
   if y<68 then return mix('torso','far_upper_arm',(y-55)/13)
   elseif y<96 then return mix('far_upper_arm','far_forearm',(y-85)/11)
   else return mix('far_forearm','far_hand',(y-118)/8) end
  else
   if y<68 then return mix('torso','near_upper_arm',(y-55)/13)
   elseif y<91 then return mix('near_upper_arm','near_forearm',(y-80)/11)
   else return mix('near_forearm','hand',(y-102)/9) end
  end
 end
 if name=='torso_pelvis' then
  if y<58 then return mix('head','torso',(y-51)/7) end
  return mix('torso','hips',(y-87)/23)
 elseif name=='far_leg' or name=='near_leg' then
  local side=name=='far_leg' and 'far' or 'near'
  local knee=side=='far' and 167 or 169;local ankle=side=='far' and 213 or 219
  if y<134 then return mix('hips',side..'_thigh',(y-122)/12)
  elseif y<knee+5 then return mix(side..'_thigh',side..'_shin',(y-knee+5)/10)
  else return mix(side..'_shin',side..'_foot',(y-ankle+4)/8) end
 elseif name=='far_arm' then
  if y<73 then return mix('torso','far_upper_arm',(y-61)/12)
  elseif y<100 then return mix('far_upper_arm','far_forearm',(y-89)/10)
  else return mix('far_forearm','far_hand',(y-116)/8) end
 else
  if y<73 then return mix('torso','near_upper_arm',(y-60)/13)
  elseif y<97 then return mix('near_upper_arm','near_forearm',(y-86)/11)
  else return mix('near_forearm','hand',(y-103)/8) end
 end
end
local function make_mesh(p)
 local cells={}
 local function occupied(x,y)return x>=0 and y>=0 and x<W and y<H and p.mask[y*W+x] end
 local function cell(x,y,s)
  local n=0;for yy=y,y+s-1 do for xx=x,x+s-1 do if occupied(xx,yy) then n=n+1 end end end
  if n==0 then return elseif n==s*s then cells[#cells+1]={x,y,s}
  else local h=s/2;cell(x,y,h);cell(x+h,y,h);cell(x,y+h,h);cell(x+h,y+h,h) end
 end
 for y=0,H-1,4 do for x=0,W-1,4 do cell(x,y,4) end end
 local vertices,lookup,triangles,ws={},{},{},{}
 local function vertex(x,y)
  local k=string.format('%.3f,%.3f',x,y);if lookup[k] then return lookup[k] end
  local idx=#vertices;vertices[idx+1]={x,y};ws[idx+1]=weights(p.name,x,y);lookup[k]=idx;return idx
 end
 for _,c in ipairs(cells) do local x,y,s=c[1],c[2],c[3];vertex(x,y);vertex(x+s,y);vertex(x+s,y+s);vertex(x,y+s) end
 -- Split shared edges at every existing corner to remove T-junctions.
 -- Neighbouring triangles share vertices and identical weights when posed.
 for _,c in ipairs(cells) do
  local x,y,s=c[1],c[2],c[3];local edge={}
  local function add(xx,yy)local k=string.format('%.3f,%.3f',xx,yy);if lookup[k]~=nil then edge[#edge+1]=lookup[k] end end
  for k=0,s-1 do add(x+k,y) end
  for k=0,s-1 do add(x+s,y+k) end
  for k=0,s-1 do add(x+s-k,y+s) end
  for k=0,s-1 do add(x,y+s-k) end
  local centre=vertex(x+s/2,y+s/2)
  for i=1,#edge do triangles[#triangles+1]={centre,edge[i],edge[i%#edge+1]} end
 end
 return {name=p.name,vertices=vertices,weights=ws,triangles=triangles}
end
local shades={}
for y=0,H-1 do
 local x=0
 while x<W do
  if silhouette[y*W+x] then
   local a=x;while x<W and silhouette[y*W+x] do x=x+1 end
   local b=x-1
   for xx=a,b do
    local t=(xx-a)/math.max(1,b-a)
    local value=.82+.18*math.sin(t*math.pi)+.035*(1-t)
    shades[y*W+xx]=math.floor(value*24+.5)/24
   end
  else x=x+1 end
 end
end
local master=Sprite(W,H,ColorMode.RGB);master:deleteLayer(master.layers[1])
local meshes={};local master_pixels=0;local union={}
for _,p in ipairs(pieces) do
 local im=Image(W,H)
 for y=0,H-1 do for x=0,W-1 do if p.mask[y*W+x] then
  -- Smooth neutral sculpture shading; no clothing texture or seams.
  local shade=shades[y*W+x] or 1
  local col=p.native_image and p.native_image:getPixel(x,y) or pc.rgba(math.floor(202*shade),math.floor(181*shade),math.floor(158*shade),255)
  im:drawPixel(x,y,col);union[y*W+x]=true
 end end end
 local layer=master:newLayer();layer.name=p.name;master:newCel(layer,1,im,Point(0,0))
 im:saveAs(out..prefix..'-'..p.name..'.png')
 meshes[#meshes+1]=make_mesh(p)
end
for _ in pairs(union) do master_pixels=master_pixels+1 end
local body=Image(W,H);body:drawSprite(master,1);body:saveAs(out..prefix..'-master.png')
local wire=Image(W,H)
local function line(im,a,b,col)
 local n=math.max(math.abs(b[1]-a[1]),math.abs(b[2]-a[2]))
 for i=0,math.ceil(n) do local t=n==0 and 0 or math.min(1,i/n);local x=math.floor(a[1]+(b[1]-a[1])*t);local y=math.floor(a[2]+(b[2]-a[2])*t)
  if x>=0 and x<W and y>=0 and y<H then im:drawPixel(x,y,col) end
 end
end
for _,m in ipairs(meshes) do for _,t in ipairs(m.triangles) do for j=1,3 do line(wire,m.vertices[t[j]+1],m.vertices[t[j%3+1]+1],pc.rgba(65,93,104,255)) end end end
local layer=master:newLayer();layer.name='Mesh - generated from body contour';master:newCel(layer,1,wire,Point(0,0));layer.isVisible=false
local bones=dofile(root..'/scripts/'..(male and 'male_rig_landmarks.lua' or 'rig_landmarks.lua'))
local anatomy={};local joints=Image(W,H)
for _,b in ipairs(bones) do if not b.accessory then
 local dx,dy=b.tip[1]-b.at[1],b.tip[2]-b.at[2];b.length=math.sqrt(dx*dx+dy*dy);b.angle=math.atan(dy,dx);anatomy[#anatomy+1]=b
 line(joints,b.at,b.tip,pc.rgba(70,242,183,255))
end end
local bl=master:newLayer();bl.name='Skeleton rest joints';master:newCel(bl,1,joints,Point(0,0));bl.isVisible=false
local head
if male then
 head=Image(W,H)
 for y=0,45 do for x=0,W-1 do
  local sx,sy=math.floor((x+.5)*5),math.floor((y+.5)*5)
  if sx<ref.width and sy<ref.height then
   local c=ref:getPixel(sx,sy);local r,g,b=pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)
   if pc.rgbaA(c)>127 and not(math.min(r,g,b)>210 and math.max(r,g,b)-math.min(r,g,b)<12) and (y<39 or (r>g*1.08 and g>b*1.09)) then head:drawPixel(x,y,c) end
  end
 end end
else head=Image{fromFile=out..headfile} end
if edited_master then
 for _,l in ipairs(edited_master.layers) do if l.name=='Approved face and hair' or l.name=='Face and hair' then
  local cel=l:cel(1);head=Image(W,H);head:drawImage(cel.image,cel.position)
 end end
end
head:saveAs(out..headfile)
local hl=master:newLayer();hl.name=male and 'Face and hair' or 'Approved face and hair';master:newCel(hl,1,head,Point(0,0))
master:saveAs(base..'aseprite/'..native)
local flat=Image(W,H);flat:drawSprite(master,1);flat:saveAs(out..prefix..'-preview.png')
local data={meshes=meshes,garments=false,art_status=male and 'pending user review' or 'user approved 2026-09-06',source_guide=source..' proportion and silhouette guide; body painted separately',mesh_source=edited_master and 'native Aseprite master layers' or 'initial contour draft',master=prefix..'-master.png',width=W,height=H,master_pixels=master_pixels,body_shape='contour authored in Aseprite; mesh follows the same body master'}
write(out..prefix..'-mesh.json',data);write(out..prefix..'-rig.json',{bones=anatomy})
local check=Sprite{fromFile=base..'aseprite/'..native}
assert(#check.layers==8 and #check.frames==1)
local readback=Image(W,H);readback:drawSprite(check,1);assert(readback:isEqual(flat),'Native source roundtrip differs')
print('BODY_CONTOUR_READY character='..(male and 'male' or 'female')..' parts='..#meshes..' master_pixels='..master_pixels..' native_roundtrip=true')
