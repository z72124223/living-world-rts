-- Run in Aseprite batch mode with --script-param root=<this worktree>.
-- Crops generated atlases, preserves alpha, and exports native editable pixel assets.
local root=assert(app.params.root)
local source=root..'/pixel-assets/prototype-map/'
local out=root..'/godot-client/prototype/map/art/'
local atlas=Image{fromFile=source..'environment-atlas-v01.png'}
local function crop(image,x,y,w,h)
 local result=Image(w,h,ColorMode.RGB)
 result:drawImage(image,Point(-x,-y))
 return result
end
local assets={
 {'tent',0,0,580,545,194,180},
 {'tree',580,0,430,545,130,170},
 {'rock',1010,0,526,545,146,134},
 {'crate',0,545,540,479,104,92},
 {'wall',570,540,430,484,80,304},
 {'hearth',1000,545,536,479,92,76}
}
for _,item in ipairs(assets) do
 local image=crop(atlas,item[2],item[3],item[4],item[5])
 -- Transparent padding is excluded from size decisions. Keep alpha and edge details.
 local minx,miny,maxx,maxy=image.width,image.height,-1,-1
 for it in image:pixels() do
  if app.pixelColor.rgbaA(it())>180 then
   minx=math.min(minx,it.x); miny=math.min(miny,it.y)
   maxx=math.max(maxx,it.x); maxy=math.max(maxy,it.y)
  end
 end
 assert(maxx>=minx,item[1]..' has no opaque pixels')
 image=crop(image,math.max(0,minx-2),math.max(0,miny-2),math.min(image.width-minx,maxx-minx+5),math.min(image.height-miny,maxy-miny+5))
 local sprite=Sprite(image.width,image.height,ColorMode.RGB)
 sprite.layers[1].name='Generated pixel material - pending art approval'
 sprite.cels[1].image=image
 sprite:resize(item[6],item[7])
 sprite:saveAs(source..item[1]..'-v01.aseprite')
 sprite:saveCopyAs(out..item[1]..'.png')
 local roundtrip=Sprite{fromFile=source..item[1]..'-v01.aseprite'}
 local a=Image(sprite.width,sprite.height);a:drawSprite(sprite,1)
 local b=Image(roundtrip.width,roundtrip.height);b:drawSprite(roundtrip,1)
 assert(a:isEqual(b),'Native roundtrip differs: '..item[1])
 print(item[1]..': '..sprite.width..'x'..sprite.height..' native_roundtrip=true')
 roundtrip:close();sprite:close()
end
local ground=Image{fromFile=source..'ground-atlas-v01.png'}
local pond=Sprite{fromFile=source..'pond-source-v01.png'}
pond.layers[1].name='Generated shallow pool - pending art approval'
pond:resize(432,240)
pond:saveAs(source..'pond-v01.aseprite')
pond:saveCopyAs(out..'pond.png')
local pondRoundtrip=Sprite{fromFile=source..'pond-v01.aseprite'}
local pondA=Image(432,240);pondA:drawSprite(pond,1)
local pondB=Image(432,240);pondB:drawSprite(pondRoundtrip,1)
assert(pondA:isEqual(pondB),'Pond native roundtrip differs')
print('pond: 432x240 native_roundtrip=true')
pondRoundtrip:close();pond:close()
local tiles={}
local tileNames={'grass','dirt','camp'}
for i=1,3 do
 local span=math.floor(ground.width/3)
 local tile=crop(ground,(i-1)*span,0,span,ground.height)
 local sprite=Sprite(tile.width,tile.height,ColorMode.RGB)
 sprite.cels[1].image=tile
 sprite:resize(256,256)
 local final=Image(256,256);final:drawSprite(sprite,1)
 tiles[i]=final
 final:saveAs(out..tileNames[i]..'.png')
 sprite:close()
end
local W,H=1024,768 -- final map samples at 2 world pixels, maintaining crisp pixel density
local terrain=Sprite(W,H,ColorMode.RGB)
terrain.layers[1].name='Woodland moss - generated texture'
local grass=Image(W,H)
local path=Image(W,H)
local camp=Image(W,H)
local function distance(x,y,ax,ay,bx,by)
 local dx,dy=bx-ax,by-ay
 local t=math.max(0,math.min(1,((x-ax)*dx+(y-ay)*dy)/(dx*dx+dy*dy)))
 return math.sqrt((x-ax-t*dx)^2+(y-ay-t*dy)^2)
end
local lines={{{160,848},{592,848},{720,784},{1040,784},{1712,848},{1936,848}},{{1040,784},{1072,624},{1040,304}},{{336,848},{336,1200},{624,1392}}}
local function tint(pixel,r,g,b,alpha)
 return app.pixelColor.rgba(math.floor(app.pixelColor.rgbaR(pixel)*r),math.floor(app.pixelColor.rgbaG(pixel)*g),math.floor(app.pixelColor.rgbaB(pixel)*b),alpha or 255)
end
for y=0,H-1 do
 for x=0,W-1 do
  local wx,wy=x*2,y*2
  local noise=((x*73+y*151+(x*y)%239)%97)/97
  grass:drawPixel(x,y,tint(tiles[1]:getPixel(x%256,y%256),0.74,0.87,0.85))
  local near=10000
  for _,line in ipairs(lines) do
   for i=1,#line-1 do near=math.min(near,distance(wx,wy,line[i][1],line[i][2],line[i+1][1],line[i+1][2])) end
  end
  local edge=math.max(0,math.min(1,(74-near+noise*12)/32))
  if edge>0 then path:drawPixel(x,y,tint(tiles[2]:getPixel(x%256,y%256),1,1,1,math.floor(edge*255))) end
  local campdist=math.sqrt((wx-336)^2+(wy-848)^2)
  local clearing=math.max(0,math.min(1,(135-campdist+noise*16)/30))
  if clearing>0 then camp:drawPixel(x,y,tint(tiles[3]:getPixel(x%256,y%256),1,1,1,math.floor(clearing*255))) end
 end
end
terrain.cels[1].image=grass
local layer=terrain:newLayer();layer.name='Worn footpaths - feathered texture';terrain:newCel(layer,1,path)
layer=terrain:newLayer();layer.name='Camp clearing - stone fragments';terrain:newCel(layer,1,camp)
terrain:saveAs(source..'terrain-v01.aseprite')
terrain:saveCopyAs(out..'terrain.png')
local final=Image(W,H);final:drawSprite(terrain,1)
local readback=Sprite{fromFile=source..'terrain-v01.aseprite'}
local check=Image(W,H);check:drawSprite(readback,1)
assert(check:isEqual(final),'Terrain native roundtrip differs')
print('terrain: 1024x768 -> 2048x1536 world native_roundtrip=true')
