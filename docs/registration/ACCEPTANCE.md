# 本機版本驗收

**這是新增測試模式前的歷史驗收。最新整合版見 [SESSION-ACCEPTANCE.md](SESSION-ACCEPTANCE.md)。** 下方 39／24／8 項原生證據屬舊版；不得用來宣稱本輪新 UI、啟動器或打包版本已通過實機驗收。

日期：2026-09-06。範圍：登入、帳號、實名串接、OpenAI 串接與首次創角。沒有把外部服務替身稱為真實查核。

| 驗收 | 結果與證據 |
| --- | --- |
| 後端測試 | `node --test registration-service/tests/*.test.mjs`：12／12 通過。包括密碼雜湊、權杖到期、偽造狀態、重複／封鎖證件、費用同意與上限、精確姓名、逾時、撤銷查核、子女併發配對、HTTP 來源限制、Persona／OpenAI 回覆契約。 |
| 本機保密與重開 | Windows DPAPI 主金鑰重開、SQLite 帳號重開、再次登入與解密成功；資料庫無測試用明文密碼／API key。這是測試資料，不包含真實證件或金鑰。 |
| 原生操作完整路徑 | `godot-client/registration/verification/success-final/registration-report.json`：39 項通過。用原生滑鼠／鍵盤輸入通過 HTTP 測試後端；畫面有「測試資料」標示。 |
| 未設定實名服務 | `godot-client/registration/verification/unconfigured-final/registration-report.json`：24 項通過。Persona adapter 未設定，確認畫面顯示未開放且實名不被放行。 |
| 匯出資源操作 | `godot-client/registration/verification/export-final/bundle-report.json`：8 項通過。Godot 4.6.3 直接載入匯出 EXE 內的資源，驗證登入 → 新介面 → 創角待查核 → 返回、960×540 截圖。沒有載入原始專案資源代替匯出包。 |
| 匯出執行檔啟動 | `scripts/build-yiyu-registration.ps1` 匯出後用實際 EXE 無視窗載入，檢查當次新紀錄無腳本／素材錯誤。接著 `Start-Yiyu.ps1 -VerifyLaunch` 以實際 Node、加密儲存與原生 EXE 啟動，回傳 `YIYU_BUNDLE_LAUNCH_VERIFIED yiyu-registration`；遊戲離開後自身啟動的後端會關閉。 |
| 真實 Persona | **未執行**：使用者尚未申請帳號，無正式環境範本與營運金鑰。 |
| 真實付費 OpenAI | **未執行**：沒有代用其他帳號或其他供應商的金鑰。Luna 合約以測試替身驗證。 |
| 公開部署、政府死亡登記、家庭系統、戰鬥 | **未執行／不在本次範圍**。 |
| LATTICE 新決策寫入 | **失敗待同步**：`FOREMAN_REPLAY_CORRUPT` 與 `CONTROL_PRODUCT_STORE_REJECTED`，見 `LATTICE_PENDING.md`。已保存的舊美術決策沒有被冒稱成新版本。 |

原生實機曾發現人物圖片超出相框，已改正 TextureRect 尺寸設定順序，並補入實際尺寸檢查。匯出曾遺漏程式引用的字型／人物資源，已改成明確匯出清單，重做匯出資源操作與執行檔啟動。PowerShell 多個引數中的路徑引號已改成明確單一字串，啟動驗收同時確認紀錄是本次產生，避免舊紀錄被當成成功。

## 重跑

後端：`node --test registration-service/tests/*.test.mjs`。

原生完整流程：先於隔離環境執行 `node registration-service/tests/ui-fixture.mjs --fixture-success`，另個命令設定 `YIYU_VERIFY_DIR` 為新證據目錄、`YIYU_UI_FIXTURE=success`，執行 `godot --path godot-client -- --verify-registration`。未設定流程改用不帶 `--fixture-success` 的 fixture 服務，並設定 `YIYU_UI_FIXTURE=unconfigured`。測試 fixture 不放入可執行包；不要與真實帳號服務共用 8787 埠。

匯出：`scripts/build-yiyu-registration.ps1`。使用 Godot 4.6.3 Windows x86_64 release template 與 Node v24.16.0。預設只有此次登入／創角資源，不捆綁舊營地與戰鬥程式。

匯出資源畫面：設定 `YIYU_BUNDLE_VERIFY_DIR` 為新證據目錄，再執行 `godot --main-pack playable/yiyu-registration-20260906/異域.exe --script scripts/verify-yiyu-bundle.gd`。實際 EXE 可用 `Start-Yiyu.ps1 -VerifyLaunch` 驗證啟動；不要把外部測試腳本是否可被 release template 的命令列執行當成產品功能。

可執行包：`playable/yiyu-registration-20260906/啟動異域.cmd`。附有 Node、Godot 與字型授權文件，不含測試帳號、Persona 金鑰、玩家金鑰或證件。
