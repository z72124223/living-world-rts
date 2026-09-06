-- Run by real Aseprite: aseprite -b --script-param root=... --script this.lua
-- Source art is AI generated; segmentation, keyed cutout animation, cels,
-- weapon pixels, scene assets and all exports are authored through Aseprite.
local root=assert(app.params.root,'root parameter required')
local src=root..'/pixel-assets/sources/'
local out=root..'/godot-client/assets/'
local ase=root..'/pixel-assets/aseprite/'
local pc=app.pixelColor
local W,H,S=256,256,0.20
local function json(v)
  if type(v)=='table' then
    local a={};if #v>0 then for _,x in ipairs(v) do a[#a+1]=json(x) end return '['..table.concat(a,',')..']' end
    for k,x in pairs(v) do a[#a+1]=json(k)..':'..json(x) end return '{'..table.concat(a,',')..'}'
  elseif type(v)=='string' then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'
  elseif type(v)=='boolean' then return v and 'true' or 'false' else return tostring(v) end
end
local function write(path,v)local f=assert(io.open(path,'w'));f:write(json(v));f:close() end
local function inside(x,y,p)
  local c=false;local j=#p
  for i=1,#p do local a,b=p[i],p[j];if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then c=not c end;j=i end
  return c
end
local arm=Image{fromFile=src..'female-armoured-reference.png'}
local cloth=Image{fromFile=src..'female-cloth-base.png'}
local function is_bg(c)
  if pc.rgbaA(c)<128 then return true end
  local r,g,b=pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)
  return (r>175 and g>169 and b>150 and math.max(r,g,b)-math.min(r,g,b)<47)
end
-- Sample a target pixel from the approved source. Native game pixels are fixed,
-- and backgrounds are excluded with both outline masks and colour tests.
local function sample(im,x,y)
  local xx=math.floor((x+.5)/S);local yy=math.floor((y+.5)/S)
  if xx<0 or yy<0 or xx>=im.width or yy>=im.height then return 0 end
  local c=im:getPixel(xx,yy);if is_bg(c) then return 0 end
  return pc.rgba(pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c),255)
end
local bones=dofile(root..'/scripts/rig_landmarks.lua')
for _,b in ipairs(bones) do
 local dx,dy=b.tip[1]-b.at[1],b.tip[2]-b.at[2]
 b.length=math.sqrt(dx*dx+dy*dy);b.angle=math.atan(dy,dx)
end
local bmap={};for _,b in ipairs(bones) do bmap[b.name]=b end
local parts={}
local function part(name,bone,im,poly,gear,z)
  local image=Image(W,H,ColorMode.RGB)
  for y=0,H-1 do for x=0,W-1 do
    if inside((x+.5)/S,(y+.5)/S,poly) then
      local c=sample(im,x,y)
      -- Complete the area underneath the resting near hand, so moving that
      -- hand never leaves a duplicate hand painted on the waist layer.
      if (name=='armour_tassets' or name=='cloth_waist') and inside(x/S,y/S,{{631,524},{719,520},{737,559},{710,591},{650,588},{628,565}}) then
        c=sample(im,x-21,y)
      end
      image:drawPixel(x,y,c)
    end
  end end
  local p={name=name,bone=bone,gear=gear or 'base',z=z,image=image};parts[#parts+1]=p
  return p
end
-- Leg pieces overlap behind tassets and boots. Their hidden joint areas are
-- filled from the cloth image, and never depend on a flattened armour image.
part('far_trousers','far_thigh',cloth,{{481,641},{618,640},{635,832},{627,916},{592,953},{523,938},{477,897},{472,754}},nil,0)
part('near_trousers','near_thigh',cloth,{{610,624},{732,614},{764,738},{801,859},{786,924},{739,957},{670,943},{617,892}},nil,1)
part('far_boot','far_shin',arm,{{517,895},{605,891},{603,964},{582,1020},{582,1120},{527,1137},{445,1141},{403,1126},{403,1098},{472,1064},{493,979}},nil,2)
part('near_boot','near_shin',arm,{{680,907},{765,910},{776,1006},{790,1067},{794,1151},{767,1196},{715,1200},{690,1175},{695,1119},{686,1045},{670,978}},nil,3)
part('far_sleeve','far_upper_arm',cloth,{{500,332},{555,325},{550,442},{519,532},{463,533},{463,478},{481,400}},nil,4)
part('far_hand_bracer','far_forearm',arm,{{469,493},{514,500},{494,583},{477,617},{475,661},{460,686},{440,680},{431,650},{438,608},{447,557}},nil,5)
part('cloth_torso','torso',cloth,{{584,269},{648,268},{703,296},{738,375},{701,466},{680,515},{531,521},{500,456},{519,350}},nil,6)
part('cloth_waist','hips',cloth,{{532,448},{694,447},{715,515},{707,599},{743,677},{716,758},{538,764},{495,694},{505,582}},nil,7)
part('sheathed_sword','hips',arm,{{688,556},{741,572},{776,631},{923,788},{917,815},{896,821},{868,802},{743,677},{697,628}},'sheath',8)
part('armour_torso','torso',arm,{{548,279},{605,316},{674,279},{709,307},{711,393},{694,455},{675,493},{531,496},{499,450},{481,396},{502,320}},'armour',9)
part('armour_tassets','hips',arm,{{496,510},{613,512},{660,492},{701,514},{749,598},{757,695},{792,753},{775,779},{684,800},{649,759},{552,743},{483,723},{452,707},{457,611}},'armour',10)
part('red_belt','hips',arm,{{531,442},{578,462},{660,453},{692,437},{710,470},{682,506},{631,529},{578,521},{521,510}},nil,11)
part('red_sash','sash',arm,{{583,494},{628,495},{640,601},{680,772},{646,785},{616,774},{601,683},{590,587}},nil,12)
part('near_sleeve','near_upper_arm',cloth,{{689,296},{737,311},{771,348},{800,407},{821,457},{793,484},{745,493},{713,443},{689,381}},nil,13)
part('near_bracer','near_forearm',arm,{{752,454},{796,472},{785,510},{758,548},{715,564},{687,534},{711,497}},nil,14)
part('far_pauldron','far_upper_arm',arm,{{502,298},{551,276},{563,306},{552,349},{517,383},{484,398},{479,369}},'armour',15)
part('near_pauldron','near_upper_arm',arm,{{680,276},{725,289},{751,313},{767,345},{788,381},{768,399},{706,378},{675,335}},'armour',16)
part('head_hair','head',arm,{{510,177},{514,145},{555,98},{613,88},{632,52},{666,42},{698,62},{717,101},{728,172},{754,218},{757,264},{738,307},{699,307},{658,281},{642,311},{583,303},{561,280},{545,237},{524,218}},nil,17)
part('near_hand','hand',arm,{{684,525},{717,546},{707,570},{682,584},{660,578},{637,568},{638,550},{654,535}},nil,19)

local function color(h)return pc.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),255) end
local function pixline(im,x0,y0,x1,y1,c,r)
  local n=math.max(math.abs(x1-x0),math.abs(y1-y0));for i=0,n do local t=n==0 and 0 or i/n;local x=math.floor(x0+(x1-x0)*t+.5);local y=math.floor(y0+(y1-y0)*t+.5)
    for yy=y-(r or 0),y+(r or 0) do for xx=x-(r or 0),x+(r or 0) do if xx>=0 and yy>=0 and xx<im.width and yy<im.height then im:drawPixel(xx,yy,c) end end end
  end
end
local sword=Image(W,H,ColorMode.RGB)
-- The weapon's handle is at the same hand attachment; blade points down-right.
pixline(sword,134,106,174,151,color('202d37'),2)
pixline(sword,141,114,174,151,color('829b9c'),1)
pixline(sword,141,113,173,149,color('dae1c5'),0)
pixline(sword,137,119,148,110,color('b89755'),1)
pixline(sword,134,106,139,112,color('624631'),1)
parts[#parts+1]={name='drawn_sword',bone='weapon',gear='sword',z=18,image=sword}
local spear=Image(W,H,ColorMode.RGB)
pixline(spear,157,150,117,57,color('293039'),2)
pixline(spear,157,150,117,57,color('98734b'),1)
pixline(spear,117,60,108,38,color('c7d1bf'),1)
pixline(spear,117,58,121,46,color('769297'),1)
pixline(spear,121,46,108,38,color('e7e9cc'),0)
pixline(spear,117,60,121,73,color('a64337'),1)
parts[#parts+1]={name='long_spear',bone='weapon',gear='spear',z=18,image=spear}
table.sort(parts,function(a,b)return a.z<b.z end)

-- Bone keys are stepped at 10 FPS in both Aseprite and Godot. No claim of
-- hand-drawn multi-view animation: this is keyed modular cutout animation.
local frames={}
local function key(anim,i,n)
 local a={};local bob=0;local t=(i-1)/n*math.pi*2
 if anim=='idle' then a.torso=math.sin(t)*.7;a.head=-math.sin(t)*.7;bob=math.floor(math.sin(t)+.5)
 elseif anim=='walk' then
   a.far_thigh=math.sin(t)*11;a.near_thigh=-math.sin(t)*11
   a.far_shin=math.max(0,-math.sin(t))*15;a.near_shin=math.max(0,math.sin(t))*15
   a.far_upper_arm=-math.sin(t)*9;a.near_upper_arm=math.sin(t)*7
   a.far_forearm=math.cos(t)*5;a.near_forearm=-math.cos(t)*4
   a.sash=math.sin(t-.5)*4;a.torso=math.sin(t)*1.5;bob=-math.floor(math.abs(math.sin(t))*2+.5)
 else
   local s={-7,-18,-25,32,18,0};a.torso=s[i]*.22;a.near_upper_arm=s[i];a.near_forearm=s[i]*.8;a.weapon=s[i]*1.15;a.head=-s[i]*.12;a.sash=-s[i]*.14;bob=i==4 and 1 or 0
 end
 return {animation=anim,index=i,duration=anim=='attack' and .095 or .10,angles=a,bob=bob}
end
for _,a in ipairs({{'idle',4},{'walk',8},{'attack',6}}) do for i=1,a[2] do frames[#frames+1]=key(a[1],i,a[2]) end end
local function transforms(f)
 local map={}
 for _,b in ipairs(bones) do
   local rot=(f.angles[b.name] or 0)*math.pi/180;local x,y=b.at[1],b.at[2]+f.bob
   if b.parent~='' then local p=map[b.parent];local bp=bmap[b.parent];local dx,dy=b.at[1]-bp.at[1],b.at[2]-bp.at[2]
     x=p.x+math.cos(p.r)*dx-math.sin(p.r)*dy;y=p.y+math.sin(p.r)*dx+math.cos(p.r)*dy;rot=rot+p.r
   end
   map[b.name]={x=x,y=y,r=rot}
 end
 return map
end
local function render_part(p,t)
 local im=Image(W,H,ColorMode.RGB);local b=bmap[p.bone];local cs,sn=math.cos(t.r),math.sin(t.r)
 for y=0,H-1 do for x=0,W-1 do
   local dx,dy=x-t.x,y-t.y;local sx=math.floor(cs*dx+sn*dy+b.at[1]+.5);local sy=math.floor(-sn*dx+cs*dy+b.at[2]+.5)
   if sx>=0 and sy>=0 and sx<W and sy<H then local c=p.image:getPixel(sx,sy);if pc.rgbaA(c)>0 then im:drawPixel(x,y,c) end end
 end end
 return im
end
local sprite=Sprite(W,H,ColorMode.RGB);sprite:deleteLayer(sprite.layers[1]);sprite.filename=ase..'female-modular.aseprite'
for _,p in ipairs(parts) do p.layer=sprite:newLayer();p.layer.name=p.name;p.layer.data=json{bone=p.bone,gear=p.gear};p.image:saveAs(out..'parts/'..p.name..'.png') end
for fi,f in ipairs(frames) do
 if fi>1 then sprite:newEmptyFrame(fi) end;sprite.frames[fi].duration=f.duration
 local ts=transforms(f);for _,p in ipairs(parts) do sprite:newCel(p.layer,fi,render_part(p,ts[p.bone]),Point(0,0)) end
end
for _,t in ipairs({{'idle',1,4},{'walk',5,12},{'attack',13,18}}) do local tag=sprite:newTag(t[2],t[3]);tag.name=t[1] end
local function visibility(armoured,weapon)
 for _,p in ipairs(parts) do p.layer.isVisible=p.gear=='base' or p.gear=='armour' and armoured or p.gear==weapon or p.gear=='sheath' and weapon=='sword' end
end
local variants={}
for _,outfit in ipairs({'armour','cloth'}) do for _,weapon in ipairs({'sword','spear','none'}) do
 visibility(outfit=='armour',weapon)
 local sheet=Image(W*6,H*3,ColorMode.RGB)
 for fi=1,#frames do sheet:drawSprite(sprite,fi,Point(((fi-1)%6)*W,math.floor((fi-1)/6)*H)) end
 local name=outfit..'_'..weapon;sheet:saveAs(out..'frames/'..name..'.png');variants[#variants+1]=name
end end
visibility(true,'sword');sprite:saveAs(ase..'female-modular.aseprite')
local pose=Image(W,H);pose:drawSprite(sprite,1);pose:saveAs(out..'female-preview.png')
local metadata={width=W,height=H,foot={128,239},bones=bones,parts={},frames=frames,variants=variants}
for _,p in ipairs(parts) do metadata.parts[#metadata.parts+1]={name=p.name,bone=p.bone,gear=p.gear,z=p.z} end
write(out..'character.json',metadata)

-- Scene texture remains editable in its own native file.
local courtyard=Sprite{fromFile=src..'courtyard.png'}
courtyard:resize(768,512);courtyard.layers[1].name='Courtyard ground and boundary';courtyard:saveAs(ase..'courtyard.aseprite');courtyard:saveCopyAs(out..'courtyard.png')

-- Four-frame slashing effect and a wooden training dummy, authored as pixels.
local fx=Sprite(128,128,ColorMode.RGB);fx.layers[1].name='Sword arc'
for f=1,6 do
 if f>1 then fx:newEmptyFrame(f) end;fx.frames[f].duration=.045;local im=Image(128,128)
 for y=0,127 do for x=0,127 do local dx,dy=x-64,y-64;local d=math.sqrt(dx*dx+dy*dy);local a=math.atan(dy,dx)
   if d>39-f*2 and d<48 and a>-.9+f*.18 and a<1.0+f*.18 then
     im:drawPixel(x,y,color(d>44 and 'ffe8a0' or d>40 and 'e7b557' or 'b55d35'))
   end
 end end
 if f==1 then fx.cels[1].image=im else fx:newCel(fx.layers[1],f,im,Point(0,0)) end
end
local tag=fx:newTag(1,6);tag.name='slash';fx:saveAs(ase..'slash.aseprite')
local fxsheet=Image(768,128);for f=1,6 do fxsheet:drawSprite(fx,f,Point((f-1)*128,0)) end;fxsheet:saveAs(out..'slash.png')
local dummy=Sprite(64,96,ColorMode.RGB);dummy.layers[1].name='Wooden training target';local d=Image(64,96)
local dark,wood,light,rope=color('302b29'),color('76543a'),color('b08754'),color('c8ac72')
for y=6,86 do for x=24,40 do local edge=x<27 or x>37;d:drawPixel(x,y,edge and dark or x<31 and light or wood) end end
for y=29,38 do for x=5,59 do d:drawPixel(x,y,y<32 and light or y>36 and dark or wood) end end
for y=43,70 do for x=19,45 do if (x-32)^2/180+(y-56)^2/205<1 then d:drawPixel(x,y,x<25 and light or wood) end end end
for _,y in ipairs({17,20,47,50,61,64,80}) do pixline(d,23,y,41,y,rope,0) end
pixline(d,12,89,53,89,dark,2);pixline(d,22,86,9,92,wood,1);pixline(d,40,86,54,92,wood,1)
dummy.cels[1].image=d;dummy:saveAs(ase..'training-target.aseprite');d:saveAs(out..'training-target.png')
write(root..'/pixel-assets/build-report.json',{tool='Aseprite',version=tostring(app.version),frames=#frames,layers=#parts,bones=#bones,variants=variants,character_source='AI reference segmented and keyed in Aseprite',animation_method='Modular cutout keyframes rasterized into native Aseprite cels; same keys drive Godot Bone2D',art_approved=false})
print('ASEPRITE_SAMPLE_ASSETS_READY frames='..#frames..' layers='..#parts..' bones='..#bones)
