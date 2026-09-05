# Rust 後端伺服器架構指南

## 目標
建立高性能、低延遲的多人 RTS 遊戲伺服器，採用「伺服器權威（Server-Authoritative）_」模式。

---

## 一、技術選型

| 組件 | 選擇 | 理由 |
|------|------|------|
| 網路框架 | **Tokio** (async runtime) | Rust 生態最成熟的 async |
| WebSocket | **tokio-tungstenite** | 支援 WSS（加密連線） |
| TCP 备选 | **tokio::net::TcpListener** | 高吞吐、低延遲場景 |
| 資料序列化 | **MessagePack** + **Protobuf** | 小包體、高效能 |
| 狀態同步 | **Tick-based State Sync** | 30-60 tick/s 推送完整狀態快照 |
| 資料庫（選配） | **SQLite** (rqlite) / **PostgreSQL** | 存取玩家帳號、排名 |
| 日誌 | **tracing + tracing-subscriber** | 生產級 observability |

---

## 二、專案結構

\\\ust-server/
├── Cargo.toml
├── Cargo.lock
├── src/
│   ├── main.rs                  # Entry point
│   ├── config.rs                # 設定檔
│   ├── protocol/                # 通訊協定定義
│   │   ├── mod.rs
│   │   ├── handshake.rs         # 連線握手
│   │   ├── commands.rs          # 客戶端→伺服器指令
│   │   └── states.rs            # 伺服器→客戶端狀態更新
│   ├── network/
│   │   ├── mod.rs
│   │   ├── server.rs            # 主伺服器邏輯
│   │   ├── ws_handler.rs        # WebSocket 連線處理
│   │   └── connection.rs        # 連線管理
│   ├── game/
│   │   ├── mod.rs
│   │   ├── match_manager.rs     # 對戰匹配管理
│   │   ├── entity.rs            # 遊戲實體定義
│   │   ├── component.rs         # ECS 組件
│   │   ├── system/              # 遊戲系統
│   │   │   ├── movement.rs      # 移動系統
│   │   │   ├── combat.rs        # 戰鬥系統
│   │   │   ├── economy.rs       # 經濟系統
│   │   │   └── ai.rs            # AI 系統
│   │   └── state_sync.rs        # 狀態同步
│   ├── auth/                    # （選配）驗證系統
│   │   ├── mod.rs
│   │   └── player_db.rs
│   └── util/
│       ├── mod.rs
│       ├── hash.rs              # 防作弊雜湊
│       └── time.rs              # 伺服器時間
├── proto/
│   └── game.proto               # Protobuf schema
├── tests/
│   ├── network_test.rs
│   └── combat_test.rs
└── benches/
    └── performance_bench.rs
\\\

---

## 三、核心設計原則

### 3.1 伺服器權威（Server-Authoritative）
\\\
客戶端只發送「輸入意圖」(Input Intent)，不發送最終位置。
伺服器根據所有玩家的輸入計算世界狀態，再廣播給所有人。

Flow:
Player A → [MoveTo(x,y)] → Server → Calculated → Broadcast State
Player B ← [State Update]← Server ← Calculated ← Broadcast State
\\\

### 3.2 Tick-Based 同步
\\\
- 伺服器 tick rate: 30 Hz（一般 RTS 足夠）
- 高競技場景可提升到 60 Hz
- 每個 tick 計算：
  1. 收集所有玩家最新輸入
  2. 運行 game systems
  3. 生成狀態快照（compressed）
  4. 廣播給所有連線玩家
\\\

### 3.3 數據壓縮策略
\\\
狀態更新不是每次傳完整世界：
- Delta Compression：只傳差異部分
- Viewport Culling：只傳視野範圍內的實體
- Entity Pool：未發現的實體不傳送
- Field Snapping：位置量化到整數（節省 float 空間）
\\\

---

## 四、通訊協定定義（Protobuf）

\\\protobuf
syntax = "proto3";
package rts;

// 客戶端→伺服器指令
message ClientCommand {
  uint32 player_id = 1;
  uint32 tick = 2;
  oneof command {
    SelectUnits select = 10;
    MoveOrder move = 11;
    AttackOrder attack = 12;
    BuildOrder build = 13;
    ChatMessage chat = 14;
    Resign resign = 15;
  }
}

message SelectUnits {
  repeated uint32 unit_ids = 1;
  bool box_select = 2;     // 框選 vs 單選
  Vector2 box_start = 3;
  Vector2 box_end = 4;
}

message MoveOrder {
  repeated uint32 unit_ids = 1;
  Vector2 target = 2;
  bool formation = 3;      // 是否使用陣型
}

message AttackOrder {
  repeated uint32 unit_ids = 1;
  uint32 target_unit_id = 2;
  Vector2 target_pos = 3;
}

message BuildOrder {
  uint32 building_id = 1;
  Vector2 position = 2;
  float rotation = 3;
}

// 伺服器→客戶端狀態
message StateUpdate {
  uint32 server_tick = 1;
  repeated UnitState units = 10;
  repeated BuildingState buildings = 20;
  repeated ResourceState resources = 30;
  MapState map = 40;
  float timestamp = 50;    // 伺服器時間戳記
}

message UnitState {
  uint32 id = 1;
  uint32 owner_id = 2;
  Vector2 position = 3;
  Vector2 velocity = 4;
  float health = 5;
  uint32 status = 6;       // idle, moving, attacking...
}

message Vector2 {
  float x = 1;
  float y = 2;
}

// 簡化版 — 只傳有變化的實體
// Server 可以用 bitfield 表示哪些 entity 更新了
message EntityDelta {
  uint32 entity_id = 1;
  map<string, float> fields = 2;  // key-value 只傳變動欄位
}
\\\

---

## 五、關鍵模組實作要點

### 5.1 連線管理（network/server.rs）
\\\ust
use tokio::net::TcpListener;
use tokio_tungstenite::accept_stream;

struct ServerState {
    players: HashMap<u32, PlayerConnection>,
    matches: HashMap<u32, MatchRoom>,
    next_player_id: u32,
    tick_rate: u32,
}

impl ServerState {
    // 每 tick 執行一次
    async fn process_tick(&mut self) {
        // 1. 接收並緩衝玩家的輸入
        // 2. 運行遊戲系統（移動、戰鬥、經濟）
        // 3. 壓縮並廣播狀態更新
    }
}
\\\

### 5.2 匹配系統（match_manager.rs）
\\\ust
struct MatchRoom {
    room_id: u32,
    players: Vec<PlayerInfo>,   // 最多 8 人 FFA 或 2v2/4v4
    state: RoomState,           // waiting, playing, finished
    tick_count: u32,
    map_seed: u64,              // 隨機地圖種子
}

enum RoomState {
    Waiting,
    Playing,
    Paused,
    Finished,
}
\\\

### 5.3 遊戲系統迴圈（game/system/*.rs）
\\\ust
// ECS 範例結構
struct World {
    entities: EntityStore<Unit>,
    buildings: EntityStore<Building>,
    resources: ResourceMap,
    input_buffer: InputBuffer,
}

fn update_world(world: &mut World, dt: f32) {
    movement_system::update(world, dt);
    combat_system::update(world, dt);
    economy_system::update(world, dt);
    ai_system::update(world, dt);
}
\\\

---

## 六、效能指標目標

| 指標 | 目標值 |
|------|--------|
| Tick 週期 | < 3ms（30 tick/s） |
| 單一房間承載 | 8-16 名玩家 |
| 記憶體使用 | < 500MB / 房間 |
| 網路頻寬（每玩家） | < 50 KB/s uplink, < 200 KB/s downlink |
| 伺服器到客戶端延遲 | < 20 tick 緩衝 |

---

## 七、安全性考慮

1. **輸入驗證** — 伺服器永遠不信任客戶端輸入
2. **速率限制** — 防止命令噴濺（Command Spam）
3. **時鐘同步** — NTP 校準伺服器時間
4. **防作弊** — 伺服器檢查單位移動速度上限、建造位置合法性
5. **TLS/WSS** — 生產環境強制加密連線

---

*最後更新：2026-07-25*
