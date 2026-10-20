import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/queries.dart';
import '../../theme/tokens.dart';
import '../widgets/pooper_avatar.dart';

/// 某一天在日期格右上角的功能角标。
enum HolidayKind {
  /// 法定假日（休）。红色实心药丸。
  off,

  /// 调休上班（班）。蓝色实心药丸 —— 注意这批恰恰是周末补班。
  work,
}

/// 日历里的一格。
///
/// 视觉全面升级：
///   - 选中态：双层暖棕渐变 + 柔和焦糖弥散阴影 + 立体高光字
///   - 今天态：暖奶油质感微底 + 焦糖高亮环 + 小指示点
///   - 徽标药丸：精致微阴影和饱满头像排版
///   - 按压弹性反馈，提升交互流畅感
class DayCell extends StatefulWidget {
  const DayCell({
    super.key,
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.isWeekend,
    required this.badges,
    this.holiday,
    this.showBadges = true,
    this.showHolidayTags = true,
    this.weekendBrandColor = true,
    this.maxBadgeRows = 2,
    this.onTap,
    this.onLongPress,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final bool isWeekend;
  final List<PooperCount> badges;
  final HolidayKind? holiday;
  final bool showBadges;
  final bool showHolidayTags;
  final bool weekendBrandColor;
  final int maxBadgeRows;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<DayCell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isSelected = widget.isSelected;
    final isToday = widget.isToday;
    final isWeekend = widget.isWeekend;
    final inMonth = widget.inMonth;

    final isOffDay = widget.holiday == HolidayKind.off;
    final isWorkDay = widget.holiday == HolidayKind.work;

    // ---- 渐变 / 背景色（区分法定假日 / 调休补班 / 普通双休 / 工作日） ----
    final Gradient? gradient = isSelected
        ? LinearGradient(
            colors: [t.brand, t.brandFill],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    final Color? bg = isSelected
        ? null
        : (isToday
            ? (isOffDay
                ? t.offSoft.withValues(alpha: 0.5)
                : (isWorkDay
                    ? t.workSoft.withValues(alpha: 0.5)
                    : (t.isDark
                        ? t.brandSoft.withValues(alpha: 0.35)
                        : const Color(0xFFFFF9F2))))
            : (isOffDay
                ? t.offSoft.withValues(alpha: 0.42)
                : (isWorkDay
                    ? t.workSoft.withValues(alpha: 0.42)
                    : (isWeekend
                        ? (t.isDark ? t.surface2 : const Color(0xFFFAF6F0))
                        : null))));

    // ---- 日期数字颜色 ----
    Color numColor = t.ink;
    if (isSelected) {
      numColor = Colors.white;
    } else if (isToday) {
      numColor = isOffDay ? t.off : (isWorkDay ? t.work : t.brandInk);
    } else if (isOffDay) {
      numColor = t.off;
    } else if (isWorkDay) {
      numColor = t.work;
    } else if (isWeekend && widget.weekendBrandColor) {
      numColor = t.brandInk;
    }

    // 今天态微边框
    final Border? border = !isSelected && isToday
        ? Border.all(
            color: isOffDay
                ? t.off.withValues(alpha: 0.7)
                : (isWorkDay
                    ? t.work.withValues(alpha: 0.7)
                    : t.brandInk.withValues(alpha: 0.65)),
            width: 1.5,
          )
        : null;

    final dim = !inMonth;

    return Semantics(
      label: _semanticLabel(),
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          // 这里以前是 AnimatedContainer（180ms 颜色渐变）。一个月的网格
          // 有 42 格，每格一个隐式动画控制器：翻月时新旧两套网格同时在场，
          // 84 个控制器一起 tick、一起重建装饰，正是切月掉帧的主要来源。
          //
          // 选中/今天本来就是「点下去立刻高亮」更干脆，不需要渐变；
          // 换成普通 Container 后，翻月只做一次布局与绘制。
          //
          // 同时去掉 clipBehavior：格子的内容有 4px 内边距，不会碰到 9px
          // 圆角，裁剪只是每帧多一次离屏绘制。
          child: Container(
            alignment: Alignment.topLeft,
            decoration: BoxDecoration(
              gradient: gradient,
              color: bg,
              borderRadius: BorderRadius.circular(9),
              border: border,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: t.brandFill.withValues(alpha: 0.28),
                        blurRadius: 8,
                        spreadRadius: -1,
                        offset: const Offset(0, 2.5),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(4, 3, 4, 2),
            child: Opacity(
              opacity: dim ? 0.38 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 1, top: 1),
                        child: Text(
                          '${widget.date.day}',
                          style: TextStyle(
                            color: numColor,
                            fontSize: 14.5,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w800
                                : FontWeight.w700,
                            height: 1,
                            letterSpacing: -0.3,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (widget.showHolidayTags && widget.holiday != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 1, top: 1),
                          child: _HolidayTag(
                            kind: widget.holiday!,
                            onSelected: isSelected,
                            t: t,
                          ),
                        ),
                    ],
                  ),
                  if (widget.showBadges && widget.badges.isNotEmpty) ...[
                    // ⚠ 必须与 `layout.dart` 的 `_dateToBadgeGap` 保持一致：
                    //   它是格子高度预算的一部分，两边差 1px 就会在 1.3× 字号下
                    //   把内容挤出格子（底部一条黄黑警戒条）。
                    const SizedBox(height: 1),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _badgeRows(t, isSelected),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _badgeRows(PoopTokens t, bool isSelected) {
    final shown = widget.badges.take(widget.maxBadgeRows).toList();
    final extra = widget.badges.length - shown.length;

    return [
      for (var i = 0; i < shown.length; i++)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
          child: SizedBox(
            height: 15,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 3.5 : 2.5,
                  vertical: 1.2,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.22)
                      : (t.isDark
                          ? t.surface.withValues(alpha: 0.8)
                          : t.paperDeep.withValues(alpha: 0.75)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.28)
                        : t.lineSoft.withValues(alpha: 0.7),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PooperAvatar.xs(
                      shown[i].pooper,
                      dimmed: shown[i].pooper.archivedAt != null,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${shown[i].count}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : t.ink,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (i == shown.length - 1 && extra > 0) ...[
                      const SizedBox(width: 2.5),
                      Text(
                        '+$extra',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.9)
                              : t.brandInk,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }

  String _semanticLabel() {
    const wd = ['一', '二', '三', '四', '五', '六', '日'];
    final parts = <String>[
      '${widget.date.month}月${widget.date.day}日',
      '周${wd[widget.date.weekday - 1]}',
    ];
    if (!widget.inMonth) parts.add('非本月');
    if (widget.isToday) parts.add('今天');
    if (widget.holiday == HolidayKind.off) parts.add('休息日');
    if (widget.holiday == HolidayKind.work) parts.add('调休上班');
    if (widget.badges.isEmpty) {
      parts.add('无记录');
    } else {
      parts.add(
        widget.badges.map((b) => '${b.pooper.name} ${b.count} 次').join('，'),
      );
    }
    return parts.join('，');
  }
}

class _HolidayTag extends StatelessWidget {
  const _HolidayTag({
    required this.kind,
    required this.onSelected,
    required this.t,
  });

  final HolidayKind kind;
  final bool onSelected;
  final PoopTokens t;

  @override
  Widget build(BuildContext context) {
    final isOff = kind == HolidayKind.off;

    // 选中态：在焦糖渐变上使用半透明白底与高对比度文字
    // 普通态：使用精巧的柔和轻彩底与清晰主题色文字，去除粗硬边框，杜绝尺寸溢出
    final bg = onSelected
        ? Colors.white.withValues(alpha: 0.22)
        : (isOff
            ? t.offSoft.withValues(alpha: 0.75)
            : t.workSoft.withValues(alpha: 0.75));

    final fg = onSelected
        ? Colors.white
        : (isOff ? t.off : t.work);

    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3.5),
      ),
      child: Text(
        isOff ? '休' : '班',
        style: TextStyle(
          color: fg,
          fontSize: 9.0,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
