/// 应用当前正式版本号（不含 `v` 前缀）。
///
/// 这里是**代码里唯一的版本号来源** —— 设置页展示、检查更新比对、
/// 启动自动检查都读它，免得各处各写一份后慢慢走偏。
///
/// 发版时必须与另外两处同步，见 `docs/release_workflow.md` 阶段一：
///   1. `pubspec.yaml` 的 `version:`（前缀部分）；
///   2. `lib/src/ui/settings/changelog_page.dart` 的 `kAppChangelogs` 头部条目。
const String kAppVersion = '1.1.4';

/// 带 `v` 前缀与渠道后缀的展示用版本号。
const String kAppVersionLabel = 'v$kAppVersion 正式版';
