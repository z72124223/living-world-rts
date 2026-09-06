# 獨立創角 demo 服務交付

日期：2026-09-06。此報告只涵蓋開發測試服務；整個 SESSION 由統籌窗口 `01a074b8-04d3-7e80-a83d-6bf2e7995a78` 最終驗證。

## 範圍與啟動

- 新增 `registration-service/demo.mjs`、`registration-service/tests/demo.test.mjs` 及本報告。
- 在已有同版 `core.mjs`、`providers.mjs`、`vault.mjs` 的專案根目錄執行 `node registration-service/demo.mjs`，只監聽 **127.0.0.1:8788**。正式 `server.mjs` 及 8787 不受影響。
- 匯出 `createDemoService()` 與 `createDemoHTTP(service)`，供整合測試使用 `server.listen(0, '127.0.0.1')`。完成後先關閉 HTTP server，再呼叫 `service.close()`。
- 每次 start 建立一份 `Registration({path: ':memory:'})` 與隨機的記憶體加密金鑰，不讀環境中的正式資料路徑、Persona 設定或 OpenAI 金鑰。不載入正式 server、不呼叫 `localVault`，不呼叫 Persona／OpenAI，也不收費。
- demo 在內部使用固定模擬字串銜接既有核心金鑰關卡；不是可用的 API 金鑰，不接受使用者提交金鑰。帳號、權杖摘要、姓名審核、子女與角色都只在該次記憶體資料庫中。

## 整合接口

所有回應（包含錯誤）有頂層 `mode: "demo"` 及 `X-Yiyu-Mode: demo`。業務操作需要 `X-Yiyu-Client: native-v1`；POST 需要 JSON 物件與 `Content-Type: application/json`。除 start 與 health 外需要 `Authorization: Bearer <token>`，不接受省略 Bearer 的權杖。Host 必須精確等於 `127.0.0.1:<實際埠>`；出現 Origin 或 Sec-Fetch-Site 一律拒絕，包含空字串。沒有瀏覽器 CORS 放行。

| 方法與路徑 | JSON 輸入／效果 | 成功回應主要欄位 |
| --- | --- | --- |
| GET `/health` | 可不帶登入／client header，仍驗 Host 與來源 | `service: "yiyu-registration-demo"`、`mode: "demo"`、`personaConfigured: false`、`openaiConnected: false`、`chargeable: false`、`dataStorage: "memory"` |
| POST `/v1/demo/start` | `{}`。未帶 Bearer 開始新測試；帶合法 Bearer 重開該次測試 | `token`、`state`；重開後須替換客戶端舊 token |
| POST `/v1/demo/identity` | `{ "consent": true }`，明確啟用固定虛構查核 | `state` |
| POST `/v1/demo/ai` | `{ "consent": true, "dailyMax": 20 }`；dailyMax 可省略，預設 20、範圍 1–100 | `state` |
| GET `/v1/me` | 目前測試狀態 | `state` |
| POST `/v1/names/suggest` | `{ "surname": "", "consent": true }`；可指定一或二個漢字的姓 | `suggestion`、`state` |
| POST `/v1/names/review` | `{ "surname": "林", "given": "知遠", "consent": true }` | `approved`、`reason`、`state` |
| POST `/v1/characters` | `{ "entry": "arrival", "surname": "林", "given": "知遠", "policy": "yiyu-names-2026-09-v1", "acceptPolicy": true }`；投胎改為 `entry: "reincarnation"` | `state` |
| POST `/v1/ai/remove` | `{}`；移除模擬 AI 與姓名審核 | `state` |
| POST `/v1/logout` | `{}`；結束並丟棄此測試 run | `ok: true` |

不提供正式 register/login、identity/start、identity/check、ai/connect 或任何正式資料清理端點。欄位採白名單，金鑰、性別、外貌、初始物品或指定子女欄位會被拒絕且不回顯值。

`state` 保留核心帳號、identity、sex、aiConnected、dailyMax、callsToday、review、availableChildren、character、policy 等欄位。初始為 `identity: "unverified"`、`sex: null`、`aiConnected: false`；明確啟用模擬查核後才是 `identity: "verified"`、`sex: "F"`，啟用模擬 AI 後才是 `aiConnected: true`。**這些只表示 demo 流程關卡**。`state.mode` 固定為 `demo`，`identityServiceConfigured` 及 `hasKey` 永遠為 false，並附：

```json
{
  "demo": {
    "notice": "開發測試：僅虛構記憶體資料；模擬查核與 AI，未連接 Persona／OpenAI，不收費。",
    "dataStorage": "memory",
    "fictionalAccount": true,
    "fixedRegisteredSex": "F",
    "identitySimulated": false,
    "aiSimulated": false,
    "realIdentityVerified": false,
    "realAIConnected": false,
    "chargeable": false,
    "nameReview": "deterministic-fixture"
  }
}
```

介面應顯示「模擬查核／模擬 AI」。`identitySimulated` 與 `aiSimulated` 隨核心狀態改變，其餘上述安全標記不變。model 沿用核心 `gpt-5.6-luna` 識別，但完全沒有模型推理或外部費用。

## 核心約束與虛構資料

- 每次建立隨機 `demo_…` 測試帳號，固定虛構登記性別 F；沒有性別與外貌選擇。首次傳送外貌由核心固定為 `arrival-female`，不增加物品或背景選項。
- 沿用既有核心實名、AI 前置、每天請求數量、15 分鐘 AI／姓名審核時效、精確姓名與政策核對、單帳號單角色及 SQLite 交易內隨機占用。
- 姓名建議固定為林知遠，指定複姓則保留該姓。建議不等於審核；仍須明確執行審核。格式由核心限制姓與名各一至兩個漢字。
- 審核為明確的固定測試替身；包含「廣告、皇帝、客服、管理、白痴」的姓名作拒絕反例，其他符合格式姓名可測試通過路徑。不代表真實 AI 語意判斷，拒絕不會封禁／刪角。
- 每個 run 有兩位虛構合格公開女孩：`demo-public-lin`（林知遠）與 `demo-public-ouyang`（歐陽映禾），姓名已由虛構父母取定並標記測試審核通過。伺服器隨機選擇並沿用既有姓名。
- 另有保留女孩、標記公開但仍有 reserved_for 的女孩、公開男孩、已占用女孩及未審核女孩等五個反例；不列入固定 F 測試帳號的合格池。
- 重開成功後只關閉同 Bearer 所屬的舊記憶體資料庫，舊 token 失效；其他測試 run 保留。start 不接受任何 path、帳號、金鑰或 reset-target。32 個同時記憶體 run 上限、12 小時權杖時效、每來源每分鐘 90 次業務請求限制。

## 當回合驗證

- Node.js `v24.16.0`；`node --check registration-service/demo.mjs` 通過。
- 以 Node `--permission --allow-fs-read=<此工作樹的 registration-service>`，**未允許 fs.write 或 child process，也未允許正式資料目錄讀取**，執行首次傳送 → 重開（確認舊 token 失效）→ 隨機投胎，全部通過。該程序以拋錯替身攔截全域 fetch，實際外部供應商呼叫數 **0**。這是實際核心流程的隔離執行證據。
- HTTP focused tests：根窗口實際執行 `node --test registration-service/tests/demo.test.mjs`，**15 / 15 通過、0 失敗、0 跳過、exit 0**，duration 1802.2912 ms。包含明確同意、固定性別、姓名格式與精確審核、政策與重複創角、子女排除與無候選、15 分鐘審核／AI 過期、重開與登出、Host／來源／認證／JSON 大小與每日限制。完整 HTTP flow 中攔截 fetch 及 Persona／OpenAI 原型呼叫為 0；臨時假正式目錄的哨兵檔案保持不變。所有服務均用隨機埠並關閉。
- 獨立唯讀子代理另以兩個隨機埠執行 35 項斷言，涵蓋空 Origin／Sec-Fetch-Site、只有單一合格子女時沿用父母姓名、並發重開只成功一次、會話過期拒絕與過期 run 清理；未發現可重現缺陷。這是另外的臨時驗證，不冒充已納入上述 15 項測試檔。
- 從原目錄唯讀複製的七個基底檔案，複製後 SHA-256 全數相同；只將三個新交付檔案納入提交。未修改共用原目錄、正式服務、Godot、launcher 或產品規則，未推送或部署。

整合所需基底 SHA-256（避免在較舊工作樹直接套用）：

| 檔案 | SHA-256 |
| --- | --- |
| `core.mjs` | `9cf982cb34e5e56854116f67ee0d231917ab406560570a4484b4d4a1a9eb0a70` |
| `providers.mjs` | `269416f6d7d0fee6497da5fd7aff8ab7fed96f1098052543825e516dd4ac8a1d` |
| `vault.mjs` | `4e7db9d3ea0f95107849ffc5e6f23c12fc5fe5e7a29b09cb623d3fd9a75bdb7c` |

## LATTICE 與未完成項

本回合原生 `lattice_runtime_status` 回傳 `scope: receipt-only`、`status: NOT_STARTED`、foreman `replay_status: VERIFIED`、`degraded_code: null`、generation 4；先前 `FOREMAN_REPLAY_CORRUPT` 本回合未重現，沒有繞過 ledger 驗證。

統籌窗口另回報其當回合仍為 `FOREMAN_REPLAY_CORRUPT / CONTROL_PRODUCT_STORE_REJECTED`。上述成功讀回只代表此 demo 開發窗口的工具結果，不代表統籌窗口已恢復。

既有實作 task `82ad0247d26c64d2eee3fe6095111ba21fbcac11be3006a799149e6ae26d9fff` 回讀為 `SUBMITTED / DRAFT`，`failure_code: null`。現行決策讀取 revision 3，digest `8711affd71fbe6806b6bfc3f5a524f3d5646436a19171c9f09fb9fa0b54d674a`，依最新委派僅完成獨立測試服務，不另造任務完成狀態。

未執行：真實 Persona 身分查核、真實 OpenAI／付費模型連線、Godot 原生畫面、launcher 啟動、正式 8788 長駐整合驗收、整個 SESSION 的最終驗證。demo 通過不能替代以上證據。請統籌窗口整合三個新檔後進行最終驗證。
