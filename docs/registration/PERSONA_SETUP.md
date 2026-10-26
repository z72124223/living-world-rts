# 實名驗證啟用：營運方設定

2026-09-06 已知狀態：使用者尚未申請 Persona。正式查核未執行；程式不預填任何營運方秘密。

## 申請與供應商確認

1. 營運方自行申請 [Persona 帳號](https://withpersona.com/)。正式環境須與供應商開通；測試環境金鑰不能當正式實名查核。[Persona 金鑰文件](https://docs.withpersona.com/api-keys)
2. 明確指定營運國家／地區與需要的國民身分證種類。確認供應商可取得可信的 `identification-number`、`country-code`、`id-class` 與政府證件 `sex`。目前不能以玩家自行填寫或自拍推定欄位代替。
3. 建立正式 inquiry template：要求有效政府證件、自拍與證件本人比對（`selfie_id_comparison`）、活體（`selfie_liveness_detection`）。所有必要查核通過才把 inquiry 設為 `approved`；`completed` 仍不足以放行。若缺少欄位或支援，留在人工複查，不擅自把未知性別映射成男／女。
4. 設定符合營運地需求的告知同意、資料保存與刪除、申覆窗口、合法調取程序。此階段需營運方與供應商確認，不以遊戲 UI 文案替代正式文件。
5. 建立只具必要 inquiry 建立／讀取／恢復、verification 讀取權限的營運金鑰。證件原件與私有查核參照不能分享給其他玩家。

## 本機設定與測試

在受信任的營運電腦，用 PowerShell 執行 `registration-service/設定實名服務.ps1`。它以隱藏輸入讀取金鑰並加密寫入 `%LOCALAPPDATA%/Yiyu/registration/persona.encrypted`。不要把金鑰、證件照片或原始證號貼到 AI 對話、Git 或命令參數。

設定後重新啟動本機帳號服務。介面「已設定」只表示已提供設定，**不是供應商查核驗收通過**。從遊戲帳號開始 inquiry，預建 inquiry 的 `reference-id` 綁定私有 account ID。遊戲開啟 Persona 託管頁，玩家在該頁自行提交證件與本人查核，回遊戲按「查詢查核結果」。後端重新從 Persona 取得結果；不信任頁面跳轉、URL 參數或玩家提交的 success 狀態。

正式啟用前，以供應商核准的測試流程檢查：正常證件與本人通過、自拍不匹配、活體失敗、證件過期、缺少法定性別、inquiry 尚待複查、重複證件、被封鎖證件、回呼 reference 不符、網路中斷與到期恢復。驗證 sandbox 與 production 設定隔離。測試者自行在供應商頁操作，不收集其秘密到本文件。

政府死亡資料並未接入。若要要求「政府已登記死亡就不得註冊」的直接資料查詢，另須合法授權與可信資料服務；目前只做有效證件及本人活體查核，不可對外宣稱已查到政府死亡名單。

## 已採用的官方介面

- [預建 inquiry 的 Hosted Flow](https://docs.withpersona.com/tutorial-hosted-flow-unique-api)：服務端建立後開啟託管驗證頁，綁定 reference-id。
- [政府證件 verification](https://docs.withpersona.com/api-reference/verifications/government-id-verifications/retrieve-a-government-id-verification)：讀取可信證件欄位，不信任 inquiry 的預填欄位。
- [自拍 verification](https://docs.withpersona.com/api-reference/verifications/selfie-verifications/retrieve-a-selfie-verification)：查核本人比對與活體結果。
- [OpenAI Luna 模型](https://developers.openai.com/api/docs/models/gpt-5.6-luna)、[結構化回覆](https://developers.openai.com/api/docs/guides/structured-outputs)：固定模型與 JSON schema，用真實呼叫確認可用性。

Persona API 版本鎖定 `2025-12-08`。目前 provider 合約測試使用官方形狀的替身回覆；沒有供應商帳號的這一回合未做真正的 Persona 或 OpenAI 付費請求。

## 2026-09-06 provider 契約補充

以下為程式 BOT 工作樹的修復交付，仍由主窗口整合及最終驗收。離線測試結果與整合注意事項見 [providers 報告](reports/providers.md)。

- 正式服務設定現在檢查 `persona_production_` 金鑰前綴，拒絕把沙盒金鑰搭配 `environment=production` 當成正式設定。這只是防止設定錯誤；前綴、`configured=true` 與範本 ID 都不能證明遠端權限有效。[官方 quickstart](https://docs.withpersona.com/api-quickstart-tutorial)
- 建立、重用、恢復、查詢均核對 inquiry 的資源種類、ID、私有帳號 `reference-id` 和設定的 `inquiry-template` 關聯。營運方切換範本時，舊範本 inquiry 會停止放行，需規劃重新驗證；不能移除比對來遷移。建立若直接回 `pending`，需使用回傳的 `session-token`；缺少權杖就報錯。[建立](https://docs.withpersona.com/api-reference/inquiries/create-an-inquiry)、[恢復](https://docs.withpersona.com/api-reference/inquiries/resume-an-inquiry)
- 官方政府證件欄位可缺少或為 null，不能據此保證所有營運地／證件皆提供登記性別與穩定證號。此程式要求非空字串證號、證件種類、兩碼大寫國碼、M/F；有提供的到期日必須是有效且未過期的日期。沒有到期日仍依賴供應商的有效證件查核與營運方範本配置，不能解讀為程式已證明該證件永不過期。[政府證件契約](https://docs.withpersona.com/api-reference/verifications/government-id-verifications/retrieve-a-government-id-verification)
- `checks.requirement` 是選填；省略但 `status=passed` 可接受，省略且查核失敗時不能自行當成非必要。自拍仍要求比對及活體各自有明確通過證據。公開自拍資料契約未保證可取得「本次自拍實際比對哪個政府證件 verification」的直接關聯；本版對多份通過的政府證件留待複查，單一證件配對及範本重試行為仍需供應商實測。[自拍契約](https://docs.withpersona.com/api-reference/verifications/selfie-verifications/retrieve-a-selfie-verification)
- OpenAI 官方文件確認 Luna 支援 Responses、結構化回覆與 `reasoning.effort=none`，不代表任一玩家金鑰有權限、額度或付款能力。正式成功仍須取得玩家費用同意後，以固定模型實際呼叫。[Luna](https://developers.openai.com/api/docs/models/gpt-5.6-luna)、[結構化回覆與拒絕處理](https://developers.openai.com/api/docs/guides/structured-outputs)

Persona 尚未申請；正式組織、金鑰最小權限、範本查核項目／核准工作流程、地區支援、資料保存與申覆窗口都由營運方確認。本版未新增政府死亡登記來源，也不推定 Persona 的任意 inquiry 範本具備該能力。
