# 屙了么 PoopedYet v1.1.2 正式版发版说明

> **记录每一次舒畅时刻的温润手帐 · 纯本地私密存储 · 温暖治愈系日历打卡**

- **发布版本**：v1.1.2 (versionCode: 101200)
- **发版日期**：2026年10月
- **项目地址**：[https://github.com/wuyanHH/PoopedYet](https://github.com/wuyanHH/PoopedYet)

---

### 🌟 本次更新亮点

本次是一个**围绕桌面小组件与记录闭环的集中修复版**，四条用户反馈全部定位到根因并修复。

#### 1. 切换小组成员不再把 App 拽到前台

以前点小组件的成员区，浮层确实弹出来了，但整个应用也一起被顶到最前面，浮层关掉之后 App 还赖在屏幕上。

**根因**：`PendingIntent.getActivity` 必须带 `FLAG_ACTIVITY_NEW_TASK`，而配置页的默认 `taskAffinity` 就是包名 —— 系统会**复用 App 自己的任务栈**，把 MainActivity 连同整个 App 一起拉到前台。

**修法**：为「换人」单独开一个 `activity-alias`（`taskAffinity=""` + `singleInstance` + `excludeFromRecents`），让它跑在自己的空 affinity 任务里，关掉浮层即回桌面。

> 不能直接给真实 Activity 加 `taskAffinity=""`：系统「添加组件」走的是 `startActivityForResult`，目标一旦被挪进另一个任务，Android 会立刻按 `RESULT_CANCELED` 回传，桌面上就永远放不出组件。所以拆成两条路 —— **添加走真实 Activity，换人走别名**，代码侧还留了 `resolveActivity` 兜底。

#### 2. 换人浮层重做：有动画了，也不卡了

| 现象 | 根因 |
|---|---|
| 背景变化很奇怪 | 用的是 `Theme.Material.Dialog` + 系统 `backgroundDim`，变暗是**直接切换**、没有任何过渡 |
| 没有动画 | Dialog 主题那套老缩放转场在新系统上基本不播 |
| 卡顿 | 成员列表在主线程**同步 base64 解码每一个头像**；高度用 `post{}` 回填，先铺满再缩回去抖一帧 |

- 主题改为透明窗口自绘遮罩 + 自定义转场：遮罩淡入 220ms、退出 160ms，卡片在 `onResume` 从下方 26dp 上滑淡入（放 `onResume` 是因为 `onCreate` 时窗口往往还没可见，动画会白跑掉大半段）；
- 新增 `MaxHeightScrollView`，在 `onMeasure` 里一次封顶，**彻底去掉二次布局**；
- 头像改为后台解码 + `LruCache` 缓存，主线程先挂占位图，成员再多也不会堵住首帧；
- 成员行补上系统涟漪反馈（原来是纯 shape，按下去整整一帧没有任何视觉变化）；
- 顺手修掉一个隐藏 bug：卡片没设 `clickable`，**点卡片空白处会穿透到遮罩把浮层关掉**。

#### 3. 记录详情里点「完成」现在真的会结束记录

打开一条正在屙的记录、点底部那颗焦糖色大按钮，记录却依然挂在进行中 —— 因为它**无论什么状态都只关闭弹层**。

现在：进行中（含超阈值待确认）时按钮文案变「完成打卡」并真正写入结束时间；已结束的记录才保留「完成 = 关闭弹层」这个编辑收尾语义。刻意不把「未记结束」算作进行中 —— 给一条三天前的记录补一个"现在结束"，只会把时长算得更离谱。

#### 4. 冷启动时点小组件「开屙 / 完成」不再没反应

这是最难复现的一条，**App 只要还活着就一切正常，进程被回收后才失灵**：

```text
App 进程活着 → FlutterLoader 已 initialized → 两个初始化方法提前 return → 侥幸能用
进程被回收   → initialized == false → 走到 @UiThread 断言
             → IllegalStateException → 被 catch 吞掉 → 动作直接丢弃
```

引擎源码里 `startInitialization` / `ensureInitializationComplete` 都带主线程断言，而后台执行器把整个准备过程放在了后台线程。

- 引擎启动**全程回归主线程**；
- 广播接收端改用 `goAsync()` 攥住 `PendingResult` 保活 —— 冷启动那一秒进程随时可能被系统回收；
- 加轮次令牌丢弃迟到回调，否则「超时兜底 + Dart 迟到回报」会把**下一个**动作悄悄吞掉；
- 加 8 秒看门狗，防止 Dart 一直不回报把广播拖成 ANR。

#### 5. 顺带修复：锁屏胶囊的「完成打卡」在冷启动时被丢弃

`configureFlutterEngine` 里抢跑 `invokeMethod("onDeepLink")`，而那一刻 **Dart 的 `main()` 还没开始跑**、`setMethodCallHandler` 更没注册，调用 100% 被丢弃；排队字段又被清空，Dart 稍后主动来拉也拉不到 —— 于是「App 打开了、记录却没结束」。

改成拉取式握手：Dart 首次调用 `getPendingDeepLink` 才算就绪，那之前来的链接一律排队；`configureFlutterEngine` 里同时把就绪标志归零（Activity 重建等于换了一个全新的 Dart isolate）；再加一道 `resumed` 补拉兜底。

---

### 📦 各架构发布包与压缩包资产清单

本次发布针对所有架构均同时提供 **标准 APK 安装包** 与 **ZIP 压缩包**，可按需下载：

| 文件名称 | 说明与推荐受众 | 体积 |
|---|---|---|
| **`PoopedYet-v1.1.2-arm64-v8a.apk`** | 现代 Android 智能手机（64 位 ARM，强烈推荐首选） | 17.5 MB |
| **`PoopedYet-v1.1.2-arm64-v8a.zip`** | arm64-v8a 安装包的 ZIP 压缩归档 | 17.2 MB |
| **`PoopedYet-v1.1.2-universal.apk`** | 全架构集成通用版（兼容所有 Android 32/64 位设备与模拟器） | 36.2 MB |
| **`PoopedYet-v1.1.2-universal.zip`** | 全架构通用版安装包的 ZIP 压缩归档 | 35.8 MB |
| **`PoopedYet-v1.1.2-armeabi-v7a.apk`** | 早期 32 位 Android 旧机型 | 17.1 MB |
| **`PoopedYet-v1.1.2-armeabi-v7a.zip`** | 32 位旧架构安装包的 ZIP 压缩归档 | 16.8 MB |
| **`PoopedYet-v1.1.2-x86_64.apk`** | PC Android 模拟器、Intel/AMD x86_64 平板设备 | 17.7 MB |
| **`PoopedYet-v1.1.2-x86_64.zip`** | x86_64 安装包的 ZIP 压缩归档 | 17.4 MB |
| **`PoopedYet-v1.1.2-release.aab`** | Google Play 官方标准 App Bundle 上架原包 | 69.4 MB |
| **`PoopedYet-v1.1.2-release-aab.zip`** | Google Play AAB 原包的 ZIP 压缩归档 | 69.0 MB |
| **`PoopedYet-v1.1.2-all-apks.zip`** | 包含以上全部 4 个架构 APK 的离线合集压缩包 | 87.3 MB |

---

### 🔐 SHA-256 完整性校验和

```text
a6c5c74aa09f7f1745adb9ae31b581fe6a082c76ef90a2e9dd5e9f68261d55d2  PoopedYet-v1.1.2-all-apks.zip
909123829519bb7535dd8b2e8a11c36f7a914e1d2c7927d328646951fe9d1395  PoopedYet-v1.1.2-arm64-v8a.apk
75407fcdb38752464e2b2be8a936f517227cf5f12613605d8bb7e20bc1b06e9a  PoopedYet-v1.1.2-arm64-v8a.zip
544be6b00491dd456941e684bd5a049d7d27e1ccc50d5fee0cfe99e689cc6a6b  PoopedYet-v1.1.2-armeabi-v7a.apk
d8d32cfba2fcc2b7dfb36b8bed21af57b2ef3114386564082ff9fc3d36171ee1  PoopedYet-v1.1.2-armeabi-v7a.zip
ce93a48428c018f3c5b932c8612e8f7718d775e3ede5b2d28910b26b9fcc9618  PoopedYet-v1.1.2-release-aab.zip
9e03176bdf27fd90e5d42c7e352c3db579fe49842ea986c95e9800763788a0ec  PoopedYet-v1.1.2-release.aab
55f41cffa48b636ee8fbe5ea044fc77dcc78eb216d024bb4f8b14c52d717c7d5  PoopedYet-v1.1.2-universal.apk
b41b49c8b1f6a9ccf7e38c2e9f29616a8469e7fd355784a5ce9613218d5cee78  PoopedYet-v1.1.2-universal.zip
175775a309ef81d74073e3d741ffcf57f12142751b69252fef26da522255c247  PoopedYet-v1.1.2-x86_64.apk
12b179a2dc70e54db116b00c261ca101b0dcda418564031d9e06c6cfd3e5710b  PoopedYet-v1.1.2-x86_64.zip
```

---

### ⬆️ 从 v1.1.1 升级

应用内「设置 → 检查新版本」即可看到本版本，点「立即下载」直接在本机下载对应架构安装包并一键安装。数据全部保存在本地 SQLite，升级不会影响既有记录。
