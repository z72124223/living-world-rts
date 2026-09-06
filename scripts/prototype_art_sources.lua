-- Aseprite-native garment authoring. Reads approved source pixels; writes only new actor assets.
local root=assert(app.params.root)
local pc=app.pixelColor
local W,H=256,256
local out=root..'/pixel-assets/prototype-actors/source-textures/'
local function col(h) return pc.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),255) end
local function inside(x,y,p)
 local yes=false;local j=#p
 for i=1,#p do local a,b=p[i],p[j]; if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then yes=not yes end;j=i end
 return yes
end
local function line(im,x0,y0,x1,y1,c,r)
 local n=math.max(math.abs(x1-x0),math.abs(y1-y0));for i=0,n do local t=n==0 and 0 or i/n;local x,y=math.floor(x0+(x1-x0)*t+.5),math.floor(y0+(y1-y0)*t+.5)
 for yy=y-(r or 0),y+(r or 0) do for xx=x-(r or 0),x+(r or 0) do if xx>=0 and yy>=0 and xx<W and yy<H then im:drawPixel(xx,yy,c) end end end end
end
local function shade(hex,s)
 local c=col(hex);return pc.rgba(math.floor(pc.rgbaR(c)*s),math.floor(pc.rgbaG(c)*s),math.floor(pc.rgbaB(c)*s),255)
end
for _,gender in ipairs({'female','male'}) do
 local male=gender=='male'
 local prefix=male and 'male-body-v01' or 'body-v03'
 local input=root..'/asset-library/characters/human-'..gender..'-base/'..(male and '0.1.0' or '1.0.0')..'/runtime/assets/'
 local source={}
 for _,part in ipairs({'far_leg','near_leg','far_arm','torso_pelvis','near_arm'}) do source[part]=Image{fromFile=input..prefix..'-'..part..'.png'} end
 for di,direction in ipairs({'sw','se','nw','ne'}) do
  local back=direction=='nw' or direction=='ne'
  local right=direction=='se' or direction=='ne'
  local native=Sprite(W,H,ColorMode.RGB);native:deleteLayer(native.layers[1])
  local function save(name,im)
   local l=native:newLayer();l.name=name;native:newCel(l,1,im,Point(0,0));im:saveAs(out..gender..'-'..direction..'-'..name..'.png')
  end
  for _,part in ipairs({'far_leg','near_leg','far_arm','torso_pelvis','near_arm'}) do
   local im=source[part];save('body_'..part,im)
   local cloth=Image(W,H)
   for y=0,H-1 do for x=0,W-1 do
    local c=im:getPixel(x,y)
    if pc.rgbaA(c)>0 then
     local on=true;local h='304553'
     if part=='torso_pelvis' then
      local neck=male and 46 or 56
      if y<neck+2 then on=false end
      if not back and y<neck+15 and math.abs(x-(right and 123 or 116))<(neck+15-y)*.48 then on=false end
      if y>=113 and y<=120 then h='743f32'
      elseif y>124 then h='263c49'
      elseif y==112 or y==121 then h='ad8956'
      elseif back and math.abs(x-122)<=1 then h='253441'
      elseif not back and x==(right and 126 or 114) then h='a68d60' end
     elseif part:find('leg') then
      h=y>=(male and 197 or 194) and '352f2b' or '8c8571'
      if y>=(male and 195 or 192) and y<=(male and 198 or 195) then h='9c8058' end
      if y>=227 then h='201f20' end
     else
      local cutoff=part=='far_arm' and (male and 120 or 116) or (male and 104 or 103)
      if y>=cutoff then on=false elseif y>=cutoff-5 then h='604937' end
     end
     if on then
      local original=pc.rgbaR(c)/202; local s=math.floor((.65+original*.30+((x+di*3)%7==0 and .04 or 0))*8)/8
      cloth:drawPixel(x,y,shade(h,s))
     end
    end
   end end
   save('cloth_'..part,cloth)
  end
  local armor=Image(W,H)
  local top=male and 49 or 60
  local p={{102,top+1},{113,top+7},{125,top+9},{139,top+1},{144,top+16},{139,100},{133,111},{103,111},{97,99},{98,top+17}}
  if male then p={{101,top},{115,top+6},{128,top+6},{145,top},{151,top+20},{143,101},{136,112},{102,112},{94,101},{96,top+17}} end
  for y=0,H-1 do for x=0,W-1 do if inside(x+.5,y+.5,p) and pc.rgbaA(source.torso_pelvis:getPixel(x,y))>0 then
   local edge=false;for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do if not inside(x+d[1]+.5,y+d[2]+.5,p) then edge=true end end
   local h=edge and 'ae8951' or (back and '48504b' or '525d59')
   if not edge and y>top+12 and (y-top)%9<=1 then h='283230' end
   if not edge and y>top+13 and (x-(right and 121 or 116))%13==0 and (y-top)%9==4 then h='b39a6b' end
   armor:drawPixel(x,y,shade(h,.80+(x<120 and .12 or 0)))
  end end end
  save('chest',armor)
  local sword=Image(W,H)
  -- Anatomical LEFT attachment is projected independently for front/back turns.
  local sx=back and 103 or 138;local sy=117
  local dx=back and -23 or 27
  line(sword,sx,sy,sx+dx,sy+64,col('222827'),3)
  line(sword,sx+2,sy+4,sx+dx,sy+62,col('58442f'),2)
  line(sword,sx+dx-2,sy+60,sx+dx+2,sy+65,col('ad8b55'),1)
  line(sword,sx,sy,sx-5,sy-14,col('332b25'),2)
  line(sword,sx-9,sy-2,sx+7,sy-7,col('b99451'),1)
  line(sword,sx-4,sy-11,sx-2,sy-4,col('9e7a49'),0)
  save('sword',sword)
  -- New views: hair and faces from imagegen reference crops are added by head script.
  native:saveAs(root..'/pixel-assets/prototype-actors/native/'..gender..'-'..direction..'-garment-source.aseprite');native:close()
 end
end
print('ACTOR GARMENT SOURCES SAVED')
