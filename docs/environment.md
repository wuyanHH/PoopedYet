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
