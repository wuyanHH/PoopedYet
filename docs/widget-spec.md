# 屙了么 (PoopedYet) · 桌面小组件详细设计规格书 v2.0

> 配套文档：[UI 设计规范 (design-system.md)](design-system.md) · [技术栈与架构 (tech-stack.md)](tech-stack.md) · [命名规范 (naming.md)](naming.md)
>
> **v2.0 相对 v1.0 的变更**：视觉从「纸质手帐风」改为「现代卡片风」；成员头像与姓名整体放大 2~3 倍；新增添加时的成员配置向导与 App 内小组件管理页；三款组件补齐真实预览图。落地状态见 §8。
>
> ⚠️ `.design/widget-reference.html` 是 **v1.0 纸质手帐风**的历史视觉原型，已不代表当前实现；现行视觉以 §2 与 `values/colors.xml` 为准。

---

## 1. 方案定位与设计哲学

桌面小组件不是主 App 的缩小版，而是**桌面上的即刻触达入口**与**生活节律观察窗**。

v2.0 确立四条支柱：

1. **成员身份优先 (Who-first)**：拿到一个小组件，第一眼必须看清「这是谁的数据」。因此头像与姓名是版面里字号最大、对比最强的元素，其余信息全部让位。
2. **现代卡片风 (Modern Card)**：干净白卡片 + 24dp 大圆角 + 强字重对比 + 焦糖色强调块，在系统桌面上挺括、有识别度，不再是「一张贴上去的米色纸」。
3. **零阻力记录 (Zero-Friction)**：`现在开屙` / `完成打卡` 永远在拇指最舒服的底部位置，一次点击直达。
4. **体面隐私 (Dignity)**：暗号模式一键把全部排泄敏感词替换为「日常轻体 / 放空减负」。

---

## 2. 视觉规范：现代卡片风

### 2.1 色彩令牌

与 `android/app/src/main/res/values/colors.xml`、`values-night/colors.xml` 严格同源。**改这里必须同步改那两个文件。**

| Token | 浅色 | 深色 | 用途 |
|---|---|---|---|
| `widget_paper` | `#FFFFFF` | `#1C1917` | 组件根卡片底（纯白，现代感来源） |
| `widget_surface_2` | `#F5F2EF` | `#302B28` | 成员行 / 周历格 / 次要按钮底 |
| `widget_line` | `#ECE6E0` | `#3A342F` | 1dp 分隔线、根卡片描边 |
| `widget_ink` | `#1A1613` | `#F5F1EC` | 姓名、日期大数字（对白底 16.1:1） |
| `widget_ink_2` | `#5F5852` | `#BDB4AB` | 次级文字（7.2:1） |
| `widget_ink_3` | `#8A817A` | `#928880` | 三级文字、状态行（4.6:1） |
| `widget_brand_fill` | `#A85F29` | `#A85F29` | **主按钮底**，白字对其 4.85:1 |
| `widget_brand_ink` | `#8F4A15` | `#F0A05C` | 焦糖色**文字**（对 `brand_soft` 5.94:1） |
| `widget_brand_soft` | `#FDF0E4` | `#3A2716` | 焦糖浅底（胶囊、今天格） |
| `widget_live` | `#2F7A4F` | `#5CB37E` | 进行中呼吸点、卡片绿描边 |

**品牌焦糖一色三分**：`brand_fill` 只能当**底**（上面盖白字），`brand_ink` 只能当**文字**，`brand_soft` 只能当**浅底**。把 `brand_fill` 拿去写文字会掉到 4.5:1 以下 —— 这是 v1.0 踩过的坑。

### 2.2 形状与字体

- **圆角**：根卡片 24dp、成员行/信息块 16dp、周历格 12dp、按钮 99dp（胶囊）。
- **数字**：`sans-serif-black`（重量感、防抖动）用于日期大数字、今日次数、计时器。
- **姓名/标签**：`sans-serif-medium`，与主 App 的正文族保持一致。
- **阴影**：不手绘 —— Android 12+ 会基于 `targetSdk` 自动为小组件加圆角裁剪与外投影。
- **图标**：Lucide 线性矢量（`ic_widget_*.xml`），**禁止彩色 Emoji**。

---

## 3. 各尺寸规格

### 3.1 小号 (2×2) ——「成员打卡卡」

- 逻辑尺寸：155pt × 155pt；内边距 14pt；主按钮高 42pt。
- 关键约束：内容宽仅 **127pt**。所以**不做**「姓名 + 次数胶囊 + 切换箭头」三件套（放不下会互相压字），改为把「今日次数」与「距上次」合并成成员区第二行。

```text
┌───────────────────────────────┐
│ ╭────╮  我                    │  ← 头像 40pt + 姓名 15sp 粗
│ │ 我 │  今日 2 次 · 4h前       │  ← 11sp ink_3
│ ╰────╯                        │
│                               │
│ 18   10月 · 周六               │  ← 日期 32sp 黑体 + 12.5sp
│                               │
│ ╭───────────────────────────╮ │
│ │        ＋  现在开屙         │ │  ← 42pt 胶囊主按钮（brand_fill）
│ ╰───────────────────────────╯ │
└───────────────────────────────┘
```

进行中态：中部切换为原生 `Chronometer`（30sp）+ 绿点 + 「正在屙…」，按钮变为 `完成打卡`（深咖底），根卡片换成 2dp 绿描边。

### 3.2 中号 (4×2) ——「行动舱 + 7 天周历」

- 逻辑尺寸：320pt × 155pt；内边距 12pt；左舱宽 104pt。
- 成员信息升到**顶部通栏**（原来挤在左侧窄栏里），周历高亮的是**当前绑定成员**的打卡。

```text
┌────────────────────────────────────────────────────────────┐
│ ╭────╮ 我                        ⌄  ╭连续顺畅 5 天╮        │
│ │ 我 │ 今日 2 次 · 上次 08:30 · 顺畅  ╰────────────╯        │
│ ╰────╯                                                     │
│ ────────────────────────────────────────────────────────── │
│                       │  一   二   三   四   五   六   日   │
│  4h  距上次            │  12   13   14   15   16   17   18   │
│                       │  ●    ●    ●    ●              ●    │
│ ╭───────────────────╮ │                                    │
│ │   ＋  现在开屙      │ │                                    │
│ ╰───────────────────╯ │                                    │
└────────────────────────────────────────────────────────────┘
```

进行中态：左舱大字换成实时计时（21sp，`widget_live` 绿）+「正在屙…」，按钮变 `完成打卡`；右侧周历保持不动，避免整卡跳动。

> 周历的打卡点由快照里的 `pooperCounts[pooperId]` 决定，**不是**全家汇总 —— 否则「我的组件」会点亮别人的记录。

### 3.3 大号 (4×4) ——「家庭健康看板」

- 逻辑尺寸：320pt × 320pt；内边距 12pt；成员行高 48pt（头像 34pt）。
- v1.0 是「三列并排小卡」，成员一多姓名就被压成两个字；v2.0 改为**三行列表**，每位成员独占一行并有独立操作。
- 顶部标题栏右侧是**成员胶囊**（20pt 头像 + 姓名 + 箭头），点它和 2×2 / 4×2 一样原地换人；绑定的那位在看板里**置顶**。

```text
┌──────────────────────────────────────────────────────────┐
│ 屙了么 · 家庭看板     ╭🖼 我 ⌄╮    10月18日 周六          │
│ ╭──────────────────────────────────────────────────────╮ │
│ │ ╭──╮ 我      今日 2 次 · 上次 14:15        ╭记一次╮  │ │
│ ╰──────────────────────────────────────────────────────╯ │
│ ╭──────────────────────────────────────────────────────╮ │
│ │ ╭──╮ 咪咪    今日 1 次 · 上次 07:20          ╭帮记╮  │ │
│ ╰──────────────────────────────────────────────────────╯ │
│ ╭──────────────────────────────────────────────────────╮ │
│ │ ╭──╮ 宝宝    昨天 19:40                     ╭帮记╮  │ │
│ ╰──────────────────────────────────────────────────────╯ │
│ ╭──────────────────────────────────────────────────────╮ │
│ │ 我 · 14:15 (用时 11m)                        #顺畅    │ │
│ │ “喝完温水后排空，非常舒适顺畅。”                       │ │
│ ╰──────────────────────────────────────────────────────╯ │
│ ╭────────────╮ ╭──────────╮ ╭──────────╮                 │
│ │ ＋极速开屙   │ │ 补录便签  │ │ 打开日历  │                 │
│ ╰────────────╯ ╰──────────╯ ╰──────────╯                 │
└──────────────────────────────────────────────────────────┘
```

- 成员超过 3 位时，第 3 行自动变成「还有 N 位家庭成员 / 查看全部」入口。
- 已归档的成员**不占看板位置**。
- 成员行与行内按钮都指向 `poopedyet://action/start?pooperId={id}` —— 一次点击即为该成员开屙。
- 便签卡是弹性区（`layout_weight=1`），成员多、便签长时自动让位，底部按钮永远贴底。

### 3.4 成员信息放大对照表

> **换人暗示统一**：三款组件一律是「整块成员区可点 + **姓名紧跟一条下拉线**」。
> 2×2 早期为了省宽度把下拉线省掉了，结果用户根本看不出那里能点；4×2 曾经把
> 下拉线放在 streak 胶囊左边，看起来像是胶囊的一部分。
> 实现上有个坑：姓名的 `layout_width` **不能用 `weight=1`** —— 它会占满剩余宽度，
> 把下拉线又顶到最右边去，必须用 `wrap_content` + `maxWidth` 兜底。

| 位置 | v1.0 | v2.0 | 倍率 |
|---|---|---|---|
| 小号 头像 / 姓名 | 14dp / 10sp | **40dp / 15sp** | 2.9× / 1.5× |
| 中号 头像 / 姓名 | 22dp / 11sp | **36dp / 15sp** | 1.6× / 1.4× |
| 大号 头像 / 姓名 | 22dp / 10.5sp | **34dp / 14sp** | 1.5× / 1.3× |
| 配置浮层 头像 / 姓名 | —（不存在） | **44dp / 15.5sp** | 新增 |

### 3.4 4×4 底部那块：从「便签」换成「本周小结 + 节律」

这里原本是「最新便签速记」，并且拿了 `weight=1` —— 在真机上占近四成高度。
但便签是**低频**内容：绝大多数时候那一整块是「暂无近期便签速记」的空白，
还只读、点不动。等于用整卡最贵的位置放最没信息量的东西。

现在换成三行，主次分明：

| 行 | 内容 | 说明 |
|---|---|---|
| ① | `本周 12 次 · 6 天有记录 · 最勤 xiaojie` | 数据来自快照的 `weeklySummary`，直接复用已算好的 `weekDays`，不多查一次库 |
| ② | **7 天节律带** `一3 二5 三2 四4 五1 六6 日2` | 一格一天；今天高亮；没记录显示成 `一·`。一眼看出这周哪天断了、哪天最集中 |
| ③ | `我 · 14:15 · 喝完温水后排空…` | 便签退成**一行**，而且**没有便签时整行 `GONE`**，不占地方 |

**高度预算**是这块最容易翻车的地方：4×4 标准约 280dp（启动器不同会在 280~442dp 之间浮动），
而「标题 + 3 行成员 + 小结卡 + 按钮」很容易超。所以成员行压到 **40dp**、头像 **32dp**、
节律格 **17dp**；成员行与小结卡都用 `weight` 分配，**跟着高度伸缩**而不是留出空洞。

> 成员行不够 3 位（第 3 行 `GONE`）时，剩余两块会自动变大填满 ——
> 早期的做法是塞一个占位 View 吸收富余，结果 2 位成员时中间裂开一道大缝。

### 3.5 头像：三层兜底，原生与 Flutter 必须逐层对齐

主 App 的 `PooperAvatar` 是三层兜底，小组件必须一模一样：

| 层 | 条件 | 小组件实现 |
|---|---|---|
| ① 照片 | `avatarBase64` 非空 | `BitmapFactory` 解码 + 圆角裁剪 + centerCrop |
| ② **内置图标** | `iconKey` 非空且能找到资源 | `drawable/ic_pooper_<snake_case>.xml` 矢量图 + `setTint(colorFg)` |
| ③ 姓名首字 | 兜底 | `colorBg` 圆角底 + `colorFg` 加粗首字 |

**第 ② 层曾经是缺失的**：小组件只做了「照片 → 首字」两层，于是给成员设了
小狗图标的用户，在桌面上看到的是一个「X」色块。这正是「小组件头像不会显示
正确的屙屎人设定的头像」那条反馈的根因 —— 跟快照同步无关，是渲染少了一层。

图标资源由 `.design/build-widget-avatar-icons.py` 从 `.design/icons/svg/*.svg`
（lucide-static，ISC 许可）生成，key 与 `pooper_icons.dart` 的 40 个 key 一一对应
（camelCase → snake_case）。描边色写死成黑色，运行时用 `Drawable.setTint`
染成该成员的专属前景色 —— 一份资源服务所有配色，不必为每人生成一张图。

> 之所以不走「Flutter 侧渲染成 PNG 再塞进快照」：那样每次改头像都要跑一遍
> 渲染管线，快照也会膨胀（每位成员一张 base64）。Lucide 本来就是矢量，
> 交给系统画更清晰、更省，也离得开 Flutter 引擎。

---

## 4. 成员绑定与配置向导

每个小组件实例**独立绑定**一位屙屎人：同一个 2×2 放两个，可以一个看你、一个看家人。

### 4.1 三个入口

| 入口 | 实现 | 适用时机 |
|---|---|---|
| **添加时配置向导** | `android:configure` → `WidgetConfigActivity` | 系统添加组件时自动弹出，选完才落桌面 |
| **点击组件成员区** | 组件上的 `PendingIntent` 原地拉起同一个 `WidgetConfigActivity` | 日常换人，**不需要删掉组件重新添加** |
| **App 内管理页** | 设置 → 桌面小组件 → `WidgetManagerPage` | 总览桌面上所有组件、批量调整 |

### 4.2 系统契约（重要）

Android 规定：`AppWidgetProvider` 的配置 Activity **只要没有 `setResult(RESULT_OK)`，这次添加就作废**。因此 `WidgetConfigActivity.onCreate()` 的第一件事就是把结果预设为 `RESULT_CANCELED` —— 用户中途按返回键时，桌面上不会留下一个「没配好的」空组件。

配套声明：

```xml
<activity
    android:name=".widget.WidgetConfigActivity"
    android:exported="true"
    android:excludeFromRecents="true"
    android:noHistory="true"
    android:taskAffinity=""
    android:theme="@style/Theme.PoopedYet.WidgetConfig">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_CONFIGURE" />
    </intent-filter>
</activity>
```

三个 `appwidget-provider` 里同步声明：

```xml
android:configure="com.poopedyet.app.widget.WidgetConfigActivity"
android:widgetFeatures="reconfigurable"
```

`reconfigurable` 让 Android 12+ 支持「长按组件 → 编辑」，等于第五个入口，零额外代码。

### 4.3 「跟随默认成员」永远可用

绑定值为 `null` 时，组件运行时回退到 App 的默认屙屎人。**配置浮层的这一项不依赖任何数据**，因此：

- App 从未启动过、跨进程快照还是空的时候，用户依然能把组件放上桌面；
- 之后在 App 里改默认成员，所有「跟随默认」的组件会一起变。

只有在需要指定某个人时，才要求快照里有 `familyMembers`；缺失时浮层给出明确提示而不是空白。

### 4.4 读写接口

```kotlin
// 每个 appWidgetId 一条键：widget_pooper_<id>
WidgetDataProvider.getWidgetPooperId(context, appWidgetId)   // null = 跟随默认
WidgetDataProvider.setWidgetPooperId(context, appWidgetId, pooperId)
WidgetDataProvider.clearWidgetPooperId(context, appWidgetId)
```

Flutter 侧通过 `com.poopedyet.app/widget` 通道读写：

| 方法 | 方向 | 载荷 |
|---|---|---|
| `updateSnapshot` | Flutter → 原生 | `{snapshotJson}` |
| `listWidgetBindings` | Flutter → 原生 | 返回 JSON 数组字符串 |
| `setWidgetPooper` | Flutter → 原生 | `{widgetId, pooperId?}`，`pooperId` 为空即「跟随默认」 |

写入后原生立刻 `triggerUpdateAll()` 重绘桌面，**无需重启 App、无需重新添加组件**。

### 4.5 成员生命周期与绑定的联动

小组件是按 `pooperId` 绑定的。一旦成员从「可用列表」里消失（归档 / 彻底删除），
必须有明确的收尾，否则那个组件会**静默回退成显示默认成员** ——
用户看到的是「头像莫名换成了别人」，而且在任何选择界面里都找不到原因。

| 事件 | 数据层 | 小组件侧 |
|---|---|---|
| 归档 | `archivePooperAndDetachWidgets`：归档 + 同步快照 + 把所有绑着 TA 的组件改回「跟随默认」 | 配置浮层不再列出已归档的人 |
| 取消归档 | `unarchivePooper`：恢复 + 同步快照 | 重新出现在可选列表 |
| 彻底删除 | `purgePooperAndDetachWidgets`：先解绑，再按「备注 → 记录 → 人」顺序删除，最后同步快照 | 同上，且绑定已被收回 |
| 设为默认 | `setDefaultPooper`：改默认 + 同步快照 | 所有「跟随默认」的组件立刻换人 |

两个容易踩的点：

1. **快照里必须保留归档成员。** 原生渲染时如果查不到绑定的那个人，就会回退到默认成员。
   把归档成员一并放进 `familyMembers`（带 `isArchived` 标志），渲染才能一直画对人 ——
   「不被选择」和「不被渲染」是两件事，不能靠同一份列表解决。
2. **这些生命周期方法原本都不触发快照同步。** 人归档了、默认换了，桌面组件却还拿着旧快照 ——
   这正是「归档之后依旧能被选择」和「头像不对」两条反馈的共同根因。
3. **冷启动必须同步一次。** 快照此前只在「有写操作」时更新，而用户完全可能改完头像、
   归档完成员就直接退出。更隐蔽的是：这句同步曾经挂在 `bootReportProvider` 上，
   而那个 provider **从来没有任何地方 watch 过**，等于从未执行。现在挂在
   `databaseProvider`（数据库的唯一创建点）上，任何用到数据库的路径都必然经过它，
   不会再出现「没人 watch 就不执行」。

配置浮层对归档项的处理：默认不列出；**唯一例外是当前正绑着的那一位**，
此时显式展示并置灰（`alpha = 0.45`），否则用户会看到一个没有任何选中项的列表，
只会以为界面坏了。

### 4.6 彻底删除成员

「删除屙屎人」和「归档」是两件事，UI 上刻意分开：

- **归档**（列表行右侧归档按钮 / 编辑页右上角）：人从选择列表消失，历史记录与日历统计全部保留，可恢复。
- **彻底删除**（列表的「已归档」区 / 编辑页底部「危险操作」）：
  `purgePooperAndDetachWidgets` 会连同 TA 的全部记录一起删除，**不可恢复**。

删除确认框必须**先算出要删多少条记录**（`countRecordsOf`）并写进按钮文案
（如「永久删除 37 条」）—— 不报数字的确认框等于没确认。
同时在文案里把「你其实想用的是归档吧」这条路指出来。

### 4.7 「开屙 / 完成」在后台完成，不打开 App

小组件上最重要的两个动作，点完之后**不该把用户拽进 App** ——
他此刻在桌面，只是顺手记一笔，弹出一个全屏应用会打断手上的事。

链路：按钮挂 `PendingIntent.getBroadcast` → `WidgetActionReceiver`
→ `WidgetActionRunner` 临时拉一个**没有界面**的 `FlutterEngine`，
执行 Dart 入口 `widgetActionMain`（标了 `@pragma('vm:entry-point')`），
写完库把新快照推回原生，然后销毁引擎并刷新桌面。

**为什么不图省事让原生直接写 SQLite**（那样更快也更简单）：要复刻一整套业务契约 ——
drift 的 `DateTime` 编码、`ux_active_record` 唯一索引（一个人同时只能挂一条进行中记录）、
外键约束，以及「重复开屙」「记录已被别处结束」这些边界。在 Kotlin 里复刻一份，
迟早会在某次 schema 变更后**悄悄写坏用户数据**——而这个 App 的全部价值就是那些记录。
让 Dart 去写，规则永远只有一份。

代价：首次点约 0.5~1s（加载 native 库 + Dart VM 快照）。连点会排队逐个执行。

> 快照推送、绑定读写这几个通道方法抽在 `WidgetChannelHandler` 里，
> `MainActivity` 和后台引擎共用同一份实现，两边不会漂移。

**两个踩过的坑，都值得记下来：**

1. **入口函数必须定义在 `main.dart`（根库）里。**
   Flutter 的 `DartEntrypoint` 只在根库的顶层作用域按名字解析函数，
   放在 `src/widget/xxx.dart` 里会直接报
   `Could not resolve main entrypoint function` —— 而且不弹任何界面，
   用户看到的就是「点了没反应」。所以真正的入口是 `main.dart` 里那个
   `@pragma('vm:entry-point')` 转发函数，它再调用实现。
2. **入口所在的库必须被 import 进编译产物。**
   一个不含 UI 代码、没人引用的库不会被打进包，同样会解析失败。

诊断时直接看 `adb logcat | grep WidgetAction`：正常时能看到
「收到小组件动作: ACTION_FINISH」，失败时紧跟一条 entrypoint 报错。

**有意保留进 App 的入口**：点卡片空白处（打开主页）、点成员区/胶囊（换人浮层）、
大号的「补录便签」「打开日历」——后两件事本来就需要完整界面。

---

## 5. 预览图与选择器

按 Android 版本走两条路，两条都补齐：

| 版本 | 机制 | 说明 |
|---|---|---|
| **Android 12+** | `android:previewLayout="@layout/widget_small"` 等 | 系统直接静态渲染**真实布局**，预览即成品，永远不会和实际跑偏 |
| **Android 11 及以下** | `android:previewImage="@drawable/widget_preview_*"` | 位图兜底，由 `.design/build-widget-previews.py` 生成 |

> **预览图必须是不透明的。**
>
> 生成脚本原本用 RGBA 全透明背景，保存时又 `convert("RGB")` —— 透明区在转换里
> 被压成**纯黑**，于是启动器的组件列表里每张预览图四角都是黑边（实测四角像素
> 就是 `(0, 0, 0)`）。
>
> 现在背景直接铺成不透明白色，最外层卡片画成**直角**：圆角交给启动器自己裁
> （Android 12+ 会裁，而且各家半径本来就不一样，画死反而对不齐）。
> App 内那张预览另加 `ClipRRect` 保持圆角观感。

预览位图严格复刻布局的尺寸、间距、字号与配色（`SCALE = 3.0`），三张分别是 465×465 / 960×465 / 960×960。

**布局里给头像 `ImageView` 留了默认 `src`**（`ic_widget_avatar_placeholder`）—— 这既让 `previewLayout` 不会出现空白方块，也让「快照还没同步」的极早期状态有一个体面的中性头像，而不是一片空白。

选择器里的组件名也逐个区分（原来三个都显示 App 名「屙了么」）：

| 组件 | 选择器显示名 |
|---|---|
| 2×2 | 屙了么 · 成员打卡 (2×2) |
| 4×2 | 屙了么 · 行动周历 (4×2) |
| 4×4 | 屙了么 · 家庭看板 (4×4) |

### 5.1 App 内也能看预览、一键添加

设置 →「桌面小组件」页顶部直接列出三款组件的**真实预览图**与「添加」按钮，用户不必先把组件拖到桌面再删掉重来。

| 能力 | 实现 |
|---|---|
| 预览图 | `assets/widget_previews/*.png`，与原生 `previewImage` 是**同一张位图**（生成脚本一次产出两份），不可能出现「预览与实际不符」 |

> **说明卡右侧那个刷新按钮做两件事**（缺一不可，因为它们是两类不同步）：
>
> 1. **重新算一遍快照推给桌面** —— 在 App 里改了成员、补了记录之后，桌面该跟着变
>    （平时由写操作自动触发，这里是手动兜底）；
> 2. **重读桌面上已放置的组件列表** —— 用户可能在桌面加了或删了组件。
>
> 早期只做了第 2 件、不给任何反馈，tooltip 还写成「重新读取」，结果就是
> 「点了没反应，也不知道它在更新什么」。现在点击时图标转一圈、完成弹
> 「已重新同步到桌面」、同步中置灰防连点，tooltip 也改成
> 「把最新数据重新同步到桌面」。
| 一键添加 | `AppWidgetManager.requestPinAppWidget`（Android 8.0+），系统弹出确认框 |
| 不支持时 | 通道返回 `false`，页面转为引导「长按桌面空白处 → 小组件 → 屙了么」 |

对应通道方法：`requestPinWidget {type}`，`type ∈ {small, medium, large}`。

---

## 6. 交互行为与 Deep Link 契约

| 触发热区 | 路由 / 动作 | 行为 |
|---|---|---|
| 点击成员区（小/中号） | 原生 `WidgetConfigActivity` | **原地换人**，不打开 App |
| 点击成员胶囊（大号顶部） | 原生 `WidgetConfigActivity` | 同上 —— 三款组件的换人入口位置与反应必须一致 |
| 点击「＋现在开屙」 | 广播 → 后台引擎 | **不打开 App**，为**绑定那一位**开屙 |
| 点击「✓完成/完成打卡」 | 广播 → 后台引擎 | **不打开 App**，结束**绑定那一位**的计时 |
| 点大号某一行 / 该行的记一次·帮记 | 广播 → 后台引擎 | **不打开 App**，只作用于**这一行那一位** |
| 点大号底部主按钮 | 广播 → 后台引擎 | **不打开 App**，只作用于**成员胶囊上那一位** |
| 点击周历某一格 | `poopedyet://calendar?date={YYYY-MM-DD}` | 打开 App 并定位到该日 |
| 点击「补录便签」 | `poopedyet://action/create_manual` | 打开 App 并弹出补录底表 |
| 点击「打开日历」 | `poopedyet://calendar` | 打开 App 月历 |
| 点击卡片空白处 | `poopedyet://main` | 打开 App 主页 |

### 6.1 状态归属：谁在屙，只影响谁

这是多人场景下最容易做错的地方。三条规则：

1. **每个组件只反映自己绑定那一位。** 顶层 `liveSession` 是「全家最新的一条进行中记录」，
   只配给锁屏胶囊/前台服务用；渲染任何单人卡片都必须走 `liveStateOf(familyMembers, pooperId)`
   —— 否则家里有人开屙，绑定别人的组件也会切成「完成打卡」，点下去结束的是别人的计时。
2. **4×4 逐行独立。** 每一行显示该行那一位自己的计时（绿色「正在屙 · 已用 N 分钟」），
   按钮相应变成「完成」；没在屙的行保持常态。底部主按钮**只跟随成员胶囊上那一位**。
3. **所有统计都按人取，不回落全家。** 今日次数、上次时间、距上次多久、连续天数、
   周历打卡点，一律从 `familyMembers` 里按 `targetId` 查。曾经用
   `currentMember?.optInt(...) ?: todaySummary.optInt(...)` 这种「取不到就退回全家」的写法，
   结果就是绑定 haohao 的组件显示着 xiaojie 的次数。

`liveSession` 同时带上了 `pooperId` / `pooperName`：家里两个人可能同时开着计时，
通知栏显示成默认成员的名字会让人以为记错了人。

`PendingIntent` 的 requestCode 以「用途偏移 + widgetId」区分（如小号换人 `10000 + widgetId`），保证多实例互不覆盖。

**计时器**一律使用系统级 `Chronometer` + `setChronometer(base, "%s", true)`，以 `SystemClock.elapsedRealtime()` 反推基准。用静态文本渲染秒表会在快照不刷新时「一直显示 0 分钟」—— 这是 v1.0 的 bug，v2.0 全线改用原生驱动。

---

## 7. 数据架构与跨进程同步

```text
┌─────────────────────────────────────────────────────────────┐
│ Flutter 主应用 (Drift SQLite / Riverpod)                     │
│ 开屙 · 结束 · 补录 · 改人 · 改设置                             │
│   → WidgetSnapshotService.buildSnapshot()                   │
│   → WidgetSyncManager.sync()                                │
└──────────────────────────────┬──────────────────────────────┘
                               │ MethodChannel('com.poopedyet.app/widget')
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 原生侧 WidgetDataProvider                                    │
│  · SharedPreferences 快照 + 内存级缓存                        │
│  · widget_pooper_<appWidgetId> 成员绑定                       │
└──────────────────────────────┬──────────────────────────────┘
                               │ triggerUpdateAll()
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SmallWidgetProvider / MediumWidgetProvider / LargeWidgetProvider │
│  RemoteViews 渲染 + Chronometer 原生跳秒                       │
└─────────────────────────────────────────────────────────────┘
```

### 快照契约（v2.0 增量）

```jsonc
{
  "updatedAt": "2026-10-18T14:26:00",
  "isIncognito": false,
  "defaultPooper": { "id": "pooper_1", "name": "我", "iconKey": "dog",
                     "avatarBase64": "…", "initial": "我",
                     "colorBg": "#F7E5D2", "colorFg": "#B4662F" },
  "liveSession": { "isLive": false, "recordId": null,
                   "startedAtMillis": null, "elapsedMinutes": 0 },
  "todaySummary": { "dateStr": "2026-10-18", "dayNum": 18, "weekdayName": "周六",
                    "totalCount": 2, "lastTimeStr": "14:15",
                    "hoursSinceLast": 4, "lastRemark": "顺畅" },
  "weekStreakDays": 5,
  "weekDays": [
    {
      "dateStr": "2026-10-18", "dayNum": 18, "weekday": 7, "weekdayLabel": "日",
      "isToday": true, "isHoliday": false, "isWorkday": false,
      "count": 2,                      // 全家汇总
      "iconKeys": ["dog"],
      "pooperCounts": { "pooper_1": 2 }  // ★ v2.0：按成员拆分，周历据此点亮
    }
  ],
  "familyMembers": [
    { "id": "pooper_1", "name": "我", "iconKey": "dog", "avatarBase64": "…",
      "initial": "我", "colorBg": "#F7E5D2", "colorFg": "#B4662F",
      "todayCount": 2, "lastTimeDesc": "今日 2 次 · 14:15",
      "lastTimeStr": "14:15", "hoursSinceLast": 4, "lastRemark": "顺畅",
      "isArchived": false,          // ★ 归档成员也留在快照里（见 §4.5）
      "isLive": true,               // ★ 这位此刻在不在屙
      "liveRecordId": "rec_9",      // ★ 结束按钮要用的记录 id
      "liveStartedAtMillis": 1760000000000,
      "streakDays": 5 }             // ★ 这位自己的连续天数
  ],
  "recentNote": { "pooperName": "我", "iconKey": "dog", "timeStr": "14:15",
                  "durationMinutes": 11, "text": "喝完温水后排空…" },
  "weeklySummary": {             // ★ 4×4 底部小结卡的主信息
    "totalCount": 12,            //   本周全家合计
    "activeDays": 6,             //   本周有记录的天数
    "mostActiveName": "我",      //   本周最勤的那位
    "mostActiveCount": 6
  }
}
```

`familyMembers` 是三个新界面的共同数据源：配置浮层的成员列表、App 管理页的绑定展示、以及每位成员自己的统计回退。

---

## 8. 落地状态

| 能力 | 状态 | 位置 |
|---|---|---|
| 现代卡片风视觉体系 | ✅ | `values/colors.xml` · `values-night/colors.xml` · `drawable/bg_*.xml` |
| 2×2 / 4×2 / 4×4 布局重做 | ✅ | `layout/widget_small.xml` · `widget_medium.xml` · `widget_large.xml` |
| 成员头像与姓名放大 | ✅ | 三个 Provider 的 `WidgetAvatarHelper.createAvatarBitmap(..., 40/36/34)` |
| 添加时配置向导 | ✅ | `WidgetConfigActivity` · `layout/widget_config.xml` |
| 点击组件原地换人 | ✅ | 三个 Provider 的 `buildConfigPendingIntent()` |
| `reconfigurable`（长按编辑） | ✅ | 三个 `*_widget_info.xml` |
| App 内小组件管理页 | ✅ | `lib/src/ui/settings/widget_manager_page.dart` |
| App 内预览图 + 一键添加 | ✅ | `assets/widget_previews/` · 通道 `requestPinWidget` |
| 通道读写绑定 | ✅ | `MainActivity` · `lib/src/widget/widget_binding.dart` |
| 真实预览图（12+ / 11-） | ✅ | `android:previewLayout` · `.design/build-widget-previews.py` |
| 选择器逐个命名 | ✅ | `AndroidManifest.xml` 的 `android:label` |
| 周历按成员点亮 | ✅ | 快照 `pooperCounts` · `MediumWidgetProvider.renderWeekStrip()` |
| 三款组件换人入口统一 | ✅ | 大号标题栏成员胶囊 + 绑定成员置顶 |
| 成员生命周期联动绑定 | ✅ | `pooper_actions.dart` 的两个 `*AndDetachWidgets` |
| 快照保留归档成员 | ✅ | `familyMembers[].isArchived` |
| 头像支持内置 Lucide 图标 | ✅ | `WidgetAvatarHelper` + `drawable/ic_pooper_*.xml` |
| 冷启动同步快照 | ✅ | `databaseProvider` |
| 彻底删除成员（含记录） | ✅ | `countRecordsOf` · `purgePooperAndDetachWidgets` · 列表页与编辑页两个入口 |
| 返回转场跟随手势边缘 | ✅ | `smooth_page_route.dart` 读取 `PredictiveBackEvent.swipeEdge` |
| 状态按绑定成员隔离 | ✅ | `liveStateOf()` · 三个 Provider 不再读顶层 `liveSession` |
| 4×4 逐行显示各自计时 | ✅ | `LargeWidgetProvider` 每行独立判断 + 行内「完成」 |
| 统计一律按成员取（不回落全家） | ✅ | 今日次数 / 上次时间 / 距上次 / `streakDays` |
| 开屙·完成后台执行不跳 App | ✅ | `WidgetActionReceiver` · `WidgetActionRunner` · 根库入口 `widgetActionMain` |
| 4×4 底部为本周小结 + 7 天节律 | ✅ | `weeklySummary`；便签退成一行、无则隐藏 |
| 换人暗示三款统一 | ✅ | 整块成员区可点 + 姓名紧跟下拉线 |
| iOS / 锁屏 / 灵动岛 | ⬜ | 本仓库暂无 iOS 工程，`docs` 中保留设计意向 |
