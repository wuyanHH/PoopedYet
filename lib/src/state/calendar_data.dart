import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/holiday_loader.dart';
import '../data/queries.dart';
import '../providers.dart';
import 'settings.dart';

/// 在册的屙屎人（未归档），已按 sortOrder 排好。
final activePoopersProvider = FutureProvider<List<Pooper>>((ref) {
  return ref.watch(databaseProvider).activePoopers();
});

/// **全部**屙屎人（含已归档）。
///
/// 日历徽标要按这个顺序排：已归档的人历史仍在，如果把他们从排序里去掉，
/// 剩下的人在他出现/消失的日子里位置会跳。
final allPoopersProvider = FutureProvider<List<Pooper>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.poopers)
        ..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.createdAt),
        ]))
      .get();
});

/// 日历格上的徽标数据：`日期键 -> [该天每人次数，已按人排序]`。
///
/// 用 `family` 按月份缓存 —— 翻回上个月时不用重新查库。
/// 这里刻意**不用 autoDispose**：日历会来回翻，缓存住更顺手，
/// 而且一个月的聚合结果很小（几 KB）。
final monthBadgesProvider =
    FutureProvider.family<Map<String, List<PooperCount>>, DateTime>(
  (ref, month) async {
    final db = ref.watch(databaseProvider);
    final settings = ref.watch(settingsProvider);
    final poopers = await ref.watch(allPoopersProvider.future);

    final raw = await db.monthGridCounts(month, settings.weekStart);
    return _orderBadges(raw, poopers, settings.hideArchivedPoopers);
  },
);

/// 周视图的徽标数据。
final weekBadgesProvider =
    FutureProvider.family<Map<String, List<PooperCount>>, DateTime>(
  (ref, anyDayInWeek) async {
    final db = ref.watch(databaseProvider);
    final settings = ref.watch(settingsProvider);
    final poopers = await ref.watch(allPoopersProvider.future);

    final raw = await db.weekCounts(anyDayInWeek, settings.weekStart);
    return _orderBadges(raw, poopers, settings.hideArchivedPoopers);
  },
);

/// 把"每人次数"按**屙屎人顺序**排好。
///
/// 为什么不按次数排序：那样徽标的位置会随数据跳。
/// 昨天阿狗多、今天咪咪多，徽标就换位置，看日历的人会以为点错了。
/// 按人排则相对顺序恒定，最多是"今天没有谁"。
Map<String, List<PooperCount>> _orderBadges(
  Map<String, Map<String, int>> raw,
  List<Pooper> poopersInOrder,
  bool hideArchived,
) {
  final order = <String, int>{
    for (var i = 0; i < poopersInOrder.length; i++) poopersInOrder[i].id: i,
  };

  final out = <String, List<PooperCount>>{};
  for (final entry in raw.entries) {
    final list = <PooperCount>[];
    for (final p in poopersInOrder) {
      if (hideArchived && p.archivedAt != null) continue;
      final n = entry.value[p.id];
      if (n == null || n == 0) continue;
      list.add(PooperCount(pooper: p, count: n));
    }
    list.sort((a, b) =>
        (order[a.pooper.id] ?? 0).compareTo(order[b.pooper.id] ?? 0));
    out[entry.key] = list;
  }
  return out;
}

/// 某一天的记录（含人、含备注），已排好序。
///
/// `autoDispose`：日期会不停切换，旧日期的列表没必要留着。
final dayRecordsProvider =
    FutureProvider.autoDispose.family<List<RecordDetail>, DateTime>(
  (ref, day) {
    return ref.watch(databaseProvider).recordsOn(day);
  },
);

/// 启动时扫一遍挂起的记录，把超 24 小时的收敛成「未记结束」。
///
/// 结果同时喂给主页面 —— 有待确认的记录时要弹"还在屙吗"。
final staleRecordsProvider = FutureProvider<List<RecordDetail>>((ref) {
  return ref.watch(databaseProvider).settleStaleRecords();
});

/// 某一年里哪些月份有记录。年月选择器上的小点靠它。
final monthsWithRecordsProvider = FutureProvider.family<Set<int>, int>(
  (ref, year) => ref.watch(databaseProvider).monthsWithRecords(year),
);

/// 确保打包的节假日数据已灌进 `holidays` 表。
///
/// 单独抽一层是为了**只跑一次**：下面 [holidaysProvider] 会 await 它，
/// 但它自己是个 FutureProvider，所以整个 App 生命周期只执行一遍。
final _holidaySeedProvider = FutureProvider<void>((ref) async {
  await loadHolidaysFromAssets(ref.watch(databaseProvider));
});

/// 节假日查找表：`yyyy-MM-dd -> Holiday`。
///
/// **一次性把整表读进来**（9 年约 330 行）而不是按月查 ——
/// 数据量太小了，按月查反而要处理"跨月的那一周"这种边界。
final holidaysProvider = FutureProvider<Map<String, Holiday>>((ref) async {
  await ref.watch(_holidaySeedProvider.future);
  final rows = await ref.watch(databaseProvider).select(ref.watch(databaseProvider).holidays).get();
  return {for (final h in rows) h.date: h};
});

/// 节假日数据统计（年份范围与记录条数，设置页展示用）。
final holidayStatsProvider =
    FutureProvider<({List<int> years, int totalCount})>((ref) async {
  await ref.watch(_holidaySeedProvider.future);
  final db = ref.watch(databaseProvider);
  return getHolidayDatabaseStats(db);
});

/// 启动时要做的事。
///
/// **`ensureDefaultPooper()` 的调用点在这里** —— 不能在 UI 里"用到的时候再说"。
/// 不先建档的话，全新安装打开 App 会看到一个没有任何屙屎人的日历，
/// 而且 FAB 是点了才顺手把人建出来（顺序是错的）。
///
/// 首启和「归档掉最后一个人」共用这一段守卫，见 docs/design-system.md §9a / §9d。
final bootstrapProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  await db.ensureDefaultPooper();
  // 顺手把超过 24 小时还挂着的收敛成「未记结束」。
  // 不做的话，用户第二天打开会看到一条"正在屙"挂了 20 小时。
  await db.settleStaleRecords();
});

/// 单条记录的完整详情。记录详情弹层用。
///
/// `autoDispose`：弹层关掉就该释放。
/// 每次编辑之后调用方要 `ref.invalidate(recordDetailProvider(id))` 让它重读 ——
/// 比在内存里维护一份可变副本安全得多（那份副本迟早和库里不一致）。
final recordDetailProvider =
    FutureProvider.autoDispose.family<RecordDetail?, String>(
  (ref, id) => ref.watch(databaseProvider).recordById(id),
);

/// 默认备注模板（「拉肚子」「很顺畅」…），按用户排的顺序。
///
/// 备注输入框上那一排快捷 chip 靠它。用户手打的新备注也会沉淀成模板
/// （见 `RecordActions.bumpNoteTemplate`），所以这个列表会自己长大。
final noteTemplatesProvider = FutureProvider<List<NoteTemplate>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.noteTemplates)
        ..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.createdAt),
        ]))
      .get();
});
