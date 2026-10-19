# 屙了么 PoopedYet v1.1.1 正式版发版说明

> **记录每一次舒畅时刻的温润手帐 · 纯本地私密存储 · 温暖治愈系日历打卡**

- **发布版本**：v1.1.1 (versionCode: 101100)
- **发版日期**：2026年10月
- **项目地址**：[https://github.com/wuyanHH/PoopedYet](https://github.com/wuyanHH/PoopedYet)

---

### 🌟 本次更新亮点

#### 1. 应用内直下安装 —— 更新不再跳浏览器
- **应用内流式下载**：点「立即下载」后由应用自行流式下载 APK，实时显示百分比、速度与剩余时间，全程不跳外部浏览器；
- **断点续传**：采用 `.part` 临时文件 + HTTP `Range` 续传，网络中断、进程被杀或手动取消之后，下次从已下载字节处继续，不必重下 17 MB；
- **静默后台下载**：点「后台下载并隐藏」后弹窗关闭、下载继续进行，通知栏不出现任何下载通知；主页只保留一条可收起的迷你进度条（收起后是一颗带进度的小圆环），随时能找回来；
- **下载完一键安装**：完成后提示「已下载，点击安装」，走 `FileProvider` 拉起系统安装器；首次会引导到「安装未知应用」授权页，而不是抛一个看不懂的异常；
- **任务序号防串台**：在「其他架构安装包」里连点两个包时，旧任务的取消与失败不会回写覆盖新任务的下载状态；
- **桌面端回退**：Windows 等桌面平台没有这套安装机制，按钮自动退回「前往发布页」走浏览器下载。

> 为什么不用系统 `DownloadManager`：它的通知可见性在不同 Android 版本与定制 ROM 上并不完全受应用控制，而自己用 `HttpClient` 流式写文件天然没有通知，进度也不需要轮询原生。代价是下载活在 Dart isolate 里，因此用断点续传来兜底。

#### 2. 手帐风富文本更新日志
- 自写轻量 Markdown 解析（`changelog_parser.dart`）：块级支持标题、列表、任务列表、引用、分割线与代码块，行内支持粗体、斜体、删除线、行内代码、链接与裸链接；
- 渲染层按项目设计令牌重排，更新弹窗正文不再是纯文本堆砌；
- 顶部新增「新增 / 优化 / 修复」分类条目计数胶囊，一眼看出这次值不值得升。

#### 3. 预测性返回手势与页面转场回归官方实现
- 页面转场从自研 `PageRouteBuilder` 回归 `MaterialPageRoute`，并显式配置 `PageTransitionsTheme`；
- Android 使用官方 `PredictiveBackPageTransitionsBuilder`，Android 14+ 在支持预测性返回的系统上拖动返回时可实时预览上一页，不支持时自动回退 `FadeForwards`；
- `fallbackColor` 固定为纸张色，修掉深色主题下转场闪现一块偏亮底色的问题；
- 顺带修掉了原先「三层动画同时跑 + 方向依赖全局 `ValueNotifier`」造成的方向不直觉问题。

#### 4. 滚动与转场性能治理
- **打卡卡片**：去掉整卡 `BoxShadow`（模糊需按整卡面积离屏渲染）与两层多余 `ClipRRect`，卡片圆角改由自身 decoration 与滑动背景层分别绘制，删除动画复用 `AnimatedBuilder.child`；
- **日历格**：`AnimatedContainer` 改回常驻 `Container` —— 一个月 42 格、翻月时新旧两套网格同时在场，原先等于 84 个隐式动画控制器一起 tick；同时去掉每格圆角裁剪与角标小阴影；
- **当日列表**：去掉包住整个 `ListView` 的 `AnimatedSwitcher`（切日期时新旧两套列表同时渲染），`cacheExtent` 600 → 400；
- **正在屙胶囊**：文字与布局不再随 60fps 呼吸动画每帧重建，自身挂 `RepaintBoundary`，避免把顶栏拖进每帧重绘；
- 修掉卡片弹簧回弹监听器只增不减、多次滑动后一帧内多次 `setState` 的泄漏。

---

### 📦 各架构发布包与压缩包资产清单

本次发布针对所有架构均同时提供 **标准 APK 安装包** 与 **ZIP 压缩包**，可按需下载：

| 文件名称 | 说明与推荐受众 | 体积 |
|---|---|---|
| **`PoopedYet-v1.1.1-arm64-v8a.apk`** | 现代 Android 智能手机（64 位 ARM，强烈推荐首选） | 17.5 MB |
| **`PoopedYet-v1.1.1-arm64-v8a.zip`** | arm64-v8a 安装包的 ZIP 压缩归档 | 17.2 MB |
| **`PoopedYet-v1.1.1-universal.apk`** | 全架构集成通用版（兼容所有 Android 32/64 位设备与模拟器） | 36.2 MB |
| **`PoopedYet-v1.1.1-universal.zip`** | 全架构通用版安装包的 ZIP 压缩归档 | 35.8 MB |
| **`PoopedYet-v1.1.1-armeabi-v7a.apk`** | 早期 32 位 Android 旧机型 | 17.1 MB |
| **`PoopedYet-v1.1.1-armeabi-v7a.zip`** | 32 位旧架构安装包的 ZIP 压缩归档 | 16.8 MB |
| **`PoopedYet-v1.1.1-x86_64.apk`** | PC Android 模拟器、Intel/AMD x86_64 平板设备 | 17.7 MB |
| **`PoopedYet-v1.1.1-x86_64.zip`** | x86_64 安装包的 ZIP 压缩归档 | 17.4 MB |
| **`PoopedYet-v1.1.1-release.aab`** | Google Play 官方标准 App Bundle 上架原包 | 69.4 MB |
| **`PoopedYet-v1.1.1-release-aab.zip`** | Google Play AAB 原包的 ZIP 压缩归档 | 69.0 MB |
| **`PoopedYet-v1.1.1-all-apks.zip`** | 包含以上全部 4 个架构 APK 的离线合集压缩包 | 87.2 MB |

---

### 🔐 SHA-256 完整性校验和

```text
085c4503091f2a345778b356ac1716135f25b14a05775b1da79842f0016bc694  PoopedYet-v1.1.1-all-apks.zip
a5af25fe9edf95c4c60dda66fc076b17ff07ae435a2b958cd9e8a6c9f6c27035  PoopedYet-v1.1.1-arm64-v8a.apk
1aa1afa7a13e65e24ebb03c96f755aaa460fe9042bfe9c52411364512416154a  PoopedYet-v1.1.1-arm64-v8a.zip
45f5b4a0e17f2a72ac3fae80164ca296c6b398d8fecdddfff322ed272bab8cd2  PoopedYet-v1.1.1-armeabi-v7a.apk
9680551bbf051b377b2a969e27175dfa095fbc93c273246f435686e84841e100  PoopedYet-v1.1.1-armeabi-v7a.zip
702fc176dc8839b1b66d82dc094c53050d20f51cfd1ff5d95f68f36b455c52aa  PoopedYet-v1.1.1-release-aab.zip
a6b14ff90b030fc85a74571aa6c5b80b1154acf3a7f404eaa93655bfa4e5aff4  PoopedYet-v1.1.1-release.aab
780f15ded513422daaf5c2285f36166f29e7cbada9c9d398d1501d50e5ac0d3f  PoopedYet-v1.1.1-universal.apk
c71c4a6008644df298c6f7650ba9b2dbd3a0c07f57c21e576ba6eacbb6226560  PoopedYet-v1.1.1-universal.zip
77eac84d2bee99c593acc09dbd72c4bec7045982f13ce92fbfea5d374c5c443c  PoopedYet-v1.1.1-x86_64.apk
59c0f617444c3a02bda4704774ea17ef7680470804128539d152d66b7bbdc5d4  PoopedYet-v1.1.1-x86_64.zip
```

---

### ⬆️ 从 v1.1.0 升级

应用内「设置 → 检查新版本」即可看到本版本，点「立即下载」直接在本机下载对应架构安装包并一键安装。数据全部保存在本地 SQLite，升级不会影响既有记录。
