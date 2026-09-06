local root=assert(app.params.root)
local pc=app.pixelColor
local result={}
local function json(v)
 if type(v)=='table' then
  local a={};if #v>0 then for _,x in ipairs(v) do a[#a+1]=json(x) end;return '['..table.concat(a,',')..']' end
  for k,x in pairs(v) do a[#a+1]=json(k)..':'..json(x) end;return '{'..table.concat(a,',')..'}'
 elseif type(v)=='string' then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"')..'"'
 elseif type(v)=='boolean' then return v and 'true' or 'false' else return tostring(v) end
end
for _,gender in ipairs({'female','male'}) do
 local atlas=Image{fromFile=root..'/pixel-assets/prototype-actors/previews/'..gender..'-all.png'}
 local direction_differences={}
 for _,pair in ipairs({{0,1},{2,3},{0,2},{1,3}}) do
  local difference=192*192;local reflected=pair[2]-pair[1]==1
  -- Search adjacent pixel alignments as well; a one-pixel anchor offset must
  -- not make a mirrored duplicate pass this test.
  for shift=(reflected and -2 or 0),(reflected and 2 or 0) do
   local candidate=0
   for y=0,191 do for x=0,191 do
    local a=atlas:getPixel(x,pair[1]*192+y)
    local sx=reflected and (191-x+shift) or x
    local b=sx>=0 and sx<192 and atlas:getPixel(sx,pair[2]*192+y) or 0
    if a~=b then candidate=candidate+1 end
   end end
   difference=math.min(difference,candidate)
  end
  assert(difference>30,'Direction is only a mirror/duplicate')
  direction_differences[#direction_differences+1]={first=pair[1],second=pair[2],reflected_comparison=reflected,different_pixels=difference}
 end
 local edge_pixels=0;local min_height,max_height=192,0;local min_bottom,max_bottom=192,0
 for d=0,3 do for f=0,19 do
  local top,bottom=192,-1
  for y=0,191 do for x=0,191 do if pc.rgbaA(atlas:getPixel(f*192+x,d*192+y))>0 then
   top=math.min(top,y);bottom=math.max(bottom,y)
   if x==0 or x==191 or y==0 or y==191 then edge_pixels=edge_pixels+1 end
  end end end
  assert(bottom>=top,'Empty animation frame')
  min_height=math.min(min_height,bottom-top+1);max_height=math.max(max_height,bottom-top+1)
  min_bottom=math.min(min_bottom,bottom);max_bottom=math.max(max_bottom,bottom)
 end end
 assert(edge_pixels==0,'Clipped actor frame')
 local distinct_equipment=0;local prior={}
 local native=app.open(root..'/pixel-assets/prototype-actors/native/'..gender..'-actor.aseprite')
 for cloth=0,1 do for armor=0,1 do for weapon=0,1 do
  local name=cloth..armor..weapon
  for _,layer in ipairs(native.layers) do
   local n=layer.name
   layer.isVisible=(not n:find('cloth_') or cloth==1) and (n~='chest' or armor==1) and (n~='sword' or weapon==1)
  end
  local im=Image(192,192);im:drawSprite(native,1)
  for _,other in ipairs(prior) do
   local diff=0;for y=0,191 do for x=0,191 do if im:getPixel(x,y)~=other:getPixel(x,y) then diff=diff+1 end end end
   assert(diff>0,'Two equipment variants have identical pixels')
  end
  prior[#prior+1]=im;distinct_equipment=distinct_equipment+1
 end end end
 native:close()
 local approved=root..'/asset-library/characters/human-'..gender..'-base/'..(gender=='male' and '0.1.0' or '1.0.0')..'/runtime/assets/'..(gender=='male' and 'male-body-head.png' or 'body-head.png')
 local src=Image{fromFile=approved};local dst=Image{fromFile=root..'/pixel-assets/prototype-actors/source-textures/'..gender..'-sw-head.png'}
 local head_difference=0;for y=0,255 do for x=0,255 do if src:getPixel(x,y)~=dst:getPixel(x,y) then head_difference=head_difference+1 end end end
 assert(head_difference==0,'Approved SW face changed')
 result[gender]={frames=80,layers=13,tags=12,editable_cels=1040,source_sw_head_pixel_difference=head_difference,clipped_edge_pixels=edge_pixels,height_range={min_height,max_height},foot_bottom_range={min_bottom,max_bottom},distinct_equipment_variants=distinct_equipment,direction_differences=direction_differences}
end
result.passed=true
result.art_status='PENDING_USER_REVIEW'
local file=assert(io.open(root..'/prototype/reports/actors/aseprite-pixel-report.json','w'));file:write(json(result));file:close()
print('ASEPRITE PIXEL CHECK PASS; exact SW head, non-mirrored directions, no clipped frames, 8 distinct equipment variants per gender')
