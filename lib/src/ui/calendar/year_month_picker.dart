import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../calendar/calendar_math.dart';
import '../../state/calendar_data.dart';
import '../../state/calendar_view.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../widgets/sheet_shell.dart';

// ============================================================================
//  日历快速跳转弹窗（按月展示只打开月选择，按周展示只打开周选择，无任何切换Tab）
// ============================================================================

/// 年月快速选择弹窗（月模式专属，无任何 Tab）。
Future<DateTime?> showYearMonthPickerSheet(
  BuildContext context, {
  required DateTime current,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _YearMonthPickerSheet(current: current),
  );
}

/// 周次快速选择弹窗（周模式专属，无任何 Tab，支持点击月份直接下钻切换）。
Future<WeekRange?> showWeekPickerSheet(
  BuildContext context, {
  required DateTime current,
}) {
  return showModalBottomSheet<WeekRange>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WeekPickerSheet(current: current),
  );
}

/// 统一跳转分流入口。
Future<dynamic> showCalendarJumpPickerSheet(
  BuildContext context, {
  required CalendarMode initialMode,
  required DateTime currentDate,
  required DateTime visibleMonth,
}) {
  if (initialMode == CalendarMode.month) {
    return showYearMonthPickerSheet(context, current: visibleMonth);
  } else {
    return showWeekPickerSheet(context, current: currentDate);
  }
}

// ============================================================================
//  1. 月份选择专属弹窗（无任何 Tab，纯粹微缩真实日历年矩阵）
// ============================================================================

class _YearMonthPickerSheet extends ConsumerStatefulWidget {
  const _YearMonthPickerSheet({required this.current});

  final DateTime current;

  @override
  ConsumerState<_YearMonthPickerSheet> createState() =>
      _YearMonthPickerSheetState();
}

class _YearMonthPickerSheetState extends ConsumerState<_YearMonthPickerSheet> {
  late int _year = widget.current.year;
  bool _showYearGrid = false;
  late int _yearGridPageBase = (_year ~/ 12) * 12;

  static const _minYear = 2015;
  static final _maxYear = DateTime.now().year + 6;

  void _changeYear(int y) {
    if (y < _minYear || y > _maxYear) return;
    setState(() {
      _year = y;
      _yearGridPageBase = (_year ~/ 12) * 12;
    });
  }

  void _prevYearPage() {
    final nextBase = _yearGridPageBase - 12;
    if (nextBase + 11 >= _minYear) {
      setState(() => _yearGridPageBase = nextBase);
    }
  }

  void _nextYearPage() {
    final nextBase = _yearGridPageBase + 12;
    if (nextBase <= _maxYear) {
      setState(() => _yearGridPageBase = nextBase);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = DateTime.now();
    final withRecords =
        ref.watch(monthsWithRecordsProvider(_year)).value ?? const <int>{};

    final title = _showYearGrid ? '选择年份' : '选择月份';
    final subtitle = _showYearGrid ? '点击年份快速跳转' : '挑选目标月份，微缩日历呈现全年排布';

    return SheetShell(
      title: title,
      subtitle: subtitle,
      scrollable: true,
      maxHeightFactor: 0.88,
      bottomBar: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop(DateTime(today.year, today.month));
        },
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: t.brandSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: t.brandInk.withValues(alpha: 0.25),
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.calendarCheck, size: 16, color: t.brandInk),
              const SizedBox(width: 8),
              Text(
                '回到本月 · ${today.year}年${today.month}月',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: t.brandInk,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 2),

            // 一体化流线型年份导航胶囊
            _IntegratedCapsuleNavigator(
              title: _showYearGrid
                  ? '$_yearGridPageBase - ${_yearGridPageBase + 11} 年'
                  : '$_year 年',
              isExpanded: _showYearGrid,
              prevEnabled: _showYearGrid
                  ? _yearGridPageBase > _minYear
                  : _year > _minYear,
              nextEnabled: _showYearGrid
                  ? _yearGridPageBase + 11 < _maxYear
                  : _year < _maxYear,
              onPrev: _showYearGrid
                  ? _prevYearPage
                  : () => _changeYear(_year - 1),
              onNext: _showYearGrid
                  ? _nextYearPage
                  : () => _changeYear(_year + 1),
              onTapTitle: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _showYearGrid = !_showYearGrid;
                  _yearGridPageBase = (_year ~/ 12) * 12;
                });
              },
            ),
            const SizedBox(height: 14),

            // 12 个微缩真实日历年矩阵 / 年份选择矩阵
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _showYearGrid
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildMonthsGrid(t, today, withRecords),
              secondChild: _buildYearsGrid(t, today),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthsGrid(
    PoopTokens t,
    DateTime today,
    Set<int> withRecords,
  ) {
    final settings = ref.watch(settingsProvider);

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15, // 黄金舒展比例：彻底解决真机上的高度溢出，排版整洁大方
      children: [
        for (var m = 1; m <= 12; m++)
          _MonthCard(
            year: _year,
            month: m,
            weekStart: settings.weekStart,
            isViewing: _year == widget.current.year && m == widget.current.month,
            isTodayMonth: _year == today.year && m == today.month,
            hasRecords: withRecords.contains(m),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(DateTime(_year, m));
            },
          ),
      ],
    );
  }

  Widget _buildYearsGrid(PoopTokens t, DateTime today) {
    final years = List.generate(12, (i) => _yearGridPageBase + i);

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        for (final y in years)
          _YearTile(
            year: y,
            isSelected: y == _year,
            isThisYear: y == today.year,
            enabled: y >= _minYear && y <= _maxYear,
            onTap: () {
              HapticFeedback.lightImpact();
              _changeYear(y);
              setState(() => _showYearGrid = false);
            },
          ),
      ],
    );
  }
}

// ============================================================================
//  2. 周次选择专属弹窗（无任何 Tab，可点击月份直接展开微缩日历）
// ============================================================================

class _WeekPickerSheet extends ConsumerStatefulWidget {
  const _WeekPickerSheet({required this.current});

  final DateTime current;

  @override
  ConsumerState<_WeekPickerSheet> createState() => _WeekPickerSheetState();
}

class _WeekPickerSheetState extends ConsumerState<_WeekPickerSheet> {
  late DateTime _weekMonth = DateTime(widget.current.year, widget.current.month);
  bool _showMonthGridInWeek = false;

  void _prevWeekMonth() {
    setState(() {
      _weekMonth = DateTime(_weekMonth.year, _weekMonth.month - 1);
    });
  }

  void _nextWeekMonth() {
    setState(() {
      _weekMonth = DateTime(_weekMonth.year, _weekMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = ref.watch(settingsProvider);
    final today = DateTime.now();

    final weeks =
        weeksOfMonth(_weekMonth.year, _weekMonth.month, settings.weekStart);
    final withRecords =
        ref.watch(monthsWithRecordsProvider(_weekMonth.year)).value ??
            const <int>{};

    final title = _showMonthGridInWeek ? '选择月份' : '选择周次';
    final subtitle =
        _showMonthGridInWeek ? '挑选目标月份查看周次' : '挑选目标周次，可透视 7 日全景';

    return SheetShell(
      title: title,
      subtitle: subtitle,
      scrollable: true,
      maxHeightFactor: 0.88,
      bottomBar: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          final weekDays = weekDaysOf(today, settings.weekStart);
          Navigator.of(context).pop(WeekRange(weekDays.first, weekDays.last));
        },
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: t.brandSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: t.brandInk.withValues(alpha: 0.25),
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.calendarCheck, size: 16, color: t.brandInk),
              const SizedBox(width: 8),
              Text(
                '回到本周 · 今天是周${_wd(today)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: t.brandInk,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 2),

            // 一体化流线型月份切换胶囊：点击中间标题直接展开微缩日历选月份！
            _IntegratedCapsuleNavigator(
              title: '${_weekMonth.year}年${_weekMonth.month}月 · 共 ${weeks.length} 周',
              prefixIcon: LucideIcons.calendarDays,
              isExpanded: _showMonthGridInWeek,
              onPrev: _prevWeekMonth,
              onNext: _nextWeekMonth,
              onTapTitle: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _showMonthGridInWeek = !_showMonthGridInWeek;
                });
              },
            ),
            const SizedBox(height: 12),

            // 点击中间月份标题后展开微缩日历网格选月份，选完秒切回该月周次！
            if (_showMonthGridInWeek) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 4),
                child: Text(
                  '点击月份快速直达：',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: t.ink3,
                  ),
                ),
              ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15, // 黄金舒展比例，杜绝溢出
                children: [
                  for (var m = 1; m <= 12; m++)
                    _MonthCard(
                      year: _weekMonth.year,
                      month: m,
                      weekStart: settings.weekStart,
                      isViewing: m == _weekMonth.month,
                      isTodayMonth:
                          _weekMonth.year == today.year && m == today.month,
                      hasRecords: withRecords.contains(m),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _weekMonth = DateTime(_weekMonth.year, m);
                          _showMonthGridInWeek = false;
                        });
                      },
                    ),
                ],
              ),
            ] else ...[
              // 周次卡片列表
              for (final (i, w) in weeks.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                _WeekCard(
                  index: i + 1,
                  week: w,
                  currentMonth: _weekMonth,
                  isCurrent: w.contains(widget.current),
                  isThisWeek: w.contains(today),
                  today: today,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop(w);
                  },
                ),
              ],
            ],

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static String _wd(DateTime d) =>
      const ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1];
}

// ============================================================================
//  分段选择小部件与卡片
// ============================================================================

/// 一体化流线型手账导航胶囊（告别原先左右散落的三个丑陋方块）
class _IntegratedCapsuleNavigator extends StatelessWidget {
  const _IntegratedCapsuleNavigator({
    required this.title,
    required this.onPrev,
    required this.onNext,
    required this.onTapTitle,
    this.prevEnabled = true,
    this.nextEnabled = true,
    this.isExpanded = false,
    this.prefixIcon,
  });

  final String title;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapTitle;
  final bool prevEnabled;
  final bool nextEnabled;
  final bool isExpanded;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: t.paperDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.lineSoft, width: 1.0),
      ),
      child: Row(
        children: [
          // 左侧快速翻退按钮
          _NavArrowButton(
            icon: LucideIcons.chevronLeft,
            enabled: prevEnabled,
            onTap: onPrev,
          ),

          // 中间大字可点击标题区域（带点击微触感与平滑展开箭头旋转）
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapTitle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (prefixIcon != null) ...[
                    Icon(prefixIcon, size: 15, color: t.brandInk),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    title,
                    style: displayStyle(
                      size: 16,
                      letterSpacing: 0.6,
                      color: isExpanded ? t.brandInk : t.ink,
                    ),
                  ),
                  const SizedBox(width: 5),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 15,
                      color: isExpanded ? t.brandInk : t.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 右侧快速翻进按钮
          _NavArrowButton(
            icon: LucideIcons.chevronRight,
            enabled: nextEnabled,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

/// 胶囊内部内嵌的微触感箭头按键
class _NavArrowButton extends StatefulWidget {
  const _NavArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_NavArrowButton> createState() => _NavArrowButtonState();
}

class _NavArrowButtonState extends State<_NavArrowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = widget.enabled;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: Container(
          width: 40,
          height: double.infinity,
          alignment: Alignment.center,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1.0 : 0.3,
            child: Icon(
              widget.icon,
              size: 17,
              color: t.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _YearTile extends StatelessWidget {
  const _YearTile({
    required this.year,
    required this.isSelected,
    required this.isThisYear,
    required this.enabled,
    required this.onTap,
  });

  final int year;
  final bool isSelected;
  final bool isThisYear;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (!enabled) {
      return Container(
        decoration: BoxDecoration(
          color: t.paperDeep.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          '$year',
          style: TextStyle(
            fontSize: 14,
            color: t.ink4.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [t.brand, t.brandFill],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : t.surface,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? null
              : Border.all(
                  color: isThisYear
                      ? t.brandInk.withValues(alpha: 0.6)
                      : t.lineSoft,
                  width: isThisYear ? 1.5 : 1.0,
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: t.brandFill.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$year',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected || isThisYear
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isThisYear ? t.brandInk : t.ink),
                letterSpacing: 0.5,
              ),
            ),
            if (isThisYear && !isSelected) ...[
              const SizedBox(width: 4),
              Container(
                width: 4.5,
                height: 4.5,
                decoration: BoxDecoration(
                  color: t.brandInk,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthCard extends StatefulWidget {
  const _MonthCard({
    required this.year,
    required this.month,
    required this.weekStart,
    required this.isViewing,
    required this.isTodayMonth,
    required this.hasRecords,
    required this.onTap,
  });

  final int year;
  final int month;
  final WeekStart weekStart;
  final bool isViewing;
  final bool isTodayMonth;
  final bool hasRecords;
  final VoidCallback onTap;

  @override
  State<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends State<_MonthCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isViewing = widget.isViewing;
    final isTodayMonth = widget.isTodayMonth;
    final hasRecords = widget.hasRecords;

    final bg = isViewing
        ? null
        : (isTodayMonth
            ? (t.isDark
                ? t.brandSoft.withValues(alpha: 0.35)
                : const Color(0xFFFFF9F2))
            : t.surface);

    final fg = isViewing
        ? Colors.white
        : (isTodayMonth ? t.brandInk : t.ink);

    // 计算当月的真实微缩日历网格数据
    final leading = leadingBlanks(widget.year, widget.month, widget.weekStart);
    final totalDays = daysInMonth(widget.year, widget.month);
    final rows = monthGridRows(widget.year, widget.month, widget.weekStart);

    // 星期表头（跟随 weekStart 排布）
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final orderedWeekdays = widget.weekStart == WeekStart.monday
        ? weekdays
        : [weekdays.last, ...weekdays.take(6)];

    final today = DateTime.now();
    final isCurrentRealMonth =
        widget.year == today.year && widget.month == today.month;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          decoration: BoxDecoration(
            gradient: isViewing
                ? LinearGradient(
                    colors: [t.brand, t.brandFill],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: bg,
            borderRadius: BorderRadius.circular(13),
            border: isViewing
                ? null
                : Border.all(
                    color: isTodayMonth
                        ? t.brandInk.withValues(alpha: 0.55)
                        : t.lineSoft,
                    width: isTodayMonth ? 1.4 : 1.0,
                  ),
            boxShadow: isViewing
                ? [
                    BoxShadow(
                      color: t.brandFill.withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 卡片头部：月份大标题 + 状态小标签
              Row(
                children: [
                  Text(
                    '${widget.month}月',
                    style: displayStyle(
                      size: 15,
                      letterSpacing: 0.2,
                      color: fg,
                    ),
                  ),
                  const Spacer(),
                  if (isTodayMonth && !isViewing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: t.brandSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '本月',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: t.brandInk,
                        ),
                      ),
                    )
                  else if (hasRecords)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isViewing ? Colors.white : t.brandInk,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),

              // 2. 真实微缩日历网格区（加入 FittedBox 防真机溢出保护，100% 绝对安全）
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 88,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 微缩星期指示行
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final label in orderedWeekdays)
                              SizedBox(
                                width: 10,
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w700,
                                    color: isViewing
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : t.ink4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // 微缩日期点阵（精准还原真实月历星期排布）
                        for (var r = 0; r < rows; r++) ...[
                          if (r > 0) const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var c = 0; c < 7; c++)
                                _buildMiniDayCell(
                                  t: t,
                                  dayIndex: r * 7 + c,
                                  leading: leading,
                                  totalDays: totalDays,
                                  isViewing: isViewing,
                                  isCurrentRealMonth: isCurrentRealMonth,
                                  todayDay: today.day,
                                  hasRecords: hasRecords,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniDayCell({
    required PoopTokens t,
    required int dayIndex,
    required int leading,
    required int totalDays,
    required bool isViewing,
    required bool isCurrentRealMonth,
    required int todayDay,
    required bool hasRecords,
  }) {
    final inMonth = dayIndex >= leading && dayIndex < leading + totalDays;
    if (!inMonth) {
      return const SizedBox(width: 10, height: 4.5);
    }

    final dayNum = dayIndex - leading + 1;
    final isRealToday = isCurrentRealMonth && dayNum == todayDay;

    // 默认微缩圆点
    final Color dotColor;
    if (isViewing) {
      dotColor = isRealToday
          ? Colors.white
          : Colors.white.withValues(alpha: 0.45);
    } else {
      dotColor = isRealToday
          ? t.brandInk
          : (hasRecords
              ? t.brandInk.withValues(alpha: 0.45)
              : (t.isDark ? const Color(0x33E7DAC6) : const Color(0xFFDFD4C2)));
    }

    return SizedBox(
      width: 10,
      height: 5.5,
      child: Center(
        child: Container(
          width: isRealToday ? 4.5 : 3.5,
          height: isRealToday ? 4.5 : 3.5,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: isRealToday && !isViewing
                ? Border.all(color: t.brandInk, width: 0.8)
                : null,
          ),
        ),
      ),
    );
  }
}

class _WeekCard extends StatefulWidget {
  const _WeekCard({
    required this.index,
    required this.week,
    required this.currentMonth,
    required this.isCurrent,
    required this.isThisWeek,
    required this.today,
    required this.onTap,
  });

  final int index;
  final WeekRange week;
  final DateTime currentMonth;
  final bool isCurrent;
  final bool isThisWeek;
  final DateTime today;
  final VoidCallback onTap;

  @override
  State<_WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends State<_WeekCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isCurrent = widget.isCurrent;
    final isThisWeek = widget.isThisWeek;

    final gradient = isCurrent
        ? LinearGradient(
            colors: [t.brand, t.brandFill],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    final bg = isCurrent
        ? null
        : (isThisWeek
            ? (t.isDark
                ? t.brandSoft.withValues(alpha: 0.35)
                : const Color(0xFFFFF9F2))
            : t.surface);

    final border = isCurrent
        ? null
        : Border.all(
            color: isThisWeek
                ? t.brandInk.withValues(alpha: 0.6)
                : t.lineSoft,
            width: isThisWeek ? 1.5 : 1.0,
          );

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          decoration: BoxDecoration(
            gradient: gradient,
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: border,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: t.brandFill.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '第 ${widget.index} 周',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isCurrent ? Colors.white : t.ink,
                          ),
                        ),
                        if (isThisWeek) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : t.brandSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '本周',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isCurrent ? Colors.white : t.brandInk,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.week.labelCn(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isCurrent
                            ? Colors.white.withValues(alpha: 0.85)
                            : t.ink3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: _WeekDaysStrip(
                  week: widget.week,
                  currentMonth: widget.currentMonth,
                  isCurrentWeek: isCurrent,
                  today: widget.today,
                  t: t,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekDaysStrip extends StatelessWidget {
  const _WeekDaysStrip({
    required this.week,
    required this.currentMonth,
    required this.isCurrentWeek,
    required this.today,
    required this.t,
  });

  final WeekRange week;
  final DateTime currentMonth;
  final bool isCurrentWeek;
  final DateTime today;
  final PoopTokens t;

  @override
  Widget build(BuildContext context) {
    final days = <DateTime>[];
    for (var i = 0; i < 7; i++) {
      days.add(week.first.add(Duration(days: i)));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentWeek
            ? Colors.white.withValues(alpha: 0.15)
            : t.paperDeep,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final d in days) _buildDayDot(d),
        ],
      ),
    );
  }

  Widget _buildDayDot(DateTime d) {
    final isSameMonth = d.month == currentMonth.month;
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;

    Color fg;
    if (isCurrentWeek) {
      fg = isSameMonth
          ? Colors.white
          : Colors.white.withValues(alpha: 0.45);
    } else {
      fg = isSameMonth
          ? (isToday ? t.brandInk : t.ink2)
          : t.ink4.withValues(alpha: 0.45);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${d.day}',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: fg,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (isToday)
          Container(
            margin: const EdgeInsets.only(top: 1.5),
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: isCurrentWeek ? Colors.white : t.brandInk,
              shape: BoxShape.circle,
            ),
          )
        else
          const SizedBox(height: 4.5),
      ],
    );
  }
}
