import 'package:flutter/material.dart';

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
/// 规格取自视觉稿 `.cell`：高 58、圆角 13、内边距 3/3/2。
/// 里面的东西自上而下是：日期数字（+ 休/班角标）→ 头像徽标（最多 2 行 + `+N`）。
///
/// **它不自己读 provider**，全部数据靠参数传进来 ——
/// 这样它能被 widget test 单独渲染，也能在周视图里复用（只是尺寸不同）。
class DayCell extends StatelessWidget {
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

  /// 是否属于当前显示的月份。false 时整格降级显示。
  final bool inMonth;

  final bool isToday;
  final bool isSelected;

  /// 周六/周日。
  final bool isWeekend;

  /// 这一天每人的次数，**已按屙屎人顺序排好**（见 `_orderBadges`）。
  final List<PooperCount> badges;

  final HolidayKind? holiday;

  final bool showBadges;
  final bool showHolidayTags;
  final bool weekendBrandColor;

  /// 月视图 2 行，周视图可以放 3 行。
  final int maxBadgeRows;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // ---- 底色 ----
    // 选中 > 今天 > 无。选中态必须压过今天态，否则点今天那一格看不出被选中。
    Color? bg;
    if (isSelected) {
      bg = t.brandFill;
    } else if (isToday) {
      bg = const Color(0xFFFFFBF5);
    }

    // ---- 日期数字颜色 ----
    Color numColor = t.ink;
    if (isSelected) {
      numColor = Colors.white;
    } else if (isToday) {
      numColor = t.brandInk;
    } else if (isWeekend && weekendBrandColor) {
      numColor = t.brandInk;
    }

    // ---- 今天：一道焦糖细环 ----
    // 用 foregroundDecoration 而不是 border —— border 会占掉 1.5px 布局空间，
    // 让格子里的内容整体位移；foregroundDecoration 只画在上面，不动布局。
    final BoxDecoration? ring = isToday
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(PoopRadii.cell),
            border: Border.all(color: t.brand, width: 1.5),
          )
        : null;

    // 非本月的格子整体降级。这是**有意的**降级，不是对比度不达标。
    final dim = !inMonth;

    return Semantics(
      // 读屏不能只念一个"11"。整个 App 的语义标签都还没系统设计过，
      // 这里先给日历格一个能用的最小版本。
      label: _semanticLabel(),
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(PoopRadii.cell),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x57A85F29),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          foregroundDecoration: ring,
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
          child: Opacity(
            opacity: dim ? 0.45 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 1),
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: numColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          letterSpacing: -0.3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (showHolidayTags && holiday != null)
                      _HolidayTag(kind: holiday!, onSelected: isSelected, t: t),
                  ],
                ),
                const SizedBox(height: 2),
                if (showBadges && badges.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _badgeRows(t, isSelected),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 最多 [maxBadgeRows] 行，放不下的用 `+N` 收在最后一行末尾。
  ///
  /// 每一行都套了 `FittedBox(scaleDown)`：格子只有 46px 宽，
  /// 次数涨到两位数（`14`）时 头像+数字+`+N` 会超宽。
  /// 让它等比缩一点，好过溢出画到隔壁格子上。
  List<Widget> _badgeRows(PoopTokens t, bool isSelected) {
    final shown = badges.take(maxBadgeRows).toList();
    final extra = badges.length - shown.length;

    return [
      for (var i = 0; i < shown.length; i++)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
          child: SizedBox(
            height: 14,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PooperAvatar.xs(
                    shown[i].pooper,
                    dimmed: shown[i].pooper.archivedAt != null,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${shown[i].count}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : t.ink2,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (i == shown.length - 1 && extra > 0) ...[
                    const SizedBox(width: 2),
                    Text(
                      '+$extra',
                      style: TextStyle(
                        color: isSelected ? Colors.white : t.ink3,
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
    ];
  }

  String _semanticLabel() {
    const wd = ['一', '二', '三', '四', '五', '六', '日'];
    final parts = <String>[
      '${date.month}月${date.day}日',
      '周${wd[date.weekday - 1]}',
    ];
    if (!inMonth) parts.add('非本月');
    if (isToday) parts.add('今天');
    if (holiday == HolidayKind.off) parts.add('休息日');
    if (holiday == HolidayKind.work) parts.add('调休上班');
    if (badges.isEmpty) {
      parts.add('无记录');
    } else {
      parts.add(badges.map((b) => '${b.pooper.name} ${b.count} 次').join('，'));
    }
    return parts.join('，');
  }
}

/// 休 / 班 角标。
///
/// 早期版本是「浅底 + 彩色文字」，8.5px 时对比度只有 3.27:1，而且小到认不出。
/// 改成**实心药丸 + 白字**：白字对 `off` 是 6.01:1、对 `work` 是 4.61:1，
/// 字号还能从 8.5px 提到 10px。
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
    // 选中格里改成白底 + 原色字，否则红药丸压在焦糖底上会糊成一团。
    final bg = onSelected ? Colors.white : (isOff ? t.off : t.work);
    final fg = onSelected ? (isOff ? t.off : t.work) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOff ? '休' : '班',
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
