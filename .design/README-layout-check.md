# 视觉稿工具链

两个脚本：**出图** 和 **自检**。改完 `.design/ui-reference.html` 后按顺序跑。

```powershell
node .design/build-icons.mjs          # 1) 图标 -> SVG 雪碧图（幂等，可反复跑）
pwsh .design/build-shots.ps1          # 2) 出 4 张分组 PNG
# 3) 布局自检（见下）
```

---

## 1. 图标：`build-icons.mjs`

把 `icons/svg/` 里的 Lucide SVG 内联成雪碧图，写进 `ui-reference.html` 的 `<!--SPRITE:START-->` / `<!--SPRITE:END-->` 之间。

加图标：从 [lucide-static](https://www.npmjs.com/package/lucide-static) 拷对应 svg 到 `icons/svg/`，名字加进脚本里的 `ICONS` 数组，重跑。

## 2. 出图：`build-shots.ps1`

先量每组 `.stage` 的实际宽高，再按实测尺寸开窗口截图，输出 `ui-main.png` / `ui-history.png` / `ui-people.png` / `ui-calendar.png`。

## 3. 自检：`layout-check.js`

把脚本内联注入页面，用无头 Chrome 的 `--dump-dom` 回读 `<pre id="DIAG">` 的测量结果。能抓出格子溢出、列表被切、字体没加载、flex 静默压缩这些问题。

```powershell
$d = ".design"
$h = Get-Content "$d\ui-reference.html" -Raw -Encoding UTF8
$j = Get-Content "$d\layout-check.js"  -Raw -Encoding UTF8

# 注入前先自检：脚本注释里若含闭合标签字面量，HTML 会提前截断内联脚本
if ($j -match '</script|</body') { throw "layout-check.js 注释里含闭合标签字面量" }

$h.Replace('</body>', "<script>`n$j`n</script>`n</body>") |
    Set-Content "$d\_t.html" -Encoding UTF8 -NoNewline

$dom = & "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu `
    --hide-scrollbars --allow-file-access-from-files "--force-device-scale-factor=1" `
    "--window-size=2400,7000" --virtual-time-budget=12000 `
    --dump-dom "file:///E:/Projects/PoopedYet/.design/_t.html#all" 2>$null | Out-String

Remove-Item "$d\_t.html" -Force

# 取【最后一个】匹配：前面的都落在 script 源码里
$ms = [regex]::Matches($dom, '(?s)<pre id="DIAG">(.*?)</pre>')
$ms[$ms.Count-1].Groups[1].Value -replace '&lt;','<' -replace '&gt;','>' -replace '&amp;','&'
```

### 判定标准

| 指标 | 期望 |
|---|---|
| `SCREENS` / `SCREENS_NOT_LAID_OUT` | `15` / `0` |
| `SCREEN_OVERFLOW_COUNT` | `0` |
| `GRIDn` `vOverflow` / `hOverflow` | `0@-1` |
| `BROW_H_OVERFLOW` | `0@-1` |
| `AVATAR_GRID_V_OVERFLOW` / `CHART_BAR_OVERFLOW` | `0` |
| `LISTn` / `PAGEn` / `SHEETn` 的 `CLIPPED` / `SQUEEZED` | `false` |
| `PHONESn` | `RENDERED=true WRAPPED=false` |
| `FONT_SMILEY_LOADED` | `true` |
| `SPRITE` | `symbols=73 empty=0` |
| `H_OVERFLOW` | `false` |

## 4. 对比度自检：`contrast-check.js`

遍历所有带直接文本的元素，算出「有效前景色 / 有效背景色」，按 WCAG 2.1 AA 判定。
图标（非文本）单独按 3:1 统计。

```powershell
$d = ".design"
$h = Get-Content "$d\ui-reference.html" -Raw -Encoding UTF8
$c = Get-Content "$d\contrast-check.js" -Raw -Encoding UTF8
if ($c -match '</script|</body') { throw "注释里含闭合标签字面量" }

$h.Replace('</body>', "<script>`n$c`n</script>`n</body>") |
    Set-Content "$d\_a.html" -Encoding UTF8 -NoNewline

$dom = & "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu `
    --hide-scrollbars --allow-file-access-from-files "--force-device-scale-factor=1" `
    "--window-size=2600,7600" --virtual-time-budget=12000 `
    --dump-dom "file:///E:/Projects/PoopedYet/.design/_a.html#all" 2>$null | Out-String

Remove-Item "$d\_a.html" -Force
$ms = [regex]::Matches($dom, '(?s)<pre id="A11Y">(.*?)</pre>')
$ms[$ms.Count-1].Groups[1].Value -replace '&lt;','<' -replace '&gt;','>' -replace '&amp;','&'
```

### 判定标准

| 指标 | 期望 |
|---|---|
| `A11Y_FAIL_COUNT` | **`0`** |
| `A11Y_ICON_FAIL_COUNT` | **`0`** |
| `A11Y_DIM_OK_COUNT` | 当前 21（非本月日期 15 + 周末日期 6，有意降级） |

### 它算的是「有效色」，不是「声明色」

这四条不做，结论就是错的：

1. **背景要沿祖先链往上找**第一个不透明背景，不能只看元素自身。
2. **祖先链上的 `opacity` 会整体合成**，必须累乘后把文字色往背景色上混。
   选中格里的 `+N` 就是栽在这——声明白 85%，叠在焦糖底上实际只有 3.98:1。
3. **渐变背景取第一个色标**当近似值。主按钮的渐变浅端比深端差得多。
4. **大字判定**：`>= 24px`，或 `>= 18.66px 且 font-weight >= 700`，阈值降到 3:1。

### 有意降级怎么标记

给元素或其祖先加 `class="a11y-dim-ok"`，自检会归到「已声明降级」而不是失败。
非本月的日期就是这样处理的——否则每次跑检查都会被那 15 格淹没，真正的回归反而看不见。

---

## 踩过的坑（都真实发生过）

### 1. 内联脚本注释里不能出现 `</script>` 字面量
HTML 解析器在内联 script 中遇到该序列会**提前终止脚本**。脚本被截断后静默不执行，`<pre id="DIAG">` 里空空如也 —— 而判定函数因为匹配不到任何指标，会报「全部通过」。**假通过比报错更危险。**

### 2. 提取 `DIAG` 必须取最后一个匹配
script 源码里也含有 `<pre id="DIAG">` 这个字符串，取第一个会匹配到源码而不是渲染结果。

### 3. `--window-size=$w,$h` 在 PowerShell 里必须整体加引号
裸写时 PowerShell 把 `,` 解析成数组构造，Chrome 收到的是两个独立参数，于是**静默回退到默认窗口**（约 495×261），出的图全糊。正确写法：`"--window-size=$winW,$winH"`。

### 4. 量高度要量 `.stage`，不能量 `body`
`body` 有 `min-height:100vh`，量出来的是被视口撑开的高度。同一页在 `--window-size=…,3000` 和 `…,6200` 下会量出完全不同的「内容高度」。

### 5. 分组切换别用 CSS `:has()` / `:target`
在无头 Chrome 里行为不稳定，曾导致 4 个分组同时渲染，`.stage` 高度虚高到 4524（真实值 1311）。现在改成 JS 按 `location.hash` 显式设 `style.display`。

### 6. `.phones` 设 `flex-wrap:nowrap`
换行会让「一行放几台」变得不可预测，出图脚本也就没法按实测尺寸定窗口。

### 7. flex 子项溢出是「静默压缩」而不是「溢出」
`.scrollpage` 是 `display:flex; flex-direction:column`，子项默认 `flex-shrink:1` —— 内容超高时会被压扁，`scrollHeight` 仍然等于 `clientHeight`，`CLIPPED` 检查永远为 false。所以自检脚本额外算了「子项自然高度之和 `need`」，用 `SQUEEZED` 暴露这种情况。

### 8. 绝对定位元素找不到定位祖先会逃逸到 `.screen`
「编辑屙屎人」页的相机角标 `position:absolute; right:-4px; bottom:-4px`，因为没套 `.wrap`（`position:relative`），直接相对 `.screen` 定位，导致整屏多出 4px 溢出。**凡是绝对定位，先确认祖先链上有 `position:relative`。**

### 9. `String.replace` 的字符串替换会把 `$` 当特殊语法
`build-icons.mjs` 里注入雪碧图时若用字符串式替换，图标路径里一旦出现 `$&` / `$1` 就会被解释掉。改用函数式替换 `replace(re, () => ...)`。

### 10. 用 `String.Replace` 做批量改色时，短令牌会吃掉长令牌的前缀
`color:var(--brand)` 会把 `color:var(--brand-deep)` 改写成 `color:var(--brand-ink-deep)`。
用带右括号的正则 `color:var\(--brand\)` 就行了——`--brand-deep)` 里 `--brand` 后面是 `-` 不是 `)`。

**同一类问题**：批量替换必须**逐个校验锚点是否命中，不命中就报错**。
静默跳过一个替换，后果是"以为改完了"而实际没有，比直接报错危险得多。

### 11. 对比度不能靠眼睛判断
这套色板初版有 **355 处文本 + 50 处图标**不合格，肉眼看完全正常。
暖色调尤其容易骗人：米色底 + 中灰文字看着"柔和高级"，实测 2.76:1。
**任何颜色改动之后必须重跑 `contrast-check.js`。**

### 12. 自检脚本自己也会「双标」
`a11y-dim-ok` 这个降级标记，文本路径认了，**图标路径忘了认**。
后果：同一个降级格子里，数字被正确归到「已声明降级」，头像却被算成 4 处「不合格」。
自检工具内部两套判定标准，等于工具在骗自己。

**改自检脚本本身时，要拿一个已知的降级元素去验它两条路径行为一致。**

### 13. 用「刚好合适」的样例数据验证，等于没验证
日历网格写死 35 格，而样例月份是 2026 年 2 月（周日开头 + 28 天 = 34 格），正好 5 行。
于是这个 bug 藏了很久，实际 2026 年有 3 个月（3/8/11 月）需要 6 行、会各丢一星期。

**边界值要专门造一屏去盯**——第 ⑲ 屏画的就是 8 月，纯为了这个。

---

## 5. 设备端定位：`find_regions.py`

模拟器上做 UI 自动化时要 `adb shell input tap x y`，但 **Flutter 画在 canvas 上，
`uiautomator` 读不到界面结构**，只能猜坐标 —— 我猜错过好几次，试了四个位置全落空。

这个脚本用另一条路：**从截图里找特定颜色的连通区域，取包围盒反推元素位置**。

```powershell
$py = "<bundled python>"
adb exec-out screencap -p > $env:TEMP\screen.png
& $py .design\find_regions.py $env:TEMP\screen.png A85F29 FFFFFF FAF5EC
```

设计令牌的每个颜色都只用在少数几个元素上，所以颜色就是可靠的"锚点"：

| 颜色 | 出现在 |
|---|---|
| `#A85F29` brandFill | FAB / 完成 / 添加这条备注（禁用时是 40% 透明，找不到） |
| `#FFFFFF` surface | 时间卡 / 备注输入框 / 次要按钮 / 未选中的 chip |
| `#F7E5D2` brandSoft | 选中的 chip / 快捷备注 chip / 主线按钮 |
| `#FAF5EC` paper | 弹层底色、页面底色 |

实测精度到 1~2 逻辑像素。用白色区域一次就把时间卡（y 389–471）和
「重新打开」按钮（y 483–523）的位置定下来了，一次点中。

**注意**：`Opacity` 小于 1 的元素颜色会被混合，匹配不上 ——
这反而是个特性（可以据此判断按钮是不是禁用态）。
