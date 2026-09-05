# Rust 世界核心現況與邊界

更新：2026-09-06。沿用此文件位置方便查找；目前是世界規則函式庫，尚無執行中的網路伺服器。取代舊版通用 RTS 伺服器範本。

## 目前實作

- 根目錄 `Cargo.toml` 是 Rust workspace，只有 `crates/world-core` 成員。
- `character.rs` 提供統一人物模型、ID、控制來源、能力尺度、在線／離線、清醒／昏迷、生死與最低直接指揮資格。
- 目前 ID 配發是程序內計數器；尚未提供跨程序持久唯一性、載入／存檔或世界級身分登錄。
- 目前指揮判定包含在線條件；它不是已完成的離線 AI、公平性或代理指揮政策。
- 尚無組織樹、完整指揮鏈、網路、資料庫、戰鬥與具名武將循環實作。

## 與 Godot 的分工

Rust 保存世界事實與規則；Godot 收集玩家意圖，呈現對玩家可見的結果與動畫。連接方式尚未決定，不提前加入通訊或資料庫套件。

人物生命、具名身分及跨生命記憶依 [GD-002](decisions/GD-002_NAMED_IDENTITY_CYCLE.md) 分開；組織引用人物 ID，不複製人物。Godot 的顯示物件或動畫消失不等同人物死亡。

畫面可見範圍、網路傳輸最佳化與玩家有權知道的資訊是不同問題。後續介接必須遵守憲法的情報限制，不能因鏡頭位置或全世界狀態廣播而洩漏未知人物與命令。

## 下一步與驗證

世界核心下一步仍是 [MP0-002](https://github.com/z72124223/living-world-rts/issues/3) 及 [MP0 指揮場景](milestones/MP0_SPEC.md)。現行 CI 指令：

```sh
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace --all-targets
```

只在實際執行並通過後回報驗證成功。此輪只更新文件，未執行上述程式檢查。

技術決策依 [TD-001](decisions/TD-001_RUST_WORLD_CORE.md) 與 [TD-002](decisions/TD-002_GODOT_BLENDER_ART_PIPELINE.md)。Tokio、WebSocket、Protobuf、資料庫、固定更新頻率與房間容量均未定案。
