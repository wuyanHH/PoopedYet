import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// 日历卡：头部 + 星期头 + 网格 + 底部拖动小白条。
///
/// 视觉与交互动画全面升级：
///   - 底部添加物理质感拖动小白条（Handle Bar），支持上下拖动与点击切换周/月视图
///   - 重构周/月切换动效：采用平滑高度折叠卷帘动效与顶部锁定对齐，彻底消除居中错位与抖动
///   - 优化横向切月/切周翻页动效：平滑缓动滑入滑出，自然跟手无生硬感
///   - 左右与上下手势严格解耦，上下切换模式、左右翻切日期
class CalendarCard extends ConsumerStatefulWidget {
  const CalendarCard({super.key});

  @override
  ConsumerState<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends ConsumerState<CalendarCard> {
  DateTime? _lastAnchor;
  CalendarMode? _lastMode;
  int _direction = 1; // 1: next, -1: prev, 0: 模式切换
  bool _isVertical = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final view = ref.watch(calendarViewProvider);
    final settings = ref.watch(settingsProvider);
    final today = ref.watch(todayProvider);
    final nav = ref.read(calendarViewProvider.notifier);

    final isMonth = view.mode == CalendarMode.month;

    // 当前网格日期的锚点，用于唯一标识和比较滑动方向
    final currentAnchor = isMonth
        ? DateTime(view.visibleMonth.year, view.visibleMonth.month)
        : weekDaysOf(view.selectedDate, settings.weekStart).first;

    if (_lastAnchor != null) {
      if (_lastMode != view.mode) {
        _direction = 0; // 周/月模式切换
      } else if (currentAnchor.isAfter(_lastAnchor!)) {
        _direction = 1; // 下一月 / 下一周
      } else if (currentAnchor.isBefore(_lastAnchor!)) {
        _direction = -1; // 上一月 / 上一周
      }
    }
    _lastAnchor = currentAnchor;
    _lastMode = view.mode;

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

    final badges = badgesAsync.value ?? const <String, List<PooperCount>>{};

    final gridKey = isMonth
        ? ValueKey('m:${view.visibleMonth.year}-${view.visibleMonth.month}')
        : ValueKey('w:${currentAnchor.year}-${currentAnchor.month}-${currentAnchor.day}');

    final isModeSwitch = _direction == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(PoopRadii.card),
        border: Border.all(color: t.line, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: t.isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0x122D1B0D),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: t.isDark
                ? Colors.black.withValues(alpha: 0.2)
                : const Color(0x0A2D1B0D),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      // 用 hardEdge 而不是 antiAlias：网格四周有 10px 内边距，永远碰不到
      // 卡片的圆角，矩形裁剪的视觉效果完全一致，但不用走抗锯齿离屏绘制。
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头部：标题与切换分段控件
          _Header(
            title: isMonth
                ? '${view.visibleMonth.year}年${view.visibleMonth.month}月'
                : _weekLabel(view, settings.weekStart),
            mode: view.mode,
            direction: _direction,
            isVertical: _isVertical,
            onTitleTap: () => _openPicker(context, ref),
            onModeChanged: nav.setMode,
          ),
          const SizedBox(height: 10),

          // 星期栏：一 二 三 四 五 六 日
          WeekdayHeader(
            weekStart: settings.weekStart,
            weekendBrandColor: settings.weekendBrandColor,
          ),

          // 日历网格区域：月视图支持顺畅的双向手势切月，周视图专注水平切周
          SwipeToNavigate(
            allowVertical: isMonth,
            onPrev: ({required bool isVertical}) {
              HapticFeedback.selectionClick();
              setState(() {
                _isVertical = isVertical;
              });
              if (isMonth) {
                nav.prevMonth();
              } else {
                nav.prevWeek();
              }
            },
            onNext: ({required bool isVertical}) {
              HapticFeedback.selectionClick();
              setState(() {
                _isVertical = isVertical;
              });
              if (isMonth) {
                nav.nextMonth();
              } else {
                nav.nextWeek();
              }
            },
            child: AnimatedSize(
              // 只有周↔月切换才需要高度折叠动画。同模式的左右翻页两套网格
              // 高度完全相同，让 AnimatedSize 也跑 260ms 只是白开一条动画。
              duration: isModeSwitch
                  ? const Duration(milliseconds: 320)
                  : Duration.zero,
              curve: Curves.fastEaseInToSlowEaseOut,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: AnimatedSwitcher(
                  duration: Duration(milliseconds: isModeSwitch ? 320 : 260),
                  switchInCurve: Curves.fastEaseInToSlowEaseOut,
                  switchOutCurve: Curves.fastEaseInToSlowEaseOut,
                  layoutBuilder: (currentChild, previousChildren) {
                    if (isModeSwitch) {
                      // 模式切换（周↔月）专属布局：顶端锁定对齐，配合 AnimatedSize 形成丝滑的卷帘折叠展开
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        alignment: Alignment.topCenter,
                        children: [
                          if (previousChildren.isNotEmpty)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: previousChildren.last,
                            ),
                          if (currentChild != null) currentChild,
                        ],
                      );
                    }
                    // 同模式翻页：新旧网格视差穿透推拉，上层平滑推入，底层快速退场
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      alignment: Alignment.topCenter,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final isIncoming = child.key == gridKey;

                    if (isModeSwitch) {
                      // 模式切换（周/月切换）：Material 3 容器舒展与呼吸微缩放，消除跳跃与生硬感
                      final scaleAnim = isIncoming
                          ? Tween<double>(begin: 0.96, end: 1.0).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.fastEaseInToSlowEaseOut,
                              ),
                            )
                          : const AlwaysStoppedAnimation(1.0);

                      final slideAnim = isIncoming
                          ? Tween<Offset>(
                              begin: const Offset(0, 0.02),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.fastEaseInToSlowEaseOut,
                            ))
                          : const AlwaysStoppedAnimation(Offset.zero);

                      final fadeAnim = CurvedAnimation(
                        parent: animation,
                        curve: isIncoming
                            ? const Interval(0.12, 1.0, curve: Curves.easeOutCubic)
                            : const Interval(0.0, 0.50, curve: Curves.easeInCubic),
                      );

                      return SlideTransition(
                        position: slideAnim,
                        child: ScaleTransition(
                          scale: scaleAnim,
                          child: FadeTransition(
                            opacity: fadeAnim,
                            child: child,
                          ),
                        ),
                      );
                    }

                    // 翻页切月 / 切周：视差微移穿透模型
                    // 水平滑动沿 X 轴穿透，垂直上下滑沿 Y 轴穿透，手势与动效完全同向，自然连贯
                    final slideOffset = _isVertical
                        ? (isIncoming
                            ? Offset(0, _direction * 0.22)
                            : Offset(0, -_direction * 0.16))
                        : (isIncoming
                            ? Offset(_direction * 0.26, 0)
                            : Offset(-_direction * 0.18, 0));

                    final offsetAnimation = Tween<Offset>(
                      begin: slideOffset,
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.fastEaseInToSlowEaseOut,
                    ));

                    final fadeAnimation = CurvedAnimation(
                      parent: animation,
                      curve: isIncoming
                          ? const Interval(0.15, 1.0, curve: Curves.easeOut)
                          : const Interval(0.0, 0.45, curve: Curves.easeIn),
                    );

                    return SlideTransition(
                      position: offsetAnimation,
                      child: FadeTransition(
                        opacity: fadeAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: gridKey,
                    child: RepaintBoundary(
                      child: Container(
                        // 赋予实心表面底色，滑动翻页时上层日历天然完美遮挡底层，100% 杜绝透字
                        color: t.surface,
                        child: CalendarGrid(
                          days: days,
                          monthAnchor: isMonth ? view.visibleMonth : null,
                          view: view,
                          settings: settings,
                          badges: badges,
                          holidays: holidays,
                          today: today,
                          weekMode: !isMonth,
                          onSelectDay: (d) => nav.selectDay(d),
                          onLongPressDay: (d) => showBackfillSheet(context, day: d),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ),

          // 底部拖动小白条（紧凑衔接，不再冗余留白）
          _CalendarHandleBar(
            isMonth: isMonth,
            onToggle: () {
              nav.setMode(isMonth ? CalendarMode.week : CalendarMode.month);
            },
            onDragUp: () {
              if (isMonth) nav.setMode(CalendarMode.week);
            },
            onDragDown: () {
              if (!isMonth) nav.setMode(CalendarMode.month);
            },
          ),
        ],
      ),
    );
  }

  String _weekLabel(CalendarViewState view, WeekStart weekStart) {
    final days = weekDaysOf(view.selectedDate, weekStart);
    final first = days.first;
    final last = days.last;
    final wNum = weekNumberOfRow(days);

    final dateRange = first.month == last.month
        ? '${first.month}月${first.day}日–${last.day}日'
        : '${first.month}月${first.day}日–${last.month}月${last.day}日';
    return '第 $wNum 周 · $dateRange';
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final view = ref.read(calendarViewProvider);
    final nav = ref.read(calendarViewProvider.notifier);

    if (view.mode == CalendarMode.month) {
      // 当前是按月展示：只打开纯粹的按月选择，绝无任何 Tab
      final picked = await showYearMonthPickerSheet(
        context,
        current: view.visibleMonth,
      );
      if (picked != null) {
        nav.goToMonth(picked);
      }
    } else {
      // 当前是按周展示：只打开纯粹的按周选择，绝无任何 Tab
      final picked = await showWeekPickerSheet(
        context,
        current: view.selectedDate,
      );
      if (picked != null) {
        nav.goToWeek(picked);
      }
    }
  }
}

/// 日历卡片底部控制栏：
/// - 正中保持物理质感微把手，支持垂直轻拖上下折叠/展开与轻点切换。
class _CalendarHandleBar extends StatefulWidget {
  const _CalendarHandleBar({
    required this.isMonth,
    required this.onToggle,
    required this.onDragUp,
    required this.onDragDown,
  });

  final bool isMonth;
  final VoidCallback onToggle;
  final VoidCallback onDragUp;
  final VoidCallback onDragDown;

  @override
  State<_CalendarHandleBar> createState() => _CalendarHandleBarState();
}

class _CalendarHandleBarState extends State<_CalendarHandleBar> {
  double _dragOffset = 0.0;
  bool _isHoveredOrPressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onToggle,
      onVerticalDragStart: (_) {
        setState(() {
          _isHoveredOrPressed = true;
          _dragOffset = 0.0;
        });
      },
      onVerticalDragUpdate: (d) {
        setState(() {
          // 顺滑弹性物理位移，给予清晰可感知的跟手反馈
          _dragOffset = (_dragOffset + d.delta.dy * 0.38).clamp(-6.0, 6.0);
        });
      },
      onVerticalDragEnd: (d) {
        final vy = d.velocity.pixelsPerSecond.dy;
        if (_dragOffset < -2.5 || vy < -80) {
          HapticFeedback.mediumImpact();
          widget.onDragUp();
        } else if (_dragOffset > 2.5 || vy > 80) {
          HapticFeedback.mediumImpact();
          widget.onDragDown();
        } else {
          // 短触/原地微动直接切换
          if (_dragOffset.abs() < 2.0 && vy.abs() < 100) {
            HapticFeedback.mediumImpact();
            widget.onToggle();
          }
        }
        setState(() {
          _dragOffset = 0.0;
          _isHoveredOrPressed = false;
        });
      },
      onVerticalDragCancel: () {
        setState(() {
          _dragOffset = 0.0;
          _isHoveredOrPressed = false;
        });
      },
      child: Tooltip(
        message: '轻点或上下拖拽：切换周/月模式',
        preferBelow: false,
        verticalOffset: 16,
        waitDuration: const Duration(milliseconds: 250),
        triggerMode: TooltipTriggerMode.longPress,
        child: SizedBox(
          width: double.infinity,
          height: 20,
          child: Center(
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                width: _isHoveredOrPressed ? 40 : 32,
                height: _isHoveredOrPressed ? 3.8 : 3.0,
                decoration: BoxDecoration(
                  color: _isHoveredOrPressed
                      ? t.brandInk.withValues(alpha: 0.7)
                      : t.line.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(PoopRadii.pill),
                  boxShadow: [
                    BoxShadow(
                      color: t.isDark
                          ? Colors.black.withValues(alpha: 0.25)
                          : const Color(0x1F2D1B0D),
                      blurRadius: _isHoveredOrPressed ? 3.0 : 1.5,
                      offset: const Offset(0, 0.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.mode,
    required this.direction,
    required this.isVertical,
    required this.onTitleTap,
    required this.onModeChanged,
  });

  final String title;
  final CalendarMode mode;
  final int direction;
  final bool isVertical;
  final VoidCallback onTitleTap;
  final ValueChanged<CalendarMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isMonth = mode == CalendarMode.month;

    return Row(
      children: [
        // 标题区：固定高度与基线对齐，彻底消除切换日期时的微像素抖动
        Expanded(
          child: Tooltip(
            message: '点击切换年份与月份',
            preferBelow: true,
            verticalOffset: 20,
            waitDuration: const Duration(milliseconds: 200),
            triggerMode: TooltipTriggerMode.longPress,
            child: InkWell(
              onTap: onTitleTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SizedBox(
                        height: 26,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.centerLeft,
                              clipBehavior: Clip.none,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) {
                            final isIncoming = child.key == ValueKey(title);

                            // 时序错开，出场先退、入场后进，彻底杜绝文字交叉重叠双影
                            final fadeAnim = CurvedAnimation(
                              parent: animation,
                              curve: isIncoming
                                  ? const Interval(0.35, 1.0, curve: Curves.easeOutCubic)
                                  : const Interval(0.0, 0.40, curve: Curves.easeInCubic),
                            );

                            // 位移微动效：精细收敛位移幅度，顺滑过渡且杜绝抖动
                            final Offset slideOffset;
                            if (direction == 0) {
                              // 模式切换：原位平滑浮现
                              slideOffset = isIncoming
                                  ? const Offset(0, 0.04)
                                  : const Offset(0, -0.04);
                            } else if (isVertical) {
                              // 垂直切月：轻微 Y 轴视差位移
                              slideOffset = isIncoming
                                  ? Offset(0, direction * 0.12)
                                  : Offset(0, -direction * 0.08);
                            } else {
                              // 水平切月/切周：轻微 X 轴视差位移
                              slideOffset = isIncoming
                                  ? Offset(direction * 0.12, 0)
                                  : Offset(-direction * 0.08, 0);
                            }

                            final offsetAnimation = Tween<Offset>(
                              begin: slideOffset,
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.fastEaseInToSlowEaseOut,
                            ));

                            return SlideTransition(
                              position: offsetAnimation,
                              child: FadeTransition(
                                opacity: fadeAnim,
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            title,
                            key: ValueKey(title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: displayStyle(
                              size: isMonth ? 18.5 : 15.5,
                              letterSpacing: isMonth ? 0.4 : 0.2,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: t.paperDeep,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(LucideIcons.chevronDown, size: 13, color: t.ink2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 月/周 分段控件
        _ModeSwitch(mode: mode, onChanged: onModeChanged),
      ],
    );
  }
}

/// 月 / 周 分段控件。
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final CalendarMode mode;
  final ValueChanged<CalendarMode> onChanged;

  static const double _itemWidth = 35.0;
  static const double _itemHeight = 25.0;
  static const double _padding = 2.5;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isMonth = mode == CalendarMode.month;

    return Container(
      width: _itemWidth * 2 + _padding * 2,
      height: _itemHeight + _padding * 2,
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: t.paperDeep,
        borderRadius: BorderRadius.circular(PoopRadii.pill),
      ),
      child: Stack(
        children: [
          // 丝滑物理平移的指示器胶囊滑块
          AnimatedAlign(
            duration: PoopMotions.switchDuration,
            curve: PoopMotions.switchCurve,
            alignment: isMonth ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: _itemWidth,
              height: _itemHeight,
              decoration: BoxDecoration(
                gradient: t.brandGradient,
                borderRadius: BorderRadius.circular(PoopRadii.pill),
                boxShadow: t.brandShadow,
              ),
            ),
          ),
          // 上层点击与文字层
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeSwitchItem(
                label: '月',
                selected: isMonth,
                width: _itemWidth,
                height: _itemHeight,
                onTap: () => onChanged(CalendarMode.month),
              ),
              _ModeSwitchItem(
                label: '周',
                selected: !isMonth,
                width: _itemWidth,
                height: _itemHeight,
                onTap: () => onChanged(CalendarMode.week),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeSwitchItem extends StatelessWidget {
  const _ModeSwitchItem({
    required this.label,
    required this.selected,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tooltipText = label == '月' ? '切换为月历视图' : '切换为周历视图';

    return Tooltip(
      message: tooltipText,
      preferBelow: true,
      verticalOffset: 20,
      waitDuration: const Duration(milliseconds: 250),
      triggerMode: TooltipTriggerMode.longPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: width,
          height: height,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: selected ? Colors.white : t.ink3,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
