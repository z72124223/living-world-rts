# 《異域》登入／首次創角：本次協作範圍報告

報告日期：2026-09-06（Asia/Taipei）。狀態：依主窗口本回合後續指示定稿交付，不等待其他 BOT，不重新派工。用途：供主窗口逐項收件、整合及最終驗收；本報告不是新增產品決策，也不代表整個 session 通過。最終結論由主窗口建立 SESSION-ACCEPTANCE 記錄。

## 來源與證據界線

- 主窗口：`01a074b8-04d3-7e80-a83d-6bf2e7995a78`，host `local`，名稱「提供專業遊戲開發建議」。本回合已讀回其最近兩個回合；使用者要求分窗完成後回報，再由主窗口驗證本次 session 是否全數通過。
- 總控：`01a075c1-9709-7a62-9b66-93130d71c702`，host `local`。只新增本報告，沒有重新派工。
- 主工作區（本回合唯讀）：`C:/Users/f7212/OneDrive/文件/遊戲開發`。
- 本報告：`C:/Users/f7212/.codex/worktrees/8e4f/遊戲開發/docs/registration/reports/session-scope.md`。
- 規則入口：[AGENTS.md](C:/Users/f7212/OneDrive/文件/遊戲開發/AGENTS.md)。規格：[SPEC.md](C:/Users/f7212/OneDrive/文件/遊戲開發/docs/registration/SPEC.md)，交件前讀回 83 行，SHA-256 `9662f318c3ce77adb061752cb72a12bf6cb393fcff81747efdad80edf1ce9bee`。下表的 `SPEC Lx` 均指這份快照的行號，之後若文件變更應重核對。撰寫期間主窗口新增示範模式段落；初讀 77 行摘要 `311955642a232d0cd42a814130d1b5772d10681355edcd814ba7ae088672faf1` 已由此較新快照取代。
- 補充來源：[PERSONA_SETUP.md](C:/Users/f7212/OneDrive/文件/遊戲開發/docs/registration/PERSONA_SETUP.md)、[roles.json](C:/Users/f7212/OneDrive/文件/遊戲開發/bots/roles.json)，均已唯讀；後者是角色入口，不能替代正式任務狀態。
- 本回合總控沒有讀取秘密、操作證件、呼叫付費 API、執行遊戲或重跑產品測試。以下「待驗」意指總控尚未取得主窗口對最終整合版本的驗收證據，不能解讀成每個項目都尚未實作。
- 狀態用語：`READBACK_OK` 僅是本回合工具／文件讀取成功；`REPORTED` 是其他窗口的報告；`PENDING_ACCEPTANCE` 是尚待主窗口驗收；`NOT RUN` 是本回合未執行；`EXTERNAL_BLOCKER` 是規格記載且本回合不能完成的外部前置；`FUTURE` 是保留規則、不在本次建造範圍。

## 本回合 LATTICE：不同窗口分開記錄

| 入口 | 本回合觀察 | 能支持的結論 |
| --- | --- | --- |
| 總控 `lattice_runtime_status({})` | READBACK_OK；`scope=receipt-only`、`status=NOT_STARTED`、Foreman replay `VERIFIED`；Graphify `READY`、Hermes `PREPARED` | 此窗口原生工具成功回應；全域 `ALL_COMPLETED` 不是本專案或本 session 已完成 |
| 總控 current decisions | READBACK_OK；revision `3`，digest `8711affd71fbe6806b6bfc3f5a524f3d5646436a19171c9f09fb9fa0b54d674a`，2 項現行決策，未截斷 | 已讀回 `yiyu-art-creation-correction-20260906` 及 `yiyu-four-bots-project-placement-20260906` |
| 總控 project snapshot | READBACK_OK；revision `823c35d563722029a662f4c92853ce75e679d5eead8e04d09a2c03c9836d3e96`；3 項任務皆 `SUBMITTED / DRAFT` | 快照的決策文字是預覽，完整現行美術規則以 current packet 為準；沒有正式完成證據 |
| 總控 task status | `82ad0247d26c64d2eee3fe6095111ba21fbcac11be3006a799149e6ae26d9fff` 為 `SUBMITTED / DRAFT`，`result_digest=null` | 創角實作登記仍為草稿，不能自行結案 |
| 主窗口 | 本次委派訊息回報 `FOREMAN_REPLAY_CORRUPT / CONTROL_PRODUCT_STORE_REJECTED`；另以 read_thread 看到當前回合 runtime/current snapshot 呼叫標為 failed，但此次未拉取其錯誤輸出內容 | 精確錯誤碼屬主窗口提供的證據；總控讀取成功不能證明主窗口已恢復，也不據此更改 ledger |
| demo 窗口 | 主窗口委派說明及 demo 進度均報告該窗口可讀回 LATTICE | REPORTED；不把 demo 的成功套用到其他窗口 |

project_id：`e8e9d77c-1c05-4864-ad3e-80152a9919a1`。本回合沒有新增 LATTICE 任務、寫入決策或調整帳本。

## 已有分工與收件位置

這是主窗口既有指派的摘錄，不是總控重新派工。所有 host 都是 `local`。

| 既有入口 | 正式任務 ID | 本次責任／收件絕對路徑 | 首次狀態快照 |
| --- | --- | --- | --- |
| 主窗口「提供專業遊戲開發建議」 | `01a074b8-04d3-7e80-a83d-6bf2e7995a78` | 主工作區 Godot UI、launcher、build、整合及最終逐項驗收 | 進行中；其操作仍由主窗口驗收 |
| 異域 BOT｜程式開發 | `01a075c1-9719-7200-a5ea-b3ff4396f408` | `C:/Users/f7212/.codex/worktrees/fb25/遊戲開發/registration-service/providers.mjs`、`registration-service/tests/provider-contract.test.mjs`；報告 `C:/Users/f7212/.codex/worktrees/fb25/遊戲開發/docs/registration/reports/providers.md`；必要 Persona 設定文件補充 | 進行中；尚未收取最終修補與測試結果 |
| 異域 BOT｜美術製作與核對 | `01a075c1-9b25-71b3-9830-d07bd0b238a1` | 唯讀既有實機截圖及素材；報告 `C:/Users/f7212/.codex/worktrees/e43b/遊戲開發/docs/registration/reports/art-review.md` | 進行中；新 demo 截圖另待主窗口提供 |
| 異域 BOT｜實機測試 | `01a075c1-9c9f-77d3-b400-64bc7cefd342` | 第一階段隔離服務測試／驗收缺口；報告 `C:/Users/f7212/.codex/worktrees/50b6/遊戲開發/docs/registration/reports/qa-session.md`；第二階段依主窗口整合後基準驗收 | 進行中；第一階段不等於最終 Godot 實機驗收 |
| 異域｜獨立創角測試服務 | `01a075f7-3570-7122-919e-1e21593b86b6` | 僅 `registration-service/demo.mjs`、`registration-service/tests/demo.test.mjs`、`docs/registration/reports/demo-service.md`；完整工作樹絕對路徑待正式交件，不能由 client ID 猜測 | 進行中；進度 REPORTED「15 項 HTTP 測試通過」，總控未讀原始測試輸出、未重跑 |

首次 wait_threads 狀態快照時間為約 2026-09-06 17:18 +08:00，四個分工皆 active/inProgress。歷史游標保留供追溯：程式 `f71a0828-831c-412e-9310-ec9800f93ceb:2`；美術 `0e41a0b1-f41f-4f4f-81cb-b444d4842f55:2`；測試 `27d4d1a0-dd2c-46c1-b714-7fc8a5ef8529:2`；demo `0c03648c-10e7-4a4c-9c44-c768a2d53478:1`。下列主窗口後續回報取代此處的舊進度，不再等待或輪詢。

### 交件前最新收件與限制

來源：主窗口 `01a074b8-04d3-7e80-a83d-6bf2e7995a78` 本回合送達總控的後續訊息。這些均為 `REPORTED`；總控未重新執行或讀取測試原始輸出。本段列出主窗口提供的結果，不把未提供的命令、版本或測試細節補寫成證據。

| 項目 | 主窗口最新回報 | 本報告標示與影響 |
| --- | --- | --- |
| demo | 已交付，主窗口重跑 15/15 通過 | REPORTED（主窗口重跑通過）；D03 的早期 BOT 進度已更新，總控自己的測試仍 NOT RUN。精確命令、整合版本由 SESSION-ACCEPTANCE 提供 |
| 美術 | 已交件 | REPORTED（已收件），不據此推定所有新畫面通過。內容及是否含新 demo 畫面由主窗口最終結論界定 |
| provider | 預備 77 項契約；Persona 欄位缺失將由 provider 修補解決 | REPORTED（準備／待修補），不是 77 項已通過，也不是正式 Persona 驗證完成；修補與測試結果待主窗口最終記錄 |
| QA | 已發現 3 個缺口 | REPORTED（發現問題）；其中 AI 重連失敗仍有權限、壞子女姓名 fallback 由主窗口報告已修 core；Persona 欄位缺失由 provider 處理。總控未重跑修補後回歸，不能標缺口已驗證關閉 |
| 主窗口 core | 已修 AI 重連失敗的權限與壞子女姓名 fallback | REPORTED（修改已做）；S09／S11／S12／S17 的相關回歸仍以主窗口結果為準。沒有把總控的 C04／C11 契約疑點自動視為因此解決 |
| Godot UI／腳本 | 無視窗元件 26/26 及腳本語法通過 | REPORTED（相應範圍通過），不足以代替原生整合實機驗收 |
| 新增原生整合啟動 | 自動核准審查拒絕，訊息為 `blocked by policy` | BLOCKED／NOT RUN。只知道回報的拒絕訊息，未提供更細政策理由；不繞過限制、不交他人重試，也不以無視窗測試取代 |
| 最終 session 判定 | 主窗口自行建立 SESSION-ACCEPTANCE | 總控不宣告全 session passed；外部查核、付費 API、原生整合未執行項必須保留各自狀態 |

以上更新僅封存目前可追溯來源，沒有主目錄寫入、重新分派或帳本變更。

## 本次需落地與驗收的項目

下列編號只供本報告追蹤，不是新建任務或新增產品規則。除個別說明之外，整合驗收狀態均為 `PENDING_ACCEPTANCE`；供應商替身通過只能支持程式契約。

| 編號 | 本次要求與必要證據 | 來源 | 既有責任／驗證限制 |
| --- | --- | --- | --- |
| S01 | 原生登入頁可進入帳號登入／註冊、實名、AI 設定及首次創角；所有步驟可查看；後端條件不足不能正式創角；通過後保存角色並顯示登記結果 | SPEC L9 | 主窗口＋測試；需最終整合版實機路徑，不能只驗服務 HTTP |
| S02 | 本次停止於登記結果，不啟動舊營地執行檔，也不混入戰鬥／婚育／交易／死亡後選角 UI | SPEC L9 | 主窗口＋測試；核對 launcher、入世按鈕與匯出包 |
| S03 | 人物簡化 2D 手繪、清楚輪廓、有限色塊與少量陰影；人物與洞窟場景參考分開；閒置創角無水墨打擊特效 | SPEC L14–15、L81–83；current art 決策 | 美術＋主窗口；既有截圖與新渲染分別標示 |
| S04 | 無捏臉、髮型／髮色／膚色／外貌預設／隨機外貌／性別選單；固定人物唯讀且完整不裁切；介面繁中 | SPEC L16、L19、L83；current art 決策 | 美術＋測試；需目視及操作，單張概念圖不足 |
| S05 | 性別僅來自可信實名欄位；不推定自拍性別；缺欄位待複查；伺服器決定固定 appearance ID，忽略客戶端提供的 sex／appearance／items | SPEC L17、L19、L65 | 程式＋測試；真實 Persona 欄位能力為 E02，不得用 demo 固定值代替 |
| S06 | 成年角色，不顯示數字年齡，不恢復「16 歲」、自然老化或成長設定 | SPEC L18 | 美術＋主窗口；需核對素材與文字，家庭系統屬未來 |
| S07 | 首次傳送用玩家現代時代：普通現代衣服，沒有物品、武器、食物、行李；不選朝代、國家、職業或技能 | SPEC L20 | 美術＋測試；核对預覽、表單與伺服器初始資料 |
| S08 | 華語姓名：姓、名各 1–2 漢字，支援複姓及合理罕名；與實名姓名分開；外國玩家可用 AI 取得建議 | SPEC L22–23 | 主窗口＋測試；取名建議不等於審核通過 |
| S09 | 姓名審核綁帳號、精確姓／名、政策版本、時間及結果，15 分鐘內有效；正式創角再核對精確字串；修改字串或過期不得沿用舊審核 | SPEC L62 | 測試；需正反例與最後創角重核，AI 判斷本身為 E03 |
| S10 | 入世前命名規範彈窗含刪角、惡意再犯凍結／實名黑名單、人工依證據處置與申覆；單次 AI 拒絕不得自動封禁 | SPEC L25 | 主窗口＋測試；正式申覆營運窗口仍 E04 |
| S11 | 隨機投胎由伺服器選同登記性別、公開、未保留、未占用、姓名已通過審核的子女；無候選人禁用；不接受指定 child ID | SPEC L17、L21、L65–66 | 測試＋主窗口；正式子女來源 E09，demo 虛構池僅支持模擬流程 |
| S12 | 投胎沿用父母所取既有姓名，接手者不能改名；SQLite BEGIN IMMEDIATE 交易中重新篩選並隨機占用，避免並發重複占用 | SPEC L24、L66 | 測試；不能以單次成功證明原子性；子女姓名歷史資料契約見 C04 |
| S13 | 帳號密码以隨機 salt＋scrypt 保存於後端 SQLite，不存明文 | SPEC L57 | 測試；文件敘述不能代替資料／程式測試證據 |
| S14 | 登入權杖在客戶端記憶體；後端存 SHA-256 摘要，12 小時失效；登出撤銷 | SPEC L58 | 測試；需要過期與登出後拒絕案例 |
| S15 | Persona 查核從後端取得 inquiry；reference-id 必須符合帳號；approved、政府證件 passed、自拍本人比對與活體均須通過；前端回呼或布林值不授權 | SPEC L59；PERSONA_SETUP | 程式＋測試；缺值、錯帳號、未 approved、失敗分項不得被誤判通過；真實查核 E01–E02 |
| S16 | 身分識別用 HMAC(國別、證件種類、可信證號)，不保存原始證號；同份可識別證件唯一性，不宣稱跨證件唯一自然人 | SPEC L60 | 程式＋測試；跨證件去重 E05 |
| S17 | 僅 OpenAI、玩家自備金鑰且負擔費用；固定 gpt-5.6-luna，實際呼叫成功才算有效，不用字串格式／模型清單／訂閱／虛構餘額放行 | SPEC L26–27 | 程式＋主窗口＋測試；本回合實際付費呼叫 NOT RUN，不能更換模型或取消門檻 |
| S18 | 金鑰 AES-256-GCM 加密並綁帳號；本機主金鑰 Windows DPAPI 保護；資料在使用者 LOCALAPPDATA/Yiyu/registration，不進專案與匯出包 | SPEC L61 | 主窗口＋測試；需核對打包排除與保護機制；總控不讀秘密 |
| S19 | AI 使用 Responses API、固定 Luna、結構化 JSON、store:false、最多 300 輸出 token；不傳實名、證號、照片、履歷 | SPEC L63 | 程式＋測試；契約替身可核對請求與格式，不能證明真實模型可用或姓名判斷品質 |
| S20 | AI 操作先取得玩家同意；預設每日 20 次，可調 1–100 次；UTC 日重置；失敗嘗試也計次；不宣稱精確金額上限 | SPEC L64 | 主窗口＋測試；需同意、邊界值、重置、失敗計次與提示核對 |
| S21 | 官方本機 moderate.mjs 需要案件參照與理由、留稽核；無公開 HTTP 封禁端點；刪角以可供申覆還原的停用墓碑處理 | SPEC L67 | 測試；不是本次新增營運 UI，亦不能用帳號封禁代替 AI 拒絕 |
| S22 | 正式本機服務只綁 127.0.0.1:8787，拒絕錯誤 Host／跨站瀏覽器；不可作多人線上反作弊權威 | SPEC L69 | 測試＋主窗口；本回合不進行公開部署 |
| S23 | 未設定 Persona 顯示「實名驗證服務尚未設定」；設定存在與真實查核通过分開；沒有政府死亡資料查詢，不顯示已驗存亡 | SPEC L47、L51；PERSONA_SETUP | 程式＋主窗口＋測試；需未設定／待複查／失敗的真實狀態呈現 |
| S24 | 交付拆分背景、固定人物與原生表單；不用帶假狀態的整張概念圖充當 UI；最終截圖核對完整人物、禁選項、服裝、狀態 | SPEC L81–83 | 主窗口＋美術＋測試；單張圖不能证明可重用動畫或戰鬥效能 |

### 本回合另外已指派的 demo 與整合

以下出自主窗口當前回合 `01a075f4-11a5-73e0-9230-a07889c519f5` 的既有委派；交件前已核對新增 SPEC L73–77 的示範模式段落。這是分開的示範流程，不降低正式服務規則。

| 編號 | 已指派內容／應回收證據 | 責任與狀態 |
| --- | --- | --- |
| D01 | 獨立 127.0.0.1:8788；mode=demo；僅記憶體測試資料，不讀正式資料／金鑰、不連 Persona/OpenAI、不收費；重開不能清理正式資料 | demo＋測試；PENDING_ACCEPTANCE |
| D02 | POST /v1/demo/start 回傳 token＋state；依序主動操作 identity／ai 端點啟用模擬查核，不接受證件、真實帳密或 API 金鑰；測試身分固定女性，沒有性別或外貌控制項 | demo＋主窗口；SPEC L75–77；PENDING_ACCEPTANCE |
| D03 | 提供合格虛構公開子女及保留／異性別／占用反例；保留父母所取的子女既有姓名；重開可測首次傳送與投胎；姓名及配對沿用核心限制 | demo＋測試；最新 REPORTED 已交件且主窗口重跑 15/15；原始命令與整合版本由主窗口 SESSION-ACCEPTANCE 記錄 |
| D04 | 保留精確 Host、來源、認證保護；測試用隨機埠，避免佔主窗口 8787/8788 | demo＋測試；PENDING_ACCEPTANCE |
| D05 | 主窗口整合 Godot UI／launcher／build、「測試創建角色.cmd」及 --registration-demo 入口；模式識別與模擬提示持續可見；最終從登入走完創角，核對未配置正式流程與匯出包；模擬狀態不得帶入正式帳號 | SPEC L75–77；主窗口回報無視窗元件 26/26／語法通過，但新增原生整合啟動遭審查拒絕，BLOCKED／NOT RUN；最終範圍由 SESSION-ACCEPTANCE 記錄 |

## 外部阻塞與後續服務（不能宣稱完成）

| 編號 | 缺少的前置或證據 | 來源／對本次驗收的影響 |
| --- | --- | --- |
| E01 | Persona 帳號尚未申請；正式帳號、template、金鑰及實際查核未完成 | SPEC L43–47、L71；EXTERNAL_BLOCKER。未配置拒絕流程可驗，真實實名通過 NOT RUN |
| E02 | 各營運地證件支援、可信法定性別、稳定證號、本人比對／活體與 inquiry 綁定的真實供應商證據 | SPEC L17、L51、L59；EXTERNAL_BLOCKER。不能由假回應或自拍推定补齐 |
| E03 | 玩家付費 Luna 真實呼叫、帳號可用性及真實姓名審核結果 | SPEC L27、L71；NOT RUN，本次禁止付費測試。提供者契約通過不等於模型可用，不自行換模型 |
| E04 | 正式隱私告知、申覆窗口、供應商保存與刪除政策、營運地管轄與合法調取程序 | SPEC L49、L71；EXTERNAL_BLOCKER。只記缺口，不代擬法律結論、不宣稱已建立營運流程 |
| E05 | 跨不同證件的同一自然人去重方案 | SPEC L60、L71；FUTURE／供應商方案待定；現有 HMAC 只涵蓋同一可識別證件 |
| E06 | 帳號復原流程 | SPEC L71；FUTURE。本次登入與權杖測試不等於帳號復原完成 |
| E07 | 營運方 HTTPS、集中式資料庫／金鑰管理、備份還原與營運權限環境 | SPEC L69、L71；FUTURE。本機程式與匯出不等於正式多人服務，本回合禁止部署 |
| E08 | 政府死亡登記資料與相應授權 | SPEC L51；未接入且非本次採用的實名方案。不可承諾已查政府存亡，不能把缺此資料說成已完成 |
| E09 | 正式家庭／世界後端提供可接手子女資料 | SPEC L39、L71；FUTURE。可以验空池禁用与 demo 配對；虛構子女不等於真實世界接入 |

## 已保留但本次不建造的系統

| 編號 | 已有規則與未定部分 | 來源 |
| --- | --- | --- |
| F01 | 世界為 RTS＋RPG／AI 生態；洞窟聚落、洞外危險；本次不擴建戰鬥或世界模擬 | SPEC L9、L13 |
| F02 | 生育、出生姓名與審核、監護、公開／保留給單一父母帳號由家庭後端管理；已占用子女不得被強制取代 | SPEC L24、L32–33、L39 |
| F03 | 父母死亡後登入合格保留子女；否則重新創角；不把原角色資產／聲望直接複製給陌生新角色；死亡後選角 UI 不在本次 | SPEC L9、L34、L71 |
| F04 | 帳號登入權與遺產所有權分開；遺產法律尚未選定，不代填財產／聲望繼承制度 | SPEC L35 |
| F05 | 同性婚姻允許；雙方無生物子女可領養／接手未占用子女；成年男女雙方同意生育；妊娠週期未定 | SPEC L36–37 |
| F06 | 收養／轉讓限未占用子女，解除原保留權、移轉家庭關係、使用新父母角色姓；交易與家庭後端未完成 | SPEC L38–39 |
| F07 | 未來玩家與自己武將溝通使用玩家 AI；其他 AI 用途未定；較高模型屬後續版本決策 | SPEC L27–28 |
| F08 | 可重用動畫是現行美術要求；本次範圍未提供動畫／戰鬥效能驗收指標或動態證據，不以靜態圖宣稱已通過 | SPEC L14、L83 |

## 規則差異、已解決優先序與驗證缺口

| 編號 | 比對結果 | 本次採用的界線／待驗點 |
| --- | --- | --- |
| C01 | current art 決策仍保留「創角圖片討論」；SPEC L81 與本回合使用者已授權登入／創角實作 | 這是有最新指示可解決的時間差，不是停工理由；沿用現行美術禁項，不把工程授權擴展到婚育／世界系統。總控不改 ledger |
| C02 | current 決策稱 v02 待評閱；SPEC L81 說 v02 作視覺基礎 | 採作素材方向不等於使用者正式核准。需主窗口最終畫面與美術核對，不能自稱 v02 已核准 |
| C03 | 正式創角要求 Persona＋實際 Luna；demo 可使用模擬通過；8787 正式與 8788 demo 端點不同 | 已授權的是獨立示範服務，正式門檻不變。必驗模式識別、資料隔離、提示、付費請求為零及不誤連正式服務；demo 通過不能寫正式驗證通過 |
| C04 | 子女姓名在出生時審核且接手不得改；一般姓名審核綁帳號並限 15 分鐘 | SPEC 沒有明示既有子女姓名審核如何關聯父母／接手帳號及其歷史政策版本。需由既有 source／測試證據釐清路徑；不得要求玩家改名，也不擅自把首次命名的時限套成全部子女到期失效。此處是資料契約驗證缺口，不宣布存在程式錯誤 |
| C05 | 真人查核能確認帳號擁有人，但固定手繪外貌不還原證件照片；法定性別可信欄位可能缺失 | 並不衝突。未知欄位待複查，不新增性別選單、不從自拍猜測、不預填正式男／女 |
| C06 | 可查看全部步驟，但正式入世必要條件必须由後端檢查 | 並不衝突。瀏覽入口不等於創角授權；需驗 UI 可查看且服務端拒絕繞過，不能只驗按鈕 disabled |
| C07 | AI 拒絕姓名、官方刪角／黑名單與申覆是不同流程 | 並不衝突。AI 只產生姓名審核；人工案件與處置稽核另驗，正式申覆管道 E04 不宣稱已開通 |
| C08 | 固定 gpt-5.6-luna 為產品要求；Persona／OpenAI 真實可用性未驗證 | 這是外部證據缺口，不判定模型無效或擅換供應商。程式 BOT 官方文件查證與契約修補仍須交件；真實測試保持 NOT RUN |
| C09 | SPEC／PERSONA_SETUP 的「已寫串接」及舊 ACCEPTANCE／截圖可能描述較早版本；主目錄正有未提交更新 | 文件存在、舊測試與候選圖皆不是本次最終整合證據；主窗口須把交件版本、實際命令、結果、截圖與檔案路徑對上。本總控沒有稽核 source，因此不把預期缺口定為已證實程式缺陷 |
| C10 | 新增 SPEC L77 使用「沿用父母姓名」，但 L24 是父母在出生時取定子女姓名、接手沿用子女既有姓名，L66 禁止接手改名 | 有文字歧義／衝突需主窗口核對：不能據 L77 把子女改成父母本人的姓名。本報告不自行修改 SPEC，驗收應保留「沿用父母所取的子女既有姓名」這個已有規則，請主窗口核對用詞 |
| C11 | SPEC L18 要求成年角色，L21／L66 的子女候選条件未明列成年資格或可信來源 | 屬驗收契約缺口：現有 source／資料是否保證成年仍未查證，不能宣稱成年資格已驗通，也不擅加生長／年齡系統或自行設定年齡數值 |

主窗口可繼續整合已授權的明確項目；C10 需核對規格用詞，C04、C11 需補具體資料／測試證據，不由總控增訂規則。E01–E04 仍限制正式服務完成宣稱。

## 本報告的實際讀取與未執行事項

| 類別 | 本回合實際操作 | 結果 |
| --- | --- | --- |
| LATTICE | `lattice_runtime_status({})`；`lattice_control_snapshot({decisions:{mode:"current",scope:"e8e9d77c-1c05-4864-ad3e-80152a9919a1",limit:20}})`；`lattice_control_snapshot({project_id:"e8e9d77c-1c05-4864-ad3e-80152a9919a1"})`；`lattice_task_status({task_ref:"82ad0247d26c64d2eee3fe6095111ba21fbcac11be3006a799149e6ae26d9fff"})` | READBACK_OK；這些是工具呼叫，不是遊戲測試 |
| 規則與規格 | `Get-Content -LiteralPath 'C:/Users/f7212/OneDrive/文件/遊戲開發/AGENTS.md' -Raw`；同方式讀 SPEC.md、PERSONA_SETUP.md、bots/roles.json；`Get-FileHash -Algorithm SHA256 -LiteralPath 'C:/Users/f7212/OneDrive/文件/遊戲開發/docs/registration/SPEC.md'` | 讀取命令 exit 0；SPEC 摘要如來源段 |
| 工作樹 | `Get-Location`；`rg --files -g AGENTS.md -g 'session-scope.md' -g '*registration*' -g '!node_modules' -g '!.git'`；`git status --short`；`Test-Path -LiteralPath 'C:/Users/f7212/.codex/worktrees/8e4f/遊戲開發/docs/registration/reports/session-scope.md'` | 初始 git status 無變更；此工作樹無對應搜尋檔案；報告路徑原先不存在。不能據此說主專案缺檔 |
| 跨窗口讀取 | `wait_threads` 四個既有分工，timeoutMs 0；`read_thread` 主窗口，turnLimit 2、includeOutputs false | READBACK_OK；分工當時仍進行，demo 測試結果僅 REPORTED |
| 產品／外部驗收 | Node、Godot、匯出包、真實 Persona、付費 Luna | NOT RUN（總控本回合） |
| 本次寫入與讀回 | 僅本工作樹 `docs/registration/reports/session-scope.md`；`Get-Content -LiteralPath 'C:/Users/f7212/.codex/worktrees/8e4f/遊戲開發/docs/registration/reports/session-scope.md' -Raw`、規則編號計數、`rg -n '9662f318\|定稿交付\|最新收件\|預備 77\|26/26\|C10\|C11\|本次寫入'`、`Get-FileHash -Algorithm SHA256`（對本報告）、`git status --short --untracked-files=all` | 定稿讀回 exit 0；24 項 S、5 項 D、9 項 E、8 項 F、11 項 C；審查拒絕 NOT RUN 與主窗口最終驗收歸屬皆存在；Git 僅此報告為 untracked。這是文件核對，不是產品測試通過 |

主窗口可沿 S01–S24、D01–D05，在 SESSION-ACCEPTANCE 對最終整合版本逐項填入自己的實際命令、結果和證據。外部阻塞 E01–E09、未來 F01–F08 及自動核准審查拒絕導致的原生整合 NOT RUN 分開保留。總控依目前來源定稿回報，不再等待／重新派工、不擴大施工、不宣告全 session passed。
