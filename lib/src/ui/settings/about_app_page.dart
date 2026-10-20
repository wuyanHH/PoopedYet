import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/update/apk_downloader.dart';
import '../../data/update/app_version.dart';
import '../../data/update/auto_update_checker.dart';
import '../../data/update/update_prefs.dart';
import '../../dev/demo_seeder.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../theme/tokens.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/smooth_page_route.dart';
import '../widgets/update_dialog.dart';
import 'changelog_page.dart';

/// 关于应用页面。
///
/// 包含应用品牌 Header、自动更新设置、检查更新、版本演进日志、开源协议，
/// 以及版本号连击 5 次激活的开发者调试彩蛋。
class AboutAppPage extends ConsumerStatefulWidget {
  const AboutAppPage({super.key});

  /// 手动检查更新逻辑（供主页与本页复用）
  static Future<void> handleCheckUpdate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final t = context.tokens;
    // 弹出轻量 Loading 弹窗
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.lineSoft),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x142D1B0D),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: t.brandInk,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '正在检查新版本...',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final store = ref.read(updatePrefsProvider.notifier);
      final result = await AutoUpdateChecker.run(
        prefs: ref.read(updatePrefsProvider),
        store: store,
        manual: true,
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 关闭 Loading

      if (result.hasUpdate) {
        final release = result.release!;
        unawaited(
          UpdateDialog.show(
            context,
            releaseInfo: release,
            deviceAbi: result.deviceAbi ?? 'arm64-v8a',
            skippable: true,
            onSkip: () => store.skipVersion(release.versionName),
          ),
        );
      } else if (result.status == AutoUpdateStatus.upToDate) {
        _showSnack(context, '当前已是最新版本 (v$kAppVersion)');
      } else {
        _showSnack(context, '未检测到新版本发布（若网络受限可稍后重试）');
      }
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 关闭 Loading
      _showSnack(context, '检查更新超时，请检查网络连接后重试');
    }
  }

  static void _showSnack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  ConsumerState<AboutAppPage> createState() => _AboutAppPageState();
}

class _AboutAppPageState extends ConsumerState<AboutAppPage> {
  int _easterEggClicks = 0;
  bool _developerModeUnlocked = false;

  void _onVersionTap() {
    HapticFeedback.lightImpact();
    setState(() {
      _easterEggClicks++;
      if (_easterEggClicks >= 5 && !_developerModeUnlocked) {
        _developerModeUnlocked = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已激活开发者调试菜单'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.tokens.ink,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final updatePrefs = ref.watch(updatePrefsProvider);
    final download = ref.watch(updateDownloadProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: '关于屙了么',
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + bottomInset),
        children: [
          // 顶部应用 Brand 门面（与启动页和主页完全同源的一体化门面 Logo）
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const BrandHeaderBadge(size: 72),
                const SizedBox(height: 12),
                Text(
                  '屙了么 PoopedYet',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _onVersionTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: t.brandSoft,
                      borderRadius: BorderRadius.circular(PoopRadii.pill),
                    ),
                    child: Text(
                      kAppVersionLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.brandInk,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '关爱身心健康的排便手账 · 离线优先 & 私有云同步',
                  style: TextStyle(fontSize: 12, color: t.ink3),
                ),
              ],
            ),
          ),

          // ---------------- 版本与更新 ----------------
          const SettingsSectionLabel('版本与更新'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.refreshCw,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '自动检查更新',
                subtitle: updatePrefs.autoCheck
                    ? (updatePrefs.lastCheckAt == null
                        ? '启动后静默检查，${AutoUpdateChecker.intervalLabel}'
                        : '上次检查：'
                            '${DateFormat('MM-dd HH:mm').format(updatePrefs.lastCheckAt!)}'
                            ' · ${AutoUpdateChecker.intervalLabel}')
                    : '已关闭 · 仅在手动点击时检查',
                trailing: SettingsSwitch(
                  value: updatePrefs.autoCheck,
                  onChanged: (v) =>
                      ref.read(updatePrefsProvider.notifier).setAutoCheck(v),
                ),
              ),
              SettingsRow(
                leading: LucideIcons.cloudDownload,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '检查新版本',
                subtitle: download.isDownloading
                    ? '正在后台下载 v${download.release?.versionName ?? ''} · ${download.percent}%'
                    : download.isCompleted
                        ? 'v${download.release?.versionName ?? ''} 安装包已就绪，点击安装'
                        : '连接 GitHub Releases 获取最新发布包',
                trailing: const SettingsChevron(),
                onTap: () => AboutAppPage.handleCheckUpdate(context, ref),
              ),
              SettingsRow(
                leading: LucideIcons.scrollText,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '版本更新日志',
                subtitle: '查看 v$kAppVersion 与历次里程碑特性',
                trailing: const SettingsChevron(),
                onTap: () => Navigator.of(context).push(
                  smoothPageRoute(const ChangelogPage()),
                ),
              ),
            ],
          ),

          // ---------------- 协议与合规 ----------------
          const SettingsSectionLabel('协议与致谢'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.notebookPen,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '开源许可与致谢',
                subtitle: '得意黑字体及第三方 Flutter 开源库授权声明',
                trailing: const SettingsChevron(),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: '屙了么 PoopedYet',
                  applicationVersion: kAppVersionLabel,
                ),
              ),
            ],
          ),

          // ---------------- 开发者调试彩蛋 ----------------
          if (_developerModeUnlocked || kDebugMode) ...[
            const SettingsSectionLabel('开发者调试工具'),
            SettingsCard(
              children: [
                SettingsRow(
                  leading: LucideIcons.flaskConical,
                  leadingColor: t.brandInk,
                  leadingBackground: t.brandSoft,
                  title: '生成演示数据',
                  subtitle: '清空并生成丰富的体验样本，用于演示日历角标与状态',
                  trailing: const SettingsChevron(),
                  onTap: () => _showDevDemoDialog(context, ref),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static void _showDevDemoDialog(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PoopRadii.card),
        ),
        title: Text(
          '生成演示数据',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: t.ink,
          ),
        ),
        content: Text(
          '警告：演示数据会清空现有所有记录与人员，并生成虚构打卡样本。确定要继续吗？',
          style: TextStyle(fontSize: 13, color: t.ink2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: TextStyle(color: t.ink3)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.brandFill),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final db = ref.read(databaseProvider);
              await DemoSeeder(db).run();
              ref.invalidate(monthBadgesProvider);
              ref.invalidate(weekBadgesProvider);
              ref.invalidate(dayRecordsProvider);
              ref.invalidate(activePoopersProvider);
              ref.invalidate(staleRecordsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('演示数据已生成'),
                    backgroundColor: t.ink,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('确认生成'),
          ),
        ],
      ),
    );
  }
}
