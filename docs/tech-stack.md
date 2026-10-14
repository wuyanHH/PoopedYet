# 屙了么 · 技术栈与架构建议

> 本文回答两个问题：**用什么做**、**怎么拆**。UI 规范见 [design-system.md](design-system.md)。

---

## 0. 结论先行

| 决策点 | 推荐 | 一句话理由 |
|---|---|---|
| 框架 | **Flutter 3.41 / Dart 3.11** | 本机 `flutter doctor` 已零问题；日历这种高度定制 UI 用 Flutter 最省事 |
| 状态管理 | **Riverpod 3** | 编译期安全，日历聚合数据易缓存、易测 |
| 本地存储 | **Drift（SQLite）** | 日历要"按天 × 按人 GROUP BY COUNT"，SQL 最自然 |
| 轻量配置 | **shared_preferences** | 默认屙屎人、每周起始日这类单值 |
| 日历 | **自绘 GridView**（不用 table_calendar） | 格子里要塞头像徽标 + 休/班角标，改造现成库比自绘更麻烦 |
| 图标 | **`lucide_icons_flutter` 3.1.25** | Lucide ISC 协议可商用；2px 圆头描边和手帐调性最搭 |
| 节假日数据 | **打包 JSON**（holiday-cn） | 完全离线，不依赖第三方 API 存活 |
| 目标产物 | **APK，arm64 + armeabi-v7a 分包** | 单包体积从 ~22MB 降到 ~9MB |

**备选方案与放弃理由**

- **Kotlin + Jetpack Compose**：原生、包体最小、系统能力最全。但如果只有你一个人写，同样的 UI 样板量大约是 Flutter 的 1.5–2 倍，改一版样式要等 Gradle 编译。适合"我本来就写 Android"的情况。
- **React Native / Expo**：JS 生态熟悉，Expo EAS 能云打包。缺点是自定义绘制（日历格子里的徽标布局）要走 native 桥，包体也不占优。
- **Tauri v2 mobile**：包体可以做到 3–5MB，但移动端插件生态还在早期，`image_picker` 这类基础能力需要自己接。
- **uni-app**：只有在"以后还想出微信小程序"时才值得考虑。

> 本机环境已核实：Flutter 3.41.5 stable、Dart 3.11.3、Android SDK 36.1.0、JDK 21、adb 1.0.41，`ANDROID_HOME=E:\Development\AndroidSdk`。**可以直接出 APK，不需要额外装环境。**

---

## 1. 数据模型

四张业务表 + 一张只读的节假日表。

```dart
// 屙屎人
Pooper {
  id          TEXT PK
  name        TEXT NOT NULL
  iconKey     TEXT?          // 内置 Lucide 图标名，如 'dog'；与 avatarBlob 二选一
  avatarBlob  BLOB?          // 96px 缩略图直接入库（存文件路径会在重装/换机后失效）
  remark      TEXT?          // 备注，如"起床后、午饭后各一次"
  isDefault   BOOL           // 全局最多一个为 true，见下方唯一索引
  archivedAt  DATETIME?      // ★ 删人 = 归档，不是真删。见下方「删除屙屎人」
  sortOrder   INT
  createdAt   DATETIME
}

// 一次拉屎
PoopRecord {
  id         TEXT PK
  pooperId   TEXT FK -> Pooper
  startedAt  DATETIME NOT NULL
  endedAt    DATETIME?       // 有值 = 正常结束
  endUnknown BOOL NOT NULL DEFAULT 0   // ★ true = 确认已结束，但结束时间不详
  createdAt  DATETIME
  updatedAt  DATETIME
  // 不变式：endedAt != null 时 endUnknown 必须为 false
}

// 本次的多条备注（每条自带时刻）
RecordNote {
  id        TEXT PK
  recordId  TEXT FK -> PoopRecord  (ON DELETE CASCADE)
  text      TEXT NOT NULL
  notedAt   DATETIME NOT NULL      // 录入当刻，默认 now()
  sortOrder INT
}

// 默认备注（"拉肚子""很顺畅"…），用户可增删
NoteTemplate {
  id        TEXT PK
  text      TEXT NOT NULL UNIQUE
  sortOrder INT
  useCount  INT              // 用于按使用频率排序
}
```

**关键设计点**

1. **`endedAt` 可空**是需求的核心，不要用 `0` 或空串哨兵值。但**"可空"不等于"进行中"** —— 见下面第 3 点的状态机，这是原设计里的一个真 bug。
2. **备注独立成表**，而不是在 `PoopRecord` 上挂一个 JSON 数组。因为需求要"备注也有实时时间"，一条备注就是一个带时刻的实体，独立成表才能单独增删改、单独排序、将来做备注级统计。
3. **"没有结束时间"是两种状态，不是一种**。详见下面的状态机。
4. **跨零点归属**：23:50 开始、00:05 结束，算哪天？建议**按 `startedAt` 归属**，并在设置里留一个开关。这是必须显式决策的点，否则日历计数会和直觉不符。

---

### 记录状态机：修掉"永远进行中"的 bug

原设计把 `endedAt == null` 一律当作"进行中"。但用户说得很对——**结束时间经常是不知道的**。于是"没填结束时间"实际包含两种完全不同的情况：

1. 真的还在屙
2. 屙完了，但忘了记 / 不知道具体几点

混为一谈会导致三个后果：

- **唯一索引把用户锁死**：部分唯一索引 `WHERE ended_at IS NULL` 的本意是"一个人同时只能有一次进行中"，但只要忘了一次，这个人的 `ended_at` 就永远是 NULL，**再也开不了新记录**。这是最严重的一个。
- 计时器无限跑：卡片上显示"已 3 天 6 小时"。
- 日历上永远挂着一格"进行中"。

**修法**：把"结束但不知道时间"提升为一个显式终态（`endUnknown`），并用它修正唯一索引。

| 状态 | 条件 | 卡片显示 | 时长列 |
|---|---|---|---|
| **正在屙** | `endedAt == null && !endUnknown`，且未超阈值 | 脉冲点 + `正在屙` | 实时计时 |
| **待确认** | 同上，但已超阈值 | 琥珀提示，弹"还在屙吗？" | 停在阈值，不再增长 |
| **未记结束** | `endUnknown == true` | `09:12 → 未记结束` | `时长不详` |
| **已完成** | `endedAt != null` | `09:12 → 09:26` | `14 分钟` |

阈值默认 **2 小时**转"待确认"、**24 小时**自动收敛为"未记结束"，都可在设置里改。计时显示必须在阈值处停住，否则"已 3 天"很荒唐。

修正后的唯一索引 —— 无论走哪条路收敛，记录都不再是 active，**用户立刻能开下一次**：

```sql
CREATE UNIQUE INDEX ux_active ON poop_records(pooper_id)
WHERE ended_at IS NULL AND end_unknown = 0;
```

**统计口径要区分**：`endUnknown = true` 的记录**不能**计入"平均时长"，否则统计会被拉偏；但**日历计数照算**（按 `startedAt` 归属）。

**状态命名**：「进行中」太通用，浪费了玩梗的机会。推荐 **「正在屙」** —— 和 app 名"屙了么"同源，三个字，清楚且有品牌感。备选「蹲着呢」（画面感更强，但稍长）。"结束但没时间"推荐叫 **「未记结束」**，强调是"没记"而不是"不知道"，对自我记录类 app 更准确。

---

### 删除屙屎人：归档，不是真删

数据模型里只定义了备注的级联删除，**从没定义删人时他的记录怎么办**。
按最自然的写法（外键 `ON DELETE CASCADE`），删掉"阿狗"会静默抹掉他几百条历史记录。

这是不可接受的数据丢失。做法：

- `Pooper.archivedAt` 有值 = 已归档。历史记录**原样保留**。
- 选择器、日历徽标、默认屙屎人候选中都不再出现他。
- 统计页给一个开关"是否计入已归档的屙屎人"。
- 真要彻底删除，放在设置页的「危险操作」里，明确写清会删掉 N 条记录。

### 默认屙屎人的唯一性

`isDefault` 只是普通布尔字段的话，可能同时存在两个默认、或一个都没有（默认那个被删了）。
必须加部分唯一索引，并在删除 / 归档默认屙屎人时转移默认：

`sql
CREATE UNIQUE INDEX ux_default ON poopers(is_default) WHERE is_default = 1;
`

光有索引不够，两条边界规则必须一起做：

1. 归档 / 删除默认人时，自动把**剩下最早创建**的那个人提升为默认
2. 如果一个人都不剩，isDefault 全为 null

### ★ 首启和「归档掉最后一个人」是同一个状态

「一个屙屎人都没有」不是首启专属的。归档掉最后一个人也会回到这里。

所以自动建档的逻辑必须抽成一个可复用的守卫，两个时机都调用：

`dart
/// 保证始终至少有一个可用的默认屙屎人。
/// 首启时调用；归档 / 删除后也要调用。
Future<Pooper> ensureDefaultPooper() async {
  final alive = await db.activePoopers();          // archivedAt IS NULL
  if (alive.isEmpty) {
    return db.createPooper(name: '我', isDefault: true);   // 静默建档，不弹墙
  }
  if (!alive.any((p) => p.isDefault)) {
    await db.setDefault(alive.first);              // 按 sortOrder / createdAt 最早的那个
  }
  return db.defaultPooper();
}
`

**不要写成 if (isFirstRun)** —— 那就会漏掉「归档掉最后一个人」这条路径。
详见 [design-system.md §9a / §9d](design-system.md)。

### 头像存 BLOB，不存路径

原方案是把用户上传的头像写进应用私有目录、DB 里存相对路径。
问题是**重装 App 或换机恢复后路径全部失效**，头像集体变默认，用户会以为数据丢了。

改成把 **96px 缩略图直接以 BLOB 入库**（几十 KB，几百个屙屎人才几 MB）。
原图不必存。好处是导出 JSON 时头像跟着走，备份天然完整。

---

**日历聚合查询**（整月一次查完，不要按天循环查）
```sql
SELECT date(started_at, 'localtime') AS day,
       pooper_id,
       COUNT(*) AS cnt
FROM poop_records
WHERE started_at >= :monthStart AND started_at < :monthEnd
GROUP BY day, pooper_id;
```

结果在内存里转成 `Map<String, Map<String,int>>`，正好就是 mockup 里 `DATA` 那个结构。

---

## 2. 节假日 / 调休数据

**推荐：打包 JSON，离线优先。**

- 数据源：[NateScarlet/holiday-cn](https://github.com/NateScarlet/holiday-cn) —— 每日自动抓取国务院公告，输出按年分文件。
- 放 `assets/holidays/2024.json`、`2025.json`、`2026.json`，首次启动导入到本地表或直接在内存里建索引。
- 格式（上游结构）：
  ```json
  { "year": 2026, "days": [
      { "name": "春节", "date": "2026-02-15", "isOffDay": true },
      { "name": "春节", "date": "2026-02-14", "isOffDay": false }
  ]}
  ```

**三态渲染规则**

| 条件 | 展示 | 颜色 |
|---|---|---|
| 在 `days` 里且 `isOffDay = true` | 角标 **休** | 朱红 `#D2564A` |
| 在 `days` 里且 `isOffDay = false` | 角标 **班** | 青蓝 `#4A7C8C` |
| 不在 `days` 里 | 无角标 | 周六日数字用焦糖色区分 |

注意 `isOffDay = false` 的那批**恰恰是周六周日**（调休上班），所以"周末染色"和"班角标"会同时出现，视觉上要靠角标压住周末色。

> 我没有依赖在线 API（`timor.tech` 之类）。这类第三方接口挂掉或改协议，你的日历就会集体失准；而节假日数据一年只需要更新一次，打包进 APK 成本几乎为零。

---

## 3. 界面结构（20 页）

```
MainShell
├── ① 日历主页 · 月视图 ★核心
│   ├── 应用栏：屙了么 + 搜索 / 设置
│   ├── 日历卡：月份标题（可点 ▾ 开年月选择器）+ ‹ › + [月|周] 分段控件
│   │           星期头 + rows 行日期格（休/班角标 + 头像徽标）
│   ├── 日期栏：2月11日 周三 · 今天  [回到今天]  [共 4 次]
│   ├── 记录列表：按 startedAt 升序，"正在屙"的置顶
│   └── FAB：「现在开屙」→ 走"秒开"路径
├── ② 日历主页 · 周视图          （格高 126px，徽标最多 3 行；标题显示周区间，可点开周选择器）
├── ③ 记一次（ModalBottomSheet）
│   ├── 谁在屙（默认选中 isDefault 那位）
│   ├── 开始时间（默认 now）/ 结束时间（非必填）
│   ├── 快捷备注 chips（点一下把文字追加进下面的文本域）
│   ├── 备注输入（多行 TextField，建议 maxLength 200）+「添加这条备注」
│   └── 本次备注列表（每条带时刻，可逐条编辑 / 删除）
├── ④ 忘了点结束 · 待确认        （超阈值时弹出；三个出口：刚刚结束 / 没记结束时间 / 还在屙）
├── ⑤ 记录详情 · 编辑            （同弹层，加删除 / 逐条备注编辑）
├── ⑥ 历史记录 · 时间线          （按日期倒序分组，顶部按人筛选）
├── ⑦ 搜索与筛选                （关键词 + 时间范围 + 多选屙屎人）
├── ⑧ 补录历史记录              （选日期 + 时间，结束时间可留空）
├── ⑨ 空状态                    （某天无记录）
├── ⑳ 首次打开                  （空日历 + 一次性加人提示条）
├── ⑩ 设置主页                  （分组入口）
├── ⑪ 屙屎人管理                （增删改 / 拖拽排序）
├── ⑫ 新增 / 编辑屙屎人          （图标头像 or 上传照片 / 名称 / 备注 / 设为默认）
├── ⑬ 默认备注管理              （增删改排序 + 使用次数）
├── ⑭ 节假日与日历              （数据版本 / 格内显示项 / 每周起始日 / 跨零点归属 / 记录阈值）
├── ⑮ 统计                     （周月年频次 / 按人分布 / 平均时长）
├── ⑯ 备份与导出                （JSON / CSV / 恢复 / 清空）
├── ⑰ 跳到哪个月                （年条 + 12 月网格；有记录的月带点）
├── ⑱ 跳到哪一周                （该月周列表 + 每周次数）
└── ⑲ 6 行月份 · 8月            （边界态：验证日历行数按月份实算）
```

### 日历字号要钳制在格内

日历格固定 58px，字体放大到 2.0× 时 6 行月份要吃掉约 477px，而可用高度只有约 553px ——
记录列表会被挤没。做法是用 MediaQuery **只包住 GridView**，上限 1.3×：

`dart
final s = MediaQuery.textScalerOf(context);
final clamped = TextScaler.linear(s.scale(1) > 1.3 ? 1.3 : s.scale(1));

MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: clamped),
  child: calendarGrid,          // 只包日历格，日历卡的标题 / 星期头 / 日期栏照常跟随系统
)
`

理由和实测数字见 [design-system.md §9e](design-system.md)。

### 日历行数必须实算（别写死 5 行）

```dart
final offset = (DateTime(y, m, 1).weekday - DateTime.monday) % 7;  // 周一作首列
final days   = DateTime(y, m + 1, 0).day;
final rows   = ((offset + days) / 7).ceil();                        // 5 或 6
```

写死 `35` 格会让 **2026 年的 3 月 / 8 月 / 11 月各丢掉最后一整个星期**。
样例数据用的是 2 月（周日开头 + 28 天 = 34 格，正好 5 行），所以这个 bug 藏了很久。
详见 [design-system.md §9b](design-system.md)。

**交互要点**

- FAB **一键开屙**：不弹层，直接把"默认屙屎人 + 当前时间"落库成为一条进行中记录，列表顶部立即出现一张带脉冲点的卡片。弹层是"补充细节"时才用。这是这个 App 的手感关键——记一次拉屎不该超过一次点击。
- **打开 App 时先扫一遍超阈值的"正在屙"**，有就弹"还在屙吗？"。这是防止记录永远挂着的主要手段，不能只靠用户主动去点结束。
- 点日历任意日期 → 下方列表切换；左右滑动日历 → 切月/周。
- **点月份 / 周标题 → 开年月选择器 / 周选择器**。只靠 `‹ ›` 从 2026年2月 回到 2024年8月要点 18 次，走不通。
- **不在今天时，日期栏右侧出现「回到今天」**。放在日期栏而不是日历头部，因为头部横向只剩约 2px。
- 长按记录卡 → 快速改结束时间；长按备注 → 编辑/删除。
- "正在屙"的记录卡上加"结束"按钮，点一下写入 `endedAt = now`；旁边次要位置放"没记结束时间"，写入 `endUnknown = true`。
- 补录入口放在历史页的 FAB 上，和"现在开屙"区分开——补录不会动默认屙屎人，也不会碰进行中的记录。

**图标：`lucide_icons_flutter` 3.1.25**

全部图标走 Lucide（ISC 协议可商用），**禁止 emoji**。原因和尺寸规范见 [design-system.md 第 7 节](design-system.md#7-图标规范)。Flutter 侧直接用 `LucideIcons.xxx`，不需要打包 SVG 资源。

备选：`phosphor_flutter` 2.1.0（6 种字重，MIT）、`material_symbols_icons` 4.2960.0（7000+ 图标）。

---

## 4. 打包与签名

```bash
# 1) 生成签名（只需一次）
keytool -genkey -v -keystore poopedyet.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias poopedyet

# 2) android/key.properties 指向 keystore，build.gradle.kts 里读入 signingConfigs

# 3) 出包（按 ABI 分包，体积最优）
flutter build apk --release --split-per-abi
# 产物：build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

- 包名建议 `com.poopedyet.app`（避免用 `com.example`，否则无法上架任何商店）。
- `applicationId` 定下来后**不要再改**，否则等于换了一个 App，老用户升不上去。
- `minSdk` 建议 24（Android 7.0），覆盖足够且能用现代 API。

---

## 5. 最终决策定案（已完全工程落地）

本轮架构落地中，以下设计决策已经全部定案并体现在正式代码与数据库中：

1. **跨零点归属**：严格按 **`startedAt` 本地日期归属**。日历聚合、历史倒序、分组均以开始时间为基准，逻辑自洽且符合用户心理预期。
2. **私有云同步与数据备份**：采用**纯 Dart 原生 WebDAV 同步 + 全量 JSON 导出/导入 + 系统剪贴板互操作**。完全保护用户数据隐私，无需托管中心化服务器，坚果云、群晖 NAS、Nextcloud 即开即用。
3. **深浅色自适应与主题色系**：支持跟随系统、浅色、深色三种模式，并在设计令牌中内置了**经典焦糖、抹茶森林、深海微风、烟雨丁香、落日陶土**五套对比度严格达标（WCAG 2.1 AA）的温润色板。
4. **头像与图标规范**：全面采用 **Lucide 矢量图标（`lucide_icons_flutter`），严格禁止粗糙 emoji**；头像支持精选图标、姓名首字色彩兜底，以及 96px 缩略图直接 BLOB 入库。

