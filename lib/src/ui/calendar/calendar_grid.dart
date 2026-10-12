import 'package:flutter/material.dart';

import '../../calendar/calendar_math.dart';
import '../../calendar/layout.dart';
import '../../data/database.dart';
import '../../data/queries.dart';
import '../../state/calendar_view.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import 'day_cell.dart';

/// 日历的网格。月视图与周视图共用。
///
/// 两种模式的区别只有三处：日期列表、格高、每格放几行徽标。
/// 所以做一套参数化的网格，而不是写两遍 —— 写两遍迟早改漏一处。
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.days,
    required this.view,
    required this.settings,
    required this.badges,
    required this.holidays,
    required this.today,
    required this.onSelectDay,
    this.monthAnchor,
    this.weekMode = false,
  });

  /// 网格里的全部日期，长度恒为 7 的倍数。
  final List<DateTime> days;

  /// 用来判断"是不是本月的日期"。
  ///
  /// 周视图传 null —— 周视图没有"本月/非本月"的降级，七天都是当前周，
  /// 不该有格子被淡化。
  final DateTime? monthAnchor;

  final CalendarViewState view;
  final Settings settings;

  /// `日期键 -> 该天每人次数`，已按屙屎人顺序排好。
  final Map<String, List<PooperCount>> badges;

  /// `yyyy-MM-dd -> Holiday`。没有这条键就是普通日子，不画角标。
  final Map<String, Holiday> holidays;

  final DateTime today;
  final ValueChanged<DateTime> onSelectDay;

  /// 周视图：格子更高、能放更多行徽标。
  final bool weekMode;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = effectiveCalendarScale(
      mq.textScaler.scale(1),
      settings.calendarTextSize.scale,
    );

    // ★ 关键：把钳制过的 textScaler 真正灌进子树。
    //   只算出来拿去算格高是不够的 —— 文字本身也得按这个倍率渲染，
    //   否则算的是一套、画的是另一套，格高白算。
    //
    //   这个 MediaQuery **只包日历格**。日历卡的月份标题、星期头、日期栏
    //   都在它外面，照常跟随系统字号。
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(scale)),
      child: _grid(context, scale),
    );
  }

  Widget _grid(BuildContext context, double scale) {
    final badgeRows = weekMode ? 3 : 2;
    final cellHeight =
        weekMode ? 126.0 : cellHeightFor(scale, badgeRows: badgeRows);
    final rows = days.length ~/ 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < rows; r++)
            Padding(
              padding: EdgeInsets.only(top: r == 0 ? 0 : 3),
              child: SizedBox(
                height: cellHeight,
                child: Row(
                  spacing: 3,
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: _cell(days[r * 7 + c], badgeRows),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(DateTime date, int badgeRows) {
    final anchor = monthAnchor;
    final inMonth = anchor == null ||
        (date.year == anchor.year && date.month == anchor.month);
    final key = dayKey(date);

    return DayCell(
      date: date,
      inMonth: inMonth,
      isToday: isSameDay(date, today),
      isSelected: isSameDay(date, view.selectedDate),
      isWeekend: date.weekday >= DateTime.saturday,
      badges: badges[key] ?? const [],
      holiday: holidayKindOf(holidays[key]),
      showBadges: settings.showBadges,
      showHolidayTags: settings.showHolidayTags,
      weekendBrandColor: settings.weekendBrandColor,
      maxBadgeRows: badgeRows,
      onTap: () => onSelectDay(date),
    );
  }
}

/// 把数据库里的节假日行翻译成日历格要的角标类型。
///
/// **`isOffDay == false` 才是「班」** —— 反直觉但正确：
/// 这批日期是周末补班，一年只有五六天，恰恰是最需要提醒用户的。
HolidayKind? holidayKindOf(Holiday? h) {
  if (h == null) return null;
  return h.isOffDay ? HolidayKind.off : HolidayKind.work;
}

/// 星期头（一二三四五六日）。
///
/// 跟着 [Settings.weekStart] 换顺序 —— 网格的列序和它必须一致，
/// 不然"周一作首列"的设置下会显示成周日在前。
class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({
    super.key,
    required this.weekStart,
    required this.weekendBrandColor,
  });

  final WeekStart weekStart;
  final bool weekendBrandColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const labels = ['一', '二', '三', '四', '五', '六', '日'];

    // 周一作首列时顺序是 一二三四五六日；
    // 周日作首列时把"日"挪到最前面 → 日一二三四五六。
    final ordered = weekStart == WeekStart.monday
        ? labels
        : [labels.last, ...labels.take(6)];

    // ⚠ 必须和网格用同一个 spacing，否则列宽算出来不一样、整排错位。
    // ⚠ 周末判断要看**标签本身**，不能看顺序下标 ——
    //   周日作首列时"六"跑到最后一列、"日"在第一列，按下标判断会染错两个。
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 0, 9, 5),
      child: Row(
        spacing: 3,
        children: [
          for (final label in ordered)
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: weekendBrandColor && (label == '六' || label == '日')
                      ? t.brandInk
                      : t.ink3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
