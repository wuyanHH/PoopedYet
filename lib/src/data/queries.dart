import 'package:drift/drift.dart';

import '../calendar/calendar_math.dart';
import '../domain/record_state.dart';
import 'database.dart';

/// 某一天、某个屙屎人的次数。
class PooperCount {
  const PooperCount({required this.pooper, required this.count});

  final Pooper pooper;
  final int count;
}

/// 记录 + 它的人 + 它的备注。日历下方列表要用的完整形状。
class RecordDetail {
  const RecordDetail({
    required this.record,
    required this.pooper,
    required this.notes,
  });

  final PoopRecord record;
  final Pooper pooper;
  final List<PoopNote> notes;

  RecordState stateAt(DateTime now) => recordStateOf(record, now: now);
}

/// 日历与记录列表的查询。
///
/// 这些做成 `extension` 挂在 [AppDatabase] 上，而不是塞进 database.dart ——
/// 那个文件已经很长了，而且这些查询是"读"的职责，和建库/生命周期分开更清楚。
extension CalendarQueries on AppDatabase {
  /// 把 `[from, toExclusive)` 区间内的记录按**本地天 × 屙屎人**计数。
  ///
  /// 为什么要取整个区间一次查完、再在 Dart 里分组，而不是按天循环查：
  /// 一个月的记录撑死几百条，一次查完是**一次**查询 + 纯内存分组；
  /// 按天循环就是 30 次查询，而且每次都要重开游标。
  ///
  /// 也不在 SQL 里用 `date(started_at,'unixepoch','localtime')` 分组 ——
  /// Drift 存的是 Unix 秒，交给 SQLite 转本地时区依赖设备的时区设置，
  /// 而 Dart 侧的 [dayKey] 用的是同一套本地日期。两边各算一次迟早会分叉。
  Future<Map<String, Map<String, int>>> countsInRange(
    DateTime from,
    DateTime toExclusive,
  ) async {
    final q = selectOnly(poopRecords)
      ..addColumns([poopRecords.pooperId, poopRecords.startedAt])
      ..where(
        poopRecords.startedAt.isBiggerOrEqualValue(from) &
            poopRecords.startedAt.isSmallerThanValue(toExclusive),
      );

    final rows = await q.get();
    final out = <String, Map<String, int>>{};
    for (final row in rows) {
      final at = row.read(poopRecords.startedAt);
      final pid = row.read(poopRecords.pooperId);
      if (at == null || pid == null) continue;
      final key = dayKey(at);
      (out[key] ??= <String, int>{}).update(pid, (v) => v + 1, ifAbsent: () => 1);
    }
    return out;
  }

  /// 整个月（含网格里补位的上/下月日期）的计数。
  ///
  /// 范围按**网格**取，不是按自然月 —— 网格首尾会露出上个月末和下个月初，
  /// 那些格子上的徽标也得画出来，否则用户会觉得"那天明明有记录却没显示"。
  Future<Map<String, Map<String, int>>> monthGridCounts(
    DateTime month,
    WeekStart weekStart,
  ) {
    final days = monthGridDays(month.year, month.month, weekStart);
    final from = startOfDay(days.first);
    final to = startOfDay(days.last).add(const Duration(days: 1));
    return countsInRange(from, to);
  }

  /// 一周的计数。
  Future<Map<String, Map<String, int>>> weekCounts(
    DateTime anyDayInWeek,
    WeekStart weekStart,
  ) {
    final days = weekDaysOf(anyDayInWeek, weekStart);
    return countsInRange(
      startOfDay(days.first),
      startOfDay(days.last).add(const Duration(days: 1)),
    );
  }

  /// 某一年里**哪些月份有记录**。年月选择器上的小点靠它。
  ///
  /// 只返回月份数字的集合，不返回计数 —— 选择器上只需要"有 / 没有"，
  /// 传计数会让 UI 有机会去显示"3 月有 47 次"这种它不该关心的事。
  Future<Set<int>> monthsWithRecords(int year) async {
    final q = selectOnly(poopRecords)
      ..addColumns([poopRecords.startedAt])
      ..where(
        poopRecords.startedAt.isBiggerOrEqualValue(DateTime(year, 1, 1)) &
            poopRecords.startedAt.isSmallerThanValue(DateTime(year + 1, 1, 1)),
      );

    final rows = await q.get();
    final out = <int>{};
    for (final row in rows) {
      final at = row.read(poopRecords.startedAt);
      if (at != null) out.add(at.month);
    }
    return out;
  }

  /// 某一天的记录，已按显示顺序排好。
  ///
  /// 排序规则：**「正在屙」的置顶**，其余按 `startedAt` 升序。
  /// 置顶是因为它需要用户立刻操作（点"结束"），沉在下面会被漏掉。
  Future<List<RecordDetail>> recordsOn(DateTime day, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final from = startOfDay(day);
    final to = from.add(const Duration(days: 1));

    final recs = await (select(poopRecords)
          ..where(
            (t) =>
                t.startedAt.isBiggerOrEqualValue(from) &
                t.startedAt.isSmallerThanValue(to),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt)]))
        .get();
    if (recs.isEmpty) return const [];

    // 一次把这些记录的备注全取出来，避免 N+1
    final recIds = recs.map((r) => r.id).toList();
    final notes = await (select(poopNotes)
          ..where((t) => t.recordId.isIn(recIds))
          ..orderBy([(t) => OrderingTerm(expression: t.notedAt)]))
        .get();
    final notesByRec = <String, List<PoopNote>>{};
    for (final n in notes) {
      (notesByRec[n.recordId] ??= <PoopNote>[]).add(n);
    }

    // 记录里涉及的人。**包含已归档的** —— 归档的人历史记录仍在，
    // 只是不出现在"谁在屙"选择器里。
    final pooperIds = recs.map((r) => r.pooperId).toSet();
    final people = await (select(poopers)..where((t) => t.id.isIn(pooperIds)))
        .get();
    final byId = {for (final p in people) p.id: p};

    final details = <RecordDetail>[];
    for (final r in recs) {
      final p = byId[r.pooperId];
      if (p == null) continue; // 理论上不会发生（外键约束在）
      details.add(
        RecordDetail(
          record: r,
          pooper: p,
          notes: notesByRec[r.id] ?? const [],
        ),
      );
    }

    details.sort((a, b) {
      final aActive = recordStateOf(a.record, now: at) == RecordState.active;
      final bActive = recordStateOf(b.record, now: at) == RecordState.active;
      if (aActive != bActive) return aActive ? -1 : 1;
      return a.record.startedAt.compareTo(b.record.startedAt);
    });

    return details;
  }

  /// 当前所有"挂着的"记录（进行中或待确认），用于启动时扫一遍。
  ///
  /// 返回时已顺便把超过 24 小时的收敛成 [PoopRecord.endUnknown] 落库。
  Future<List<RecordDetail>> settleStaleRecords({DateTime? now}) async {
    final at = now ?? DateTime.now();

    final stale = await (select(poopRecords)
          ..where(
            (t) => t.endedAt.isNull() & t.endUnknown.equals(false),
          ))
        .get();

    final toConverge = stale
        .where((r) => shouldAutoConverge(r, now: at))
        .map((r) => r.id)
        .toList();
    if (toConverge.isNotEmpty) {
      await (update(poopRecords)..where((t) => t.id.isIn(toConverge)))
          .write(const PoopRecordsCompanion(endUnknown: Value(true)));
    }

    final ids = stale.map((r) => r.id).toSet();
    if (ids.isEmpty) return const [];

    final recs = await (select(poopRecords)..where((t) => t.id.isIn(ids)))
        .get();
    final people = await select(poopers).get();
    final byId = {for (final p in people) p.id: p};

    return [
      for (final r in recs)
        if (byId[r.pooperId] != null)
          RecordDetail(record: r, pooper: byId[r.pooperId]!, notes: const []),
    ];
  }
}
