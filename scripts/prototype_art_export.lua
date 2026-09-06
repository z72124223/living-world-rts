-- Real Aseprite: create layered 80-frame native files, then export all 8 loadouts.
local root=assert(app.params.root)
local W,H=192,192
local names={'body_far_leg','cloth_far_leg','body_near_leg','cloth_near_leg','body_far_arm','cloth_far_arm','body_torso_pelvis','cloth_torso_pelvis','sword','chest','body_near_arm','cloth_near_arm','head'}
local counts={idle=4,walk=8,run=8}
local offsets={idle=0,walk=4,run=12}
local durations={idle=.25,walk=.125,run=1/12}
for _,gender in ipairs({'female','male'}) do
 local sprite=Sprite(W,H,ColorMode.RGB);sprite:deleteLayer(sprite.layers[1])
 local layers={};local images={}
 for _,n in ipairs(names) do
  local l=sprite:newLayer();l.name=n
  l.data='{"source":"approved body rig + new garment layers","runtime":"baked atlas","editable":true}'
  layers[n]=l
  images[n]=Image{fromFile=root..'/pixel-assets/prototype-actors/baked-layers/'..gender..'-'..n..'.png'}
 end
 for d,direction in ipairs({'sw','se','nw','ne'}) do
  for f=0,19 do
   local fi=(d-1)*20+f+1
   if fi>1 then sprite:newEmptyFrame(fi) end
   local motion=f<4 and 'idle' or (f<12 and 'walk' or 'run')
   sprite.frames[fi].duration=durations[motion]
   for _,n in ipairs(names) do
    local im=Image(W,H)
    im:drawImage(images[n],Point(-f*W,-(d-1)*H))
    sprite:newCel(layers[n],fi,im,Point(0,0))
   end
  end
  for _,motion in ipairs({'idle','walk','run'}) do
   local first=(d-1)*20+offsets[motion]+1
   local tag=sprite:newTag(first,first+counts[motion]-1);tag.name=direction..'_'..motion
  end
 end
 sprite:saveAs(root..'/pixel-assets/prototype-actors/native/'..gender..'-actor.aseprite')
 for clothing=0,1 do for armor=0,1 do for weapon=0,1 do
  for _,n in ipairs(names) do
   layers[n].isVisible=(not n:find('cloth_') or clothing==1) and (n~='chest' or armor==1) and (n~='sword' or weapon==1)
  end
  local atlas=Image(W*20,H*4)
  for fi=1,80 do
   local im=Image(W,H);im:drawSprite(sprite,fi)
   atlas:drawImage(im,Point(((fi-1)%20)*W,math.floor((fi-1)/20)*H))
  end
  atlas:saveAs(root..'/godot-client/prototype/actors/atlases/'..gender..'-'..clothing..armor..weapon..'.png')
 end end end
 sprite:close()
 -- Read the real native file back, validate layer/cel/tag/frame editability.
 local re=app.open(root..'/pixel-assets/prototype-actors/native/'..gender..'-actor.aseprite')
 assert(#re.layers==13 and #re.frames==80 and #re.tags==12,'Native structure mismatch')
 for _,layer in ipairs(re.layers) do for fi=1,80 do assert(layer:cel(fi),'Missing editable cel') end end
 local baseline=Image{fromFile=root..'/godot-client/prototype/actors/atlases/'..gender..'-111.png'}
 local diff=0
 for fi=1,80 do
  local im=Image(W,H);im:drawSprite(re,fi)
  for y=0,H-1 do for x=0,W-1 do
   if im:getPixel(x,y)~=baseline:getPixel(((fi-1)%20)*W+x,math.floor((fi-1)/20)*H+y) then diff=diff+1 end
  end end
 end
 assert(diff==0,'Native readback differs from runtime atlas')
 print('NATIVE ROUNDTRIP PASS '..gender..' layers=13 frames=80 tags=12 cels=1040 pixel_difference='..diff)
 re:close()
end
