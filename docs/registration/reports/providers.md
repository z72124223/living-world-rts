# 外部服務 provider 契約修復

日期：2026-09-06。程式 BOT `01a075c1-9719-7200-a5ea-b3ff4396f408` 的獨立工作樹交付；由主窗口 `01a074b8-04d3-7e80-a83d-6bf2e7995a78` 整合及最終逐項驗收。

## 範圍與來源

主目錄 `C:/Users/f7212/OneDrive/文件/遊戲開發` 僅唯讀。已讀 AGENTS.md、docs/registration/SPEC.md、PERSONA_SETUP.md、providers.mjs、完整 service.test.mjs 及 core/server/vault 所需入口。

工作樹 `C:/Users/f7212/.codex/worktrees/fb25/遊戲開發` 起始 Git 狀態乾淨；依授權複製必要未提交程式作基準。只有以下四檔屬修改／新增交付：

| 絕對路徑 | 修改範圍 |
| --- | --- |
| `C:/Users/f7212/.codex/worktrees/fb25/遊戲開發/registration-service/providers.mjs` | OpenAI 回應結構、Persona 資源綁定與欄位驗證、pending 建立連結 |
| `C:/Users/f7212/.codex/worktrees/fb25/遊戲開發/registration-service/tests/provider-contract.test.mjs` | 離線 HTTP 契約測試，不接真實服務 |
| `C:/Users/f7212/.codex/worktrees/fb25/遊戲開發/docs/registration/PERSONA_SETUP.md` | 官方契約及營運設定缺口補充 |
| `C:/Users/f7212/.codex/worktrees/fb25/遊戲開發/docs/registration/reports/providers.md` | 本報告 |

工作樹中的 core.mjs、server.mjs、vault.mjs、package.json、tests/service.test.mjs 是未改動的測試基準副本，**不列入交付覆蓋清單**。Godot、launcher、demo 均未修改；未安裝依賴、未提交、未推送、未合併、未部署。

providers.mjs 基準 SHA-256：`269416F6D7D0FEE6497DA5FD7AFF8AB7FED96F1098052543825E516DD4AC8A1D`。

## 缺陷與修復

1. OpenAI 舊解析把所有 output content 文字串接，可能忽略拒絕項或把多個訊息拼成核准 JSON；`null` 結果會出現原始 TypeError。現在只接受一個已完成的 assistant message 和一個 output_text，完整比對既有 schema 的必要欄位、型別與禁止額外欄位；取名的 explanation 也必須是字串。模型、費用上限與請求內容未變。[官方結構化回覆](https://developers.openai.com/api/docs/guides/structured-outputs)
2. Persona 原 create 只驗 inquiry ID、reuse 只驗 reference、resume 只驗 token。現在共同核對資源 type、ID、帳號 reference 與設定 template；pending create 正確帶入 session-token。[建立契約](https://docs.withpersona.com/api-reference/inquiries/create-an-inquiry)、[恢復契約](https://docs.withpersona.com/api-reference/inquiries/resume-an-inquiry)、[查詢契約](https://docs.withpersona.com/api-reference/inquiries/retrieve-an-inquiry)
3. verification 回傳的自身 ID/type 與 inquiry 關聯 type 原未驗證；證號可為空白／物件、id-class 可缺失、日期可無效而仍放行。現在錯配、缺必要欄位、錯型別、無效日期及多份通過政府證件留待複查。關聯超過既有 30 筆處理上限時留待複查，不再忽略尾端資料。[政府證件契約](https://docs.withpersona.com/api-reference/verifications/government-id-verifications/retrieve-a-government-id-verification)
4. 正式設定原可接受沙盒 key 搭配 production 字串；現在先檢查正式 key 前綴以防誤设，仍不能據此宣稱真實遠端驗證。[官方環境與 key 前綴](https://docs.withpersona.com/api-quickstart-tutorial)

官方 checks.requirement 是選填，並包含 `requires_retry`：已通過的 check 不必依賴該欄位；失敗且必要性未知或需重試則停止放行。官方自拍契約沒有保證直接提供所比對政府證件的 ID，本次未發明 metadata 欄位。多份通過政府證件可能來自合法重試，本版在篩選 checks 前計數並保守複查，需營運範本及供應商確認後再擴充。[自拍契約](https://docs.withpersona.com/api-reference/verifications/selfie-verifications/retrieve-a-selfie-verification)

## 實際驗證

執行環境：Windows PowerShell，Node `v24.19.0`，執行檔 `C:/Users/f7212/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe`。以下命令的 cwd 均為本工作樹。

```powershell
& 'C:/Users/f7212/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' --test --test-reporter=spec registration-service/tests/provider-contract.test.mjs
& 'C:/Users/f7212/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' --test --test-reporter=spec registration-service/tests/service.test.mjs
& 'C:/Users/f7212/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' --check registration-service/providers.mjs
```

| 執行階段 | 結果 |
| --- | --- |
| 修改前既有 service.test.mjs | 11/11 通過 |
| 修改前首輪新增契約測試 | 67 項中 26 通過、41 失敗；重現漏驗及 TypeError |
| 最終修復後新增契約測試 | 80/80 通過，退出碼 0 |
| 修復後未改的 service.test.mjs | 9/11 通過，退出碼 1；最後兩個縮略 provider 替身不符合完整契約，詳見下段 |
| 最終 providers.mjs 語法檢查 | 通過，退出碼 0 |
| 真實 Persona、沙盒／正式證件、付費 OpenAI | 未執行；fetch 在 provider 契約測試中全由測試回應取代 |
| Godot、全專案、部署驗證 | 未執行，超出本次分工 |

這些測試驗證程式如何處理供應商回應，不能證明真實實名、活體、模型存取權限、額度、付款或姓名語意審核成功。

## 主窗口整合注意事項

原 service.test.mjs 最後兩項目前失敗，不能宣稱全套測試通過。依檔案所有權要求，本 BOT 保留該測試不改，主窗口可補完整官方形狀後重跑：

- OpenAI fixture 的 output item 補 `type: 'message'`、`role: 'assistant'`、`status: 'completed'`。目前錯誤 `AI_INVALID_RESPONSE`。
- Persona fixture 使用明示的假正式形狀 key（例如 `persona_production_test_only`）；inquiry 補 `data.type: 'inquiry'`、`relationships['inquiry-template'].data: { type: 'inquiry-template', id: 'itmpl_test' }`；verification 補自身 ID（ver_id / ver_selfie）、對應 type，及 `relationships.inquiry.data.type: 'inquiry'`。目前錯誤 `IDENTITY_PROVIDER_NOT_CONFIGURED`；只改 key 仍不足，還必須補資源欄位。

不要刪除或放寬正式 provider 驗證來遷就舊替身。只整合上述四個交付檔，先比較主目錄最新內容，保留其他窗口修改。

## LATTICE 與外部阻塞

本 BOT 本回合 runtime_status 成功：receipt-only / NOT_STARTED，foreman replay VERIFIED；current 決策 revision 3，task `82ad0247d26c64d2eee3fe6095111ba21fbcac11be3006a799149e6ae26d9fff` 為 SUBMITTED / DRAFT。這是本窗口證據，不代表主窗口回報的 FOREMAN_REPLAY_CORRUPT / CONTROL_PRODUCT_STORE_REJECTED 已修復。未改 ledger、未新建或結案任務。

Persona 尚未申請，營運方正式組織／範本／金鑰與查核項目、地區證件支援、可信性別／證號、單證件自拍配對、保存／刪除及申覆設定均待營運確認。OpenAI 官方已列 Luna 的 Responses 與 structured outputs 支援，但玩家實際金鑰權限和付費成功未測。[Luna 官方模型頁](https://developers.openai.com/api/docs/models/gpt-5.6-luna)

政府死亡登記未接入，未推定任何 Persona inquiry 範本有此能力。未建立帳號、未索取或保存真實秘密、未測真實證件或付費 API。
