# MakeHuman 人體基底來源

只保存圖形資產及其授權文件；未複製或執行 MakeHuman 應用程式碼。

- 上游：[makehumancommunity/makehuman](https://github.com/makehumancommunity/makehuman/tree/a8bc2d54ff0ac92e78ff71431b1023eda42bf482)
- 固定提交：`a8bc2d54ff0ac92e78ff71431b1023eda42bf482`
- 取得日期：2026-09-06。
- 資產授權：[CC0 1.0 Universal](LICENSE.ASSETS.md)，分類說明見 [LICENSE.md](LICENSE.md)。`base.obj` 本身及骨架／權重資料也保留上游作者與授權資訊。

| 此目錄檔案 | 上游相對路徑 |
|---|---|
| `base.obj` | `makehuman/data/3dobjs/base.obj` |
| `default.mhskel` | `makehuman/data/rigs/default.mhskel` |
| `default_weights.mhw` | `makehuman/data/rigs/default_weights.mhw` |
| `asian-male-young.target` | `makehuman/data/targets/macrodetails/asian-male-young.target` |
| `universal-male-young-averagemuscle-averageweight.target` | `makehuman/data/targets/macrodetails/universal-male-young-averagemuscle-averageweight.target` |
| `universal-male-young-maxmuscle-averageweight.target` | `makehuman/data/targets/macrodetails/universal-male-young-maxmuscle-averageweight.target` |
| `asian-female-young.target` | `makehuman/data/targets/macrodetails/asian-female-young.target` |
| `universal-female-young-averagemuscle-averageweight.target` | `makehuman/data/targets/macrodetails/universal-female-young-averagemuscle-averageweight.target` |
| `universal-female-young-maxmuscle-averageweight.target` | `makehuman/data/targets/macrodetails/universal-female-young-maxmuscle-averageweight.target` |
| `LICENSE.md`、`LICENSE.ASSETS.md` | 上游根目錄的同名文件 |

由本專案腳本組合成年男性與肌肉形態、調整尺度及頭部比例、移除輔助幾何、整理骨架及權重，另製作髮髻、簡化眼睛與像素呈現。底模不宣稱為本專案原創雕塑。來源檔案雜湊見 [v02 建模報告](../../samples/body-pixel-v02/build-report.json)。

女性輕甲樣品改用女性形態及 25% 肌肉目標，保留完整人體和姿勢骨架；另製作風格化頭部、髮型與衣甲。來源雜湊及具體修改見[女性樣品報告](../../samples/female-light-armour-v01/build-report.json)。
