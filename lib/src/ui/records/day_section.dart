import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../calendar/calendar_math.dart';
import '../../state/calendar_data.dart';
import '../../state/calendar_view.dart';
import '../../theme/tokens.dart';
import 'record_card.dart';

/// 日期栏 + 选中日期的记录列表。
///
/// 「回到今天」放在**日期栏**而不是日历头部：日历头部横向只剩约 2px 余量
/// （标题 + ▾ + 两个箭头 + 月/周控件已经占满），放不下；
/// 而这一行本来就在回答"现在看的是哪一天"，语义上也更合适。
///
/// 只在**不在今天**时出现。
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

    final recordsAsync = ref.watch(dayRecordsProvider(day));
    final records = recordsAsync.value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                '${day.month}月${day.day}日',
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: t.ink,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '周${_weekdayCn(day)}${isToday ? ' · 今天' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.ink2,
                ),
              ),
              const Spacer(),
              if (!isToday)
                _TodayButton(
                  onTap: () => ref.read(calendarViewProvider.notifier).goToday(),
                ),
              if (!isToday) const SizedBox(width: 8),
              _CountPill(count: records.length),
            ],
          ),
        ),
        Expanded(
          child: recordsAsync.isLoading && records.isEmpty
              ? const SizedBox.shrink()
              : records.isEmpty
                  ? _EmptyDay(isToday: isToday)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (_, i) => RecordCard(
                        detail: records[i],
                        now: DateTime.now(),
                        onTap: () => onTapRecord(records[i].record.id),
                      ),
                    ),
        ),
      ],
    );
  }


  static String _weekdayCn(DateTime d) =>
      const ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1];
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: t.brandSoft,
          borderRadius: BorderRadius.circular(PoopRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendarCheck, size: 12, color: t.brandInk),
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
  const _EmptyDay({required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: t.paperDeep,
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.notebookPen, size: 32, color: t.ink3),
            ),
            const SizedBox(height: 12),
            Text(
              isToday ? '今天还没有人屙过' : '这天还没有人屙过',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '要么是真的没屙，\n要么是忘了记 —— 补一条吧',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
