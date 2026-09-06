-- Aseprite source authoring; approved body files remain read-only.
local root=assert(app.params.root)
local pc=app.pixelColor
local W,H=256,256
local out=root..'/pixel-assets/prototype-actors/source-textures/'
local parts=root..'/godot-client/assets/parts/'
local function alpha(im,x,y)return x>=0 and y>=0 and x<W and y<H and pc.rgbaA(im:getPixel(x,y))>0 end
local function shade(c,s)return pc.rgba(math.min(255,math.floor(pc.rgbaR(c)*s)),math.min(255,math.floor(pc.rgbaG(c)*s)),math.min(255,math.floor(pc.rgbaB(c)*s)),pc.rgbaA(c)) end
local function merge(names)local im=Image(W,H);for _,n in ipairs(names) do im:drawImage(Image{fromFile=parts..n..'.png'}) end;return im end
-- These existing cutouts retain the reviewed reference's actual pixel clusters:
-- woven folds, bevelled metal, leather, rivets and articulated boot panels.
local materials={
 far_leg=merge({'far_trousers','far_boot'}),near_leg=merge({'near_trousers','near_boot'}),
 far_arm=merge({'far_sleeve','far_hand_bracer'}),near_arm=merge({'near_sleeve','near_bracer'}),
 torso_pelvis=merge({'cloth_torso','cloth_waist','red_belt'}),
 chest=merge({'armour_torso'}),sword=merge({'sheathed_sword'}),belt=merge({'red_belt'})}
local function bounds(im)
 local rows={};local top,bottom=H,-1
 for y=0,H-1 do local a,b=W,-1;for x=0,W-1 do if alpha(im,x,y) then a=math.min(a,x);b=math.max(b,x) end end
 if b>=a then rows[y]={a,b};top=math.min(top,y);bottom=math.max(bottom,y) end end
 return rows,top,bottom
end
local meta={}
for n,im in pairs(materials) do local r,t,b=bounds(im);meta[n]={rows=r,top=t,bottom=b} end
local function sample(n,u,v,back)
 local m=meta[n];local sy=math.floor(m.top+math.max(0,math.min(1,v))*(m.bottom-m.top)+.5);local row=m.rows[sy]
 if not row then for k=1,H do if m.rows[sy-k] then sy=sy-k;row=m.rows[sy];break elseif m.rows[sy+k] then sy=sy+k;row=m.rows[sy];break end end end
 local sx=math.floor(row[1]+math.max(0,math.min(1,u))*(row[2]-row[1])+.5)
 local c=materials[n]:getPixel(sx,sy)
 if pc.rgbaA(c)==0 then for r=1,20 do if alpha(materials[n],sx-r,sy) then c=materials[n]:getPixel(sx-r,sy);break elseif alpha(materials[n],sx+r,sy) then c=materials[n]:getPixel(sx+r,sy);break end end end
 return shade(c,back and .88 or 1)
end
local joints={
 female={far={{105,64},{97,93},{92,120},{91,131}},near={{139,64},{155,90},{142,107},{133,112}}},
 male={far={{100,55},{95,89},{87,121},{87,136}},near={{148,55},{160,84},{146,106},{136,110}}}}
local function segment_distance(x,y,a,b)
 local dx,dy=b[1]-a[1],b[2]-a[2];local t=math.max(0,math.min(1,((x-a[1])*dx+(y-a[2])*dy)/(dx*dx+dy*dy)))
 return math.sqrt((x-a[1]-dx*t)^2+(y-a[2]-dy*t)^2)
end
local function nearest_pixel(im,x,y)
 if alpha(im,x,y) then return im:getPixel(x,y) end
 for r=1,10 do for yy=math.max(0,y-r),math.min(H-1,y+r) do for xx=math.max(0,x-r),math.min(W-1,x+r) do if alpha(im,xx,yy) then return im:getPixel(xx,yy) end end end end
 return 0
end
for _,gender in ipairs({'female','male'}) do
 local male=gender=='male';local prefix=male and 'male-body-v01' or 'body-v03'
 local input=root..'/asset-library/characters/human-'..gender..'-base/'..(male and '0.1.0' or '1.0.0')..'/runtime/assets/'
 local source={};for _,part in ipairs({'far_leg','near_leg','far_arm','torso_pelvis','near_arm'}) do source[part]=Image{fromFile=input..prefix..'-'..part..'.png'} end
 for _,direction in ipairs({'sw','se','nw','ne'}) do
  local back=direction=='nw' or direction=='ne'
  local native=Sprite(W,H,ColorMode.RGB);native:deleteLayer(native.layers[1])
  local function save(n,im)local l=native:newLayer();l.name=n;native:newCel(l,1,im,Point(0,0));im:saveAs(out..gender..'-'..direction..'-'..n..'.png') end
  local clothes={}
  for _,part in ipairs({'far_leg','near_leg','far_arm','torso_pelvis','near_arm'}) do
   local im=source[part];save('body_'..part,im)
   local rows,top,bottom=bounds(im);local cloth=Image(W,H)
   local cutoff=part=='far_arm' and (male and 120 or 116) or (male and 104 or 103)
   local last=part:find('arm') and cutoff-1 or bottom
   for y=top,last do local row=rows[y]
    if row then
     local padding=part:find('leg') and y>190 and 3 or 2
     for x=row[1]-padding,row[2]+padding do
      local on=alpha(im,x,y)
      if not on then for offset=1,padding do if alpha(im,x-offset,y) or alpha(im,x+offset,y) then on=true end end end
      if on then
       local u=(x-row[1]+padding)/math.max(1,row[2]-row[1]+padding*2);local v=(y-top)/math.max(1,last-top)
       local c=sample(part,u,v,back)
       if part=='torso_pelvis' then
        local neck=male and 46 or 56
        if y<neck then on=false end
        if not back and y<neck+11 and math.abs(x-119)<(neck+11-y)*.42 then on=false end
        if y>=111 and y<=121 then c=sample('belt',u,(y-111)/10,back) end
       end
       if on then cloth:drawPixel(x,y,c) end
      end
     end
    end
   end
   clothes[part]=cloth;save('cloth_'..part,cloth)
  end
  local armor=Image(W,H);local rows=bounds(source.torso_pelvis);local top=male and 49 or 60
  for y=top,111 do local row=rows[y]
   if row then for x=row[1]+1,row[2]-1 do
    local u=(x-row[1]-1)/math.max(1,row[2]-row[1]-2)
    local c=sample('chest',u,(y-top)/(111-top),back)
    if back and x>=121 and x<=122 then c=shade(c,.7) end
    armor:drawPixel(x,y,c)
   end end
  end
  save('chest',armor)
  local sword=Image(W,H);local ax,ay=back and 102 or 139,117
  local angle=math.atan(64,back and -28 or 28)-math.atan(42,38);local cs,sn=math.cos(angle),math.sin(angle)
  for y=0,H-1 do for x=0,W-1 do
   local dx,dy=(x-ax)/1.15,(y-ay)/1.15;local sx=math.floor(143+cs*dx+sn*dy+.5);local sy=math.floor(119-sn*dx+cs*dy+.5)
   if alpha(materials.sword,sx,sy) then sword:drawPixel(x,y,materials.sword:getPixel(sx,sy)) end
  end end
  save('sword',sword)
  -- New animation-only limb cutouts use the approved pixels. Split by nearest
  -- shoulder/elbow/wrist segment with concealed overlap caps, rather than the
  -- old source's y-only weight blend that crushed a straightened elbow.
  for _,side in ipairs({'far','near'}) do
   local js=joints[gender][side]
   for _,category in ipairs({'body','cloth'}) do
    local arm=category=='body' and source[side..'_arm'] or clothes[side..'_arm']
    for segment,name in ipairs({'upper_arm','forearm','hand'}) do
     local im=Image(W,H)
     for y=0,H-1 do for x=0,W-1 do if alpha(arm,x,y) then
      local ds={};local closest=1
      for i=1,3 do ds[i]=segment_distance(x,y,js[i],js[i+1]);if ds[i]<ds[closest] then closest=i end end
      local a,b=js[segment],js[segment+1]
      local da=math.sqrt((x-a[1])^2+(y-a[2])^2);local db=math.sqrt((x-b[1])^2+(y-b[2])^2)
      if closest==segment or da<6 or db<6 then im:drawPixel(x,y,arm:getPixel(x,y)) end
     end end end
     for endpoint=1,2 do
      local j=js[segment+endpoint-1];local radius=segment==3 and 3 or 5
      if category=='cloth' then radius=radius+1 end
      for dy=-radius,radius do for dx=-radius,radius do if dx*dx+dy*dy<=radius*radius then
       local x,y=j[1]+dx,j[2]+dy
       if category=='body' or segment<3 then im:drawPixel(x,y,nearest_pixel(arm,x,y)) end
      end end end
     end
     save(category..'_'..side..'_'..name,im)
    end
   end
  end
  native:saveAs(root..'/pixel-assets/prototype-actors/native/'..gender..'-'..direction..'-garment-source.aseprite');native:close()
 end
end
print('ACTOR GARMENT SOURCES SAVED')
