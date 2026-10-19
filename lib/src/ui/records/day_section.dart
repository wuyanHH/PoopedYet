import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../calendar/calendar_math.dart';
import '../../calendar/lunar_calendar.dart';
import '../../data/database.dart';
import '../../data/record_actions.dart';
import '../../domain/record_state.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../state/calendar_view.dart';
import '../../theme/tokens.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/undo_snack_bar.dart';
import 'backfill_sheet.dart';
import 'create_record_sheet.dart';
import 'record_card.dart';

/// 日期栏 + 选中日期的记录列表。
///
/// 视觉与交互升级：
///   - 支持右滑卡片快速结束打卡（记录当前时间）
///   - 支持左滑卡片快速删除
///   - 空状态优化，动效更顺滑
class DaySection extends ConsumerWidget {
  const DaySection({super.key, required this.onTapRecord});

  final void Function(String recordId) onTapRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final view = ref.watch(calendarViewProvider);
    final today = ref.watch(todayProvider);
    final day = view.selectedDate;
    final isToday = isSameDay(day, today);

    // 每次 build 只取一次当前时间，避免每张卡片各调一次 DateTime.now()
    // 造成同一屏内状态基准不一致。
    final now = DateTime.now();

    final recordsAsync = ref.watch(dayRecordsProvider(day));
    final records = recordsAsync.value ?? const [];
    final db = ref.read(databaseProvider);

    // 农历计算与法定节假日读取
    final lunar = solarToLunar(day);
    final holidays =
        ref.watch(holidaysProvider).value ?? const <String, Holiday>{};
    final holiday = holidays[dayKey(day)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左侧信息区：公历日期 + 星期 + 今天标记 + 农历 + 节假日休/班
              // 采用 FittedBox(scaleDown) 严格锁定为单行自适应缩放，彻底杜绝向下换行折行！
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. 公历大字
                      Text(
                        '${day.month}月${day.day}日',
                        style: displayStyle(
                          size: 17.5,
                          letterSpacing: 0.4,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // 2. 星期
                      Text(
                        '周${_weekdayCn(day)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: t.ink2,
                        ),
                      ),

                      // 3. 今天徽章
                      if (isToday) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: t.brandSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '今天',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: t.brandInk,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(width: 6),
                      // 细圆点分隔符
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: t.ink4,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // 4. 农历月日 / 传统节日
                      Text(
                        lunar.displayName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: t.ink3,
                        ),
                      ),

                      // 5. 法定节假日标签与休/班胶囊
                      if (holiday != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: holiday.isOffDay
                                ? const Color(0xFFE53935).withValues(alpha: 0.1)
                                : const Color(0xFF1E88E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: holiday.isOffDay
                                  ? const Color(0xFFE53935).withValues(alpha: 0.3)
                                  : const Color(0xFF1E88E5).withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 0.5,
                                ),
                                decoration: BoxDecoration(
                                  color: holiday.isOffDay
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFF1E88E5),
                                  borderRadius: BorderRadius.circular(2.5),
                                ),
                                child: Text(
                                  holiday.isOffDay ? '休' : '班',
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              if (holiday.name != null &&
                                  holiday.name!.isNotEmpty) ...[
                                const SizedBox(width: 3),
                                Text(
                                  holiday.name!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: holiday.isOffDay
                                        ? const Color(0xFFC62828)
                                        : const Color(0xFF1565C0),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 右侧：打卡次数统计胶囊（列表上方的回到今天按钮已收敛至主页全局悬浮按钮）
              _CountPill(count: records.length),
            ],
          ),
        ),
        Expanded(
          // 这里以前用 AnimatedSwitcher 给整个列表做 180ms 淡入淡出。
          // 切日期时新旧两套 ListView 会同时在场——当天记录一多，等于在
          // 同一帧里渲染两倍数量的 RecordCard，切日和滚动都会掉帧。
          // 日历切日本来就是即时动作，直接换列表更干脆。
          child: recordsAsync.isLoading && records.isEmpty
              ? const SizedBox.shrink()
              : records.isEmpty
                  ? _EmptyDay(
                      key: const ValueKey('empty_day'),
                      isToday: isToday,
                    )
                  : ListView.separated(
                      key: ValueKey(
                        'list_${day.year}_${day.month}_${day.day}',
                      ),
                      // 600 会让离屏两屏的卡片都保持挂载。RecordCard 的构建
                      // 成本不低，收到 400 可以少挂一两张，滚动更稳。
                      cacheExtent: 400.0,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          96 + MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: records.length,
                        // 每张卡片外面已经手动包了 RepaintBoundary（带稳定的
                        // key），再让 ListView 自动包一层就是两个图层叠一起，
                        // 滚动时合成成本直接翻倍。
                        addRepaintBoundaries: false,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final item = records[i];
                          final r = item.record;
                          return RepaintBoundary(
                            key: ValueKey('card_boundary_${r.id}'),
                            child: RecordCard(
                              key: ValueKey('record_card_${r.id}'),
                              detail: item,
                              now: now,
                              onTap: () => onTapRecord(r.id),
                              onAddNote: () => onTapRecord(r.id),
                            onQuickEnd: r.endedAt == null
                                ? () async {
                                    HapticFeedback.mediumImpact();
                                    final endedAt = DateTime.now();
                                    final backupItem = item;
                                    await db.endPoop(r.id, at: endedAt);
                                    _refresh(ref);
                                    if (context.mounted) {
                                      final mins = minutesBetween(r.startedAt, endedAt);
                                      final durStr = formatDuration(Duration(minutes: mins));
                                      showUndoSnackBar(
                                        context,
                                        title: '${item.pooper.name} 已结束打卡（结束时间 ${hhmm(endedAt)}）',
                                        subtitle: '本次打卡历时约 $durStr · 如需恢复可点击撤销',
                                        onUndo: () async {
                                          HapticFeedback.lightImpact();
                                          await db.restoreRecord(backupItem);
                                          _refresh(ref);
                                        },
                                      );
                                    }
                                  }
                                : null,
                            onDelete: () async {
                              HapticFeedback.heavyImpact();
                              final backupItem = item;
                              await db.deleteRecord(r.id);
                              _refresh(ref);
                              if (context.mounted) {
                                showUndoSnackBar(
                                  context,
                                  title: '已删除 ${item.pooper.name} 的打卡记录',
                                  subtitle: item.notes.isNotEmpty
                                      ? '含 ${item.notes.length} 条备注 · 点击右侧可撤销'
                                      : '若为误触，可立即恢复此记录',
                                  onUndo: () async {
                                    HapticFeedback.lightImpact();
                                    await db.restoreRecord(backupItem);
                                    _refresh(ref);
                                  },
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(monthBadgesProvider);
    ref.invalidate(weekBadgesProvider);
    ref.invalidate(dayRecordsProvider);
    ref.invalidate(staleRecordsProvider);
    ref.invalidate(activePoopersProvider);
  }

  static String _weekdayCn(DateTime d) =>
      const ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1];
}

class _TodayButton extends StatefulWidget {
  const _TodayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_TodayButton> createState() => _TodayButtonState();
}

class _TodayButtonState extends State<_TodayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: t.brandSoft,
            borderRadius: BorderRadius.circular(PoopRadii.pill),
            border: Border.all(
              color: t.brandInk.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: t.brandInk.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.calendarCheck, size: 12.5, color: t.brandInk),
              const SizedBox(width: 4),
              Text(
                '回到今天',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: t.brandInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: t.brandSoft,
        borderRadius: BorderRadius.circular(PoopRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.chartColumn, size: 12, color: t.brandInk),
          const SizedBox(width: 4),
          Text(
            '共 $count 次',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: t.brandInk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({super.key, required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottomPadding = 72.0 + MediaQuery.paddingOf(context).bottom;

    return Align(
      // 适度居中偏上排列，并留出底部安全避让间距，彻底防止被右下角「现在开屙」主按钮遮挡
      alignment: const Alignment(0, -0.28),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isToday) {
            showCreateRecordSheet(context);
          } else {
            showBackfillSheet(context);
          }
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 12, 28, bottomPadding * 0.4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 空白状态核心品牌插画（单一来源，全工程自动同步）
              const BrandEmptyStateIllustration(size: 84),
              const SizedBox(height: 12),
              Text(
                isToday ? '今天还没有便便打卡' : '这一天没有记录',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isToday
                    ? '随时点击右下角开启一次新记录'
                    : '长按上方日历格或轻触此处可快速补录',
                style: TextStyle(
                  fontSize: 12,
                  color: t.ink3,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
