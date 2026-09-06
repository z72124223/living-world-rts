-- Non-destructive native head extraction. SW uses the approved head byte-for-byte.
-- SE / NW / NE are distinct imagegen views, not runtime mirror substitutes.
local root=assert(app.params.root)
local pc=app.pixelColor
local out=root..'/pixel-assets/prototype-actors/source-textures/'
local refs=root..'/pixel-assets/prototype-actors/references/'
local left=Image{fromFile=refs..'turnaround-study-v1.png'}
local right=Image{fromFile=refs..'right-turn-study-v2.png'}
print('REFERENCE SIZES',left.width,left.height,right.width,right.height)
local definitions={
 female={
  se={ref=right,crop={278,28,415,164},dest={98,9,48,48}},
  nw={ref=left,crop={856,27,981,131},dest={99,10,51,45}},
  ne={ref=right,crop={732,28,867,171},dest={97,9,49,51}}},
 male={
  se={ref=right,crop={301,683,416,806},dest={100,5,42,44}},
  nw={ref=left,crop={850,499,959,578},dest={100,5,44,35}},
  ne={ref=right,crop={746,678,859,793},dest={100,5,43,42}}}
}
for _,gender in ipairs({'female','male'}) do
 local male=gender=='male'
 local approved=root..'/asset-library/characters/human-'..gender..'-base/'..(male and '0.1.0' or '1.0.0')..'/runtime/assets/'..(male and 'male-body-head.png' or 'body-head.png')
 local sw=Image{fromFile=approved};sw:saveAs(out..gender..'-sw-head.png')
 for _,direction in ipairs({'se','nw','ne'}) do
  local spec=definitions[gender][direction];local im=Image(256,256)
  local c,d=spec.crop,spec.dest
  for yy=0,d[4]-1 do for xx=0,d[3]-1 do
   local sx=math.floor(c[1]+(xx+.5)*(c[3]-c[1])/d[3]);local sy=math.floor(c[2]+(yy+.5)*(c[4]-c[2])/d[4])
   local pixel=spec.ref:getPixel(sx,sy)
   local r,g,b=pc.rgbaR(pixel),pc.rgbaG(pixel),pc.rgbaB(pixel)
   if pc.rgbaA(pixel)>127 and not (r>190 and g>180 and b>165) then
    local x=d[1]+xx
    -- The rig's right-view projection reflects its base contours. Pre-reflect only
    -- this independently drawn head so its authored right-facing view stays intact.
    if direction=='se' or direction=='ne' then x=244-x end
    im:drawPixel(x,d[2]+yy,pixel)
   end
  end end
  im:saveAs(out..gender..'-'..direction..'-head.png')
 end
end
print('DISTINCT HEAD SOURCES SAVED')
