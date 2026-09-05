# 已封存：2026-07-25 舊 RTS 規劃

封存日期：2026-09-06。這些文件原本只存在本機、未納入 Git 追蹤；內容按原始位元組保留，便於追溯。**本目錄不是目前的設計、指令或驗收依據。** 原文中的舊命令、套件、HP、Unity、容量與日期承諾不得直接執行或引用為現行決定。

目前入口為 [README](../../../README.md)、[遊戲憲法](../../GAME_CONSTITUTION.md) 與 [設計想法索引](../../DESIGN_IDEAS.md)。封存表示已停止使用，不表示抹除其中曾討論過的想法。

## 文件去向

| 原始位置／封存原文 | 目前替代文件 | 原因 |
|---|---|---|
| [PLANS.md](PLANS.md) | [README](../../../README.md)、[開發順序](../../DEVELOPMENT_ROADMAP.md) | 通用 RTS、Unity 及網路優先計畫不符合目前決定 |
| [docs/BLENDER_WORKFLOW.md](docs/BLENDER_WORKFLOW.md) | [Blender 工作流程](../../BLENDER_WORKFLOW.md) | 舊 Unity 匯入方式、固定預算與未驗證腳本撤下 |
| [docs/DEVELOPMENT_ROADMAP.md](docs/DEVELOPMENT_ROADMAP.md) | [開發順序](../../DEVELOPMENT_ROADMAP.md) | 舊週數、單局玩法與資產數量未經確認 |
| [docs/RUST_SERVER_ARCH.md](docs/RUST_SERVER_ARCH.md) | [Rust 世界核心](../../RUST_SERVER_ARCH.md) | 尚不存在的網路架構、HP 協定與效能數字被誤寫成既定規則 |
| [docs/UNITY_CLIENT_ARCH.md](docs/UNITY_CLIENT_ARCH.md) | [Godot 客戶端](../../GODOT_CLIENT_ARCH.md) | 引擎已改採 Godot |
| [docs/MODULES/RTS_GAME_MODULE_CONSTITUTION.md](docs/MODULES/RTS_GAME_MODULE_CONSTITUTION.md) | [憲法](../../GAME_CONSTITUTION.md)、Godot／Rust 分工文件 | 避免舊模組規則與正式世界規則並存衝突 |

原本的 `unity-project/` 與 `rust-server/` 只有空資料夾骨架，未有專案檔或程式。本次一併移入此封存目錄保存；Git 本身不追蹤空目錄。有效 Rust 程式位於根目錄的 `crates/world-core/`。

## 原始內容校驗

以下為搬移前與封存後一致的 SHA-256，包含原來的換行、空白及不完整範例語法；不對歷史檔案重新格式化。

| 原始檔案 | SHA-256 |
|---|---|
| PLANS.md | E317709450137AEB51458731263CB26ADBCC060930C95D546C6ACAF49B04F23B |
| docs/BLENDER_WORKFLOW.md | 9B31352930AC89DEF775901A6AEB40478B5644962E1DA29086B8ECB8A2930277 |
| docs/DEVELOPMENT_ROADMAP.md | 6F81469D16E75ACABBEF5BF8D2CD117D402159F2CC24E09D71829ED8337DF4F3 |
| docs/RUST_SERVER_ARCH.md | 53F620529951C1419A051BFFB41112460FEE64F5E59549BCF88DAF36CA88CE2F |
| docs/UNITY_CLIENT_ARCH.md | D3734BA1610206E064B2FE11739A2FC406F371CF5CF70E496D3434455E88D929 |
| docs/MODULES/RTS_GAME_MODULE_CONSTITUTION.md | DCA4B21AD95B5DBFCC07677B6EF2C3A2274BD8EBD0C1658802E9708A5A8003A6 |
