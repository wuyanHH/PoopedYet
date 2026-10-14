import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/queries.dart';
import '../domain/history_filter.dart';
import '../providers.dart';

/// 历史页当前的筛选条件。
///
/// 做成 Notifier 而不是散在页面 state 里，是因为**历史页和筛选页是两个路由**，
/// 筛选页改完要能回到历史页立刻生效。
class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => const HistoryFilter();

  /// 所有变更都从这一个口子走，为的是**只在这里打一次日志**。
  ///
  /// 为什么需要日志：筛选是纯 UI 状态，不写库，所以
  /// "点了一下到底生效没有"没法靠查数据库回答；而 Flutter 画在 canvas 上、
  /// uiautomator 读不到界面文字。这行日志是设备端唯一可靠的观察窗口 ——
  /// 和 CalendarView 的 `[CAL]`、详情弹层的 `[SHEET]` 是同一个理由。
  void _emit(HistoryFilter next) {
    if (kDebugMode && next != state) debugPrint('[HIST] $next');
    state = next;
  }

  void setKeyword(String kw) => _emit(state.copyWith(keyword: kw));

  void setFrom(DateTime? d) => _emit(
        d == null ? state.copyWith(clearFrom: true) : state.copyWith(from: d),
      );

  void setTo(DateTime? d) => _emit(
        d == null ? state.copyWith(clearTo: true) : state.copyWith(to: d),
      );

  void togglePooper(String id) {
    final next = {...state.pooperIds};
    if (!next.remove(id)) next.add(id);
    _emit(state.copyWith(pooperIds: next));
  }

  void setPoopers(Set<String> ids) =>
      _emit(state.copyWith(pooperIds: ids));

  /// 清空全部条件。
  void clear() => _emit(const HistoryFilter());

  /// 应用筛选页上攒好的条件（**归一化**，保证 from <= to）。
  void apply(HistoryFilter f) => _emit(f.normalized());
}

final historyFilterProvider =
    NotifierProvider<HistoryFilterNotifier, HistoryFilter>(
  HistoryFilterNotifier.new,
);

/// 按当前筛选条件检索出的记录。
///
/// `family` 的 key 是 [HistoryFilter] 本身 —— 所以它必须实现 `==`/`hashCode`，
/// 否则每次 build 都会被当成新条件重新查库。见 `history_filter.dart`。
///
/// `autoDispose`：离开历史页就该释放，历史可能很大。
final historyRecordsProvider =
    FutureProvider.autoDispose.family<List<RecordDetail>, HistoryFilter>(
  (ref, filter) async {
    final list = await ref.watch(databaseProvider).searchRecords(filter);
    // 结果条数也打进日志：筛选条件生效了但一条都没匹配上，
    // 和"筛选压根没生效"在界面上看着都是空列表，日志能分开这两种情况。
    if (kDebugMode) debugPrint('[HIST] -> ${list.length} 条');
    return list;
  },
);

/// 当前条件下的总条数（用来显示「共 N 条」）。
///
/// 和 [historyRecordsProvider] 分开查，是因为后者有 limit ——
/// 拿 limit 后的条数当总数会显示成"共 500 条"。
final historyCountProvider =
    FutureProvider.autoDispose.family<int, HistoryFilter>(
  (ref, filter) => ref.watch(databaseProvider).countRecords(filter),
);

/// 把记录按**本地日期**分组，日期倒序、组内时间倒序。
///
/// 分组放在这里而不是 SQL 里，和日历那边同一个理由：
/// 时区只在一处处理。Drift 存的是 Unix 秒，交给 SQLite 转本地时区
/// 会依赖执行查询的设备时区，而 Dart 侧的 `dayKey` 用的是同一套本地日期。
///
/// 注意 [historyRecordsProvider] 已经按时间倒序返回了，
/// 所以这里只要顺序遍历、遇到新的一天就开一个新组，不需要再排序。
List<(String day, List<RecordDetail> items)> groupByDay(
  List<RecordDetail> records,
) {
  final out = <(String, List<RecordDetail>)>[];
  for (final r in records) {
    final key = _dayLabel(r.record.startedAt);
    if (out.isEmpty || out.last.$1 != key) {
      out.add((key, [r]));
    } else {
      out.last.$2.add(r);
    }
  }
  return out;
}

String _dayLabel(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// 分组标题上显示的那一行（「10月12日 周一」）。
String dayLabelCn(DateTime d) {
  const wd = ['一', '二', '三', '四', '五', '六', '日'];
  return '${d.month}月${d.day}日 周${wd[d.weekday - 1]}';
}
