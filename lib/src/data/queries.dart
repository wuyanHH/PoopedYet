import 'package:drift/drift.dart';

import '../calendar/calendar_math.dart';
import '../domain/history_filter.dart';
import '../domain/record_state.dart';
import '../state/settings.dart';
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
  /// 排序规则：**「正在屙」的始终置顶**，其余记录根据 [sortOrder] 排列（默认时间倒序，最新在最前）。
  Future<List<RecordDetail>> recordsOn(
    DateTime day, {
    DateTime? now,
    RecordSortOrder sortOrder = RecordSortOrder.desc,
  }) async {
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

    final details = await hydrate(recs);

    details.sort((a, b) {
      final aActive = recordStateOf(a.record, now: at) == RecordState.active;
      final bActive = recordStateOf(b.record, now: at) == RecordState.active;
      if (aActive != bActive) return aActive ? -1 : 1;
      return sortOrder == RecordSortOrder.desc
          ? b.record.startedAt.compareTo(a.record.startedAt)
          : a.record.startedAt.compareTo(b.record.startedAt);
    });

    return details;
  }

  /// 把一批记录装配成 [RecordDetail]（补上人、备注），**保持传入的顺序**。
  ///
  /// 抽出来是因为三处都要同一套装配：当日列表、记录详情、历史检索。
  /// 各写一份的话，迟早有一处忘了处理"人已被归档"或者忘了避免 N+1。
  ///
  /// 备注按 `notedAt` 升序 —— 需求里备注是带实时时间的实体，
  /// 展示时必须按写下的先后，不能按插入顺序（补记会打乱）。
  Future<List<RecordDetail>> hydrate(List<PoopRecord> recs) async {
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

    final out = <RecordDetail>[];
    for (final r in recs) {
      final p = byId[r.pooperId];
      if (p == null) continue; // 理论上不会发生（外键约束在）
      out.add(
        RecordDetail(record: r, pooper: p, notes: notesByRec[r.id] ?? const []),
      );
    }
    return out;
  }

  /// 历史检索（视觉稿 ⑥⑦）。
  ///
  /// 筛选在 SQL 里做，装配交给 [hydrate] —— 前者要快（走索引），
  /// 后者要和别处一致。
  ///
  /// [limit] 是**必须的**：历史可能累积到上万条，
  /// 一次全读进内存会卡住 UI。默认 500 条，够翻很久了。
  Future<List<RecordDetail>> searchRecords(
    HistoryFilter filter, {
    int limit = 500,
  }) async {
    final ids = await _matchingRecordIds(filter, limit: limit);
    if (ids.isEmpty) return const [];

    // 按 startedAt 倒序（历史页最新的在最上面），
    // 同一天内也倒序 —— 和"记录列表按时间正序"是刻意不同的：
    // 时间线看的是"最近发生了什么"。
    final recs = await (select(poopRecords)
          ..where((t) => t.id.isIn(ids))
          ..orderBy([
            (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
          ]))
        .get();

    return hydrate(recs);
  }

  /// 当前筛选条件下的**总条数**（用来显示「共 N 条」）。
  ///
  /// 和 [searchRecords] 分开，是因为后者有 limit ——
  /// 拿 limit 后的条数当总数会显示成"共 500 条"，是错的。
  Future<int> countRecords(HistoryFilter filter) async {
    final ids = await _matchingRecordIds(filter, limit: null);
    return ids.length;
  }

  /// 命中的记录 id。筛选条件全在这里。
  Future<List<String>> _matchingRecordIds(
    HistoryFilter filter, {
    required int? limit,
  }) async {
    final where = <String>[];
    final vars = <Variable<Object>>[];

    // ---- 时间范围 ----
    // 用左闭右开，`to` 当天算整天 ——
    // 用户选"到 10 月 12 日"时显然包含那天 23:00 的记录。
    if (filter.from != null) {
      where.add('r.started_at >= ?');
      vars.add(Variable.withInt(filter.from!.millisecondsSinceEpoch ~/ 1000));
    }
    if (filter.to != null) {
      final end = startOfDay(filter.to!).add(const Duration(days: 1));
      where.add('r.started_at < ?');
      vars.add(Variable.withInt(end.millisecondsSinceEpoch ~/ 1000));
    }

    // ---- 屙屎人 ----
    if (filter.pooperIds.isNotEmpty) {
      final ph = List.filled(filter.pooperIds.length, '?').join(',');
      where.add('r.pooper_id IN ($ph)');
      vars.addAll(filter.pooperIds.map(Variable.withString));
    }

    // ---- 关键词 ----
    // 搜备注内容**和**屙屎人名字：用户想找"上周三那次吃火锅的记录"，
    // 也可能想找"阿狗的所有记录"，两种都该命中。
    final kw = filter.keyword.trim();
    if (kw.isNotEmpty) {
      final pattern = _likePattern(kw);
      where.add(
        '(EXISTS (SELECT 1 FROM poop_notes n '
        '        WHERE n.record_id = r.id AND n.content LIKE ? ESCAPE ?) '
        ' OR p.name LIKE ? ESCAPE ?)',
      );
      // ESCAPE 的那个反斜杠不是常量构造，所以单独建一个变量。
      const escapeChar = r'\';
      vars.addAll([
        Variable.withString(pattern),
        Variable.withString(escapeChar),
        Variable.withString(pattern),
        Variable.withString(escapeChar),
      ]);
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final limitSql = limit == null ? '' : 'LIMIT $limit';

    final rows = await customSelect(
      'SELECT r.id FROM poop_records r '
      'JOIN poopers p ON p.id = r.pooper_id '
      '$whereSql '
      'ORDER BY r.started_at DESC '
      '$limitSql',
      variables: vars,
    ).get();

    return [for (final r in rows) r.read<String>('id')];
  }

  /// 把用户输入转成 LIKE 模式，**转义通配符**。
  ///
  /// 不转义的话，搜「50%」会变成"以 50 开头"、搜「_」会匹配任意单字符 ——
  /// 用户看到的结果会莫名其妙。
  static String _likePattern(String raw) {
    final escaped = raw
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  /// 按 id 取一条完整记录（含人与备注）。记录详情弹层用。
  ///
  /// 记录可能已经被删了，所以返回可空 —— 弹层开着的时候别的地方删掉它
  /// 是完全可能的（比如撤销）。
  Future<RecordDetail?> recordById(String id) async {
    final r = await (select(poopRecords)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (r == null) return null;

    final p = await (select(poopers)..where((t) => t.id.equals(r.pooperId)))
        .getSingleOrNull();
    if (p == null) return null;

    final notes = await (select(poopNotes)
          ..where((t) => t.recordId.equals(id))
          ..orderBy([(t) => OrderingTerm(expression: t.notedAt)]))
        .get();

    return RecordDetail(record: r, pooper: p, notes: notes);
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
