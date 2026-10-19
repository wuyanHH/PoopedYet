# 屙了么 PoopedYet v1.1.0 正式版发版说明

> **记录每一次舒畅时刻的温润手帐 · 纯本地私密存储 · 温暖治愈系日历打卡**

- **发布版本**：v1.1.0 (versionCode: 101000)
- **发版日期**：2026年10月
- **项目地址**：[https://github.com/1348188459/PoopedYet](https://github.com/1348188459/PoopedYet)

---

### 🌟 核心更新与亮点

#### 1. 桌面小组件 2.0 体系全面进化
- **34 种专属成员矢量图标体系**：全量内置精选 Lucide 矢量图标，日历、列表、桌面小组件全链路统一呈现成员专属视觉符号；
- **长按桌面小组件配置向导 (`WidgetConfigActivity`)**：支持长按桌面小组件即时唤起手帐配置面板，灵活指派绑定屙屎人、切换暗号脱敏模式；
- **设置页新增「桌面小组件」管理专页**：全新可视化小组件专区，提供高清实机撕历打卡 (2×2)、手帐周历 (4×2)、健康透视 (4×4) 预览与添加指南；
- **全链路原子化快照推流**：打卡开始、完成、编辑、补录与数据还原后，双向零延迟自动刷新小组件与前台胶囊。

#### 2. 全场景自动化云同步 (Auto Sync)
- **轻量后台静默云同步**：打卡、编辑、删除记录后自动触发后台增量同步，无需手动频繁点击；
- **WebDAV 容错与状态机优化**：支持坚果云、自建 NAS 等，智能折叠配置面板，优化增量合并与覆盖还原。

#### 3. 应用内智能更新与芯片架构识别
- **芯片指令集智能识别**：精准识别手机 CPU 架构（arm64-v8a、armeabi-v7a、x86_64），自动推荐体积最小（省流 50%+）、性能最佳的专属包；
- **自适应深浅色手帐更新弹窗**：支持免打扰跳过版本、静默后台轮询与一键唤起外部浏览器下载。

#### 4. 触觉阻尼手感与转场动效深度打磨
- **自研 SmoothPageRoute 转场**：全链路接入平滑优雅的手帐翻页级过渡动画；
- **卡片自研物理阻尼弹簧抽屉**：侧滑越过阈值瞬间触发系统级触觉震动反馈（HapticFeedback），操作手感更确定；
- **重绘隔离优化**：主页打卡卡片精确挂载 RepaintBoundary，彻底消除高频脉冲动画引起的图层重绘开销。

---

### 📦 各架构发布包与压缩包资产清单

本次发布针对所有架构均提供了 **标准 APK 安装包** 与 **ZIP 压缩包**，可按需下载：

| 文件名称 | 说明与推荐受众 | 体积 |
|---|---|---|
| **`PoopedYet-v1.1.0-arm64-v8a.apk`** | 现代 Android 智能手机（64位 ARM，强烈推荐首选） | 17.4 MB |
| **`PoopedYet-v1.1.0-arm64-v8a.zip`** | arm64-v8a 安装包的 ZIP 压缩归档 | 17.1 MB |
| **`PoopedYet-v1.1.0-universal.apk`** | 全架构集成通用版（兼容所有 Android 32/64 位设备与模拟器） | 36.1 MB |
| **`PoopedYet-v1.1.0-universal.zip`** | 全架构通用版安装包的 ZIP 压缩归档 | 35.7 MB |
| **`PoopedYet-v1.1.0-armeabi-v7a.apk`** | 早期 32 位 Android 旧机型 | 17.1 MB |
| **`PoopedYet-v1.1.0-armeabi-v7a.zip`** | 32 位旧架构安装包的 ZIP 压缩归档 | 16.8 MB |
| **`PoopedYet-v1.1.0-x86_64.apk`** | PC Android 模拟器、Intel/AMD x86_64 平板设备 | 17.6 MB |
| **`PoopedYet-v1.1.0-x86_64.zip`** | x86_64 安装包的 ZIP 压缩归档 | 17.4 MB |
| **`PoopedYet-v1.1.0-release.aab`** | Google Play 官方标准 App Bundle 上架原包 | 69.1 MB |
| **`PoopedYet-v1.1.0-release-aab.zip`**| Google Play AAB 原包的 ZIP 压缩归档 | 68.7 MB |
| **`PoopedYet-v1.1.0-all-apks.zip`** | 包含以上所有 4 个架构 APK 的全集离线打包大合集 | 87.0 MB |

---

### 🔐 SHA-256 完整性校验和

```text
893b8b54023c98f147e2c4c7f7169b65fbdd896c7016a09943e7acffce95c11b  PoopedYet-v1.1.0-all-apks.zip
c90c012dcb131d40916b95bb29d4559d475d4ae6c89e6bc65f5e094f1fbe391f  PoopedYet-v1.1.0-arm64-v8a.apk
3380d57231971ff2675903fbb0c5b210801d49969ee2303fcbf3d429786298cf  PoopedYet-v1.1.0-arm64-v8a.zip
88eb210b4b6c6a0f86036dd7423d565bb2003a1d4294d4cc4cd8e4108dcce81f  PoopedYet-v1.1.0-armeabi-v7a.apk
81d9f46623c712f2f8621a49d14ee83424b1bf94dd7f7411efc29f4fa046fc18  PoopedYet-v1.1.0-armeabi-v7a.zip
7b1201655ba1657e4d6315ed360439c499fb1a8561af789b362cd413581c6b94  PoopedYet-v1.1.0-release-aab.zip
f492fca022e77d8e39dc5a1a3c48b3ce7d5aa4bc965fbc7a4e064b689f83e574  PoopedYet-v1.1.0-release.aab
9f922ea746ed34769cc8e57e008bb933fcfc0e232680d70c131d5c03ea650693  PoopedYet-v1.1.0-universal.apk
ccecf0ef29c82da5ec46a7fcdf06fb2e9d9c1498bd036014051c75908704f366  PoopedYet-v1.1.0-universal.zip
6d9aaa9ec9d9181fd6baae99bd4e3034edb947d1b12ae56239f5c66342334ca7  PoopedYet-v1.1.0-x86_64.apk
d26b25ded203d42c6fc740d8d69b6e09cf25b7b7b0ab5d6afeb4840d91734777  PoopedYet-v1.1.0-x86_64.zip
```
