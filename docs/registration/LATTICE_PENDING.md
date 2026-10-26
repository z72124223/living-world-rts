# 決策同步狀態

2026-09-06 新增單項實裝：使用者要求由 AI 選一項先實裝，已接通投胎角色既有外貌的唯讀顯示。程式、素材與目前驗證見 SESSION-ACCEPTANCE.md 及 appearance-inheritance 證據目錄。本輪原生 runtime/current 仍回 FOREMAN_REPLAY_CORRUPT／CONTROL_PRODUCT_STORE_REJECTED；existing task 的 lattice_task_status 亦回 LATTICE_TASK_LEDGER_CORRUPT。沒有成功保存新的 LATTICE 狀態，不宣告整體創角任務完成。

最新使用者更正同步嘗試：使用者明確說「這次的功能只是驗證通過，但很多內容並未實裝」。本窗口已更新 SPEC、SESSION-ACCEPTANCE 與可執行包說明。總控 BOT `01a075c1-9709-7a62-9b66-93130d71c702` 可讀 current revision 4、digest `7c7117183617f7eb28e59faeed3cfe74ca26612ab9ee09f616aca1f447a0822c`，查重無同主題決策；嘗試正式 DECISION `yiyu-creation-verification-not-delivery-20260906` 時回 `Mcp error: -32602: Invalid product update arguments`。後續唯讀仍為相同 revision/digest 且無此決策，實作任務仍 SUBMITTED／DRAFT。**本次更正已保存專案，尚未保存 LATTICE 決策；沒有新 decision 成功回執，沒有結案。** 主窗口本回合原生讀取仍為回放／產品儲存錯誤，不以其他窗口讀取成功冒稱恢復。

2026-09-06 17:53（Asia/Taipei）新增待同步回報：使用者要求開啟創角測試版後，原啟動器與 demo 視窗／服務已成功讀回；使用者接著表示「審核通過了」。原話與啟動證據已存 `SESSION-ACCEPTANCE.md` 的最新更新。此為測試版使用者回報，不推定真實 Persona、付費 OpenAI 或逐項自動驗收通過。本回合 runtime/current 再次回覆下述兩個錯誤，尚未寫入 LATTICE。

最新協作回合補充：主窗口仍直接收到 `FOREMAN_REPLAY_CORRUPT` 與 `CONTROL_PRODUCT_STORE_REJECTED`，未成功同步本輪測試模式與回歸修正。其他 BOT 在各自窗口讀回 current revision 3、digest `8711affd71fbe6806b6bfc3f5a524f3d5646436a19171c9f09fb9fa0b54d674a`，實作 task 仍 `SUBMITTED / DRAFT`；此為各自來源的證據，不代表本窗口恢復。下方 revision 1 是更早紀錄，不能當成現行 revision 寫入。最新完整產品與驗收以 `SPEC.md`、`SESSION-ACCEPTANCE.md` 保存待回讀內容，本輪没有更改 ledger 或宣告任務完成。

2026-09-06 本回合前半段已成功讀回舊美術決策 `yiyu-art-creation-correction-20260906`，revision 1，digest `25d1db51f60722ad474c672ed4a3178158f123621b46ef8af5f3cfbbe9b442f1`。

後半段嘗試以 `yiyu-art-implementation-20260906` 取代舊圖片討論範圍時，`lattice_control_update` 回傳 `CONTROL_PRODUCT_STORE_REJECTED`。隨後重新讀取現行決策也回傳相同錯誤；`lattice_runtime_status({})` 回傳 `FOREMAN_REPLAY_CORRUPT`。**沒有成功保存新版決策，也沒有宣告 LATTICE 任務完成。** 不以直接修改 ledger、忽略 replay 或繞過驗證補寫。

待服務恢復後：

1. 呼叫零參數 runtime status，再讀專案 `e8e9d77c-1c05-4864-ad3e-80152a9919a1` 的 current decisions。
2. 檢查 `yiyu-art-implementation-20260906` 是否已存在，處理不確定回覆時先讀回避免重複。
3. 以最新 revision／digest 保存使用者本輪授權：原生登入後帳號、實名、OpenAI、首次創角與開發文件；取代舊「只討論圖片」範圍，美術與外貌唯讀限制仍保留。
4. 保存 `SPEC.md` 中的產品決策與 Persona「尚未申請」問答，source reference `thread:01a074b8-04d3-7e80-a83d-6bf2e7995a78/turn:01a075b5-8e4f-7b70-b009-cf68313cbc38`，綁定 task `82ad0247d26c64d2eee3fe6095111ba21fbcac11be3006a799149e6ae26d9fff`。
5. 讀回確認後更新此檔，不能把本地文件或此待同步紀錄冒充 PostgreSQL 決策已成功。

在此期間，根目錄 AGENTS.md 已明確引導 AI／開發者讀取 `docs/registration/SPEC.md` 與 `PERSONA_SETUP.md`。它們保存使用者最新指示，不依賴對話記憶才能繼續開發。
