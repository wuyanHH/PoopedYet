import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../calendar/calendar_math.dart';
import '../../data/holiday_loader.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../state/calendar_view.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../widgets/settings_widgets.dart';

/// 日历与打卡视图设置页。
///
/// 包含视图模式、起始日、排序规则、字号缩放、格内角标与节假日管理，
/// 顶部提供所见即所得的 7 天微缩实时动态预览。
class CalendarSettingsPage extends ConsumerWidget {
  const CalendarSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final s = ref.read(settingsProvider.notifier);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: '日历与打卡视图',
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + bottomInset),
        children: [
          // 顶部：7天所见即所得实时微缩预览卡
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _CalendarLivePreview(settings: settings),
          ),

          // ---------------- 视图与布局 ----------------
          const SettingsSectionLabel('视图与布局'),
          SettingsCard(
            children: [
              SettingsRow(
                title: '默认展示视图',
                subtitle: '打开应用时默认以月历或周历呈现',
                trailing: SettingsSegmented<CalendarMode>(
                  options: const [
                    ('月历', CalendarMode.month),
                    ('周历', CalendarMode.week),
                  ],
                  value: settings.defaultCalendarMode,
                  onChanged: (mode) {
                    HapticFeedback.selectionClick();
                    s.setDefaultCalendarMode(mode);
                  },
                ),
              ),
              SettingsRow(
                title: '每周起始日',
                subtitle: '决定日历网格以周一或周日为第一列',
                trailing: SettingsSegmented<WeekStart>(
                  options: const [
                    ('周一', WeekStart.monday),
                    ('周日', WeekStart.sunday),
                  ],
                  value: settings.weekStart,
                  onChanged: (ws) {
                    HapticFeedback.selectionClick();
                    s.setWeekStart(ws);
                  },
                ),
              ),
              SettingsRow(
                title: '记录排列顺序',
                subtitle: '当日打卡记录按时间倒序或正序排列',
                trailing: SettingsSegmented<RecordSortOrder>(
                  options: const [
                    ('倒序', RecordSortOrder.desc),
                    ('正序', RecordSortOrder.asc),
                  ],
                  value: settings.recordSortOrder,
                  onChanged: (order) {
                    HapticFeedback.selectionClick();
                    s.setRecordSortOrder(order);
                  },
                ),
              ),
              SettingsRow(
                title: '日历格内字号',
                subtitle: '系统字号放大时，日历格内最多跟到 1.3× 避免挤压',
                trailing: SettingsSegmented<CalendarTextSize>(
                  options: const [
                    ('小', CalendarTextSize.small),
                    ('中', CalendarTextSize.medium),
                    ('大', CalendarTextSize.large),
                  ],
                  value: settings.calendarTextSize,
                  onChanged: (size) {
                    HapticFeedback.selectionClick();
                    s.setCalendarTextSize(size);
                  },
                ),
              ),
            ],
          ),

          // ---------------- 信息与角标 ----------------
          const SettingsSectionLabel('信息与角标'),
          SettingsCard(
            children: [
              SettingsRow(
                title: '格内显示头像与次数',
                subtitle: '关闭后日期格仅保留基本日期，更为简洁清爽',
                trailing: SettingsSwitch(
                  value: settings.showBadges,
                  onChanged: s.setShowBadges,
                ),
              ),
              SettingsRow(
                title: '显示休 / 班角标',
                subtitle: '标记国家法定节假日与调休上班日',
                trailing: SettingsSwitch(
                  value: settings.showHolidayTags,
                  onChanged: s.setShowHolidayTags,
                ),
              ),
              SettingsRow(
                title: '周末日期强调色',
                subtitle: '周六与周日日期采用主题暖色高亮',
                trailing: SettingsSwitch(
                  value: settings.weekendBrandColor,
                  onChanged: s.setWeekendBrandColor,
                ),
              ),
            ],
          ),

          // ---------------- 数据与高级 ----------------
          const SettingsSectionLabel('数据与高级'),
          SettingsCard(
            children: [
              const _HolidaySyncRow(),
              SettingsRow(
                title: '隐藏已归档的屙屎人',
                subtitle: '默认关闭 · 归档人员历史记录仍在，隐藏会让日历统计看起来减少',
                trailing: SettingsSwitch(
                  value: settings.hideArchivedPoopers,
                  onChanged: s.setHideArchivedPoopers,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 7 天所见即所得的微缩日历预览卡
class _CalendarLivePreview extends StatelessWidget {
  const _CalendarLivePreview({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isMon = settings.weekStart == WeekStart.monday;

    // 模拟 7 天周数据
    final weekLabels = isMon
        ? const ['一', '二', '三', '四', '五', '六', '日']
        : const ['日', '一', '二', '三', '四', '五', '六'];

    final dayNumbers = isMon
        ? const [19, 20, 21, 22, 23, 24, 25]
        : const [18, 19, 20, 21, 22, 23, 24];

    // 缩放基数
    final textScale = settings.calendarTextSize.scale;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.lineSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C2D1B0D),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 14, color: t.brandInk),
              const SizedBox(width: 6),
              Text(
                '日历视觉效果实时预览',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
              const Spacer(),
              Text(
                settings.defaultCalendarMode == CalendarMode.month ? '月历模式' : '周历模式',
                style: TextStyle(fontSize: 11, color: t.ink3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 星期表头
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekLabels[i],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _isWeekend(i, isMon) && settings.weekendBrandColor
                            ? t.brandInk
                            : t.ink3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // 模拟的 7 个微缩日期格子
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: Container(
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == 3 ? t.brandSoft.withValues(alpha: 0.5) : t.paper,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: i == 3 ? t.brandInk.withValues(alpha: 0.3) : t.lineSoft,
                        width: i == 3 ? 1.0 : 0.6,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 休 / 班 角标
                        if (settings.showHolidayTags && (i == 5 || i == 6))
                          Positioned(
                            top: 2,
                            left: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                                vertical: 0.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE55D5D),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                '休',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                        // 日期数字
                        Positioned(
                          top: 4,
                          right: 5,
                          child: Text(
                            '${dayNumbers[i]}',
                            style: TextStyle(
                              fontSize: 12 * textScale,
                              fontWeight: i == 3 ? FontWeight.w800 : FontWeight.w600,
                              color: _isWeekend(i, isMon) && settings.weekendBrandColor
                                  ? t.brandInk
                                  : t.ink,
                            ),
                          ),
                        ),
                        // 格内头像与次数模拟
                        if (settings.showBadges && (i == 1 || i == 3 || i == 5))
                          Positioned(
                            bottom: 4,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: t.brandInk,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '💩',
                                    style: TextStyle(fontSize: 8),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  i == 3 ? '2' : '1',
                                  style: TextStyle(
                                    fontSize: 9.5 * textScale,
                                    fontWeight: FontWeight.w800,
                                    color: t.brandInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _isWeekend(int index, bool isMon) {
    if (isMon) {
      return index == 5 || index == 6; // 六、日
    } else {
      return index == 0 || index == 6; // 日、六
    }
  }
}

/// 法定节假日数据管理与在线 API 同步行
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
