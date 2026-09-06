local root=assert(app.params.root)
local s=Sprite{fromFile=root..'/pixel-assets/aseprite/female-modular.aseprite'}
assert(#s.frames==18,'Expected 18 animation frames')
assert(#s.layers>=20,'Expected separate body and equipment layers')
assert(#s.tags==3,'Expected idle, walk and attack animation tags')
local found={};for _,layer in ipairs(s.layers) do found[layer.name]=true end
for _,name in ipairs({'head_hair','cloth_torso','armour_torso','armour_tassets','near_hand','drawn_sword','long_spear'}) do assert(found[name],name..' missing') end
local a,b=Image(s.width,s.height),Image(s.width,s.height)
a:drawSprite(s,1);b:drawSprite(s,7)
assert(not a:isEmpty(),'Character is empty')
assert(not a:isEqual(b),'Walk frame must differ from idle')
local f=assert(io.open(root..'/pixel-assets/aseprite-verification.json','w'))
f:write(string.format('{"tool":"Aseprite","version":"%s","frames":%d,"layers":%d,"tags":%d,"roundtrip":true,"distinct_animation_frames":true}',tostring(app.version),#s.frames,#s.layers,#s.tags));f:close()
print('ASEPRITE_NATIVE_ROUNDTRIP_PASS frames='..#s.frames..' layers='..#s.layers)
