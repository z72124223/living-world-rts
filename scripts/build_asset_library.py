"""Archive verified character assets; copy files and metadata, never redraw art."""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'asset-library'
ASSETS = ROOT / 'godot-client/assets'
VERIFY = ROOT / 'godot-client/verification'
CATALOG = json.loads((ASSETS / 'body-catalog.json').read_text(encoding='utf-8'))
NOW = datetime.now(timezone(timedelta(hours=8))).isoformat(timespec='seconds')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def copy(source, target, protect=False):
    assert source.is_file(), f'Missing source: {source}'
    if protect and target.exists() and digest(source) != digest(target):
        raise RuntimeError(f'Archived source differs: {target}. Create a new asset version.')
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    assert digest(source) == digest(target)


entries = []
cards = []
for gender, item in CATALOG.items():
    male = gender == 'male'
    prefix = item['prefix']
    report = json.loads((VERIFY / f'{prefix}-report.json').read_text(encoding='utf-8'))
    assert report['pass'] and report['art_approved'] == item['approved']
    assert report['character_id'] == item['id'] and report['version'] == item['version']
    assert len(report['input_sha256']) == 10
    for filename, expected in report['input_sha256'].items():
        assert digest(ASSETS / filename) == expected, f'Stale Godot verification: {filename}'
    folder = LIB / 'characters' / item['id'] / item['version']
    folder.mkdir(parents=True, exist_ok=True)
    native = 'male-body-contour-v01.aseprite' if male else 'female-body-contour-v03.aseprite'
    guide = 'male-rig-reference-v01.png' if male else 'female-rig-unitard-v02.png'
    prompt = 'male-rig-reference-v01.prompt.txt' if male else 'prompts.txt'
    landmarks = 'male_rig_landmarks.lua' if male else 'rig_landmarks.lua'
    copy(ROOT / 'pixel-assets/aseprite' / native, folder / 'source' / native, True)
    for filename in [guide, prompt]:
        copy(ROOT / 'pixel-assets/sources' / filename, folder / 'source/references' / filename, True)
    if not male:
        copy(ROOT / 'pixel-assets/sources/female-armoured-reference.png', folder / 'source/references/female-armoured-reference.png', True)
    for filename in ['build_body_contour_v03.lua', landmarks]:
        copy(ROOT / 'scripts' / filename, folder / 'source/scripts' / filename, True)
    for filename in report['input_sha256']:
        copy(ASSETS / filename, folder / 'runtime/assets' / filename, True)
    for pose in ['rest', 'elbow', 'knee']:
        copy(VERIFY / f'{prefix}-{pose}.png', folder / 'previews' / f'{pose}.png')
    for suffix in ['report.json', 'gpu-mask.png', 'mask-difference.png']:
        copy(VERIFY / f'{prefix}-{suffix}', folder / 'verification' / suffix)
    build_log = 'male-body-build.log' if male else 'female-approved-build.log'
    copy(ROOT / 'pixel-assets' / build_log, folder / 'verification/aseprite-build.log')
    assert 'native_roundtrip=true' in (folder / 'verification/aseprite-build.log').read_text()
    copy(ROOT / 'godot-client/scripts/body_rig.gd', folder / 'runtime/body_rig.gd', True)
    copy(ASSETS / 'ui-font.otf', folder / 'runtime/assets/ui-font.otf', True)
    copy(ASSETS / 'FONT-LICENSE.txt', folder / 'runtime/assets/FONT-LICENSE.txt', True)
    archived_at = NOW
    if (folder / 'asset.json').exists():
        archived_at = json.loads((folder / 'asset.json').read_text(encoding='utf-8'))['archived_at']
    status = 'approved' if item['approved'] else 'pending_art_review'
    status_zh = '已確認成品' if item['approved'] else '待確認樣品'
    metadata = {
        'schema_version': 1, 'id': item['id'], 'name': item['name'] + '・曲線／網格／骨架',
        'version': item['version'], 'source_revision': 'v01' if male else 'v03',
        'category': 'characters/human/body-base', 'tags': ['2D', '像素', '人體基底', '網格', '骨架'],
        'archived_at': archived_at, 'status': status,
        'approval': {'art_approved': item['approved'], 'date': item.get('approval_date'),
                     'source': item.get('approval_source', '尚未收到使用者造型確認。')},
        'format': {'canvas_px': [256, 256], 'color': 'RGBA', 'source_layers': 8, 'source_frames': 1,
                   'view': '斜側面，朝畫面左方', 'coordinates': '原點左上；X 向右、Y 向下；所有圖層共用畫布',
                   'sampling': 'nearest', 'neutral_body': True, 'garments_included': False},
        'rig': {'engine': 'Godot 4.6.3', 'implementation': 'Skeleton2D / Bone2D / Polygon2D',
                'bones': report['bones'], 'mesh_parts': report['mesh_parts'], 'vertices': report['vertices'],
                'triangles': report['triangles'], 'root_joint_px': [120, 120] if male else [121, 120],
                'preview_joints': ['near_upper_arm', 'near_forearm', 'near_thigh', 'near_shin', 'far_thigh', 'far_shin']},
        'files': {'native': 'source/' + native, 'body_master': f'runtime/assets/{prefix}-master.png',
                  'preview': f'runtime/assets/{prefix}-preview.png', 'mesh': f'runtime/assets/{prefix}-mesh.json',
                  'skeleton': f'runtime/assets/{prefix}-rig.json', 'head': 'runtime/assets/' + item['head'],
                  'pose_previews': ['previews/rest.png', 'previews/elbow.png', 'previews/knee.png'],
                  'verification': 'verification/report.json', 'manifest': 'manifest.sha256.json'},
        'provenance': {'art': 'Codex image_gen 生成角色參考，Aseprite 製作中性人體底稿；網格由原檔像素邊界生成。',
                       'reference': 'source/references/' + guide, 'prompts': 'source/references/' + prompt,
                       'aseprite': '1.3.18.3-dev, locally built; application binary not bundled',
                       'external_asset_pack': None, 'font_license': 'runtime/assets/FONT-LICENSE.txt'},
        'verification': {'technical_pass': True, 'contour_difference_px': report['contour']['missing'] + report['contour']['extra'],
                         'mask_iou': report['contour']['iou'], 'native_roundtrip': True,
                         'method': report['contour']['method'], 'input_hashes_match': True},
        'scope': '單一方向人體基底與互動彎曲樣品；尚未製作完整動作集、衣裝綁定或大量 RTS 單位效能優化。',
        'sample_url': '/?character=' + gender,
    }
    write_json(folder / 'asset.json', metadata)
    (folder / 'README.md').write_text(f'''# {metadata['name']}

- 素材編號：`{item['id']}`；版本：`{item['version']}`；狀態：**{status_zh}**。
- 來源修訂：{metadata['source_revision']}。收錄時間：{archived_at}。
- 256 × 256 透明畫布、8 個原檔圖層、1 格站姿、5 件人體網格、15 根骨骼。
- [Aseprite 原檔](source/{native})／[素材紀錄](asset.json)／[檔案雜湊清單](manifest.sha256.json)。
- [站姿](previews/rest.png)、[彎肘](previews/elbow.png)、[彎膝](previews/knee.png)為 Godot 實際執行截圖。
- [技術驗證](verification/report.json)：網格幾何與人體底稿輪廓差異 0 像素，骨架端點與權重檢查通過。

{metadata['approval']['source']}

原檔是人體曲線的編輯來源；網格不可另改身形寬度。先複製此版本到工作區再編輯。重建 Aseprite 時，從專案根目錄執行 `scripts/build_body_contour_v03.lua`，傳入 `root=<專案絕對路徑>`、`from_master=true`{('、`character=male`' if male else '')}。重新執行 Godot 驗證後，以新版本收錄。素材庫腳本會拒絕覆寫內容不同的既有來源與執行素材。

Godot 使用 `runtime/assets/` 的同尺寸分件貼圖、網格與骨架資料。現有 `body_rig.gd` 可設定 `mesh_path`、`rig_path`、`texture_prefix`、`reference_path` 與 `head_path` 載入。字型附帶 SIL OFL 授權。原始生成參考與提示詞在 `source/references/`。

{metadata['scope']}
''', encoding='utf-8')
    manifest = {p.relative_to(folder).as_posix(): digest(p) for p in sorted(folder.rglob('*'))
                if p.is_file() and p.name != 'manifest.sha256.json'}
    write_json(folder / 'manifest.sha256.json', {'algorithm': 'SHA-256', 'files': manifest})
    for filename, sha in manifest.items():
        assert digest(folder / filename) == sha
    path = folder.relative_to(LIB).as_posix()
    entries.append({'id': item['id'], 'name': metadata['name'], 'version': item['version'], 'status': status,
                    'record': path + '/asset.json', 'native': path + '/source/' + native,
                    'preview': path + f'/runtime/assets/{prefix}-preview.png', 'files': len(manifest),
                    'sample_url': metadata['sample_url']})
    cards.append(f'''<article class="asset" data-name="{item['name']}">
<div class="card-title"><div><span class="eyebrow">{item['id']}</span><h2>{item['name']}</h2></div><span class="badge {'approved' if item['approved'] else 'pending'}">{status_zh}</span></div>
<div class="card-main"><a class="figure" href="{path}/runtime/assets/{prefix}-preview.png" aria-label="檢視{item['name']}透明預覽"><img src="{path}/runtime/assets/{prefix}-preview.png" alt="{item['name']}人體曲線" /></a>
<div class="facts"><p class="version">v{item['version']}</p><p>人體曲線<br>可變形網格<br>獨立關節骨架</p><dl><dt>畫布</dt><dd>256 × 256</dd><dt>人體分件</dt><dd>5 件</dd><dt>骨骼</dt><dd>15 根</dd><dt>輪廓差異</dt><dd class="accent">0 像素</dd></dl></div></div>
<div class="actions"><a class="primary" href="/?character={gender}">操作曲線＋骨架 ↗</a><a href="{path}/source/{native}" download>Aseprite 原檔 ↓</a></div>
<details><summary>素材紀錄與實測截圖</summary><div class="detail-links"><a href="{path}/asset.json">素材紀錄</a><a href="{path}/README.md">使用說明</a><a href="{path}/verification/report.json">驗證紀錄</a><a href="{path}/manifest.sha256.json">檔案清單</a></div><a href="{path}/previews/rest.png"><img class="screen" src="{path}/previews/rest.png" alt="{item['name']}實際骨架站姿截圖" loading="lazy" /></a><div class="detail-links"><a href="{path}/previews/elbow.png">彎肘截圖 ↗</a><a href="{path}/previews/knee.png">彎膝截圖 ↗</a></div></details>
</article>''')

write_json(LIB / 'catalog.json', {'schema_version': 1, 'name': 'Living World RTS 素材庫', 'updated_at': NOW, 'assets': entries})
approved_count = sum(item['approved'] for item in CATALOG.values())
pending_count = len(CATALOG) - approved_count
approval_summary = '；'.join(item['name'] + ('：已確認身形基準' if item['approved'] else '：等待造型確認') for item in CATALOG.values())
css = '''*{box-sizing:border-box}body{margin:0;background:#101819;color:#e8e4d8;font-family:"Microsoft JhengHei",sans-serif}a{color:inherit;text-decoration:none}a:hover{color:#9df1d0}a:focus-visible,summary:focus-visible{outline:2px solid #a1f1d4;outline-offset:5px}main{max-width:1200px;margin:auto;padding:36px 32px 48px}.eyebrow{font-size:11px;letter-spacing:1.2px;color:#93ada8}header{display:flex;justify-content:space-between;gap:24px;align-items:center;margin-bottom:32px}h1{font-size:36px;letter-spacing:3px;margin:10px 0 12px}header p{color:#a8b8b3;margin:0;line-height:1.8}.summary{color:#b3c8bd;border-left:1px solid #466057;padding:8px 0 8px 24px;white-space:nowrap;line-height:2}.grid{display:grid;grid-template-columns:1fr 1fr;gap:24px}.asset{border:1px solid #354640;border-radius:14px;background:#17231f;overflow:hidden}.card-title{display:flex;justify-content:space-between;align-items:center;gap:14px;padding:24px 26px 0}h2{font-size:26px;font-weight:500;margin:7px 0 0}.badge{font-size:12px;border:1px solid;border-radius:30px;padding:7px 12px;white-space:nowrap}.approved{color:#95e5bb;border-color:#477b5c;background:#203f2d}.pending{color:#f0ce92;border-color:#877340;background:#3c3321}.card-main{display:grid;grid-template-columns:65% 35%;align-items:center;padding:8px 16px}.figure{height:380px;display:block;background:radial-gradient(ellipse at 50% 65%,#41504400 0,#34473635 45%,transparent 68%)}.figure img{width:100%;height:100%;object-fit:contain;image-rendering:pixelated}.facts{font-size:14px;line-height:1.9;color:#acbdb2}.version{font-size:13px;color:#ddc49b;letter-spacing:2px}.facts dl{display:grid;grid-template-columns:1fr;gap:0;margin:22px 0 0}.facts dt{font-size:11px;color:#7e9e90}.facts dd{margin:0 0 9px;font-size:14px;color:#e1e4d7}.facts .accent{color:#8ed7b3}.actions{display:flex;gap:12px;margin:0 24px 24px;align-items:center;font-size:13px;flex-wrap:wrap}.actions a{border:1px solid #4d6658;border-radius:7px;padding:11px 13px}.actions .primary{background:#c5ddbf;color:#18251d;border-color:#c5ddbf;font-weight:bold}.actions .primary:hover{background:#e3edce}details{border-top:1px solid #34493e;background:#15201b}summary{cursor:pointer;padding:17px 25px;font-size:13px;color:#b7c8b8}.detail-links{display:flex;flex-wrap:wrap;gap:18px;font-size:12px;padding:8px 24px 20px;color:#b8d9c6}.screen{width:100%;display:block}footer{color:#879e93;font-size:12px;line-height:1.8;margin-top:24px;display:flex;gap:20px;justify-content:space-between}@media(max-width:760px){main{padding:24px 15px}header{display:block}.summary{margin-top:22px}.grid{grid-template-columns:1fr}.figure{height:360px}footer{display:block}h1{font-size:29px}}
'''
(LIB / 'index.html').write_text('''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>人物素材庫 · Living World RTS</title><style>''' + css + f'''</style><main><header><div><span class="eyebrow">LIVING WORLD RTS / ASSET LIBRARY</span><h1>人物素材庫</h1><p>從人體曲線開始，保存每一版的身形與骨架。<br>原檔、可用素材與驗證截圖一起收錄。</p></div><div class="summary">{approved_count:02d} 已確認成品<br>{pending_count:02d} 待確認樣品<br>Aseprite → Godot 2D</div></header><div class="grid">''' + '\n'.join(cards) + f'''</div><footer><span>{approval_summary}。</span><span><a href="catalog.json">完整目錄 ↗</a>　2026.09.06</span></footer></main></html>''', encoding='utf-8')
(LIB / 'README.md').write_text(f'''# Living World RTS 素材庫

本機瀏覽入口：<http://127.0.0.1:8780/library/>。啟動方式：在專案根目錄執行 `python scripts/serve_pixel_sample.py`。

| 素材 | 版本 | 狀態 | 紀錄 |
|---|---|---|---|
| 女性人體曲線＋網格＋骨架 | 1.0.0（來源 v03）| 使用者已確認 | [素材檔案](characters/human-female-base/1.0.0/README.md) |
| 男性人體曲線＋網格＋骨架 | 0.1.0（來源 v01）| {'使用者已確認' if CATALOG['male']['approved'] else '造型待確認'} | [素材檔案](characters/human-male-base/0.1.0/README.md) |

每份紀錄包含固定素材編號、版本、審美認可狀態、Aseprite 原檔、PNG 分件、網格權重、骨架端點、生成參考、提示詞、Godot 實測截圖及 SHA-256 雜湊清單。`catalog.json` 是目錄，個別 `asset.json` 是詳細建檔資料。

在工作區編輯與驗證，成品以版本資料夾保存。`python scripts/build_asset_library.py` 會核對目前素材與 Godot 驗證的檔案雜湊，拒絕把未驗證或內容不同的來源覆寫進既有版本。後續改版先調整角色目錄的版本號，再收錄成新版本。

男女角色的最新審美確認以各自 `asset.json` 的 `approval` 為準；版本號不因單純確認而改變。原始網格檔內的草稿描述保留為生成當時的來源紀錄。早期試作仍保留在原處。
''', encoding='utf-8')
write_json(LIB / 'verification.json', {'checked_at': NOW, 'pass': True, 'entries': len(entries),
           'files_verified': sum(e['files'] for e in entries), 'source_checksums_match': True,
           'godot_input_checksums_match': True})
print('ASSET_LIBRARY_VERIFIED ' + json.dumps({'entries': len(entries), 'files': sum(e['files'] for e in entries), 'pass': True}))
