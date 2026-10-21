# 屙了么 PoopedYet v1.1.5 正式版发版说明

> 记录每一次舒畅时刻的温润手帐 · 纯本地私密存储 · 温暖治愈系日历打卡

- 发布版本：v1.1.5（versionCode: 101500）
- 发版日期：2026 年 10 月
- 项目地址：[https://github.com/wuyanHH/PoopedYet](https://github.com/wuyanHH/PoopedYet)

---

## 本次更新内容

### 一、关于页新增「开源项目主页」入口

「关于屙了么」的协议与致谢区新增 GitHub 仓库主页入口：

- 点击唤起外部浏览器直达项目主页；
- 浏览器不可用时自动复制仓库链接到剪贴板兜底，并给出提示；
- 长按该行任意位置可直接复制仓库地址。

### 二、自动检查更新的节流间隔由 24 小时缩短为 6 小时

启动静默检查更新变得更勤快：发版节奏加快后，新版本能更快送达用户。仍保持原有克制原则——无更新或网络失败时全程无声、不打扰，只有真发现新版本才弹窗，同一版本只提醒一次。

设置页「自动检查更新」的间隔副标题、重开开关时的说明文案与项目 README 已同步更新。

### 三、组件能力沉淀

`SettingsRow` 通用设置行组件补充长按手势支持（`onLongPress`），供各设置页复用。

---

## 各架构发布包

每个架构均同时提供标准 APK 与 ZIP 压缩包：

| 文件名称 | 说明与推荐受众 | 体积 |
| --- | --- | --- |
| `PoopedYet-v1.1.5-arm64-v8a.apk` | 现代 Android 智能手机（64 位 ARM，强烈推荐首选） | 14.8 MB |
| `PoopedYet-v1.1.5-arm64-v8a.zip` | arm64-v8a 安装包的 ZIP 压缩归档 | 14.5 MB |
| `PoopedYet-v1.1.5-universal.apk` | 全架构集成通用版（兼容所有 Android 32 / 64 位设备与模拟器） | 33.6 MB |
| `PoopedYet-v1.1.5-universal.zip` | 全架构通用版安装包的 ZIP 压缩归档 | 33.2 MB |
| `PoopedYet-v1.1.5-armeabi-v7a.apk` | 早期 32 位 Android 旧机型 | 14.4 MB |
| `PoopedYet-v1.1.5-armeabi-v7a.zip` | 32 位旧架构安装包的 ZIP 压缩归档 | 14.1 MB |
| `PoopedYet-v1.1.5-x86_64.apk` | PC Android 模拟器、Intel / AMD x86_64 平板设备 | 15.0 MB |
| `PoopedYet-v1.1.5-x86_64.zip` | x86_64 安装包的 ZIP 压缩归档 | 14.7 MB |
| `PoopedYet-v1.1.5-release.aab` | Google Play 官方标准 App Bundle 上架原包 | 66.8 MB |
| `PoopedYet-v1.1.5-release-aab.zip` | Google Play AAB 原包的 ZIP 压缩归档 | 66.4 MB |
| `PoopedYet-v1.1.5-all-apks.zip` | 包含以上全部 4 个架构 APK 的离线合集压缩包 | 76.5 MB |

---

## SHA-256 完整性校验和

```text
dbbd570e4681350f8efda158068ba70f9035cbd8650913d94cc66a830895ffe3  PoopedYet-v1.1.5-all-apks.zip
d03356e11512d207bc052e5b68521892da5f6d6247feb4d7175f53857fdfc131  PoopedYet-v1.1.5-arm64-v8a.apk
d95d0d728b87422eabe62b6cc03a099b2d02d5011ec4b17ac5c11e487f968c05  PoopedYet-v1.1.5-arm64-v8a.zip
4545b0bbf172e1114ec274ede1324e839c096c9854fd1db847724a60854996cf  PoopedYet-v1.1.5-armeabi-v7a.apk
7a142dc23118e7f9c204597d9c802738ffb907e72342f8aa7c3fa43be5917168  PoopedYet-v1.1.5-armeabi-v7a.zip
56d4cefcb8605ca87a0c0f725485da56fb2e8d4f6108d2c3d00f6eced5799009  PoopedYet-v1.1.5-release-aab.zip
8c7e34262cc51f6c6415e26029166c7de90d38a836f62d0245954ca75c94086d  PoopedYet-v1.1.5-release.aab
27cfbf1aa8338a41fbe70257b999aee3cc6a1d14a5c7473fd911424886829cc6  PoopedYet-v1.1.5-universal.apk
873812a9a687f15675c67be31ad8a88530fe11a8b5138210df565ad49320eb70  PoopedYet-v1.1.5-universal.zip
01c522da5518300c96c5fe93ad6a494ade27b221d2341af56e7fe0c54a91e69b  PoopedYet-v1.1.5-x86_64.apk
4afbba5549dd0b1e51ef4c4ff562ffbdd33217313e4da88cffb28ffc318ee78d  PoopedYet-v1.1.5-x86_64.zip
```

---

## 升级说明

应用内「设置 - 关于屙了么 - 检查新版本」即可看到本版本，点「立即下载」会按本机 CPU 架构下载对应安装包并一键安装。数据全部保存在本地 SQLite，覆盖安装不影响既有记录。
