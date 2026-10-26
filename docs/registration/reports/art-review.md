# 登入／創角美術與介面獨立核對

核對日期：2026-09-06，素材與截圖指紋讀取時間為 17:15:55 +08:00。

本次結論：**已完成「讀取既有實機證據」的目視核對；未發現人物裁切、關鍵控制項嚴重遮擋或可見的外貌／性別選單。新 demo 核對待提供截圖；正式服務與本回合實機重跑均未執行。** 這不是使用者審美定版，也不是正式整體驗收通過。

- 核對窗口：`01a075c1-9b25-71b3-9830-d07bd0b238a1`（美術製作與核對）。
- 最終驗收窗口：`01a074b8-04d3-7e80-a83d-6bf2e7995a78`，host `local`。
- 唯讀來源根目錄：`C:/Users/f7212/OneDrive/文件/遊戲開發`。
- 唯一新增檔案：`C:/Users/f7212/.codex/worktrees/e43b/遊戲開發/docs/registration/reports/art-review.md`。
- 未複製或修改主目錄；未更動 UI、圖片、測試、規格或 LATTICE ledger；未生成圖片、安裝依賴、推送、合併、部署。

## 本回合規則與 LATTICE 證據

已讀 `C:/Users/f7212/OneDrive/文件/遊戲開發/AGENTS.md` 與 `C:/Users/f7212/OneDrive/文件/遊戲開發/docs/registration/SPEC.md`。

| 呼叫 | 本窗口實際結果 |
| --- | --- |
| `lattice_runtime_status({})` | 呼叫成功；`scope=receipt-only`、`status=NOT_STARTED`、foreman `replay_status=VERIFIED`。僅代表此回傳，不能當成遊戲或其他窗口服務已恢復。 |
| `lattice_control_snapshot({"decisions":{"mode":"current","scope":"e8e9d77c-1c05-4864-ad3e-80152a9919a1","limit":20}})` | 成功讀回 revision `3`、2 筆 current 決策、`truncated=false`；digest `8711affd71fbe6806b6bfc3f5a524f3d5646436a19171c9f09fb9fa0b54d674a`。 |
| `lattice_task_status({"task_ref":"82ad0247d26c64d2eee3fe6095111ba21fbcac11be3006a799149e6ae26d9fff"})` | `SUBMITTED / DRAFT`，failure 欄位為 null；未自行建立、更新或結案。 |

現行決策包含 `yiyu-art-creation-correction-20260906` 與 `yiyu-four-bots-project-placement-20260906`。主窗口本次訊息回報的 `FOREMAN_REPLAY_CORRUPT / CONTROL_PRODUCT_STORE_REJECTED` 是**主窗口回報**；本窗口未重現，但不能由本窗口成功宣稱主窗口已修復。

讀回的美術決策仍保留早期「創角圖片討論」範圍；最新直接派工及 SPEC 已明確進入原生介面實作與驗收。本核對依後者確定工作範圍，同時保留簡化 2D 手繪、外貌唯讀、性別依可信登記資料鎖定及首次傳送現代便服無物品等限制。未把 v01／v02 概念圖當作本次實機證據。

## 實際目視入口與證據性質

使用 `view_image` 直接逐張讀取以下 **19 張既有實機截圖及 3 張現有素材**，沒有啟動遊戲或重新截圖。

| 絕對目錄 | 本次目視的檔案 | 證據性質 |
| --- | --- | --- |
| `C:/Users/f7212/OneDrive/文件/遊戲開發/godot-client/registration/verification/success-final` | `01-login.png`、`02-account.png`、`03-creation-pending.png`、`04-identity.png`、`05-ai.png`、`06-creation-reviewed.png`、`07-policy.png`、`08-created.png`、`09-small-window.png` | 讀取既有實機證據；其中成功身分／AI／創角使用測試替身。 |
| `C:/Users/f7212/OneDrive/文件/遊戲開發/godot-client/registration/verification/unconfigured-final` | `01-login.png`、`02-account.png`、`03-creation-pending.png`、`04-identity.png`、`05-service-not-configured.png`、`09-small-window.png` | 讀取既有實機證據；服務未設定分支的測試資料。 |
| `C:/Users/f7212/OneDrive/文件/遊戲開發/godot-client/registration/verification/export-final` | `01-login.png`、`02-account.png`、`03-creation.png`、`04-small-window.png` | 讀取既有匯出包實機證據；畫面停在帳號／待查核創角，未證明正式服務成功。 |
| `C:/Users/f7212/OneDrive/文件/遊戲開發/godot-client/registration/assets` | `arrival-male.png`、`arrival-female.png`、`creation-background.png` | 本回合讀取的現有 PNG 素材，不是動畫、現場執行證據或新的使用者核准。 |

一般截圖為 1280×720，三張 small-window 截圖為 960×540。圖檔最後修改時間分別落在 2026-09-06 08:37:51–08:37:56 UTC（success）、08:47:42–08:47:44 UTC（unconfigured）、08:43:47–08:43:48 UTC（export）。檔案時間僅供來源辨識，不代替執行證據。

另讀三份既有報告：success-final 與 unconfigured-final 的 `registration-report.json`、export-final 的 `bundle-report.json`。三者原文皆有 `passed=true`、`external_services_called=false`；success 明載 `fixture=success` 及 fixture government sex／backend fixture 檢查。這些是**既有報告記載**，不是本回合測試結果。

## 對照 SPEC 的目視結果

| 核對項目 | 本回合目視結果與限制 |
| --- | --- |
| 簡化 2D 手繪人物 | 男女素材皆為明確輪廓、少量陰影、低彩度色塊的固定手繪全身人物；創角截圖中的人物外觀與現有素材相符。未見寫實真人、精細 3D 玩家或命中水墨特效。此為視覺一致性，未驗證可重用動畫。 |
| 洞窟堡壘氣氛 | 創角背景可見巨大岩壁、洞中木石聚落、暖燈與洞口冷光／遠方龍影，且素材本身沒有假按鈕或假驗證狀態。登入背景與人物預覽分開，背景風格不拿來取代人物風格。登入前景的示意風險見下節。 |
| 繁體中文 | 可見表單、提示、命名規範與結果主要為繁中；OpenAI、Persona、模型名與鍵名保留正式原名。未見阻礙閱讀的亂碼、缺字方框或大段英文介面。960×540 輔助文字較小、淺，但本次截圖未見裁切或重疊；未進行裝置可讀性或對比值量測。 |
| 現代衣服、無初始物品 | 現有男女素材及其創角預覽皆為青灰外套、淺色上衣、深色長褲、普通鞋；雙手空，未見背包、武器、盔甲、食物、手機或飾物。登入場景配角不能當成這項的玩家樣品。 |
| 外貌不可選 | 各創角頁只見姓名、入世方式與費用同意等控制項；有「外貌不可調整」文字，未見髮型、髮色、膚色、臉型、外貌預設或隨機外貌按鈕。靜態截圖不能證明隱藏控制或後端防竄改不存在。 |
| 登記性別不可選 | 待查核畫面顯示「待實名確認」，男性預覽下方標「角色示意・等待實名查核」，並未宣稱已確定男性。success 的後續頁顯示女及相符女性固定預覽，沒有性別下拉或男女切換。成功分支來自測試替身，不能證明 Persona 已提供可信欄位。 |
| 人物完整與主要介面遮擋 | 男女頭、手與鞋完整落在預覽框內；960×540 亦未裁切。表單按鈕、底部返回、狀態提示仍在畫面內。命名規範彈窗遮住背後部分人物屬正常模態遮罩，彈窗自身文字與兩個按鈕完整，不能當成角色裁切缺陷。 |
| 狀態真實與示意標記 | success／unconfigured 表單頂部可見「實機測試資料｜非真實身分／非付費 AI 查核」，success 姓名結果另示未呼叫外部服務；未設定畫面保留尚未驗證與營運方尚未設定提示。export 創角仍是待查核／待連線、入世按鈕呈禁用外觀，沒有假通過。禁用行為本回合未操作驗證。 |

## 需主窗口保留的兩項事項

1. **登入背景的角色示意風險，非已確定的創角違規。** 三份 `01-login.png` 的前景仍有較寫實的背包旅人，與固定手繪空手初始玩家不同。目前該圖用途是登入場景，而 SPEC 明確把洞窟圖限定為場景氣氛，因此不把場景配角直接判成初始玩家違規。新 demo 或對使用者的交付說明不得把這些人稱為已核准主人物或首次傳送裝備；若後續真要把他們當成玩家展示，須改用現行人物素材，不能沿用該背包形象。
2. **畫面覆蓋仍有缺口。** 本組資料只有女性測試替身通過查核後的畫面；男性是待查核「角色示意」，匯出包也沒有男／女查核完成兩條結果。新 demo 尚未提供，故不能將此報告套用到新版本，亦不能宣稱男性登記鎖定、完整雙性別流程、小視窗命名彈窗或新 demo 已驗收。下一次優先讀取新 demo 的男女鎖定創角／結果、未設定與小視窗彈窗截圖，再追加到本報告；由主窗口最終驗收。

## 本回合方法、實際命令與結果

下列 PowerShell 來源讀取以主目錄為 cwd；Git 狀態與寫檔在自己的工作樹執行。

```powershell
Get-Content -LiteralPath 'C:/Users/f7212/OneDrive/文件/遊戲開發/AGENTS.md','C:/Users/f7212/OneDrive/文件/遊戲開發/docs/registration/SPEC.md'
rg --files -g AGENTS.md -g '*art-review*' -g '!.git' -g '!node_modules'
git status --short
rg --files godot-client/registration/verification/success-final godot-client/registration/verification/unconfigured-final godot-client/registration/verification/export-final godot-client/registration/assets
Get-Content -LiteralPath 'godot-client/registration/verification/success-final/registration-report.json','godot-client/registration/verification/unconfigured-final/registration-report.json','godot-client/registration/verification/export-final/bundle-report.json'
Get-Location
Test-Path -LiteralPath 'docs/registration/reports/art-review.md'
git status --short --untracked-files=all
git diff --no-index --check -- NUL docs/registration/reports/art-review.md
```

圖片讀取為逐檔 `view_image({path: "完整絕對路徑"})`，清單已完整列於上表。另用 PowerShell `Get-ChildItem -File -Filter '*.png'`、`Get-Item`、`[System.IO.File]::ReadAllBytes` 讀 PNG 寬高與時間，並對每張圖執行 `Get-FileHash -LiteralPath $artEvidenceFile.FullName -Algorithm SHA256`。這是檔案辨識，沒有生成或重編碼圖片。

- 本回合成功：LATTICE 三個唯讀呼叫、規則與報告讀取、22 張圖片目視、檔案尺寸與 SHA-256 讀取。新增報告前 Git 工作樹乾淨，目標報告不存在。
- 本回合美術失敗：未發現可直接判定的重大遮擋或創角美術規則違反；保留上列示意風險與證據缺口，沒有給正式整體 `passed=true`。
- 未執行（NOT RUN）：Godot／匯出執行檔重跑、新 demo、互動操作、後端防竄改、真人證件／Persona、付費 OpenAI API、可重用動畫與效能測試。
- 寫入後範圍核對：`git status --short --untracked-files=all` 只列本報告。`git diff --no-index --check` 結束碼為 1（與空檔比較存在新檔差異），沒有空白錯誤診斷；只出現工作樹 LF 將轉 CRLF 的提示。這不是遊戲測試。

## 來源指紋

以下 SHA-256 為本回合直接讀取，供後續確認是否已換圖；單純同名檔案不足以沿用核對。

| 來源（上述主目錄下） | SHA-256 |
| --- | --- |
| `godot-client/registration/assets/arrival-male.png`（1024×1536） | `3adddba095f223c11fb4bc2aebb6af7a0ba903f7daa94696998bd62fcce279b7` |
| `godot-client/registration/assets/arrival-female.png`（1023×1537） | `c8af629b779b1c24e6ab1935f21cb15708a74bb5a1be346425879e51d75b0318` |
| `godot-client/registration/assets/creation-background.png`（1672×941） | `ea662ad5d7e52a8086f7b9b595cee0a107cb9ccec516508498dc099284efd04a` |
| 三組 `01-login.png`（同內容） | `76dc150f6fa38c91041b3341eb39e7b467c0df1b6124b977c94fdbb1fe5cdf90` |
| `success-final/06-creation-reviewed.png` | `e46030b932f792c69c8fbf4af54c01567f45dc553985ac42912196889a05eff5` |
| `success-final/07-policy.png` | `87972de6fb17869b4574c802fc3ce65c6e8fc7ac4d053998dcd1dd7af281ffe7` |
| `success-final/08-created.png` | `4cbc55555f192d688b1e81989daf142404e7ac81800b8bef63909d1569882d1b` |
| `success-final/09-small-window.png` | `eee583c0254ef2ff72025fe33f9b7f3c0c467bd7d836b7b8b9b76b4ca75a9f3b` |
| `unconfigured-final/05-service-not-configured.png` | `736ff0f149cd887837e7481fd08d56bf7a0549f23da5f7d7514d8f04d0826c07` |
| `unconfigured-final/09-small-window.png` | `962db88d1ff3fe3522857e7d221656f7b83baba44adf2bae42be7f1ccdbd4992` |
| `export-final/03-creation.png` | `db243f9764e5e39e3f954437380276a2f4fb04d636643207a319dbf4b09475f4` |
| `export-final/04-small-window.png` | `7246fac03d5ff8da0b5c32631c4f349209b61764b071c7d8ea0e4079f6db378f` |

截圖指紋列的 success-final／unconfigured-final／export-final 皆位於 `C:/Users/f7212/OneDrive/文件/遊戲開發/godot-client/registration/verification/`，不是本工作樹的新產物。
