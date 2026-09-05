# 遊戲模組憲章（Module Constitution）

## 模組分層架構

\\\
┌─────────────────────────────────────────────┐
│           Presentation Layer (Unity)         │
│  ┌──────────┬──────────┬─────────────────┐  │
│  │ Input    │ Camera   │ UI/Minimap      │  │
│  │ System   │ Control  │ Manager         │  │
│  └──────────┴──────────┴─────────────────┘  │
├─────────────────────────────────────────────┤
│           Network Layer (Both)               │
│  ┌──────────────────┬──────────────────────┐ │
│  │ Client Network   │ Server WebSocket     │ │
│  │ (WebSocket)      │ (tokio-tungstenite)  │ │
│  └──────────────────┴──────────────────────┘ │
├─────────────────────────────────────────────┤
│           Game Logic Layer (Rust Server)     │
│  ┌──────────┬──────────┬──────────┬───────┐ │
│  │ Entity   │ Combat   │ Economy  │ AI    │ │
│  │ System   │ System   │ System   │ System│ │
│  └──────────┴──────────┴──────────┴───────┘ │
├─────────────────────────────────────────────┤
│           Data / Persistence (Optional)      │
│  ┌──────────────────┬──────────────────────┐ │
│  │ Player DB        │ Match History        │ │
│  │ (SQLite/PgSQL)   │ (SQLite/PgSQL)       │ │
│  └──────────────────┴──────────────────────┘ │
└─────────────────────────────────────────────┘
\\\

---

## 模組清單

### Module 1: 實體系統（Entity System）

| 屬性 | 內容 |
|------|------|
| **ID** | \entity-system\ |
| **負責** | 遊戲世界中所有可互動物件的定義和生命周期 |
| **非責任** | 渲染、戰鬥計算、AI 邏輯 |
| **owned data** | Entity 結構定義、ECS 存儲 |
| **public contracts** | \create_entity(), \get_entity(id)\, \emove_entity(id)\ |
| **依賴** | 無（基礎層） |
| **被依賴** | combat-system, movement-system, ai-system, economy-system |
| **invariant** | 1. 每個 entity 有唯一 ID 2. 已死亡的 entity 不能再被選取 |

### Module 2: 移動系統（Movement System）

| 屬性 | 內容 |
|------|------|
| **ID** | \movement-system\ |
| **負責** | 單位位置更新、路徑尋找、移動指令處理 |
| **非責任** | 碰撞偵測、戰鬥計算 |
| **owned data** | NavMesh 數據、路徑緩衝 |
| **public contracts** | \move_entities(ids, target)\, \get_path(from, to)\ |
| **依賴** | entity-system, navmesh |
| **被依賴** | combat-system, ai-system |
| **invariant** | 1. 伺服器計算最終位置 2. 移動速度不能超過上限 |

### Module 3: 戰鬥系統（Combat System）

| 屬性 | 內容 |
|------|------|
| **ID** | \combat-system\ |
| **負責** | 傷害計算、攻擊範圍判定、防禦減免 |
| **非責任** | 特效表現、音效播放 |
| **owned data** | 武器數據表、傷害公式 |
| **public contracts** | \calculate_damage(attacker, defender)\, \pply_damage(entity, amount)\ |
| **依賴** | entity-system, movement-system |
| **被依賴** | ai-system |
| **invariant** | 1. 傷害只在伺服器端計算 2. HP 不能低於 0 |

### Module 4: 經濟系統（Economy System）

| 屬性 | 內容 |
|------|------|
| **ID** | \economy-system\ |
| **負責** | 資源採集、庫存管理、建築產出 |
| **非責任** | 科技樹研究 |
| **owned data** | 資源類型、礦點狀態 |
| **public contracts** | \collect_resource(entity_id, resource_type)\, \update_income()\ |
| **依賴** | entity-system, movement-system |
| **被依賴** | ai-system |
| **invariant** | 1. 資源不能為負數 2. 礦點枯竭後不能繼續採集 |

### Module 5: AI 系統（AI System）

| 屬性 | 內容 |
|------|------|
| **ID** | \i-system\ |
| **負責** | 電腦對手行為決策、微操 |
| **非責任** | 網路通訊、渲染 |
| **owned data** | 難度參數、行為樹 |
| **public contracts** | \generate_commands(faction, state)\ |
| **依賴** | entity-system, movement-system, combat-system, economy-system |
| **被依賴** | match-manager |
| **invariant** | 1. AI 輸入速率隨難度調整 2. AI 不能違反規則 |

### Module 6: 網路協議（Network Protocol）

| 屬性 | 內容 |
|------|------|
| **ID** | \
etwork-protocol\ |
| **負責** | 序列化/反序列化、訊息驗證 |
| **非責任** | 遊戲邏輯、連線管理 |
| **owned data** | Protobuf schema、版本號碼 |
| **public contracts** | \serialize(input)\, \deserialize(data)\ |
| **依賴** | 無 |
| **被依賴** | 所有其他模組 |
| **invariant** | 1. 版本兼容向前一版 2. 訊息有時間戳記和序號 |

### Module 7: 匹配系統（Match Management）

| 屬性 | 內容 |
|------|------|
| **ID** | \match-manager\ |
| **負責** | 房間建立、玩家匹配、遊戲開始/結束 |
| **非責任** | 玩家帳號管理、數據持久化 |
| **owned data** | 房間列表、對戰狀態 |
| **public contracts** | \create_room(players)\, \start_match(room_id)\, \end_match(room_id)\ |
| **依賴** | network-protocol, entity-system |
| **被依賴** | auth-module |
| **invariant** | 1. 同一玩家不能同時在兩個房間 2. 房間滿員才能開始 |

### Module 8: 資產管線（Asset Pipeline）

| 屬性 | 內容 |
|------|------|
| **ID** | \sset-pipeline\ |
| **負責** | Blender → Unity 資產導入流程 |
| **非責任** | 遊戲邏輯、後端 |
| **owned data** | 匯出腳本、材質模板、importer 設定 |
| **public contracts** | \export_to_gltf(model, output_path)\, \import_to_unity(gltf_path)\ |
| **依賴** | 無（外部工具鏈） |
| **被依賴** | 所有 Unity 模組 |
| **invariant** | 1. 模型命名符合規範 2. 貼圖格式正確 3. 面數在限制內 |

---

## 模組依賴圖

\\\
              ┌─────────────┐
              │ asset-pipeline│
              └──────┬──────┘
                     │ (Unity only)
          ┌──────────┼──────────┐
          │          │          │
    ┌─────▼────┐ ┌──▼────────┐ │
    │network-  │ │entity-    │ │
    │protocol  │ │system     │ │
    └────┬─────┘ └────┬──────┘ │
         │            │        │
    ┌────▼────────────▼──┐     │
    │   movement-system   │     │
    └────┬───────────────┘     │
         │                      │
    ┌────▼──────────┐          │
    │ combat-system  │          │
    └────┬──────────┘          │
         │                      │
    ┌────▼──────────┐          │
    │economy-system  │          │
    └────┬──────────┘          │
         │                      │
    ┌────▼─────────────────────▼──┐
    │       ai-system             │
    └─────────┬───────────────────┘
              │
    ┌─────────▼──────────┐
    │  match-manager      │
    └────────────────────┘
\\\

---

*最後更新：2026-07-25*
