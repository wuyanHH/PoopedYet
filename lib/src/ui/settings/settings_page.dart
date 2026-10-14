import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../calendar/calendar_math.dart';
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
                subtitle: poopers.isEmpty
                    ? '还没有'
                    : poopers.map((p) => p.name).join('、'),
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const PooperListPage()),
              ),
              SettingsRow(
                leading: LucideIcons.tags,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '便便感受',
                subtitle: '${templates.length} 条 · 管理打卡标签（如顺畅、便秘、拉肚子等）',
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const NoteTemplatePage()),
              ),
            ],
          ),

          // ---------------- 日历 ----------------
          const SettingsSectionLabel('日历'),
          SettingsCard(
            children: [
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
                trailing: const SettingsValue(_version),
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
                  applicationVersion: _version,
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

  static const _version = '0.3.0';

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                  'vivo (OriginOS 5/6) 用户请在系统通知管理中确保勾选「允许通知」、「悬浮通知」与「原子通知」，开屙时挖孔屏旁即可实时浮现灵动胶囊。',
                  style: TextStyle(
                    fontSize: 11,
                    color: t.ink2,
                    height: 1.45,
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
