# Blender 5.1 3D 資產管線指南

## 目標
建立一套可重複使用的 Blender → Unity 工作流，為多人 RTS 遊戲生產低多邊形（Low-Poly）3D 模型。

---

## 一、Blender 設定基準

### 1.1 場景單位與比例
\\\
Scene Properties > Units
- Unit System: Metric
- Unit Scale: 1.0
- Length: meters
- Unity 使用米（m），Blender 也設為米
\\\

### 1.2 座標系統（必要！）
\\\
Edit > Preferences > Add-ons
- 啟用 "Import-Export: FBX format"
- Export 時選擇 "Right-Handed (+Y Forward)"
- Unity 座標：X右、Y上、Z前（Blender 是 Z上、Y前）
\\\

### 1.3 匯出格式選擇
| 情況 | 格式 | 說明 |
|------|------|------|
| 單個模型 | **.GLTF / .GLB** | 推薦！原生支援 PBR 材質 |
| 含動畫的模型 | **.FBX** | 動畫軌道支援較好 |
| 靜態場景物件 | **.BLEND** | 直接用 Blender 內建 Unity 相容模式 |

---

## 二、建模規範

### 2.1 面數限制（多人對戰需要高效能）

| 物件類型 | 最大三角形數 | 頂點數 |
|----------|------------|--------|
| 小兵單位 | 500 - 2,000 | ~1,500 |
| 大型單位（攻城車） | 2,000 - 5,000 | ~3,000 |
| 小型建築 | 2,000 - 5,000 | ~3,000 |
| 大型建築 | 5,000 - 15,000 | ~8,000 |
| 地形片段 | 依需求 | N/A |

### 2.2 UV 展開流程
\\\
1. 進入 UV Editing 工作區
2. Select All (A)
3. U → Unwrap (Ikosuke 或 Angles Based)
4. 检查 UV 島是否浪費空間
5. 輸出 512x512 或 1024x1024 貼圖分辨率
\\\

### 2.3 PBR 材質工作流
\\\
需要的貼圖通道：
├── Albedo / Color    （固有色，sRGB）
├── Normal            （法線，Object Space 或 Tangent Space）
├── Metallic          （金屬度，灰階）
├── Roughness         （粗糙度，灰階）
└── AO                  （環境光遮蔽，灰階）

繪製工具：
- Blender 內建 Texture Paint（簡單需求）
- Substance Painter / Designer（專業流程）
- Krita（免費替代）
\\\

### 2.4 命名規範
\\\
模型命名格式：{類別}_{名稱}_{變體}

範例：
- UNIT_soldier_infantry_01   # 步兵士兵
- BUILD_castle_main_01       # 主城城堡
- PROP_treasure_chest_01     # 寶箱道具
- TERR_ground_grass_01       # 草地地形片

UV 及貼圖命名：
- {模型名}_albedo
- {模型名}_normal
- {模型名}_roughness
- {模型名}_ao
\\\

---

## 三、常用 Blender 快捷鍵速查

### 建模基礎
\\\
G       # Grab/移動
R       # Rotate/旋轉
S       # Scale/縮放
Ctrl+R  # Cut ring 環切
Ctrl+T  # 三角面化
F       # Face 補面
J       # Join 頂點焊接
Shift+A # Add 新增物件
Tab     # Edit Mode 切換
Ctrl+Tab # Subdivide 模式切換
\\\

### 多人 RTS 建模常用modifier
\\\
Subdivision Surface   # 平滑曲面（匯出前 Apply）
Mirror                # 左右對稱建模
Array                 # 複製排列（城牆、柵欄）
Boolean               # 挖洞（窗戶、門口）
Solidify              # 加厚薄片（旗幟、紙張）
Decimate              # 簡化面數 ⚠️ 慎用，看情況
\\\

---

## 四、Blender → Unity 匯出腳本

可以將以下 Python 程式碼存入 Blender Text Editor，按 Run 快速匯出選中的模型：

\\\python
import bpy
import os

def export_selected_to_gltf(filepath):
    \"\"\"匯出當前選中的物件為 GLTF\"\"\"
    # 建立臨時選擇
    bpy.ops.object.select_all(action='DESELECT')
    selected = bpy.context.selected_objects
    
    if not selected:
        print("沒有選中的物件")
        return
    
    # 匯出
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format='glTF',
        export_select_all=False,
        export_selected=True,
        export_normals=True,
        export_uv=True,
        export_materials='EXPORT'
    )
    print(f"已匯出到: {filepath}")

# 使用方法：在 Blender Python Console 中呼叫
# export_selected_to_gltf(r'C:\Users\f7212\OneDrive\文件\遊戲開發\blender-assets\models\UNIT_soldier_infantry_01.glb')
\\\

---

## 五、動畫工作流程

### 5.1 簡單動作
\\\
Idle（待機）         # 呼吸動畫
Walk（行走）         # 四循環步
Attack（攻擊）       # 武器揮砍
Death（死亡）        # 倒地動畫
Build（建造）        # 建築動畫
\\\

### 5.2  Bones 命名
\\\
Hips           # 臀部主骨
Spine_01/02/03 # 脊椎
L_UpperArm     # 左臂
R_UpperArm     # 右臂
L_ForeArm      # 左前臂
R_ForeArm      # 右前臂
L_Hand         # 左手
R_Hand         # 右手（拿武器）
L_Thigh        # 左大腿
R_Thigh        # 右大腿
L_Calf         # 左小腿
R_Calf         # 右小腿
L_Foot         # 左脚
R_Foot         # 右脚
Head           # 頭部
\\\

### 5.3 匯出動畫
\\\
1. Animation 面板中設定 Start/End Frame
2. File → Export → FBX (.fbx)
3. 勾選 "All Actions" 匯入所有動畫
4. 或是 "Only Selected Actions" 匯指定動畫
5. Armature: First, Data
6. Rest Position: Rest Position
\\\

---

## 六、Unity 端設定

### 6.1 FBX Importer 設定
\\\
模型材質設定：
- Import Limits: Scale Factor = 1.0
- Normals: Import = True, Calc Type = Calculate Elsewhere (Smooth)
- Tangents: None（如果從 Blender 帶出 UV 切線就選 Import）
- Animation Tab：
  - Frame Rate: 30
  - Loop Time: 打勾循環動作
\\\

### 6.2 Prefab 建立流程
\\\
1. 拖入 .fbx 到 Assets 資料夾
2. 展開 Prefabs 子資料夾確認動畫
3. 拖到 Hierachy 建立場景物件
4. 拉到 Project 區建立 Prefab
5. 刪除場景中的實例
6. 給 Prefab 加 Tag 和 Layer
\\\

---

## 七、建議建模順序（第一輪）

1. **地形原型** — 一塊草地＋山丘，驗證攝像機控制
2. **士兵模型** — 一個基礎人類單位，驗證移動和選取
3. **主城建築** — 驗證放置和生產系統
4. **採集點** — 金礦模型，驗證資源系統

完成這四個原型後，再進入正式內容量產階段。

---

*最後更新：2026-07-25*
