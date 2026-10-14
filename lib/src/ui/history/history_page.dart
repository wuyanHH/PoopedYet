import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../data/queries.dart';
import '../../data/record_actions.dart';
import '../../domain/history_filter.dart';
import '../../domain/record_state.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../state/history.dart';
import '../../theme/tokens.dart';
import '../records/record_card.dart';
import '../records/record_detail_sheet.dart';
import '../widgets/smooth_page_route.dart';
import '../widgets/undo_snack_bar.dart';
import 'history_filter_page.dart';

/// 历史记录 · 时间线（视觉稿 ⑥）。
///
/// 与日历主页的区别：
///   - 这里**不先定位到某一天再点进去**，而是一路往下滚 ——
///     找"上周三那次"这种模糊记忆时，翻时间线比先在日历上找日期快
///   - 顶部按人筛选（最常用的筛选，要一步可达），右上角进完整筛选页
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(historyFilterProvider);
    final recordsAsync = ref.watch(historyRecordsProvider(filter));
    final totalAsync = ref.watch(historyCountProvider(filter));

    final records = recordsAsync.value ?? const <RecordDetail>[];
    final groups = groupByDay(records);

    return Scaffold(
      backgroundColor: context.tokens.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(filter: filter),
            _PooperFilterStrip(filter: filter),
            if (filter.activeCount > 0) _ActiveSummary(filter: filter),
            Expanded(
              child: recordsAsync.isLoading && records.isEmpty
                  ? const SizedBox.shrink()
                  : records.isEmpty
                      ? _EmptyHistory(hasFilter: filter.activeCount > 0)
                      : _Timeline(
                          groups: groups,
                          // 显示的是**总数**而不是已加载条数 ——
                          // 有 limit 时两者不同，显示成"共 500 条"是错的。
                          total: totalAsync.value ?? records.length,
                          onTap: (id) =>
                              showRecordDetailSheet(context, recordId: id),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.filter});

  final HistoryFilter filter;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 4),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(LucideIcons.chevronLeft, size: 20, color: t.ink2),
            ),
          ),
          Text(
            '历史',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: t.ink,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () => Navigator.of(context).push(
              smoothPageRoute(const HistoryFilterPage()),
            ),
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(LucideIcons.slidersHorizontal, size: 18, color: t.ink2),
                  // 有筛选条件时点一个小圆点 —— 否则用户会忘了自己筛过，
                  // 然后以为"记录少了"。
                  if (filter.activeCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: t.brandFill,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部按人筛选的横条。
class _PooperFilterStrip extends ConsumerWidget {
  const _PooperFilterStrip({required this.filter});

  final HistoryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final all = ref.watch(allPoopersProvider).value ?? const <Pooper>[];
    if (all.isEmpty) return const SizedBox.shrink();

    final notifier = ref.read(historyFilterProvider.notifier);

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            key: const ValueKey('historyChip:all'),
            label: '全部',
            selected: filter.pooperIds.isEmpty,
            onTap: () => notifier.setPoopers({}),
          ),
          for (final p in all) ...[
            const SizedBox(width: 7),
            _Chip(
              // 有 key 才测得准：屙屎人名字在记录卡上也会出现，
              // 单靠 find.text 会同时命中两个。
              key: ValueKey('historyChip:${p.id}'),
              label: p.name,
              selected: filter.pooperIds.contains(p.id),
              dimmed: p.archivedAt != null,
              onTap: () => notifier.togglePooper(p.id),
            ),
          ],
          const SizedBox(width: 16),
          Center(
            child: Text(
              '可多选',
              style: TextStyle(fontSize: 10.5, color: t.ink4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dimmed = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: PoopMotions.pressDuration,
          curve: PoopMotions.pressCurve,
          child: AnimatedContainer(
            duration: PoopMotions.colorDuration,
            curve: PoopMotions.colorCurve,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              gradient: widget.selected ? PoopMotions.brandGradient : null,
              color: widget.selected ? null : t.surface,
              borderRadius: BorderRadius.circular(PoopRadii.pill),
              border: Border.all(
                color: widget.selected ? Colors.transparent : t.lineSoft,
              ),
              boxShadow: widget.selected ? PoopMotions.brandShadow : null,
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: widget.selected
                    ? Colors.white
                    : (widget.dimmed ? t.ink4 : t.ink2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 当前生效的筛选条件摘要 + 一键清空。
class _ActiveSummary extends ConsumerWidget {
  const _ActiveSummary({required this.filter});

  final HistoryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final parts = <String>[];

    final kw = filter.keyword.trim();
    if (kw.isNotEmpty) parts.add('「$kw」');

    final from = filter.from;
    final to = filter.to;
    if (from != null || to != null) {
      String d(DateTime x) => '${x.month}/${x.day}';
      parts.add(
        from != null && to != null
            ? '${d(from)} – ${d(to)}'
            : (from != null ? '${d(from)} 起' : '至 ${d(to!)}'),
      );
    }

    if (filter.pooperIds.length > 1) parts.add('${filter.pooperIds.length} 人');
    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
      child: Row(
        children: [
          Icon(LucideIcons.filter, size: 13, color: t.brandInk),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join(' · '),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.brandInk,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(historyFilterProvider.notifier).clear(),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({
    required this.groups,
    required this.total,
    required this.onTap,
  });

  final List<(String, List<RecordDetail>)> groups;
  final int total;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final db = ref.read(databaseProvider);
    final filter = ref.watch(historyFilterProvider);

    void refresh() {
      ref.invalidate(historyRecordsProvider(filter));
      ref.invalidate(historyCountProvider(filter));
      ref.invalidate(monthBadgesProvider);
      ref.invalidate(weekBadgesProvider);
      ref.invalidate(dayRecordsProvider);
      ref.invalidate(staleRecordsProvider);
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView.builder(
      cacheExtent: 600.0,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(14, 8, 14, 32 + bottomInset),
      itemCount: groups.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
            child: Text(
              '共 $total 条',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: t.ink3,
              ),
            ),
          );
        }

        final (_, items) = groups[i - 1];
        final day = items.first.record.startedAt;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DayHeader(day: day, count: items.length),
            for (final d in items) ...[
              RepaintBoundary(
                key: ValueKey('history_boundary_${d.record.id}'),
                child: RecordCard(
                  key: ValueKey('history_card_${d.record.id}'),
                  detail: d,
                  now: DateTime.now(),
                  onTap: () => onTap(d.record.id),
                  onAddNote: () => onTap(d.record.id),
                  onQuickEnd: d.record.endedAt == null
                      ? () async {
                          final now = DateTime.now();
                          final backupDetail = d;
                          await db.endPoop(d.record.id, at: now);
                          refresh();
                          if (context.mounted) {
                            final mins = minutesBetween(d.record.startedAt, now);
                            final durStr = formatDuration(Duration(minutes: mins));
                            showUndoSnackBar(
                              context,
                              title: '${d.pooper.name} 已结束打卡（结束时间 ${hhmm(now)}）',
                              subtitle: '本次打卡历时约 $durStr · 如需恢复可点击撤销',
                              onUndo: () async {
                                await db.restoreRecord(backupDetail);
                                refresh();
                              },
                            );
                          }
                        }
                      : null,
                  onDelete: () async {
                    final backupDetail = d;
                    await db.deleteRecord(d.record.id);
                    refresh();
                    if (context.mounted) {
                      showUndoSnackBar(
                        context,
                        title: '已删除 ${d.pooper.name} 的打卡记录',
                        subtitle: d.notes.isNotEmpty
                            ? '含 ${d.notes.length} 条备注 · 点击右侧可撤销'
                            : '若为误触，可立即恢复此记录',
                        onUndo: () async {
                          await db.restoreRecord(backupDetail);
                          refresh();
                        },
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 7),
          ],
        );
      },
    );
  }
}

/// 时间线里的日期分隔条。
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 9),
      child: Row(
        children: [
          Text(
            dayLabelCn(day),
            style: displayStyle(size: 15, letterSpacing: 0.4, color: t.ink),
          ),
          const SizedBox(width: 8),
          Text(
            '$count 次',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: t.brandInk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: t.line)),
        ],
      ),
    );
  }
}

class _EmptyHistory extends ConsumerWidget {
  const _EmptyHistory({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                color: t.brandSoft,
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: Icon(
                hasFilter ? LucideIcons.search : LucideIcons.notebookPen,
                size: 32,
                color: t.brandInk,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasFilter ? '没有符合条件的记录' : '还没有任何记录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 6),
            if (hasFilter)
              TextButton(
                onPressed: () =>
                    ref.read(historyFilterProvider.notifier).clear(),
                child: const Text('清空筛选条件'),
              )
            else
              Text(
                '去日历页点「现在开屙」，\n或者长按日历上的某一天补录一条。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
              ),
          ],
        ),
      ),
    );
  }
}
