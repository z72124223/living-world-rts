-- Real Aseprite native edit files + per-layer trimmed runtime atlases.
-- shrinkBounds API: https://aseprite.org/api/image#imageshrinkbounds
local root=assert(app.params.root)
local W,H=192,192
local names={'body_far_leg','cloth_far_leg','body_near_leg','cloth_near_leg','body_far_arm','cloth_far_arm','body_torso_pelvis','cloth_torso_pelvis','sword','chest','body_near_arm','cloth_near_arm','head'}
local counts={idle=4,walk=8,run=8};local offsets={idle=0,walk=4,run=12};local durations={idle=.25,walk=.125,run=1/12}
local function json(v)
 if type(v)=='table' then local a={};if #v>0 then for _,x in ipairs(v) do a[#a+1]=json(x) end;return '['..table.concat(a,',')..']' end
 for k,x in pairs(v) do a[#a+1]=json(k)..':'..json(x) end;return '{'..table.concat(a,',')..'}'
 elseif type(v)=='string' then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"')..'"'
 elseif type(v)=='boolean' then return v and 'true' or 'false' else return tostring(v) end
end
local manifest={version=2,genders={}}
for _,gender in ipairs({'female','male'}) do
 local sprite=Sprite(W,H,ColorMode.RGB);sprite:deleteLayer(sprite.layers[1])
 local layers,images,crops={},{},{}
 for _,n in ipairs(names) do
  local l=sprite:newLayer();l.name=n;l.data='{"source":"approved body + reference garment clusters + joint retargeting","editable":true}'
  layers[n]=l;images[n]=Image{fromFile=root..'/pixel-assets/prototype-actors/baked-layers/'..gender..'-'..n..'.png'}
  crops[n]={W,H,0,0}
 end
 for d,direction in ipairs({'sw','se','nw','ne'}) do
  for f=0,19 do
   local fi=(d-1)*20+f+1;if fi>1 then sprite:newEmptyFrame(fi) end
   local motion=f<4 and 'idle' or (f<12 and 'walk' or 'run');sprite.frames[fi].duration=durations[motion]
   for _,n in ipairs(names) do
    local im=Image(W,H);im:drawImage(images[n],Point(-f*W,-(d-1)*H));sprite:newCel(layers[n],fi,im,Point(0,0))
    local r=im:shrinkBounds();local c=crops[n]
    if r.width>0 and r.height>0 then c[1]=math.min(c[1],r.x);c[2]=math.min(c[2],r.y);c[3]=math.max(c[3],r.x+r.width);c[4]=math.max(c[4],r.y+r.height) end
   end
  end
  for _,motion in ipairs({'idle','walk','run'}) do local first=(d-1)*20+offsets[motion]+1;local tag=sprite:newTag(first,first+counts[motion]-1);tag.name=direction..'_'..motion end
 end
 sprite:saveAs(root..'/pixel-assets/prototype-actors/native/'..gender..'-actor.aseprite')
 local overall={W,H,0,0};local list={};local raw_bytes=0
 for _,n in ipairs(names) do
  local c=crops[n];c[1]=math.max(0,c[1]-1);c[2]=math.max(0,c[2]-1);c[3]=math.min(W,c[3]+1);c[4]=math.min(H,c[4]+1)
  local width,height=c[3]-c[1],c[4]-c[2]
  assert(width>0 and height>0,'Empty layer: '..n)
  local atlas=Image(width*20,height*4)
  for fi=1,80 do
   local cel=layers[n]:cel(fi);local im=Image(width,height)
   im:drawImage(cel.image,Point(cel.position.x-c[1],cel.position.y-c[2]))
   atlas:drawImage(im,Point(((fi-1)%20)*width,math.floor((fi-1)/20)*height))
  end
  atlas:saveAs(root..'/godot-client/prototype/actors/layers/'..gender..'-'..n..'.png')
  local slot=n:find('cloth_') and 'clothing' or (n=='chest' and 'armor' or (n=='sword' and 'weapon' or 'body'))
  list[#list+1]={name=n,slot=slot,rect={c[1],c[2],width,height},path='res://prototype/actors/layers/'..gender..'-'..n..'.png'}
  raw_bytes=raw_bytes+width*height*80*4
  overall[1]=math.min(overall[1],c[1]);overall[2]=math.min(overall[2],c[2]);overall[3]=math.max(overall[3],c[3]);overall[4]=math.max(overall[4],c[4])
 end
 local crop={overall[1],overall[2],overall[3]-overall[1],overall[4]-overall[2]}
 manifest.genders[gender]={canvas={W,H},crop=crop,anchor={96-crop[1],168-crop[2]},columns=20,rows=4,layers=list,source_rgba_bytes=raw_bytes}
 -- Only an offline evidence composite is saved, never eight runtime loadout atlases.
 local proof=Image(W*20,H*4)
 for fi=1,80 do local im=Image(W,H);im:drawSprite(sprite,fi);proof:drawImage(im,Point(((fi-1)%20)*W,math.floor((fi-1)/20)*H)) end
 proof:saveAs(root..'/pixel-assets/prototype-actors/previews/'..gender..'-all.png')
 sprite:close()
 local re=app.open(root..'/pixel-assets/prototype-actors/native/'..gender..'-actor.aseprite')
 assert(#re.layers==13 and #re.frames==80 and #re.tags==12,'Native structure mismatch')
 local diff=0
 for _,l in ipairs(re.layers) do for fi=1,80 do assert(l:cel(fi),'Missing editable cel') end end
 for fi=1,80 do
  local im=Image(W,H);im:drawSprite(re,fi)
  local compare=Image(W,H);compare:drawImage(proof,Point(-((fi-1)%20)*W,-math.floor((fi-1)/20)*H))
  if im.bytes~=compare.bytes then
   for y=0,H-1 do for x=0,W-1 do if im:getPixel(x,y)~=compare:getPixel(x,y) then diff=diff+1 end end end
  end
 end
 assert(diff==0,'Native readback mismatch')
 print('NATIVE ROUNDTRIP PASS '..gender..' layers=13 frames=80 tags=12 cels=1040 pixel_difference='..diff..' source_rgba_bytes='..raw_bytes)
 re:close()
end
local f=assert(io.open(root..'/godot-client/prototype/actors/layers/manifest.json','w'));f:write(json(manifest));f:close()
