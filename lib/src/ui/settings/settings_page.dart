import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../calendar/calendar_math.dart';
import '../../data/database.dart';
import '../../data/holiday_loader.dart';
import '../../dev/demo_seeder.dart';
import '../../providers.dart';
import '../../state/backup_state.dart';
import '../../state/calendar_data.dart';
import '../../state/calendar_view.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../../widget/widget_snapshot_service.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/smooth_page_route.dart';
import 'backup/data_backup_page.dart';
import 'backup/webdav_sync_page.dart';
import 'changelog_page.dart';
import '../../data/update/update_service.dart';
import '../widgets/update_dialog.dart';
import 'note_template_page.dart';
import 'pooper_list_page.dart';

/// 设置主页（视觉稿 ⑩）。
///
/// **只放能真正工作的项**。摆一排点了没反应的入口，比空着更糟 ——
/// 用户会以为是坏了。还没做的（统计、备份导出、节假日数据管理）
/// 等做完了再加进来。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final settings = ref.watch(settingsProvider);
    final s = ref.read(settingsProvider.notifier);

    final poopers = ref.watch(activePoopersProvider).value ?? const [];
    final templates = ref.watch(noteTemplatesProvider).value ?? const [];
    final webDavConfig = ref.watch(webDavConfigProvider);

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: '设置',
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + bottomInset),
        children: [
          // ---------------- 人员与主题 ----------------
          const SettingsSectionLabel('人员与主题'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.users,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '屙屎人',
                subtitleWidget: _buildPoopersPreview(context, poopers),
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const PooperListPage()),
              ),
              SettingsRow(
                leading: LucideIcons.tags,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '便便感受',
                subtitleWidget: _buildTemplatesPreview(context, templates),
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const NoteTemplatePage()),
              ),
            ],
          ),

          // ---------------- 日历 ----------------
          const SettingsSectionLabel('日历与列表'),
          SettingsCard(
            children: [
              SettingsRow(
                title: '记录排列顺序',
                subtitle: '当日打卡记录默认按时间倒序或正序呈现',
                trailing: SettingsSegmented<RecordSortOrder>(
                  options: const [
                    ('倒序', RecordSortOrder.desc),
                    ('正序', RecordSortOrder.asc),
                  ],
                  value: settings.recordSortOrder,
                  onChanged: s.setRecordSortOrder,
                ),
              ),
              SettingsRow(
                title: '默认展示视图',
                subtitle: '打开软件时日历默认以月或周展示',
                trailing: SettingsSegmented<CalendarMode>(
                  options: const [
                    ('月历', CalendarMode.month),
                    ('周历', CalendarMode.week),
                  ],
                  value: settings.defaultCalendarMode,
                  onChanged: s.setDefaultCalendarMode,
                ),
              ),
              SettingsRow(
                title: '每周起始日',
                subtitle: '日历第一列是周一还是周日',
                trailing: SettingsSegmented<WeekStart>(
                  options: const [('周一', WeekStart.monday), ('周日', WeekStart.sunday)],
                  value: settings.weekStart,
                  onChanged: s.setWeekStart,
                ),
              ),
              SettingsRow(
                title: '日历字号',
                subtitle: '系统字号放大时，日历最多跟到 1.3×',
                trailing: SettingsSegmented<CalendarTextSize>(
                  options: const [
                    ('小', CalendarTextSize.small),
                    ('中', CalendarTextSize.medium),
                    ('大', CalendarTextSize.large),
                  ],
                  value: settings.calendarTextSize,
                  onChanged: s.setCalendarTextSize,
                ),
              ),
              SettingsRow(
                title: '格内显示头像与次数',
                subtitle: '关闭后日期格更清爽',
                trailing: SettingsSwitch(
                  value: settings.showBadges,
                  onChanged: s.setShowBadges,
                ),
              ),
              SettingsRow(
                title: '显示休 / 班角标',
                subtitle: '法定假日与调休上班日',
                trailing: SettingsSwitch(
                  value: settings.showHolidayTags,
                  onChanged: s.setShowHolidayTags,
                ),
              ),
              const _HolidaySyncRow(),
              SettingsRow(
                title: '隐藏已归档的屙屎人',
                subtitle: '默认不隐藏 —— 归档的人历史仍在，'
                    '隐藏会让日历次数看起来莫名变少',
                trailing: SettingsSwitch(
                  value: settings.hideArchivedPoopers,
                  onChanged: s.setHideArchivedPoopers,
                ),
              ),
            ],
          ),

          // ---------------- 外观与主题 ----------------
          const SettingsSectionLabel('外观与主题'),
          SettingsCard(
            children: [
              SettingsRow(
                title: '深浅模式',
                subtitle: switch (settings.themeMode) {
                  AppThemeMode.system => '跟随系统设置自动切换',
                  AppThemeMode.light => '保持浅色暖纸风格',
                  AppThemeMode.dark => '暗夜深咖，护眼省电',
                },
                trailing: SettingsSegmented<AppThemeMode>(
                  options: const [
                    ('系统', AppThemeMode.system),
                    ('浅色', AppThemeMode.light),
                    ('深色', AppThemeMode.dark),
                  ],
                  value: settings.themeMode,
                  onChanged: s.setThemeMode,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '主题配色',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          settings.themeColor.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.brandInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '5 种暖调手账色系，自动适配浅色与深色模式',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: t.ink3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ThemeColorSelector(
                      selected: settings.themeColor,
                      onChanged: s.setThemeColor,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ---------------- 桌面小组件与灵动胶囊 ----------------
          const SettingsSectionLabel('桌面小组件与灵动胶囊'),
          const SettingsCard(
            children: [
              _WidgetIncognitoRow(),
              _LiveIslandNotificationRow(),
            ],
          ),

          // ---------------- 数据与同步 ----------------
          const SettingsSectionLabel('数据与同步'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.database,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '数据备份与恢复',
                subtitle: '本地 JSON 导出、导入与剪贴板备份',
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const DataBackupPage()),
              ),
              SettingsRow(
                leading: LucideIcons.cloud,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: 'WebDAV 云同步',
                subtitle: webDavConfig.isConfigured
                    ? (webDavConfig.lastSyncAt != null
                        ? '上次同步：${DateFormat('MM-dd HH:mm').format(webDavConfig.lastSyncAt!)}'
                        : '已配置 · 坚果云/Nextcloud等')
                    : '支持坚果云、Nextcloud、群晖等私有云',
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const WebDavSyncPage()),
              ),
            ],
          ),

          // ---------------- 关于 ----------------
          const SettingsSectionLabel('关于'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.info,
                title: '版本',
                trailing: const SettingsValue('v$_version 正式版'),
              ),
              SettingsRow(
                leading: LucideIcons.cloudDownload,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '检查新版本',
                subtitle: '连接 GitHub Releases 获取最新发布与架构专属包',
                trailing: const SettingsChevron(),
                onTap: () => _handleCheckUpdate(context),
              ),
              SettingsRow(
                leading: LucideIcons.scrollText,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '版本更新日志',
                subtitle: '查看 1.0.0 正式版与历史里程碑演进记录',
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const ChangelogPage()),
              ),
              SettingsRow(
                leading: LucideIcons.notebookPen,
                title: '开源许可',
                subtitle: '得意黑字体等第三方组件',
                trailing: const SettingsChevron(),
                // Flutter 内置的许可页。得意黑的 OFL 文本在 main() 里
                // 通过 LicenseRegistry 注册，所以这里能列出来。
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: '屙了么 PoopedYet',
                  applicationVersion: 'v$_version 正式版',
                ),
              ),
            ],
          ),

          if (kDebugMode) ...[
            const SettingsSectionLabel('开发'),
            SettingsCard(
              children: [
                SettingsRow(
                  leading: LucideIcons.flaskConical,
                  leadingColor: t.brandInk,
                  leadingBackground: t.brandSoft,
                  title: '演示数据',
                  subtitle: '生成测试与体验数据 · 演示不同打卡状态与角标',
                  onTap: () => _showDevDemoDialog(context, ref),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static const _version = '1.0.0';

  static Future<void> _handleCheckUpdate(BuildContext context) async {
    final t = context.tokens;
    // 弹出轻量 Loading 弹窗
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
    );

    try {
      final service = UpdateService();
      final futures = await Future.wait([
        service.checkLatestRelease(currentVersion: _version),
        UpdateService.getDeviceAbi(),
      ]);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 关闭 Loading

      final releaseInfo = futures[0] as UpdateReleaseInfo?;
      final deviceAbi = futures[1] as String? ?? 'arm64-v8a';

      if (releaseInfo != null && releaseInfo.isNewer) {
        UpdateDialog.show(
          context,
          releaseInfo: releaseInfo,
          deviceAbi: deviceAbi,
        );
      } else if (releaseInfo != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('🎉 当前已是最新正式版本 (v$_version)'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
      } else {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('未检测到新版本发布（若网络受限可稍后重试）'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
      }
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 关闭 Loading
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('检查更新超时，请检查网络连接后重试'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
    }
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
          '演示数据会清空现有记录与屙屎人，并生成丰富的打卡样本，用来体验日历的三种角标与不同记录状态。确定生成吗？',
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

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(smoothPageRoute(page));
  }

  Widget _buildPoopersPreview(BuildContext context, List<Pooper> poopers) {
    final t = context.tokens;
    if (poopers.isEmpty) {
      return Text('暂无成员，点击添加', style: TextStyle(fontSize: 12, color: t.ink3));
    }

    // 严格锁定单行：仅取前 3 位成员，剩余展示 +N，彻底杜绝换行
    final displayPoopers = poopers.take(3).toList();
    final remaining = poopers.length - displayPoopers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '共 ${poopers.length} 位 · 管理专属头像与默认人选',
          style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.3),
        ),
        const SizedBox(height: 5),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in displayPoopers) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: p.isDefault ? t.brandSoft : t.paperDeep,
                    borderRadius: BorderRadius.circular(PoopRadii.pill),
                    border: Border.all(
                      color: p.isDefault
                          ? t.brandInk.withValues(alpha: 0.25)
                          : t.lineSoft,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p.isDefault) ...[
                        Icon(LucideIcons.star, size: 10, color: t.brandInk),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        p.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              p.isDefault ? FontWeight.w700 : FontWeight.w500,
                          color: p.isDefault ? t.brandInk : t.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
              ],
              if (remaining > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: t.paperDeep,
                    borderRadius: BorderRadius.circular(PoopRadii.pill),
                    border: Border.all(color: t.lineSoft, width: 0.8),
                  ),
                  child: Text(
                    '+$remaining',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: t.ink3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplatesPreview(
    BuildContext context,
    List<NoteTemplate> templates,
  ) {
    final t = context.tokens;
    if (templates.isEmpty) {
      return Text('暂无标签，点击添加', style: TextStyle(fontSize: 12, color: t.ink3));
    }

    // 严格锁定单行：仅取前 3 个标签，剩余展示 +N，彻底杜绝换行
    final displayTemplates = templates.take(3).toList();
    final remaining = templates.length - displayTemplates.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '共 ${templates.length} 种 · 快速记录顺畅、便秘等便况',
          style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.3),
        ),
        const SizedBox(height: 5),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in displayTemplates) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: t.paperDeep,
                    borderRadius: BorderRadius.circular(PoopRadii.pill),
                    border: Border.all(color: t.lineSoft, width: 0.8),
                  ),
                  child: Text(
                    item.content,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: t.ink2,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              if (remaining > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: t.paperDeep,
                    borderRadius: BorderRadius.circular(PoopRadii.pill),
                    border: Border.all(color: t.lineSoft, width: 0.8),
                  ),
                  child: Text(
                    '+$remaining',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: t.ink3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 法定节假日数据管理与在线 API 同步行。
class _HolidaySyncRow extends ConsumerStatefulWidget {
  const _HolidaySyncRow();

  @override
  ConsumerState<_HolidaySyncRow> createState() => _HolidaySyncRowState();
}

class _HolidaySyncRowState extends ConsumerState<_HolidaySyncRow> {
  bool _syncing = false;

  Future<void> _doSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    try {
      final db = ref.read(databaseProvider);
      final res = await syncHolidaysFromApi(db);
      if (!mounted) return;

      if (res.success) {
        ref.invalidate(holidaysProvider);
        ref.invalidate(holidayStatsProvider);

        final yearsText = res.syncedYears.isEmpty
            ? ''
            : '（覆盖 ${res.syncedYears.join('、')} 年）';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('法定节假日同步成功$yearsText · 更新 ${res.insertedCount} 天数据'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? '同步失败，已保留离线内置数据'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('同步异常: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final statsAsync = ref.watch(holidayStatsProvider);

    final String subtitle;
    if (statsAsync.isLoading) {
      subtitle = '正在读取本地节假日数据...';
    } else if (statsAsync.hasValue) {
      final data = statsAsync.value!;
      if (data.years.isEmpty) {
        subtitle = '暂无本地数据 · 支持从开源 API 在线获取';
      } else {
        final start = data.years.first;
        final end = data.years.last;
        final rangeStr = start == end ? '$start 年' : '$start–$end 年';
        subtitle = '已收录 $rangeStr（共 ${data.totalCount} 天）· 来源国务院公告';
      }
    } else {
      subtitle = '内置 2018–2026 年数据 · 支持在线同步';
    }

    return SettingsRow(
      title: '法定节假日数据',
      subtitle: subtitle,
      trailing: _syncing
          ? SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.brandFill,
                  ),
                ),
              ),
            )
          : Tooltip(
              message: '从 API 更新',
              preferBelow: false,
              triggerMode: TooltipTriggerMode.longPress,
              decoration: BoxDecoration(
                color: t.ink,
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: TextStyle(
                color: t.paper,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _doSync,
                  borderRadius: BorderRadius.circular(PoopRadii.pill),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: t.brandSoft,
                      borderRadius: BorderRadius.circular(PoopRadii.pill),
                      border: Border.all(
                        color: t.brandInk.withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.cloudDownload,
                      size: 16,
                      color: t.brandInk,
                    ),
                  ),
                ),
              ),
            ),
      onTap: _syncing ? null : _doSync,
    );
  }
}

/// 主题色彩选择器。
class _ThemeColorSelector extends StatelessWidget {
  const _ThemeColorSelector({
    required this.selected,
    required this.onChanged,
  });

  final AppThemeColor selected;
  final ValueChanged<AppThemeColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final item in AppThemeColor.values)
          _ThemeColorItem(
            colorItem: item,
            isSelected: item == selected,
            onTap: () => onChanged(item),
          ),
      ],
    );
  }
}

class _ThemeColorItem extends StatefulWidget {
  const _ThemeColorItem({
    required this.colorItem,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeColor colorItem;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ThemeColorItem> createState() => _ThemeColorItemState();
}

class _ThemeColorItemState extends State<_ThemeColorItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isSel = widget.isSelected;
    final primary = widget.colorItem.primaryColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSel ? primary : Colors.transparent,
                  width: 2.2,
                ),
              ),
              padding: const EdgeInsets.all(2.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: isSel ? 0.45 : 0.2),
                      blurRadius: isSel ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: isSel
                    ? const Icon(
                        LucideIcons.check,
                        size: 17,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.colorItem.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                color: isSel ? primary : t.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 小组件暗号模式（防社死）切换设置项
class _WidgetIncognitoRow extends ConsumerStatefulWidget {
  const _WidgetIncognitoRow();

  @override
  ConsumerState<_WidgetIncognitoRow> createState() =>
      _WidgetIncognitoRowState();
}

class _WidgetIncognitoRowState extends ConsumerState<_WidgetIncognitoRow> {
  static const _keyIncognito = 'pref_incognito_mode';
  bool _isIncognito = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = ref.read(sharedPrefsProvider);
    if (mounted) {
      setState(() {
        _isIncognito = prefs.getBool(_keyIncognito) ?? false;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _isIncognito = value);
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool(_keyIncognito, value);
    final db = ref.read(databaseProvider);
    await WidgetSyncManager.sync(db);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      leading: LucideIcons.shieldCheck,
      leadingColor: context.tokens.brandInk,
      leadingBackground: context.tokens.brandSoft,
      title: '暗号模式（防社死）',
      subtitle: '小组件文案自动替换为“日常轻体/放空减负”，杜绝公共场合被窥屏尴尬',
      trailing: SettingsSwitch(
        value: _isIncognito,
        onChanged: _toggle,
      ),
    );
  }
}

/// 状态栏灵动胶囊 & vivo 原子岛通知设置项与指引
class _LiveIslandNotificationRow extends ConsumerStatefulWidget {
  const _LiveIslandNotificationRow();

  @override
  ConsumerState<_LiveIslandNotificationRow> createState() =>
      _LiveIslandNotificationRowState();
}

class _LiveIslandNotificationRowState
    extends ConsumerState<_LiveIslandNotificationRow>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.poopedyet.app/widget');
  bool _notificationEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    try {
      final enabled =
          await _channel.invokeMethod<bool>('isNotificationEnabled') ?? true;
      if (mounted) {
        setState(() => _notificationEnabled = enabled);
      }
    } catch (_) {}
  }

  Future<void> _handleTap() async {
    try {
      if (!_notificationEnabled) {
        await _channel.invokeMethod('requestNotificationPermission');
      }
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          leading: LucideIcons.sparkles,
          leadingColor: t.brandInk,
          leadingBackground: t.brandSoft,
          title: '状态栏灵动胶囊与锁屏通知',
          subtitle: _notificationEnabled
              ? '已授权 · 支持 vivo 原子岛、小米焦点通知、OPPO 流体云'
              : '未允许通知 · 无法在挖孔屏呈现原子岛，点击前往开启',
          trailing: _notificationEnabled
              ? const SettingsChevron()
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.brandFill,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    '去开启',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
          onTap: _handleTap,
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: t.paperDeep,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 14, color: t.brandInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '💡 vivo (OriginOS) 适配说明：\n'
                  '1. 系统挖孔屏灵动岛（原子岛）受 vivo 官方限制，仅对官方白名单推送服务开放。\n'
                  '2. 本应用支持系统级实时前台秒表与锁屏胶囊，点击上方「去开启」进入系统设置，务必开启「允许通知」、「悬浮通知」和「锁屏通知」，并将通知类别保持为「重要通知」，即可在开屙时实时跳秒并一键完成。',
                  style: TextStyle(
                    fontSize: 11,
                    color: t.ink2,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
