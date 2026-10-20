# 屙了么 PoopedYet v1.1.4 正式版发版说明

> 记录每一次舒畅时刻的温润手帐 · 纯本地私密存储 · 温暖治愈系日历打卡

- 发布版本：v1.1.4（versionCode: 101400）
- 发版日期：2026 年 10 月
- 项目地址：[https://github.com/wuyanHH/PoopedYet](https://github.com/wuyanHH/PoopedYet)

---

## 本次更新内容

### 一、灵动胶囊大图标焕新

通知大图标改为动态绘制的「落叶黄表盘卷纸时钟」圆形徽章：温润暖纸底盘（#FAF5EC）配细微手帐描边（#E9DDCA），中央居中绘制全工程统一的卷纸时钟矢量。与 App 主页 Header、开屙按钮及桌面小组件的视觉规范同源，告别老旧的闹钟便便图标。状态栏小图标同步重绘。

### 二、不再亮起桌面角标

通知渠道升级为 `poop_live_capsule_v6`，并显式清理 v3 / v4 / v5 残留渠道：

- `setShowBadge(false)`：彻底关闭桌面图标小红点与未读数字角标——进行中的如厕计时是前台服务，不是未读消息；
- `enableLights(false)`：关闭通知灯光，仅保留静默计时；
- 高优先级（IMPORTANCE_HIGH）与锁屏可见性维持不变，vivo 原子岛、小米焦点通知、ColorOS 流体云的识别不受影响。

### 三、修复：断网时自动检查更新被节流吞掉

原先启动自动检查**先落盘检查时间、再发请求**，断网或超时失败也算「查过了」——二十四小时节流会把网络恢复后的第一次检查吞掉，用户可能一连几天都收不到新版本提示。

现在改为**成功拿到线上版本信息后才落盘本次检查时间**，失败不记节流，恢复联网后的下次冷启动会重新检查。

### 四、更新检查自动重试

检查更新的网络请求在超时后自动重试一次，连接超时从 10 秒放宽到 12 秒。弱网环境与 GitHub API 偶发抖动下，首次冷启动的检查成功率明显提高。

### 五、修复：物理删除成员后可能出现「没有默认人」

物理删除（级联清理）成员后，若删掉的是唯一默认人或最后一名成员，原先会留下一个零默认人的空档。现在删除事务内补上 `ensureDefaultPooper()` 兜底闭环：自动提拔剩余成员或补建「我」，日历打卡立即可用。

### 六、修复：补录后小组件与灵动胶囊不刷新

补录历史记录后补上小组件快照推流调用，桌面小组件与锁屏灵动胶囊立即同步刷新，与打卡、编辑、删除行为保持同一推流闭环。

### 七、安装包瘦身约 2.37MB

五张设计过程草稿与重复大图（品牌规范底稿、9:16 启动底图、安全区底图等）从打包资源目录迁出归档至 `.design/`，不再被打进 APK；全工程未被引用的历史兼容组件 `poop_action_icon.dart` 一并移除。

瘦身后各架构体积：arm64-v8a 17.5MB 降至 **14.8MB**，universal 36.3MB 降至 **33.5MB**。

---

## 各架构发布包

每个架构均同时提供标准 APK 与 ZIP 压缩包：

| 文件名称 | 说明与推荐受众 | 体积 |
| --- | --- | --- |
| `PoopedYet-v1.1.4-arm64-v8a.apk` | 现代 Android 智能手机（64 位 ARM，强烈推荐首选） | 14.8 MB |
| `PoopedYet-v1.1.4-arm64-v8a.zip` | arm64-v8a 安装包的 ZIP 压缩归档 | 14.5 MB |
| `PoopedYet-v1.1.4-universal.apk` | 全架构集成通用版（兼容所有 Android 32 / 64 位设备与模拟器） | 33.5 MB |
| `PoopedYet-v1.1.4-universal.zip` | 全架构通用版安装包的 ZIP 压缩归档 | 33.2 MB |
| `PoopedYet-v1.1.4-armeabi-v7a.apk` | 早期 32 位 Android 旧机型 | 14.4 MB |
| `PoopedYet-v1.1.4-armeabi-v7a.zip` | 32 位旧架构安装包的 ZIP 压缩归档 | 14.1 MB |
| `PoopedYet-v1.1.4-x86_64.apk` | PC Android 模拟器、Intel / AMD x86_64 平板设备 | 15.0 MB |
| `PoopedYet-v1.1.4-x86_64.zip` | x86_64 安装包的 ZIP 压缩归档 | 14.7 MB |
| `PoopedYet-v1.1.4-release.aab` | Google Play 官方标准 App Bundle 上架原包 | 66.8 MB |
| `PoopedYet-v1.1.4-release-aab.zip` | Google Play AAB 原包的 ZIP 压缩归档 | 66.4 MB |
| `PoopedYet-v1.1.4-all-apks.zip` | 包含以上全部 4 个架构 APK 的离线合集压缩包 | 76.5 MB |

---

## SHA-256 完整性校验和

```text
6ad0b74d5c8e50e30e4f102525b4147908f9251778db99359b2dcc1203e10dfd  PoopedYet-v1.1.4-all-apks.zip
9768464fe21b828096bb832e852a93817e51b3bc8019066346cdb4d2fe31a551  PoopedYet-v1.1.4-arm64-v8a.apk
6c20ec84b00809bdd70808de0a1b4757d0a164b7760de8bb83e97113c8245a13  PoopedYet-v1.1.4-arm64-v8a.zip
414073e8f3fef5856c2dbf360d85084de1cd9d85a38523fb66e9a192403f0a38  PoopedYet-v1.1.4-armeabi-v7a.apk
0a1bb576fcf48edda567431bae769a66f8aefc3ea2245da4bf5c1f12cefdc856  PoopedYet-v1.1.4-armeabi-v7a.zip
a705c028cc86a8c5a5c257d3d21c91ebf04b8b96a0b05005b91a0073fcab61cd  PoopedYet-v1.1.4-release-aab.zip
2dfaf711bec44a441af3f3894b32ed0323c98daa840c4f7b896fa7e5eb1f758b  PoopedYet-v1.1.4-release.aab
a77ae5ae5cc1a916690e43e9259dbd1fb55a5dacc130afd001618bcb20d8de68  PoopedYet-v1.1.4-universal.apk
b86e0d4f8b1e632575b25ed1ad2c723bab98ebe11132fe3b6974f9cfe7390539  PoopedYet-v1.1.4-universal.zip
4b8fe07e30d20662c0b5c19a7b154ff15e9c6b9be7a1eda72605a8b3cbb58b51  PoopedYet-v1.1.4-x86_64.apk
6bfc0b765c53672f33e0fc5d24fc20ac2d809243a07b1fb58f38c2a3b4b668de  PoopedYet-v1.1.4-x86_64.zip
```

---

## 升级说明

应用内「设置 - 关于屙了么 - 检查新版本」即可看到本版本，点「立即下载」会按本机 CPU 架构下载对应安装包并一键安装。数据全部保存在本地 SQLite，覆盖安装不影响既有记录。
