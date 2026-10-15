# 屙了么 PoopedYet 标准版本发布流程规范 (Release Workflow SOP)

> 本文档定义「屙了么 PoopedYet」项目从日常开发完毕到正式上线发版的标准作业程序（SOP）。  
> 后续所有新版本（如 `v1.0.1`、`v1.1.0` 等）的构建、归档、提交与发布，均严格遵循以下 6 个标准化阶段执行。

---

## 流程概览

```
                       「屙了么 PoopedYet」标准发版流水线
 ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
 │ 1.版本与日志 │ ──> │ 2.生产编译   │ ──> │ 3.本地归档   │ ──> │ 4.Git打标   │
 │   规范对齐  │     │   架构分包  │     │   哈希校验  │     │   推送到云端│
 └─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                    │
                                                                    ▼
                                                         ┌──────────────────┐
                                                         │ 5.GitHub Release │
                                                         │   资产上传与验证 │
                                                         └──────────────────┘
                                                                    │
                                                                    ▼
                                                         ┌──────────────────┐
                                                         │ 6.移动端闭环验收 │
                                                         │   架构与下载检查 │
                                                         └──────────────────┘
```

---

## 阶段一：版本号与更新日志对齐

发版前需对齐代码中 3 处版本信息：

1. **`pubspec.yaml`**：
   - 遵循工业标准**万位语义映射规范**（`MAJOR * 100000 + MINOR * 10000 + PATCH * 100`）：
     - `1.0.1` ➔ `version: 1.0.1+100100`
     - `1.1.0` ➔ `version: 1.1.0+101000`
     - `2.0.0` ➔ `version: 2.0.0+200000`
2. **设置页版本常量** (`lib/src/ui/settings/settings_page.dart`)：
   - 修改 `static const _version = 'X.Y.Z';`
3. **离线更新日志数据源** (`lib/src/ui/settings/changelog_page.dart`)：
   - 在 `kAppChangelogs` 列表头部追加新版本的发版年月、核心亮点与说明条目。

---

## 阶段二：生产级编译构建（Release Build）

执行多架构分包命令，产出体积精简（约 17MB）、运行性能最优的专属 APK：

```powershell
flutter build apk --split-per-abi
```

**构建产物路径**：`build\app\outputs\flutter-apk\`
- `app-arm64-v8a-release.apk`（主流手机首选）
- `app-armeabi-v7a-release.apk`（32 位旧设备）
- `app-x86_64-release.apk`（PC 模拟器）

---

## 阶段三：本地归档与 SHA256 哈希校验

在项目 `release\` 目录下建立版本专属归档仓，并将编译文件规范重命名：

```powershell
# 1. 创建目标版本归档文件夹（以 v1.0.1 为例）
New-Item -ItemType Directory -Force -Path "release\v1.0.1"

# 2. 复制并重命名为标准发布文件名
Copy-Item "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "release\v1.0.1\PoopedYet-v1.0.1-arm64-v8a.apk"
Copy-Item "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "release\v1.0.1\PoopedYet-v1.0.1-armeabi-v7a.apk"
Copy-Item "build\app\outputs\flutter-apk\app-x86_64-release.apk" "release\v1.0.1\PoopedYet-v1.0.1-x86_64.apk"

# 3. 自动生成 SHA256 完整性校验和文件
Get-ChildItem "release\v1.0.1\*.apk" | ForEach-Object { 
    $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(); 
    "$h  $($_.Name)" 
} | Set-Content "release\v1.0.1\SHA256SUMS.txt" -Encoding utf8

# 4. 创建发版说明文档
# 在 release\v1.0.1\RELEASE_NOTES.md 中记录本次发布核心内容与架构说明
```

---

## 阶段四：Git 代码提交与版本打标（Tag）

```powershell
# 1. 提交所有变更代码与归档文本（APK 资产受 .gitignore 保护，不入库）
git add .
git commit -m "feat(release): 发布正式版 vX.Y.Z"
git push origin main

# 2. 创建附注版本 Tag 并推送至 GitHub
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

---

## 阶段五：GitHub Releases 云端发布

使用 GitHub CLI (`gh`) 一键创建 Release 并上传 3 架构 APK 附件：

```powershell
gh release create vX.Y.Z `
  "release\vX.Y.Z\PoopedYet-vX.Y.Z-arm64-v8a.apk" `
  "release\vX.Y.Z\PoopedYet-vX.Y.Z-armeabi-v7a.apk" `
  "release\vX.Y.Z\PoopedYet-vX.Y.Z-x86_64.apk" `
  --title "PoopedYet vX.Y.Z 正式版" `
  --notes-file "release\vX.Y.Z\RELEASE_NOTES.md"
```

> **注**：Release 标题保持简短精练（如 `PoopedYet vX.Y.Z 正式版`），防止 GitHub 侧边栏过长截断。

---

## 阶段六：移动端闭环验收

1. 打开安装了前序版本的手机应用；
2. 进入 **「设置」 ➔ 点击「检查新版本」**；
3. **核查点**：
   - 识别本机 CPU 指令集架构（如 `arm64-v8a`）；
   - 正常唤起自适应手帐风格更新弹窗；
   - 点击推荐下载按钮，验证是否正常拉起外部浏览器极速下载对应包；
   - 展开“其他架构安装包”，验证备选包列表与体积显示正确。
