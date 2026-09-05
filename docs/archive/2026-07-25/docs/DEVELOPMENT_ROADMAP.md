# 開發路線圖（Roadmap）— 多人 RTS 遊戲

## 總覽

\\\
Phase 0        Phase 1         Phase 2         Phase 3
Prototype    Core Systems     Content & Polish Testing & Launch
(2-4週)      (6-10週)         (8-12週)        (4-6週)
   │              │                │               │
   ▼              ▼                ▼               ▼
 [████████]───[███████████]───[██████████████]──[██████]
   
總計預估：約 20~32 週（5~8 個月）
\\\

---

## Phase 0：原型驗證（Weeks 1~4）

### Week 1: 環境搭建

- [ ] **工具安裝**
  - Blender 5.1（如已安裝可跳過）
  - Unity Hub + Unity 6 LTS Editor
  - Rust Toolchain（rustup + cargo）
  - VS Code / Visual Studio 2022（Rust 和 C# 支援）
  - Git + GitHub Desktop
  - Docker（選配，用於部署測試伺服器）

- [ ] **倉庫初始化**
  \\\ash
  git init "C:\Users\f7212\OneDrive\文件\遊戲開發"
  # 建立 .gitignore
  # 配置 Git LFS 追蹤 .blend, .fbx, .texture 等大檔案
  git lfs track "*.blend"
  git lfs track "*.fbx"
  git lfs track "*.tex"
  git lfs track "*.png"
  git lfs track "*.psd"
  \\\

### Week 2: Blender 第一個模型

- [ ] 在地形區塊建立基礎平面 + 簡單地形變形
- [ ] 建立一個低多邊形士兵模型（<2000 tris）
- [ ] UV展開 + 簡單貼圖
- [ ] 匯出為 GLTF → 導入 Unity
- [ ] 在 Unity 中驗證渲染效果

### Week 3: Unity 核心控制

- [ ] 設定 URP 管線和場景光照
- [ ] 實現攝像機控制器（旋轉、縮放、平移）
- [ ] 實現單位選取（點擊/框選）
- [ ] 實現單位移動指令（右鍵移動）
- [ ] 將 Blender 模型放入場景測試

### Week 4: Rust 伺服器骨架

- [ ] 初始化 Rust workspace（\cargo init\）
- [ ] 建立 WebSocket 伺服器
- [ ] 實作基本連線/斷線邏輯
- [ ] Unity 端建立 WebSocket 客戶端腳本
- [ ] 測試 Unity ↔ Rust 訊息互通

---

## Phase 1：核心系統開發（Weeks 5~14）

### Weeks 5~6: 網路同步基礎

- [ ] 定義 Protobuf 通訊協定
- [ ] 伺服器權威狀態同步
- [ ] Client-Side Prediction 架構
- [ ] Delta Compression（差異壓縮）
- [ ] 最小化延遲補償

### Weeks 7~8: 資源與經濟系統

- [ ] 資源類型定義（金礦、木材等）
- [ ] 採集單位行為
- [ ] 資源庫存 UI
- [ ] 經濟循環系統（收入/支出）

### Weeks 9~10: 單位與戰鬥系統

- [ ] 單位類別設計（步兵、弓兵、騎兵）
- [ ] 攻擊範圍計算
- [ ] 傷害公式與防禦減免
- [ ] 血條 UI
- [ ] 單位死亡與重生機制

### Weeks 11~12: 建築與生產系統

- [ ] 格子放置系統（Grid Placement）
- [ ] 建築生產佇列
- [ ] 建築生產進度 UI
- [ ] 人口上限機制

### Weeks 13~14: AI 與簡單對戰

- [ ] 基礎 AI 對手（隨機建造、出兵）
- [ ] 1v1 完整遊戲流程（開局→發展→戰鬥→勝負）
- [ ] 勝利條件判定（摧毀主城）
- [ ] 多房間並行支援

---

## Phase 2：內容填充（Weeks 15~26）

### Weeks 15~18: 3D 資產量產

- [ ] 至少 2 個可玩陣營（Faction）
- [ ] 每陣營 6-8 種單位
- [ ] 每陣營 10-15 種建築
- [ ] 地圖物件（岩石、樹木、裝飾）

### Weeks 19~21: 地圖設計

- [ ] 標準 1v1 地圖（雙側資源點）
- [ ] 2v2 地圖（中心資源 contested zone）
- [ ] FFA 4人地圖
- [ ] MiniMap 系統實作

### Weeks 22~24: UI/UX 精修

- [ ] 主選單（匹配、設定、離線模式）
- [ ] 生產面板優化（快速生產按鈕）
- [ ] 快捷鍵自訂
- [ ] 聊天系統（私訊/團隊/全局）

### Weeks 25~26: 音訊

- [ ] SFX 錄製或購買（攻擊、受傷、選取音效）
- [ ] BGM 創作（選派主題曲）
- [ ] 環境音效（風聲、遠處戰鬥）

---

## Phase 3：測試與發布（Weeks 27~32）

### Weeks 27~28: 遊戲平衡

- [ ] 單位數據表（CSV驅動）
- [ ] A/B 測試架構
- [ ] 排名系統（ELO/MMR）
- [ ] 反作弊基礎防護

### Weeks 29~30: 壓力測試

- [ ] 模擬 100+ 玩家同時在線
- [ ] 記憶體洩漏檢查
- [ ] 網路不穩定場景測試
- [ ] 邊緣情況修復

### Weeks 31~32: 發布準備

- [ ] Steam App 頁面建立
- [ ] 打包與 CI/CD pipeline
- [ ] 自動更新機制
- [ ] 雲端日誌服務

---

## 關鍵里程碑（Milestones）

| # | 里程碑 | 預計完成 | 驗證標準 |
|---|--------|----------|----------|
| M0 | 開發環境就绪 | Week 1 | \cargo build\ 成功、Unity 專案開啟、Blender 模型可匯出 |
| M1 | 原型可玩 | Week 4 | 可選取單位、移動、與伺服器連線 |
| M2 | 完整單局對戰 | Week 14 | AI 對戰可從頭打到結束 |
| M3 | 多人連線 | Week 16 | 兩個客戶端同步遊玩 |
| M4 | 內容完整 | Week 26 | 2陣營、3張地圖、完整UI |
| M5 | 封閉測試版 | Week 28 | 外部測試者反饋收集 |
| M6 | 公開 beta | Week 32 | Steam 上架 |

---

## 風險管理

| 風險 | 影響 | 緩解策略 |
|------|------|----------|
| 網路同步延遲高 | 遊戲體驗差 | Delta Compression + 預測 + 插值 |
| Blender 資產品質不足 | 美術不好看 | 使用參考素材，漸進改進 |
| Rust 學習曲線陡峭 | 開發進度落後 | 先從範例開始，善用 Crates.io 套件 |
| 平衡性難調 | 玩家流失 | 早期引入玩家社群測試 |
| 效能瓶頸 | 大量單位卡頓 | ECS/DOTS 遷移準備 |

---

*最後更新：2026-07-25*
