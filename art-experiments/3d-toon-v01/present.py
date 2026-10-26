"""Lay out untouched Blender render outputs with explanatory labels."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,base64,html
ROOT=Path(__file__).resolve().parent
report=json.loads((ROOT/'build-report.json').read_text(encoding='utf-8'))
fontpath='C:/Windows/Fonts/msjh.ttc'
boldpath='C:/Windows/Fonts/msjhbd.ttc'
font=lambda size,b=False:ImageFont.truetype(boldpath if b else fontpath,size)
board=Image.new('RGB',(1800,1060),'#f3f1ea');draw=ImageDraw.Draw(board)
ink='#203634';muted='#5c6a67'
draw.text((45,28),'3D 底模 → 美術材質：實際能得到的效果',font=font(39,True),fill=ink)
draw.text((45,91),'同一模型的本機渲染｜未用 AI 重繪｜技術試樣，尚未定版',font=font(23),fill=muted)
cards=[('01  灰模','01-clay.png','先看真實形體與衣服輪廓'),('02  上美術材質','02-toon-front.png','色塊、布面紋理、分階陰影、輪廓線'),('03  換角度','03-toon-back.png','背面也由同一組幾何渲染')]
for i,(title,path,caption) in enumerate(cards):
    x=40+i*445
    draw.rounded_rectangle((x,149,x+422,850),14,fill='#e4e5df')
    draw.text((x+18,168),title,font=font(26,True),fill=ink)
    im=Image.open(ROOT/path).convert('RGB');im=im.resize((402,536),Image.Resampling.LANCZOS)
    board.paste(im,(x+10,220))
    draw.text((x+18,784),caption,font=font(18),fill=muted)
draw.rounded_rectangle((1380,149,1760,850),14,fill='#e4e5df')
draw.text((1400,169),'04  俯視遊戲尺度',font=font(24,True),fill=ink)
draw.text((1400,220),'256 × 256 原始渲染',font=font(18),fill=muted)
board.paste(Image.open(ROOT/'05-rts.png').convert('RGB'),(1439,263))
draw.text((1400,552),'96 × 96 原始渲染',font=font(18),fill=muted)
board.paste(Image.open(ROOT/'06-rts-96.png').convert('RGB'),(1439,595))
draw.text((1400,745),'小尺寸細節會消失；',font=font(19),fill=muted)
draw.text((1400,775),'輪廓仍取決於模型。',font=font(19),fill=muted)
draw.line((45,888,1755,888),fill='#bdc5bc',width=2)
draw.text((45,913),f"本次實作：Blender {report['blender']} / Cycles · {report['evaluated_triangles']:,} 三角面 · 512 × 512 布面貼圖",font=font(22),fill=ink)
draw.text((45,958),'已證明：同模型灰模／著色與多角度實際渲染。',font=font(22),fill=ink)
draw.text((45,997),'尚未驗證：正式動畫、換装與 Godot 即時效能；臉部及服裝仍屬試作。',font=font(21),fill=muted)
board.save(ROOT/'preview.png')
def data(path):return 'data:image/png;base64,'+base64.b64encode((ROOT/path).read_bytes()).decode()
views=[('上色正面','02-toon-front.png'),('側面','04-toon-side.png'),('背面','03-toon-back.png'),('灰模','01-clay.png')]
items=''.join(f'<button onclick="show({i})">{label}</button>' for i,(label,p) in enumerate(views))
urls=json.dumps([data(p) for label,p in views])
page=f'''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>真實 3D 美術試樣</title><style>body{{margin:0;background:#eff0e9;color:#203634;font:18px system-ui,sans-serif}}main{{max-width:1200px;margin:auto;padding:28px}}h1{{font-size:30px}}button{{padding:12px 20px;margin:6px;border:1px solid #82958e;border-radius:8px;background:#fff;color:#203634;cursor:pointer}}.viewer{{display:flex;gap:24px;align-items:start}}#render{{max-width:65%;height:72vh;object-fit:contain}}aside{{max-width:330px;line-height:1.7}}a{{color:#235c4d}}@media(max-width:700px){{.viewer{{display:block}}#render{{max-width:100%}}}} </style><main><h1>真實 3D 底模＋卡通美術材質</h1><p>以下都是同一 Blender 場景的實際渲染，按鈕切換已渲染視角；此頁不是即時 3D 引擎。</p><nav>{items}</nav><div class="viewer"><img id="render" alt="模型實際渲染"><aside><p>先建模，再加布面貼圖、分階陰影及輪廓線，可以得到此種卡通 3D 外觀。</p><p>模型的臉型、身形、衣服厚度與各角度輪廓仍然保留；材質不會自動把它變成精修手繪人物。</p><p>完整源檔：<a href="model.blend">model.blend</a><br>重建腳本：<a href="build.py">build.py</a><br>實際執行紀錄：<a href="build-report.json">build-report.json</a></p><p>尚未驗證動畫與 Godot 即時效能。每個視角來自同一模型，沒有生成式重畫。</p></aside></div></main><script>const views={urls};function show(i){{document.querySelector('#render').src=views[i];}}show(0)</script></html>'''
(ROOT/'preview.html').write_text(page,encoding='utf-8')
print('Presentation created from actual rendered pixels')
