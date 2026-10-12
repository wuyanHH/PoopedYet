import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../calendar/calendar_math.dart';
import '../../state/calendar_data.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../widgets/sheet_shell.dart';

/// 年月快速选择。
///
/// 解决的问题：从 2026年2月 回到 2024年8月，靠 `‹ ›` 要点 18 次。
///
/// 三个状态要分得开：
///   - **焦糖实底** = 正在查看的月
///   - **焦糖细环** = 今天所在的月
///   - **焦糖小点** = 该月有记录（灰点 = 没有）
Future<DateTime?> showYearMonthPickerSheet(
  BuildContext context, {
  required DateTime current,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _YearMonthPicker(current: current),
  );
}

class _YearMonthPicker extends ConsumerStatefulWidget {
  const _YearMonthPicker({required this.current});

  final DateTime current;

  @override
  ConsumerState<_YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends ConsumerState<_YearMonthPicker> {
  late int _year = widget.current.year;
  late final ScrollController _yearScroll;

  /// 可选年份范围。取一个够用的窗口，不做无限滚动。
  static const _minYear = 2015;
  static final _maxYear = DateTime.now().year + 3;

  static const _pillExtent = 62.0; // 宽 + 间距

  @override
  void initState() {
    super.initState();
    // 让选中的年份一进来就可见，而不是从头开始。
    final offset = (_year - _minYear) * _pillExtent - 120;
    _yearScroll = ScrollController(initialScrollOffset: offset.clamp(0, 1e6));
  }

  @override
  void dispose() {
    _yearScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = DateTime.now();
    final withRecords =
        ref.watch(monthsWithRecordsProvider(_year)).value ?? const <int>{};

    return SheetShell(
      title: '跳到哪个月',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              controller: _yearScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _maxYear - _minYear + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (_, i) {
                final y = _minYear + i;
                final on = y == _year;
                return GestureDetector(
                  onTap: () => setState(() => _year = y),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? t.brandFill : t.paperDeep,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '$y',
                      style: displayStyle(
                        size: 15,
                        letterSpacing: 0.4,
                        color: on ? Colors.white : t.ink2,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.55,
              children: [
                for (var m = 1; m <= 12; m++)
                  _MonthCell(
                    year: _year,
                    month: m,
                    isViewing: _year == widget.current.year &&
                        m == widget.current.month,
                    isTodayMonth: _year == today.year && m == today.month,
                    hasRecords: withRecords.contains(m),
                    onTap: () => Navigator.of(context).pop(DateTime(_year, m)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 13, color: t.ink3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '焦糖点 = 该月有记录。灰点月份点进去可以直接补录。',
                    style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SheetGhostButton(
              icon: LucideIcons.calendarCheck,
              label: '回到今天 · ${today.year}年${today.month}月',
              onTap: () => Navigator.of(context).pop(DateTime(today.year, today.month)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.year,
    required this.month,
    required this.isViewing,
    required this.isTodayMonth,
    required this.hasRecords,
    required this.onTap,
  });

  final int year;
  final int month;
  final bool isViewing;
  final bool isTodayMonth;
  final bool hasRecords;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // 正在看的月用实底；今天所在的月只加一道环。
    // 两者是同一个月的叠加情况下，实底优先 —— 加环反而看不清。
    final bg = isViewing ? t.brandFill : t.paperDeep;
    final fg = isViewing ? Colors.white : t.ink2;
    final dotColor = isViewing
        ? Colors.white
        : (hasRecords ? t.brandInk : t.ink4);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: !isViewing && isTodayMonth
              ? Border.all(color: t.brandInk, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$month月',
              style: displayStyle(size: 15, letterSpacing: 0.4, color: fg),
            ),
            const SizedBox(height: 5),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 周快速选择。
///
/// 按**网格行**切分，和日历上看到的行一一对应 [weeksOfMonth]。
/// 代价是首行（如 1/26–2/1）大部分属于上个月；好处是保证当月每一天
/// 都至少属于某一周，不会有日期在周选择器里点不到。
Future<WeekRange?> showWeekPickerSheet(
  BuildContext context, {
  required DateTime current,
}) {
  return showModalBottomSheet<WeekRange>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _WeekPicker(current: current),
  );
}

class _WeekPicker extends ConsumerWidget {
  const _WeekPicker({required this.current});

  final DateTime current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final settings = ref.watch(settingsProvider);
    final month = DateTime(current.year, current.month);
    final weeks = weeksOfMonth(month.year, month.month, settings.weekStart);

    return SheetShell(
      title: '跳到哪一周',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '${month.year}年${month.month}月 · 共 ${weeks.length} 周',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: t.ink3,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              spacing: 7,
              children: [
                for (final (i, w) in weeks.indexed)
                  _WeekRow(
                    index: i + 1,
                    week: w,
                    isCurrent: w.contains(current),
                    onTap: () => Navigator.of(context).pop(w),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 13, color: t.ink3),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '跨月的那一周会横跨两个月，点它会自动切到对应月份。',
                    style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.index,
    required this.week,
    required this.isCurrent,
    required this.onTap,
  });

  final int index;
  final WeekRange week;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: isCurrent ? t.brandSoft : t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent ? t.brandInk : t.lineSoft,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                '第 $index 周',
                style: displayStyle(
                  size: 14,
                  letterSpacing: 0.4,
                  color: isCurrent ? t.brandInk : t.ink2,
                ),
              ),
            ),
            Expanded(
              child: Text(
                week.label(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (week.spansTwoMonths)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(LucideIcons.calendarRange, size: 13, color: t.ink3),
              ),
            Icon(LucideIcons.chevronRight, size: 15, color: t.ink4),
          ],
        ),
      ),
    );
  }
}