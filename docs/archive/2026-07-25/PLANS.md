# 多人即時戰略遊戲（Multiplayer RTS Game）開發計畫

## 專案概述

| 項目 | 說明 |
|------|------|
| **引擎** | Unity Hub (支援 URP/HDRP 渲染管線) |
| **後端語言** | Rust (高性能、記憶體安全) |
| **3D 建模** | Blender 5.1 |
| **遊戲類型** | 多人即時戰略（RTS / Real-Time Strategy） |
| **目標平台** | Windows PC（首發） |
| **開發階段** | 從零開始的完整專案規劃 |

---

## 技術架構總覽

\\\
┌──────────────────────────────────────────────┐
│                 Unity Client                  │
│  ┌──────────┬──────────┬──────────────────┐  │
│  │ Blender  │ Gameplay │  Network UI      │  │
│  │  Assets  │ Systems  │  Layer           │  │
│  └──────────┴──────────┴──────────────────┘  │
└──────────────────┬───────────────────────────┘
                   │ WebSocket / TCP
                   ▼
┌──────────────────────────────────────────────┐
│              Rust Game Server                 │
│  ┌──────────┬──────────┬──────────────────┐  │
│  │ Match    │ State    │ Auth + Chat      │  │
│  │ Making   │ Sync     │  Layer           │  │
│  └──────────┴──────────┴──────────────────┘  │
└──────────────────────────────────────────────┘
\\\

---

## 階段一：原型驗證（Phase 0 — 預計 2~4 週）

### 目標：驗證核心玩法循環

#### 1.1 Blender 3D 資產流程
| 任務 | 說明 | 輸出 |
|------|------|------|
| 基礎地形 | 平面地形、草地、岩石 | FBX/GLTF → unity-project/Assets/Art |
| 兵種原型 | 步兵、弓箭手、騎兵（低多邊形） | 一套可測試的單位 |
| 建築原型 | 主城、兵營、礦場 | 幾棟基礎建築 |
| 特效資產 | 選取環、攻擊效果 | Unity VFX Graph 或 Shader |

**Blender 工作指引：**
- 採用低多邊形（Low-Poly）風格，適合多人連線效能
- 模型面數控制在：< 士兵 500-2000 tris、建築 2000-10000 tris
- UV 展開 + PBR 材質流程（Albedo, Normal, Roughness, AO 四張貼圖）
- 用 Blender Grease Pencil 做簡單動畫預覽（揮劍、走路）

#### 1.2 Unity 場景搭建
| 任務 | 說明 |
|------|------|
| 設置 URP 渲染管线 | 選擇性 HDRP，看美術需求 |
| 導入 Blender 資產 | FBX importer 設定 |
| 基礎光照 | 環境光、方向光、烘培或即時光 |
| 攝像機控制 | RTS 視角：縮放、旋轉、平移 |
| 單位選取與移動 | 框選、點擊選取、右鍵移動 |

#### 1.3 Rust 後端骨架
| 任務 | 工具 |
|------|------|
| WebSocket 伺服器 | \ws-rs\ 或 \	okio-tungstenite\ |
| 基礎匹配系統 | 房間建立、加入、踢出 |
| 狀態同步 | 伺服器權威（Server-Authoritative）_tick-based_ |
| 訊息協議 | Protobuf 或 MessagePack |

**Rust Cargo.toml 依賴建議：**
\\\	oml
[dependencies]
tokio = { version = "1", features = ["full"] }
tokio-tungstenite = "0.26"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
# 選配：Protobuf
prost = "0.13"
tonic = "0.12"
\\\

---

## 階段二：核心遊戲系統（Phase 1 — 預計 6~10 週）

### 2.1 資源系統
| 模組 | 說明 |
|------|------|
| 金礦 / 木材 | 採集、庫存、耗盡機制 |
| 經濟循環 | 產出 → 消耗 → 升級 |
| 市場交易 | 玩家間或 AI 交易（選配） |

### 2.2 單位系統
| 模組 | 說明 |
|------|------|
| 單位類別 | 步兵、弓兵、騎兵、法師、攻城 |
| 行為樹 AI | 巡邏、攻擊、撤退、追擊 |
| 升級系統 | 攻擊力、防禦力、移動速度 |
| 陣列 / 編隊 | 群體移動、V 字形攻擊陣型 |

### 2.3 建築系統
| 模組 | 說明 |
|------|------|
| 建造網格 | 格子放置系統（Grid-Based Placement） |
| 生產建築 | 兵營產兵、馬厩產騎兵 |
| 防禦建築 | 城牆、箭塔 |
| 科技樹 | 研發中心 → 解鎖新單位/建築 |

### 2.4 網路同步系統
| 模組 | 說明 |
|------|------|
| Tick 同步 | 伺服器 30-60 tick/s 推送狀態 |
| 預測與回滾 | Client-Side Prediction + Lag Compensation |
| 視錐裁剪 | Frustum Culling — 只傳送視野範圍內的實體 |
| 插值 | 延遲實體位置平滑過渡 |

### 2.5 Blender 深度建模
| 資產 | 數量 |
|------|------|
| 完整兵種族（2-3 種族） | ~30 個模型 |
| 建築全套 | ~20 個建築 |
| 地形套件 | 草地、泥土、雪地、沙漠等 |
| 道具 | 寶箱、旗幟、路標、障礙物 |

---

## 階段三：內容填充與打磨（Phase 2 — 預計 8~12 週）

### 3.1 地圖設計
- 多人對戰地圖（標準 1v1、2v2、FFA）
- procedurally generated 隨機地圖（MiniMap 系統）
- 導航網（NavMesh）烘焙

### 3.2 UI/UX
- 小地圖（Minimap）
- 生產介面（Hotkey 支援）
- 聊天 / 通訊系統
- 匹配系統畫面
- 勝利 / 失敗動畫

### 3.3 音效
- SFX：攻擊、受傷、建築建造
- BGM：選派主題音樂
- 環境音：風聲、遠處戰鬥

### 3.4 平衡性調整
- 單位數據表（Excel/CSV 驅動）
- A/B 測試數據收集
- 排名系統（ELO / MMR）

---

## 階段四：測試與發布準備（Phase 3 — 預計 4~6 週）

### 4.1 測試
| 類型 | 工具 |
|------|------|
| 單元測試 | Rust: \cargo test\, Unity: NUnit |
| 整合測試 | 伺服器和客戶端到端 |
| 壓力測試 | 模擬 100+ 玩家連線 |
| 安全性 | 反作弊、訊息驗證 |

### 4.2 發布
- Steam / Epic Games 上架準備
- 自動更新機制
- 雲端日誌與錯誤報告

---

## 目錄結構

\\\
game-project/
├── blender-assets/            # Blender 模型源文件
│   ├── scenes/                # 場景檔 (.blend)
│   ├── models/                # 匯出前原始模型
│   └── animations/            # 動畫資料
│
├── rust-server/               # Rust 後端
│   ├── Cargo.toml
│   ├── src/
│   │   ├── main.rs
│   │   ├── network/           # WebSocket / TCP
│   │   ├── game/              # 遊戲邏輯
│   │   │   ├── entity/        # 實體定義
│   │   │   ├── ai/            # AI 行為樹
│   │   │   └── combat/        # 戰鬥系統
│   │   ├── state/             # 同步狀態管理
│   │   └── protocol/          # 通訊協定
│   ├── tests/
│   └── proto/                 # Protobuf 定義
│
├── unity-project/             # Unity 專案
│   ├── Assets/
│   │   ├── Art/               # Blender 匯入的模型
│   │   │   ├── Models/
│   │   │   ├── Materials/
│   │   │   └── Textures/
│   │   ├── Scripts/           # Unity C# 腳本
│   │   │   ├── Input/         # 輸入控制
│   │   │   ├── Camera/        # 攝像機
│   │   │   ├── Entities/      # 單位控制
│   │   │   ├── UI/            # 介面
│   │   │   └── Network/       # 網路同步
│   │   ├── Scenes/
│   │   ├── Prefabs/
│   │   └── Settings/          # URP 設定
│   ├── Packages/
│   └── ProjectSettings/
│
├── docs/                      # 設計文檔
│   ├── PLANS.md               # 此檔案
│   ├── GAME_DESIGN.md         # 遊戲設計文檔
│   ├── MODULES/               # 模組文件
│   └── SPECS/                 # 規格文件
│
└── scripts/                   # 自動化腳本
    ├── blender-export.py      # Blender 批量匯出
    └── deploy.sh              # 部署腳本
\\\

---

## 開發工具推薦

| 類別 | 工具 | 用途 |
|------|------|------|
| 3D 建模 | Blender 5.1 | 模型、動畫、渲染 |
| 引擎 | Unity Hub + Unity 6 LTS | 遊戲引擎 |
| 程式語言 | Rust 1.80+ | 後端伺服器 |
| 版本控制 | Git + GitHub/GitLab | 程式碼管理 |
| 通訊協定 | Protobuf | 高效資料序列化 |
| 網路庫 | tokio-tungstenite (Rust) | WebSocket 伺服器 |
| 測試 | cargo test + Unity Test Runner | 單元與整合測試 |
| 通訊 | Discord | 團隊溝通 |
| 進度管理 | GitHub Projects / Notion | 追蹤任務 |

---

## 風險與注意事項

1. **多人網路同步複雜度高** — 這是整個專案最大的技術挑戰
2. **Blender → Unity 流程** — 統一資產管線很重要，避免匯出問題
3. **Rust 學習曲線** — 如果團隊不熟 Rust，可用 C# 替代後端
4. **效能優化** — 大量單位同時計算需要 ECS 架構（考慮 Unity DOTS）
5. **遊戲平衡** — 需要大量反覆測試和調整

---

## 下一步行動

1. [ ] 確認遊戲題材與玩法方向
2. [ ] 安裝 Blender 5.1、Unity Hub、Rust 開發環境
3. [ ] 建立第一個 Unity 空專案，設定渲染管線
4. [ ] 撰寫第一個 Rust WebSocket 伺服器骨架
5. [ ] 在 Blender 中建立第一個測試模型並匯入 Unity

---

*最後更新：2026-07-25*
