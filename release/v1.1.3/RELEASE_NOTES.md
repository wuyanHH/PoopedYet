# 屙了么 PoopedYet v1.1.3 正式版发版说明

> 记录每一次舒畅时刻的温润手帐 · 纯本地私密存储 · 温暖治愈系日历打卡

- 发布版本：v1.1.3（versionCode: 101301）
- 发版日期：2026 年 10 月
- 项目地址：[https://github.com/wuyanHH/PoopedYet](https://github.com/wuyanHH/PoopedYet)

---

## 本次更新内容

### 一、设置页拆分成四个专页

原先一整页的长列表按用途拆开，找配置项不用再一路往下滚：

| 专页 | 负责范围 |
| --- | --- |
| 外观与主题 | 深浅模式（跟随系统 / 亮 / 暗）、五套手账色系，顶部配实时响应的预览卡 |
| 日历与打卡视图 | 默认视图（月 / 周）、每周起始日、记录排列顺序、格内字号、头像与次数角标、休班角标、周末强调色、归档成员可见性、法定节假日数据 |
| 通知与实时胶囊 | 开屙实时灵动胶囊总开关、系统通知权限状态，以及 vivo 原子岛 / 小米焦点通知 / ColorOS 流体云的适配说明 |
| 关于屙了么 | 品牌 Header、自动检查更新、手动检查新版本、版本演进日志、开源许可与致谢 |

主设置页从 1000 余行拆到约 200 行，原先堆在页面里的主题选择器、节假日同步行、暗号模式行、灵动胶囊行分别迁入对应专页。

### 二、实时灵动胶囊可以单独关闭

新增「开屙实时灵动胶囊」开关（`Settings.liveIslandEnabled`，默认开启）。关闭后开屙不再展示前台通知，也不再启动前台服务；原生侧补充 `stopLiveIsland` 通道方法，运行中即可立即收掉胶囊。

通知渠道由 `poop_live_island_v4` 升级为 `poop_live_capsule_v5`，并显式清理 v3 / v4 残留渠道——旧渠道被系统静音降级的设置不会带过来。同时补齐 vivo 原子岛、小米焦点通知与 ColorOS 流体云的识别字段。

### 三、修复：1.3 倍系统字号下日历格底部溢出 1 像素

真机上表现为格子下方一条黄黑警戒条。根因是格高预算与实际渲染差了几像素：

- 徽标行实际是 `SizedBox(height: 15)`，预算却按图标 14px 计算，每行少 1px，两行就是 2px；
- 日期行漏算了数字外层 `Padding(top: 1)`，再少 1px。

修法是引入 `kBadgeRowHeight = 15` 与 `_dateTopInset = 1`，让预算与 `DayCell` 的真实结构对齐；同时把日期行与徽标区的间距从 2 收到 1，使 1.3 倍下的余量从 0.15px（字体版本稍有波动就会再次溢出）扩大到 1.15px。两处常量之间加了互相引用的注释，避免以后只改一边。

### 四、修复：左右翻月时偶发的布局时序异常

日历卡高度动画在同模式翻页时传入的是 `Duration.zero`。`AnimationController` 在时长为零时会走同步捷径直接 `notifyListeners()`，而 `RenderAnimatedSize` 的监听器收到值变化就 `markNeedsLayout()`——这条路径发生在 `performLayout` 内部，于是触发框架断言「A RenderObject must not re-dirty itself while still being laid out」。改为 1ms 后走 ticker 分支，值的变化发生在帧回调里，观感上仍是瞬时。

### 五、便便感受胶囊：整套联动过渡

选中与取消原先用「渐变与纯色」互换表达，而 `BoxDecoration.lerp` 无法在渐变与纯色之间插值，切换时会硬切一下，看起来像「胶囊变色了但文字还在跳」。现统一走 `color`，底色、描边、阴影与文字颜色同步淡入淡出；`AnimatedScale` 与 `AnimatedContainer` 的时长曲线一并校准，点击也不再引起位置重排。

### 六、转场与沉浸式边到边

- 页面转场回归官方 `MaterialPageRoute` 配合 `PageTransitionsTheme`：Android 使用 `PredictiveBackPageTransitionsBuilder`（`fallbackColor` 取纸张色，避免深色主题下转场闪亮底），iOS 补上原生 `CupertinoPageTransitionsBuilder`，桌面使用 `FadeForwards`；
- 接入 `SystemUiMode.edgeToEdge` 与 `WindowCompat.setDecorFitsSystemWindows(false)`，系统导航栏改为透明并关闭对比度强制，内容延伸到状态栏与手势条之后，不再出现一条硬边色带。

### 七、记录详情：已完成记录不再假装有一个主操作

已完成的记录，底部那颗焦糖渐变大按钮其实什么也不做，只是关掉弹层，却因为又大又亮而成为视觉焦点。现改为次要样式的「关闭」按钮（`SheetGhostButton`，与「删除」等宽并列）；只有进行中的记录才保留主按钮「完成打卡」，并真正写入结束时间。

### 八、其他

- 防社死暗号模式的开关并入「桌面小组件」管理页，切换后立即重推小组件快照，桌面文案即时生效；
- 移除已不再使用的 `CutePoopIcon` 组件。

---

## 各架构发布包

每个架构均同时提供标准 APK 与 ZIP 压缩包：

| 文件名称 | 说明与推荐受众 | 体积 |
| --- | --- | --- |
| `PoopedYet-v1.1.3-arm64-v8a.apk` | 现代 Android 智能手机（64 位 ARM，强烈推荐首选） | 17.5 MB |
| `PoopedYet-v1.1.3-arm64-v8a.zip` | arm64-v8a 安装包的 ZIP 压缩归档 | 17.2 MB |
| `PoopedYet-v1.1.3-universal.apk` | 全架构集成通用版（兼容所有 Android 32 / 64 位设备与模拟器） | 36.3 MB |
| `PoopedYet-v1.1.3-universal.zip` | 全架构通用版安装包的 ZIP 压缩归档 | 35.9 MB |
| `PoopedYet-v1.1.3-armeabi-v7a.apk` | 早期 32 位 Android 旧机型 | 17.1 MB |
| `PoopedYet-v1.1.3-armeabi-v7a.zip` | 32 位旧架构安装包的 ZIP 压缩归档 | 16.9 MB |
| `PoopedYet-v1.1.3-x86_64.apk` | PC Android 模拟器、Intel / AMD x86_64 平板设备 | 17.7 MB |
| `PoopedYet-v1.1.3-x86_64.zip` | x86_64 安装包的 ZIP 压缩归档 | 17.4 MB |
| `PoopedYet-v1.1.3-release.aab` | Google Play 官方标准 App Bundle 上架原包 | 69.5 MB |
| `PoopedYet-v1.1.3-release-aab.zip` | Google Play AAB 原包的 ZIP 压缩归档 | 69.1 MB |
| `PoopedYet-v1.1.3-all-apks.zip` | 包含以上全部 4 个架构 APK 的离线合集压缩包 | 87.4 MB |

---

## SHA-256 完整性校验和

```text
dd9079ff4a06052c8b0cc88211adcf85a95344522d145cb903db2163b6d0c781  PoopedYet-v1.1.3-all-apks.zip
8678760ef7f59f27507b0f5c7beeb07907ea929da3b56e11ab591bf3c6fd804f  PoopedYet-v1.1.3-arm64-v8a.apk
491b327ab44e4b93ba0955342eef243358885a3a4bcc5a8efc5c1c6e75b1ab1f  PoopedYet-v1.1.3-arm64-v8a.zip
59e2c840a1d79b98ebc61152a99ed09e04bbdbdbd1ef573cec393e419e659972  PoopedYet-v1.1.3-armeabi-v7a.apk
9bd17cbb6b1fd943b955ea16992e61289dde29259b8429ebcd32dfc123fcc9ab  PoopedYet-v1.1.3-armeabi-v7a.zip
bea3d3dca8d2465640c09ce8be7f30a17006ff29d74ee92f3afe9c74d6dbc8dd  PoopedYet-v1.1.3-release-aab.zip
a771b4c739847d42ef67e33718304d2709da513f4f30c67fc32beeed4485cf7a  PoopedYet-v1.1.3-release.aab
858e6f55cf51586512fa75a74a710d37b03a786573294ac136e70c4278f2efc7  PoopedYet-v1.1.3-universal.apk
e315f8b64c8cac96a6a4b8873a7c9afb3c44ae88a963968731f494f537f4b3c2  PoopedYet-v1.1.3-universal.zip
c8334feb2e2a689a62cd8e70e6022c7ef723ba34edf59a299cbb3375170aa6c7  PoopedYet-v1.1.3-x86_64.apk
140f770faadd62491a9e0e8d8ba9bb91cac783a069f483a9175bc76dd8fc2e45  PoopedYet-v1.1.3-x86_64.zip
```

---

## 升级说明

应用内「设置 - 关于屙了么 - 检查新版本」即可看到本版本，点「立即下载」会按本机 CPU 架构下载对应安装包并一键安装。数据全部保存在本地 SQLite，覆盖安装不影响既有记录。
