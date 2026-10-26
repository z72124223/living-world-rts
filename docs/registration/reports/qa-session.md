# 登入／創角獨立 QA：2026-09-06 本次 session

第一階段已完成並封存，停在**待實機驗收**。最新本窗口隔離後端重跑 **118 項：118 通過、0 失敗／跳過，exit 0**，包含 12 項既有測試、80 項供應商契約、15 項模擬後端及 11 項獨立 QA。三項後端缺口已修復並獨立重驗；一項 UI 文案缺口已讀回修復。原生畫面／Godot 整合與真實外部服務均未在本窗口執行，不能宣稱產品整體或正式實名驗收通過。

- 驗收窗口：`01a075c1-9c9f-77d3-b400-64bc7cefd342`；接收報告主窗口：`01a074b8-04d3-7e80-a83d-6bf2e7995a78`，host `local`。
- 產品來源：`C:/Users/f7212/OneDrive/文件/遊戲開發`。本窗口僅讀取此處，不修改產品或他人檔案。
- 本次執行目錄：`C:/Users/f7212/.codex/worktrees/50b6/遊戲開發`。原工作樹 HEAD `0ed7393fecee1db6e577e8cefc516db014de8bdc`；複製的未提交產品另以檔案 SHA-256 綁定，不能用工作樹 HEAD 代稱產品版本。
- 修改範圍：本報告、`registration-service/tests/qa-session.test.mjs`、必要測試／來源快照；`registration-service` 是主窗口授權複製與更新的測試基底，本窗口未修補產品。
- 所有實名及 AI 測試使用明確虛構資料／替身。沒有 Persona 連線、OpenAI 付費請求、真實帳密／證件、8787/8788 服務啟動、根工作區遊戲啟動、push、merge 或部署。

## 規則與本次 LATTICE 讀回

已讀來源：主目錄 `AGENTS.md`、`docs/registration/SPEC.md`、`docs/registration/ACCEPTANCE.md`、服務及測試源碼、Godot 登入／創角源碼與 launcher。

本窗口零參數 `lattice_runtime_status` 成功：`scope=receipt-only`、`status=NOT_STARTED`、foreman `replay_status=VERIFIED`。不能把此回執視為遊戲已執行。

`lattice_control_snapshot({"decisions":{"mode":"current","scope":"e8e9d77c-1c05-4864-ad3e-80152a9919a1","limit":20}})` 成功：revision `3`，digest `8711affd71fbe6806b6bfc3f5a524f3d5646436a19171c9f09fb9fa0b54d674a`；包含美術修正與四 BOT 入口決策。`lattice_task_status` 讀回 `82ad0247d26c64d2eee3fe6095111ba21fbcac11be3006a799149e6ae26d9fff` 為 `SUBMITTED / DRAFT`，無 failure_code。本窗口沒有另建、結案或修改 ledger。

主窗口回報其 LATTICE 寫入仍遇到 `FOREMAN_REPLAY_CORRUPT / CONTROL_PRODUCT_STORE_REJECTED`。這是主窗口回報的證據；本窗口讀取成功不代表該寫入問題已修復。最新使用者實作／模擬版授權及 SPEC 優先於舊決策內「只討論圖片」的舊範圍。

## 指定基底與保留證據

證據根目錄：`C:/Users/f7212/.codex/worktrees/50b6/遊戲開發/registration-service/tests/qa-evidence-20260906-171705`。

| 檔案／階段 | SHA-256 或位置 |
| --- | --- |
| 原始 core.mjs | `9CF982CB34E5E56854116F67EE0D231917AB406560570A4484B4D4A1A9EB0A70`；保留於 `original-service/core.mjs` |
| 主窗口修復重連／子女資料後 core.mjs | `95B2F585B125B9C1E6B708FEB4E9E586EA7DC4AC994AE2E4FC259FCF9B098598`；`core-reconnect-fix-manifest.json`，2026-09-06 17:23:43 +08:00 取得 |
| 原 providers.mjs | `269416F6D7D0FEE6497DA5FD7AFF8AB7FED96F1098052543825E516DD4AC8A1D`，舊失敗版本留於 `original-service/providers.mjs` |
| 最終受測 providers.mjs | `27FC4ED93D1FA1B6396973041C52EEB1B038ACFB0EBB567692F21FC586A8D344`，已由本窗口獨立重驗 |
| SPEC.md | `311955642A232D0CD42A814130D1B5772D10681355EDCD814BA7AE088672FAF1` |
| ACCEPTANCE.md | `5842A32806EA8BB2C5905F913877B49900D715FBE9DCC5AAEB780721807EAB93`，內容中的成功紀錄皆為歷史證據 |
| 文案修復前唯讀 registration.gd | `93B667B78E96E35DAE804EA21CBC7805AFDD7D1726C65B29A8F6BE8807697D8D` |
| 最終唯讀 registration.gd | `C0BD02670CA2CCAD063CBA00478AE552F681D2E72E7F587470E38A424D5554CB`；`registration-final-readonly.gd` |
| 最新唯讀 launch.ps1 | `733F3BBE6A2CDFEAA9EDBA380505344FE0FD7917E9E746DDE4762ECC8CF54A45` |
| 最新唯讀 demo.mjs | `0EBDF6A4DB792EEB4E6FB51FD1BF078820FD9618E613A5468FD454AE95EEBBEC` |

`source-manifest.json`、`service-manifest.json`、`integrated-source-manifest.json` 保存各階段其餘檔案與精確快照路徑。最終基底於 **2026-09-06 17:28:44 +08:00** 取得，全部 14 個檔案逐一核對主目錄來源雜湊；`final-service-manifest.json` 與 `final-service-baseline/registration-service/` 保留此次受測源碼及測試，QA 檔雜湊為 `B4AFE647A8D6A330D2DEDA018ED27B3BD4FB1C40B90AFF0C769F801BCE09AF23`。主窗口只補齊 Persona fixture 的 template／resource id/type 等契約欄位；本窗口檢查過差異，原缺漏案例的拒絕斷言沒有放寬。舊失敗輸出沒有覆寫。

## 實際命令與結果

以下命令均從本窗口工作樹執行，Node `v24.16.0`。HTTP 測試使用 `server.listen(0, '127.0.0.1')`，由系統分配隨機埠並在測試結束關閉；獨立測試記錄過 54638、55353、55852、56420，最終 QA 埠為 57125，未占用 8787/8788。Windows DPAPI／SQLite 重開測試只產生測試副本自己的 `tests/evidence/persistence-*`。模擬隔離測試使用自己建立的暫存 sentinel 檔，未讀取真實帳號資料。

| 階段／實際命令 | 結果 | 直接輸出 |
| --- | --- | --- |
| 原基底：`node --test registration-service/tests/*.test.mjs`（當時尚未新增 QA 檔） | 12 通過、0 失敗；exit 0 | `baseline.tap` |
| 原基底：`node --test --test-reporter=tap registration-service/tests/qa-session.test.mjs`（8 項初版） | 7 通過、1 失敗；exit 1 | `independent.tap` |
| 原基底：同上（10 項擴充版） | 7 通過、3 失敗；exit 1 | `independent-expanded.tap` |
| 修復 core 後：同上（11 項，含四種重連失敗變體） | 10 通過、1 失敗；exit 1 | `reconnect-child-fixes.tap` |
| 修復 core 後：`node --test --test-reporter=tap registration-service/tests/service.test.mjs registration-service/tests/persistence.test.mjs registration-service/tests/qa-session.test.mjs` | 22 通過、1 失敗；exit 1 | `reconnect-child-full.tap` |
| 最終 core／providers／測試整合版：`node --test --test-reporter=tap registration-service/tests/*.test.mjs` | **118 通過、0 失敗、0 跳過；exit 0；約 4.82 秒** | `final-backend.tap` |
| `Get-Command godot,cargo` | 可發現 `Godot/bin/godot.cmd` 及 `.cargo/bin/cargo.exe`；僅可發現性 | 本任務工具輸出；沒有執行 Godot／Cargo |

模擬後端 15/15 已包括在本窗口最後的 118/118 隔離重跑。主窗口回報無視窗元件檢查從 26 增至 27 項通過，這仍是**主窗口回報**，本窗口沒有重跑 Godot 元件或原生畫面，不能替代畫面／Godot HTTP 整合驗收。

## 當前登入／創角必做清單

「本輪後端通過」只指虛構供應商下的產品邏輯；「源碼核對」不是操作驗收。「未執行」不得記為通過。

| ID | 必要驗收與明確預期 | 本輪狀態／證據 |
| --- | --- | --- |
| C01 | **登入 → 創角**：登入主畫面開啟原生帳號流程；登入後依序實名、AI、創角，可返回；不啟動舊營地 | 源碼核對：`project.godot` main_scene 為 login；`login.gd:286` 建立並顯示 registration。HTTP 註冊／登出／重登至創角本輪通過；Godot 端到端未執行 |
| C02 | 帳號密碼雜湊、權杖摘要／12 小時期限、登出撤銷；未登入不能讀帳號 | 本輪既有後端＋獨立 HTTP 測試通過；測試資料 DPAPI／SQLite 重開通過 |
| C03 | 未設定 Persona、未查核、缺可信性別及被撤銷查核均不得創角；供應商結果必須綁定帳號 | 最終替身契約測試通過；F02 三種缺漏已由 verified 改為 needs_review，真實 Persona 仍未驗證 |
| C04 | **性別／外貌不能自選**：M 僅男孩，F 僅女孩；固定外貌由伺服器決定，拒絕／忽略 client sex、appearance、items、child 選擇 | 本輪後端男女兩側通過；UI 源碼無性別／外貌選單，真實畫面未執行 |
| C05 | 首次入世只有現代日常衣服、無額外物品，不出現時代／職業／技能選項 | 後端不採用 client items 本輪通過；UI 文案已讀；人物服裝、完整輪廓及裁切未目視驗收 |
| C06 | 姓與名各 1–2 漢字，支援複姓／罕見字；實名姓名不送 AI；建議姓名仍須另按審核 | 格式、複姓、罕見字、建議不等於審核本輪通過；AI payload 源碼只含所需遊戲欄位；真實 AI 審核品質未驗證 |
| C07 | 審核綁精確姓名、政策與 15 分鐘期限；改字／過期／拒絕阻擋；AI 拒名不等於凍結帳號 | 本輪後端通過；UI 修改姓名重新核對源碼已讀；模態視窗操作未執行 |
| C08 | **無空位不能投胎**：伺服器排除異性、保留、已占用、未審核資料，空池回 NO_CHILD 且不寫角色 | 本輪既有及獨立測試通過；UI 初次快照 `registration.gd:281–284` count=0 禁用投胎並回首次傳送，`333–334` 阻止確認；實機未執行 |
| C09 | **父母命名不得改**：伺服器隨機配對合格子女，沿用既有姓名／外貌，接手端不提供改名 | 本輪男女兩側正常資料通過；UI 投胎分支無姓／名欄。原始異常空姓名 F03 已在修復 core 重驗通過 |
| C10 | 搶最後一位子女不得重複占用，保留／占用者不能被強奪 | 既有同程序競爭測試通過；`BEGIN IMMEDIATE`＋交易內重新篩選；未宣稱正式集中式資料庫跨程序壓力測試 |
| C11 | AI 同意、固定模型、實際呼叫、每日上限、失敗嘗試計數、15 分鐘期限、金鑰加密；重驗失敗不能沿用舊授權 | 本輪替身契約通過；F01 原始失敗已由主窗口修復，四種失敗變體重驗通過；真實 Luna 可用性未驗證 |
| C12 | UI 必須區分「已保存金鑰」與「目前連線有效」 | F04 已由主窗口修復，本窗口讀回最終源碼確認依 aiConnected 顯示；原生畫面未執行 |
| C13 | 本機 HTTP Host／瀏覽器來源／認證／JSON gate；帳號回應不含密碼、金鑰、權杖或證件 | 本輪既有＋獨立 HTTP 通過。一般正式服务無公開 moderation／demo 端點 |
| C14 | 正式／模擬入口清楚分離，模擬明示虛構、不收費、不驗身分，不能把模擬狀態帶入正式帳號 | 最新 UI／launcher／demo 源碼已讀；demo 使用記憶體及獨立替身，模式不符清空 token/state；本窗口模擬後端 15/15 通過，Godot 整合未執行 |
| C15 | 實機渲染、人物完整不裁切、視窗縮放、滑鼠鍵盤、命名彈窗、返回與重開測試 | **未執行（NOT RUN）**；主窗口禁止重試被核准審查阻擋的原生操作 |

## 程式問題與回歸狀態

### F01：已修復並由本窗口重驗的 AI 重連授權缺口

原 `core.mjs:147,151` 將已保存金鑰作 keyOverride；`137` 只在沒有 override 時清掉 ai_checked。成功連線／姓名審核後，再用同一金鑰重驗收到 AI_KEY_REJECTED，仍得到 `connectedAfterFailure=true`，並成功 `createOutcome=CREATED`。完整錯誤在 `independent-expanded.tap`。

主窗口修復版在送出重驗前清 ai_checked／舊 review，保留加密金鑰僅供重試。本窗口取得 SHA `95B2F585…8598` 後重跑，結果變為 `connectedAfterFailure=false`／`AI_REQUIRED`。新增原金鑰拒絕、新金鑰拒絕、AI_INCOMPLETE、approved:false 四個變體均通過。沒有真實付費請求。

### F02：已修復並由本窗口重驗的 Persona 必要欄位缺口

原始受測 `providers.mjs:107–108` 未要求非空 id-class，證號／國別未先去除空白再驗必要性。獨立合約測試僅替換 transport，三個回覆分別缺種類、空白證號、空白國別，全部得到 `verified`，預期均為 `needs_review`。證據在 `independent-expanded.tap`、`reconnect-child-full.tap`。

這是接入程式對不完整供應商資料未拒絕的缺口，不代表真實 Persona 已提供這種資料，也不代表真實實名已被繞過。主窗口整合程式 BOT 修復後，本窗口取得 SHA `27FC4ED9…D344`；完整有效資料對照與 80 項供應商契約測試通過，本窗口同三種單欄缺漏測例全部回 `needs_review`。直接證據為 `final-backend.tap` 第 106 項及相鄰 diagnostic。既有錯誤保留，不將替身驗證描述成實際 Persona 成功。

### F03：已修復並重驗的異常子女姓名回退

原 `core.mjs:202` 對空子女姓名使用 `child?.surname || input.surname`，資料表僅 NOT NULL，name_approved=1 且空姓名的異常 row 可以沿用玩家自填「任意名」。這是未來世界資料匯入的防呆缺口，目前沒有供玩家寫 children 的 HTTP 端點。

主窗口修復版 `eligibleChildren` 同時用於數量及配對，排除不完整姓名／外貌；寫入改為明確取 child 原名。新版 core 的同一測例回 `NO_CHILD`，`created=false`，本窗口重驗通過。

### F04：已讀回修復、實機未執行的 UI 連線文案

唯讀 SHA `93B667B7…7D8D` 的 `registration.gd:263` 以 hasKey 顯示「已連線；金鑰可留白重新測試。」保存金鑰可以在逾時／重驗失敗後仍存在，因此此頁與依 aiConnected 顯示的創角頁矛盾。主窗口修復後，本窗口讀回 SHA `C0BD0267…54CB` 的 265–267 行：aiConnected 才顯示已連線，僅有 hasKey 時明示「尚未連線或驗證已失效」。沒有用源碼分析冒稱已在原生畫面重現或通過。

## 外部未驗證：不得勾選正式完成

| ID | 項目 | 狀態 |
| --- | --- | --- |
| E01 | Persona 營運帳號／正式範本／實名金鑰、證件地區支援、活體與可信法定性別／穩定證號、跨證件去重 | **未執行**；使用者尚未申請的紀錄來自 SPEC，本窗口未操作供應商帳戶 |
| E02 | 玩家自己的 OpenAI 金鑰、固定 `gpt-5.6-luna` 真實 Responses API 付費呼叫與模型支援 | **未執行**；替身成功僅證明契約邏輯 |
| E03 | 隱私條款、資料保存／刪除、申覆窗口、帳號復原、集中式 HTTPS 服務與金鑰管理 | **未完成／後續營運工作**；本機服務不是正式反作弊權威 |
| E04 | 政府死亡登記或任何正式法律資料查核 | **未接入／未驗證**，不可由 Persona 生存活體等同 |

## 只保存規則的未來設計

婚姻、懷孕週期、出生與父母共同命名流程、收養／交易／監護、保留給指定父母、死亡後選角、登入繼承人、遺產法律與資產聲望傳承，均依 SPEC 保存規則，本次**不建造介面、不宣稱完成**。`children` 表及本輪異常資料防呆不等於家庭世界後端已完成。戰鬥、RTS 大規模效能、可重用動畫效能也不在本輪量測範圍。

## 第二階段與核准審查邊界

第一階段最終後端重跑及源碼核對已完成，不再擴大沒有新缺陷的測試。保留本角色，停在待實機。最終 Godot 操作與畫面須有主窗口指定的整合版路徑／雜湊與當次直接證據，且目前不得重試下述遭拒操作。所有輸出使用新的獨立目錄，不能覆寫 success-final 等歷史報告。

主窗口明確通知：啟動 `127.0.0.1:8788` 模擬服務＋Godot 輸入／截圖流程遭自動核准審查拒絕，原文 `blocked by policy`，沒有細項原因；並要求不得代試、換工具繞過。**本窗口未重試該操作**。本輪原生畫面驗收保持 NOT RUN；舊圖、歷史 ACCEPTANCE、主窗口 26 項無視窗元件檢查皆不能替代。
