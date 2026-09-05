# Unity 客戶端架構指南

## 目標
建立高效的 Unity RTS 客戶端，包含輸入控制、網路同步、UI 系統。

---

## 一、渲染管線選擇

| 選項 | 適合場景 | 建議 |
|------|----------|------|
| **URP (Universal Render Pipeline)** | 首選！多平台支援好，效能優異 | ✅ 推薦 |
| HDRP (High Definition RP) | 高畫質 PC 專用，效能開銷大 | 不推薦初期使用 |
| Built-in | 舊專案維護 | 不使用 |

### URP 設定要點
\\\
1. Create > Rendering > Universal Renderer
2. Graphics Settings → Global Pipeline Settings → URP
3. Quality Settings → 多等級設定（低/中/高/極致）
4. 開啟 MSAA 2x 抗鋸齒
\\\

---

## 二、核心系統架構

### 2.1 輸入系統（Input System）
\\\
推荐使用 Unity 新版 Input System Package
- 支援滑鼠框選（Box Selection）
- WASD 視角平移
- 滾輪縮放
- 邊緣捲動（Screen Edge Scrolling）
\\\

### 2.2 攝像機系統（Camera Controller）
\\\csharp
// CameraController.cs 核心功能
- 旋轉：右鍵拖曳 / Q/E鍵
- 縮放：滾輪（最小/最大距離）
- 平移：A/D鍵 或 移到螢幕邊緣
- 聚焦：雙擊單位將攝像機移動到該單位
\\\

### 2.3 網路同步（Network Sync）
\\\
Client-Server 模型：
┌─────────────────┐        ┌─────────────────┐
│   Unity Client   │◄──────►│    Rust Server   │
│                 │  WS    │                 │
│  - 渲染畫面      │  State │  - 遊戲邏輯      │
│  - 輸入收集      │ Tick   │  - 狀態計算      │
│  - 預測繪製      │ Comm   │  - 廣播狀態      │
└─────────────────┘        └─────────────────┘
\\\

### 2.4 ECS 架構考量（Unity DOTS）
如果單位數量超過 500+，建議導入 Unity DOTS/ECS：
\\\
- Entities 套件處理數千個實體
- Systems 處理移動、戰鬥邏輯
- Packages 處理資料
\\\

---

## 三、關鍵腳本結構

### 3.1 單位控制（EntityControl）
\\\csharp
public class EntityControl : MonoBehaviour {
    public uint entityId;
    public EntityType type;
    public Team team;
    
    // 本地顯示用的變數
    [HideInInspector] public Vector3 visualPosition;
    [HideInInspector] public Quaternion visualRotation;
    
    // 來自伺服器的權威位置
    public ServerState serverState;
    
    void Update() {
        // 插值視覺位置
        visualPosition = Vector3.Lerp(
            visualPosition, 
            serverState.position, 
            interpolationSpeed * Time.deltaTime
        );
    }
}
\\\

### 3.2 輸入管理（InputManager）
\\\csharp
public class InputManager : MonoBehaviour {
    // 收集所有用戶輸入，每 tick 打包發送到伺服器
    public List<InputCommand> GetCurrentInputs();
    
    // 選取系統
    public void HandleClick(Vector2 screenPos);
    public void HandleBoxStart(Vector2 screenPos);
    public void HandleBoxEnd(Vector2 screenPos);
    
    // 指令發送
    public void SendMoveOrder(uint[] unitIds, Vector3 target);
    public void SendAttackOrder(uint[] unitIds, uint targetId);
}
\\\

### 3.3 網路管理器（NetworkManager）
\\\csharp
public class NetworkManager : MonoBehaviour {
    private WebSocket websocket;
    private uint playerId;
    private int currentTick;
    
    // 接收伺服器狀態更新
    public void OnStateUpdate(ServerState state);
    
    // 發送輸入給伺服器
    public void SendInput(InputCommand command);
    
    // 連線健康檢查
    public bool IsConnected { get; }
    public float RoundTripTime { get; }
}
\\\

---

## 四、UI 系統（RTS 介面）

### 4.1 必要 UI 元素
\\\
Minimap (小地圖)
├── 全屏即時資訊顯示 (單位光點)
├── 視窗區域矩形框
└── 點擊快速移轉攝像機

Production Panel (生產面板)
├── 建築選定時顯示可產出的單位
├── 建造按鈕
├── 升級按鈕
└── 快捷欄（Hotbar）

Resource Bar (資源列)
├── 黃金數量
├── 木材數量
└── 人口上限

Chat Box (聊天視窗)
└── 預設隱藏，按 Enter 打開

Command Menu (命令選單)
└── 選中單位/建築時出現行動選項
\\\

### 4.2 小地圖實作要點
\\\csharp
// MinimapController.cs
- RenderTexture 從上方正交攝像機渲染
- 縮放比例：20x20 的地圖對應 200x200 像素
- 單位光點顏色表示陣營
- 矩形選取框與主攝像機關聯
\\\

---

## 五、Shaders（渲染效果）

| 效果 | Shader 類型 | 用途 |
|------|-------------|------|
| 選取環 | Vertex Displacement | 單位被選中時的圓環動畫 |
| 受傷閃紅 | Color Overlay | 單位掉血時閃爍 |
| 地形漸層 | Triplanar | 根據坡度改變材質 |
| 兵力值條 | World Space UV | 單位上方的血條 |
| 特效 VFX | Particle System | 爆炸、火焰、魔法 |

---

## 六、Unity 專案設定清單

- [ ] 安裝 Unity Hub + Unity 6 LTS
- [ ] 安裝 Visual Studio 2022 或 VS Code
- [ ] 專案設定：2D/3D Template
- [ ] 導入 URP
- [ ] 安裝 Input System 套件
- [ ] 安裝 Cinemachine（選用，進階攝影機）
- [ ] 設定 Build Settings → PC/Mac/Linux
- [ ] 配置 Git LFS（大檔案追蹤，如模型貼圖）

---

*最後更新：2026-07-25*
