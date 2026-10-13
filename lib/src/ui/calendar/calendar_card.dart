import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../calendar/calendar_math.dart';
import '../../data/database.dart';
import '../../data/queries.dart';
import '../../state/calendar_data.dart';
import '../../state/calendar_view.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../records/backfill_sheet.dart';
import 'calendar_grid.dart';
import 'swipe_to_navigate.dart';
import 'year_month_picker.dart';

/// 日历卡：头部 + 星期头 + 网格。
///
/// 月份标题是**可点的**（带 ▾），点开年月选择器。
/// 只靠 `‹ ›` 从 2026年2月 回到 2024年8月要点 18 次，实际用起来走不通。
class CalendarCard extends ConsumerWidget {
  const CalendarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final view = ref.watch(calendarViewProvider);
    final settings = ref.watch(settingsProvider);
    final today = ref.watch(todayProvider);
    final nav = ref.read(calendarViewProvider.notifier);

    final isMonth = view.mode == CalendarMode.month;

    final days = isMonth
        ? monthGridDays(
            view.visibleMonth.year,
            view.visibleMonth.month,
            settings.weekStart,
          )
        : weekDaysOf(view.selectedDate, settings.weekStart);

    final holidays = ref.watch(holidaysProvider).value ?? const <String, Holiday>{};

    final badgesAsync = isMonth
        ? ref.watch(monthBadgesProvider(view.visibleMonth))
        : ref.watch(weekBadgesProvider(view.selectedDate));

    // 加载中先按"没有徽标"画，而不是显示转圈 ——
    // 日历骨架是稳定的，徽标晚一帧出现比整块闪一下好得多。
    final badges = badgesAsync.value ?? const <String, List<PooperCount>>{};

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(PoopRadii.card),
        border: Border.all(color: const Color(0xB3E9DDCA)),
        boxShadow: PoopShadows.s1,
      ),
      padding: const EdgeInsets.fromLTRB(9, 13, 9, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            title: isMonth
                ? '${view.visibleMonth.year}年${view.visibleMonth.month}月'
                : _weekLabel(view, settings.weekStart),
            mode: view.mode,
            onTitleTap: () => _openPicker(context, ref),
            onPrev: isMonth ? nav.prevMonth : nav.prevWeek,
            onNext: isMonth ? nav.nextMonth : nav.nextWeek,
            onModeChanged: nav.setMode,
          ),
          const SizedBox(height: 10),
          WeekdayHeader(
            weekStart: settings.weekStart,
            weekendBrandColor: settings.weekendBrandColor,
          ),
          // 左右滑动切月/切周。包住**网格 + 星期头以上**的整块，
          // 但**不包头部** —— 头部有自己的按钮和分段控件，
          // 把它们的横向手势也吃掉会让点击变得迟钝。
          SwipeToNavigate(
            onPrev: isMonth ? nav.prevMonth : nav.prevWeek,
            onNext: isMonth ? nav.nextMonth : nav.nextWeek,
            child: CalendarGrid(
              days: days,
              monthAnchor: isMonth ? view.visibleMonth : null,
              view: view,
              settings: settings,
              badges: badges,
              holidays: holidays,
              today: today,
              weekMode: !isMonth,
              onSelectDay: (d) {
                // 点邻格的降级日期时把日历翻过去，否则用户点了没反应。
                nav.selectDay(d);
              },
              // 长按直接补录到那天 —— 翻到某天发现漏记了，
              // 不用先点选再找入口，少两步。
              onLongPressDay: (d) => showBackfillSheet(context, day: d),
            ),
          ),
        ],
      ),
    );
  }

  String _weekLabel(CalendarViewState view, WeekStart weekStart) {
    final days = weekDaysOf(view.selectedDate, weekStart);
    return WeekRange(days.first, days.last).labelCn();
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final view = ref.read(calendarViewProvider);

    if (view.mode == CalendarMode.week) {
      final picked = await showWeekPickerSheet(
        context,
        current: view.selectedDate,
      );
      if (picked != null) {
        ref.read(calendarViewProvider.notifier).goToWeek(picked);
      }
      return;
    }

    final picked = await showYearMonthPickerSheet(
      context,
      current: view.visibleMonth,
    );
    if (picked != null) {
      ref.read(calendarViewProvider.notifier).goToMonth(picked);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.mode,
    required this.onTitleTap,
    required this.onPrev,
    required this.onNext,
    required this.onModeChanged,
  });

  final String title;
  final CalendarMode mode;
  final VoidCallback onTitleTap;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<CalendarMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      children: [
        // 标题本身是按钮：点开年月/周选择器
        Flexible(
          child: InkWell(
            onTap: onTitleTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: displayStyle(
                        size: 19,
                        letterSpacing: 0.5,
                        color: t.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronDown, size: 15, color: t.ink3),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _NavButton(icon: LucideIcons.chevronLeft, onTap: onPrev),
        const SizedBox(width: 3),
        _NavButton(icon: LucideIcons.chevronRight, onTap: onNext),
        const Spacer(),
        _ModeSwitch(mode: mode, onChanged: onModeChanged),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: t.paperDeep,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 15, color: t.ink2),
      ),
    );
  }
}

/// 月 / 周 分段控件。
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final CalendarMode mode;
  final ValueChanged<CalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.paperDeep,
        borderRadius: BorderRadius.circular(PoopRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          for (final m in CalendarMode.values)
            GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
                decoration: BoxDecoration(
                  color: mode == m ? t.brandFill : Colors.transparent,
                  borderRadius: BorderRadius.circular(PoopRadii.pill),
                  boxShadow: mode == m
                      ? const [
                          BoxShadow(
                            color: Color(0x4DA85F29),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  m == CalendarMode.month ? '月' : '周',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: mode == m ? Colors.white : t.ink3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
