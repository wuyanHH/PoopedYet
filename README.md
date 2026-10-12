# 屙了么 (PoopedYet)

一个记录拉屎时间的安卓 App。日历为主界面，支持多个"屙屎人"、多条带时刻的备注、以及中国法定节假日/调休显示。

英文名 **PoopedYet**（「Pooped yet?」=「屙了么？」，且 pooped 在口语里另有"累瘫了"的意思），包名 `com.poopedyet.app`。命名论证见 [docs/naming.md](docs/naming.md)。

## 目录

```
docs/
  environment.md       ★ 本机环境：Flutter 升级、镜像、SDK 补丁、Gradle 镜像
  review.md            ★ 自我审查：遗漏点、阻塞项、优化点
  tech-stack.md        技术栈 + 数据模型 + 记录状态机 + 16 页界面结构 + 打包方案
  naming.md            中英文名与包名的选择论证
  design-system.md     UI 设计规范（色板/对比度/字体/图标/日历单元格/页面清单）
.design/
  ui-reference.html    视觉稿源文件（浏览器打开，顶部导航可切 5 个分组）
  ui-main.png          A 组 · 记录主流程（月视图 / 周视图 / 记一次 / 待确认 / 详情）
  ui-history.png       B 组 · 历史与补录（时间线 / 搜索筛选 / 补录 / 空状态 / 首次打开）
  ui-people.png        C 组 · 设置 · 人员与备注（设置主页 / 人员管理 / 编辑 / 备注）
  ui-calendar.png      D 组 · 设置 · 日历与数据（节假日 / 统计 / 备份）
  ui-calnav.png        E 组 · 日历快速切换（年月选择 / 周选择 / 6 行月份）
  build-icons.mjs      Lucide 图标 -> SVG 雪碧图（幂等）
  build-shots.ps1      按分组渲染 PNG
  layout-check.js      布局自检：溢出 / 裁切 / flex 静默压缩
  contrast-check.js    ★ 对比度自检：WCAG 2.1 AA，文本 + 图标
  icons/svg/           用到的 73 个 Lucide 图标源文件（34 KB）
  fonts/smiley/        得意黑 Smiley Sans（SIL OFL）
  README-layout-check.md   工具链用法 + 踩过的坑
```

## 当前状态

### 已经有代码了（脚手架）

```
lib/
  main.dart
  src/
    theme/tokens.dart            设计令牌 ThemeExtension（与视觉稿同源）+ WCAG 对比度计算
    calendar/calendar_math.dart  日历日期数学（纯函数，零 Flutter 依赖）
    data/tables.dart             Drift 表定义
    data/database.dart           数据库 + ensureDefaultPooper + 索引
    data/database.g.dart         Drift 生成（3539 行，不入 lint）
test/
  theme/tokens_contrast_test.dart     对比度护栏（含"旧值必须失败"的回归断言）
  calendar/calendar_math_test.dart    2026 全年逐月 + 1900~2300 抽样
  data/database_test.dart             归档 / 默认唯一性 / 外键 restrict / 状态机
```

`flutter analyze` 零问题，`flutter test` **60 个全过**，`flutter build apk --release` 能出包。

三块基础设施里已经埋进了设计评审的结论：焦糖一色三分、日历行数按月份实算、
归档而非删除、`endUnknown` 不挡住新记录。每一条都有对应的失败测试守着。

环境怎么配的（Flutter 升级、镜像、SDK 补丁、Gradle 镜像）见 [docs/environment.md](docs/environment.md)。

### 还没做的

需求梳理 + 技术选型 + UI 规范 + 一轮自我审查已完成，视觉稿 **20 页**已出图。**暂未开始写代码。**

已锁定的决策：

- 技术栈 Flutter + Riverpod + Drift，日历自绘，节假日数据打包进 APK
- 图标全部用 **Lucide 矢量图标，禁止 emoji**（`lucide_icons_flutter`）
- 头像：内置图标头像 + 首字色块兜底，同时支持上传照片（96px 缩略图**存 BLOB 入库**）
- 月视图密度：最多 2 个徽标 + `+N`，按添加顺序取前 2 个
- 记录状态四分：**正在屙** / 待确认 / **未记结束** / 已完成 —— 「没有结束时间」不等于「进行中」
- 跨零点按 **`startedAt`** 归属
- 全部文字色与图标色通过 **WCAG 2.1 AA**（自动检测，0 处不合格）
- 备注输入是**多行文本域**，快捷备注 chip 点一下追加进文本域，提交后存为**一条带时刻的备注**
- 日历标题可点开**年月 / 周选择器**；日历行数按月份实算（5 或 6 行）

**写代码前必须定的 4 个问题已经全部定案**（分析过程在 [docs/review.md](docs/review.md)，结论在 [docs/design-system.md](docs/design-system.md)）：

| 问题 | 结论 |
|---|---|
| 全新安装没有任何屙屎人 | 静默自动建「我」+ 主页一次性提示条，不弹引导页 |
| 删人会连带删掉全部历史 | 删除 = **归档**；历史保留、仍计入日历与统计 |
| `isDefault` 缺唯一性约束 | 部分唯一索引 + 归档时自动转移默认 |
| 系统字体缩放到 200% | 日历格内**上限 1.3×**，另给「日历字号」独立三档 |

其中第 1 和第 3 条有个共同边界：**归档掉最后一个人 = 回到"一个都没有"**，
所以自动建档逻辑要抽成 `ensureDefaultPooper()`，首启和归档后都调，不能只写 `if (isFirstRun)`。

## 本机环境（已核实可直接出 APK）

| 项 | 版本 |
|---|---|
| Flutter | 3.41.5 stable |
| Dart | 3.11.3 |
| Android SDK | 36.1.0 (`E:\Development\AndroidSdk`) |
| JDK | 21.0.8 LTS |
| adb | 1.0.41 |

`flutter doctor` 输出：**No issues found**。

## 改视觉稿

```powershell
node .design/build-icons.mjs     # 改样式后重新内联图标（幂等，可反复跑）
pwsh .design/build-shots.ps1     # 重新出 5 张分组图
# 布局自检 + 对比度自检：改完必须跑，完整命令见 .design/README-layout-check.md
```

浏览器直接打开 `.design/ui-reference.html` 即可预览，顶部导航切换 4 个分组。
