# 开发环境

这份文档记录的是**本机环境**的状态与改动。代码在 git 里，环境不在 ——
所以升级、打补丁、改镜像这些事必须写下来，否则下次撞上同样的坑要从头查。

## 工具链

| 项 | 版本 | 备注 |
|---|---|---|
| Flutter | **3.47.7** stable | 2026-10-08 发布，revision `abaf9c5237` |
| Dart | **3.13.5** | |
| Android SDK | 36.1.0 | `E:\Development\AndroidSdk` |
| JDK | 21.0.8 LTS | `E:\Development\jdk-21.0.8` |
| Gradle | wrapper 自带 | |
| Node.js | 24.1.0 | 只给 `.design/` 的工具链用 |
| Git | 2.56.0 | |

`flutter doctor` = **No issues found**。

## 一、Flutter 从 3.41.5 升到 3.47.7

### 为什么必须升

原版本（3.41.5 / Dart 3.11.3）把 `meta` 死锁在 **1.17.0**，导致：

| 想用的 | 结果 |
|---|---|
| `flutter_riverpod` 3.4.x | ❌ 要求 Dart ≥3.12 → 只能用 3.3.2 |
| `drift_dev` 2.35.x | ❌ 要 `analyzer ≥13` → 要 `meta ≥1.18` |

而且**没有任何 `drift_dev` 版本能同时满足 drift 2.35.2 和 meta 1.17.0** ——
`analyzer ≥10.0.2` 全线要求 `meta ^1.18.0`。这不是运气问题，是必然后果。

升级后：`flutter_riverpod 3.4.3` + `drift 2.35.2` + `drift_dev 2.35.1` + `analyzer 14.5.0`。

### 回滚

```powershell
cd E:\Development\flutter
git checkout 2c9eb20739dfec95e2c74bd3dfa4601b0a8a36aa   # 3.41.5
```

### 副作用：TomeTone

`E:\Projects\TomeTone` 的 SDK 约束是 `^3.11.3`，升级后仍然满足。
已验证 `flutter pub get` + `flutter analyze` 均通过，只有 4 个补丁级传递依赖变动
（`0.12.19→0.12.20`、`1.17.0→1.19.0`、`0.7.10→0.7.12`、`2.2.0→2.4.3`）。

> 注意本机有 **3 份** TomeTone：`E:\Projects\TomeTone`、`E:\Git\Tometone`、`E:\Git\TomeTone`。
> 只验证了第一份。

---

## 二、`FLUTTER_STORAGE_BASE_URL` 换了镜像

| | |
|---|---|
| 原值 | `https://mirrors.tuna.tsinghua.edu.cn/flutter` |
| 现值 | `https://storage.flutter-io.cn` |

**原因**：清华镜像尚未同步 3.47.7 的引擎产物（engine `deb287481e3…`），
`sky_engine.zip` 和 `dart-sdk` 全部 404，`flutter` 命令完全跑不动。

2026-10 实测各镜像是否已有该引擎产物：

| 镜像 | 结果 |
|---|---|
| 清华 TUNA | ❌ HTTP 404 |
| **Flutter 官方中国** | ✅ 改用它 |
| 腾讯云 | ✅ |
| 中科大 USTC | ✅ |
| 上海交大 SJTU | ✅ |
| Google 官方 | ✅ |

改回清华（若它恢复同步）：

```powershell
[Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL','https://mirrors.tuna.tsinghua.edu.cn/flutter','User')
```

`PUB_HOSTED_URL` 未改动，仍为 `https://pub.flutter-io.cn`。

**⚠ 每条 `flutter` / `dart` 命令都要能读到这个变量。**
在新开的 shell 里它来自用户级环境变量；如果某条命令报 404，先检查这个变量。

---

## 三、Flutter SDK 本地补丁：Windows 符号链接兜底

**文件**：`E:\Development\flutter\packages\flutter_tools\lib\src\flutter_plugins.dart`
**函数**：`_createPlatformPluginSymlinks`
**补丁**：`E:\Development\flutter-local-patches\windows-symlink-fallback.patch`
（仓库内副本：`.patches/windows-symlink-fallback.patch`）

### 解决的问题

Windows 上创建符号链接需要管理员权限或开发者模式。两者都没有时
`link.createSync(path)` 抛 `FileSystemException`，平台插件链接就建不出来。

补丁在 catch 里退而使用**目录联接**（`mklink /J`）—— 联接不需要任何特权。

### ⚠ 升级 Flutter 会冲掉它

已确认**上游 3.47.7 仍未修复**（只有 symlink，没有 junction 兜底），
所以这个补丁是长期需要的。

重打补丁：

```powershell
cd E:\Development\flutter
git apply --3way E:\Development\flutter-local-patches\windows-symlink-fallback.patch
```

若 `--3way` 失败（上游改动了周边代码），手工在
`} on FileSystemException catch (e) {` 之后插入补丁文件里 `+` 开头的那段，
注意保持缩进。

**升级 Flutter 的标准流程**：

1. 记下当前 revision
2. `git stash push` 掉这个补丁（否则 `git pull` 会被本地改动挡住）
3. `flutter upgrade`
4. 重新打补丁
5. `flutter doctor` 验证（它会重建 flutter_tools，顺便验证补丁能编译）

---

## 四、全局 Gradle 镜像

**文件**：`C:\Users\Lenovo\.gradle\init.gradle`（新建）

### 解决的问题

Flutter 的 android 构建里有一个 **included build**
（`<flutter>/packages/flutter_tools/gradle`），它有自己的 `settings.gradle.kts`，
只声明了 `google()` / `mavenCentral()`，插件默认走 `gradlePluginPortal()`。
国内直连这三个源经常拉不到：

```
Plugin [id: 'org.jetbrains.kotlin.jvm', version: '2.2.20'] was not found
  Searched in: Gradle Central Plugin Repository
```

**项目级的 `android/settings.gradle.kts` 改不了 included build**，所以只能放全局。

脚本做法：阿里云镜像**优先**，官方源留作兜底（只增不减，不会让原本能解析的依赖突然失败）。
影响本机所有 Gradle 构建，包括 TomeTone。**删掉该文件即可完全恢复原状。**

---

## 五、踩过的两个环境坑

### 僵死的 `flutter_tester` 占着引擎文件

`flutter doctor` 报：

```
Failed to write to "…\engine\windows-x64\icudtl.dat". The file is being used by another program.
(OS Error: 请求的操作无法在使用用户映射区域打开的文件上执行。, errno = 1224)
```

原因是一个跑了 **5.9 小时**、累计 CPU 只有 16.9 秒的 `flutter_tester.exe` 僵死进程
（在跑 `E:\Git\Tometone` 的测试）。判断方法：

```powershell
$p = Get-Process flutter_tester
$c1 = $p.CPU; Start-Sleep 4; $p.Refresh()
"4 秒内新增 CPU: $($p.CPU - $c1)"   # 0 就是僵死的，可以安全结束
```

### pub 缓存在 C 盘、项目在 E 盘

Kotlin 增量编译会报（已被 suppress，不影响构建）：

```
IllegalArgumentException: this and base files have different roots:
C:\Users\…\Pub\Cache\… and E:\Projects\PoopedYet\android
```

跨盘符的相对路径计算失败，属于已知问题。构建仍会成功。
如果哪天它变成硬失败，把 pub cache 挪到 E 盘即可：

```powershell
[Environment]::SetEnvironmentVariable('PUB_CACHE','E:\Development\pub-cache','User')
```

---

## 六、构建工具版本（暂不动）

`flutter build apk --release` 会报三条**前瞻性**告警：

```
Gradle 8.14.0        -> 建议至少 9.1.0
AGP 8.11.1           -> 建议至少 9.0.1
Kotlin 2.2.20        -> 建议至少 2.3.20
```

**这三个版本就是 Flutter 3.47.7 模板的默认值**（模板里是 `{{gradleVersion}}` 占位符，
由 flutter_tools 填充），不是我们写旧的。告警说的是"未来某个 Flutter 版本会不再支持"。

**决定：暂不升级。** 理由：

- 当前构建正常出包，升级三个版本是**同时**动 Gradle / AGP / Kotlin 三个大件，
  AGP 8→9 还是有破坏性变更的大版本。
- 本机没有连着安卓设备或模拟器，升级后**只能验证"能编译"，验证不了"能跑"**。
  仅靠编译通过就动构建工具，风险收益不划算。

**什么时候必须动**：Flutter 把最低要求提上去、构建开始失败时。
届时按告警里给的路径改：Gradle 在 `android/gradle/wrapper/gradle-wrapper.properties`，
AGP 和 Kotlin 在 `android/settings.gradle.kts` 的 `plugins` 块。

注意 `android/gradle.properties` 里已经被 Flutter 自动加了
`android.builtInKotlin=false` 和 `android.newDsl=false`，
说明 Flutter 自己正在往 AGP 9 过渡 —— 跟着它的节奏走就行。

---

## 七、模拟器与真机验证

本机 AVD：**`Medium_Phone_API_36.1`**（Android 16 / API 36 / x86_64 / 1080×2400 / 420dpi）。
Android Studio 的 GUI 不在标准路径，但 SDK、emulator、AVD 都齐。

```powershell
# 启动
Start-Process "E:\Development\AndroidSdk\emulator\emulator.exe" `
  -ArgumentList '-avd','Medium_Phone_API_36.1','-no-boot-anim'
# 等待
adb wait-for-device; adb shell getprop sys.boot_completed   # 等到 1
```

### 验证过什么

`flutter build apk --debug --target-platform android-x64` → `adb install -r` → 启动，
然后**直接拉出设备上的数据库用 sqlite3 核对**（不靠看截图）：

| 检查项 | 结果 |
|---|---|
| 5 张表 | ✅ poopers / poop_records / poop_notes / note_templates / holidays |
| 两个部分唯一索引的 WHERE 子句 | ✅ `ux_active_record ... WHERE ended_at IS NULL AND end_unknown = 0`<br>✅ `ux_default_pooper ... WHERE is_default = 1` |
| 外键动作 | ✅ `ON DELETE RESTRICT`（不是 CASCADE） |
| 首启自动建档 | ✅ `fresh=true`，建出「我」并设为默认 |
| 备注模板种子 | ✅ 7 条 |
| `schemaVersion` | ✅ `user_version = 1` |
| 重启幂等 | ✅ 仍是 1 个人、7 条模板，DB 文件 mtime 未变（复用而非重建） |
| **真实连接上的 `PRAGMA foreign_keys`** | ✅ **`true`** |

最后一条是**只有真机能验**的：SQLite 的 `PRAGMA foreign_keys` 是 per-connection、
默认关闭，而 `drift_flutter` 可能把数据库跑在后台 isolate 里。
单元测试用的是内存库，验不到那条真实连接。所以自检页会把 PRAGMA 读出来：

```
[BOOT-CHECK] default=我 poopers=1 records=0 templates=7 foreign_keys=true fresh=false
```

Flutter 画在 canvas 上，`uiautomator` 读不到界面文字 —— 所以自检结果同时打进日志，
CI / adb 这类没有 GUI 的环境也能核对。

### 拉库核对的方法

设备上没有 `sqlite3`，但 **Android platform-tools 里自带了一个**：

```powershell
cmd /c "adb exec-out run-as com.poopedyet.app cat app_flutter/pooped_yet.sqlite > $env:TEMP\db.sqlite"
& "E:\Development\AndroidSdk\platform-tools\sqlite3.exe" "$env:TEMP\db.sqlite" ".tables"
```

注意数据库在 `app_flutter/`（`drift_flutter` 用的是 documents 目录），**不是 `databases/`**。

---

## 八、查库时的时区陷阱（踩过一次）

**模拟器的时区是 `GMT`，而开发主机是 `China Standard Time (UTC+8)`。**

把设备上的数据库拉到主机上用 `sqlite3` 查时，如果用
`date(started_at,'unixepoch','localtime')`，**`localtime` 用的是主机的时区**，
结果会比设备上显示的时间**早 8 小时**。

我第一次就因此以为补录写错了时间（看到 16:00，实际是 08:00）。

正确做法：设备是 GMT 时，直接不加 localtime 修饰符才是它的本地时间。

```powershell
# 模拟器是 GMT，这样读才对
sqlite3 db.sqlite "SELECT datetime(started_at,'unixepoch') FROM poop_records;"

# 或者先确认设备时区
adb shell getprop persist.sys.timezone
adb shell date
```

顺带一提，这条也解释了为什么应用侧要**按本地日分组**而不是在 SQL 里用
`localtime` —— 那会依赖执行查询的设备时区，而 Dart 侧的 `dayKey` 用的是
设备本地日期。两边各算一次时区，迟早分叉。

---

## 九、模拟器屏幕会自动休眠

跑长时间的设备自动化时，屏幕休眠会让**截图整体变暗**，
看起来像"弹窗把界面压灰了"或"渲染坏了"。

```powershell
adb shell svc power stayon true   # 常亮
adb shell input keyevent KEYCODE_WAKEUP
```

判断依据：连**状态栏**都变暗（正常时状态栏是亮的），那就是休眠而不是遮罩。
