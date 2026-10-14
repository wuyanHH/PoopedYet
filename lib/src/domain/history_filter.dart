import '../calendar/calendar_math.dart';

/// 历史检索的筛选条件（视觉稿 ⑦）。
///
/// 做成不可变值对象，是为了让它能直接被 Riverpod 的 `family` 当 key ——
/// 所以必须实现 `==` / `hashCode`。否则每次重建都会当成"新条件"重新查库。
class HistoryFilter {
  const HistoryFilter({
    this.pooperIds = const {},
    this.keyword = '',
    this.from,
    this.to,
  });

  /// 选中的屙屎人。**空集合 = 不限**（不是"谁都不选"）。
  ///
  /// 这个约定很重要：新建的筛选器默认就该是"全部"，
  /// 如果空集合表示"一个都不选"，用户一进来会看到空列表。
  final Set<String> pooperIds;

  /// 关键词。空白字符串 = 不限。
  final String keyword;

  /// 起始日期（含当天）。null = 不限。
  final DateTime? from;

  /// 结束日期（**含当天**）。null = 不限。
  ///
  /// 查询时会转成"次日零点"并用 `<` 比较 —— 用户选"到 10 月 12 日"
  /// 显然包含那天 23:00 的记录。
  final DateTime? to;

  bool get isEmpty =>
      pooperIds.isEmpty && keyword.trim().isEmpty && from == null && to == null;

  /// 实际上会参与筛选的条件数（用来在入口上显示"已筛选 N 项"）。
  int get activeCount {
    var n = 0;
    if (pooperIds.isNotEmpty) n++;
    if (keyword.trim().isNotEmpty) n++;
    if (from != null || to != null) n++;
    return n;
  }

  HistoryFilter copyWith({
    Set<String>? pooperIds,
    String? keyword,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return HistoryFilter(
      pooperIds: pooperIds ?? this.pooperIds,
      keyword: keyword ?? this.keyword,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }

  /// 切换某个屙屎人的选中状态。
  void togglePooper(String id, void Function(HistoryFilter) emit) =>
      emit(copyWith(pooperIds: _toggled(pooperIds, id)));

  static Set<String> _toggled(Set<String> set, String id) {
    final next = {...set};
    if (!next.remove(id)) next.add(id);
    return next;
  }

  /// 把两个日期归一化：**保证 from <= to**。
  ///
  /// 用户在筛选页上可能先点结束日期再点起始日期，得到反过来的区间。
  /// 与其报错，不如直接交换 —— 他要的显然是那个区间。
  HistoryFilter normalized() {
    if (from == null || to == null) return this;
    final f = startOfDay(from!);
    final t = startOfDay(to!);
    if (f.isAfter(t)) {
      return HistoryFilter(
        pooperIds: pooperIds,
        keyword: keyword,
        from: t,
        to: f,
      );
    }
    return HistoryFilter(
      pooperIds: pooperIds,
      keyword: keyword,
      from: f,
      to: t,
    );
  }

  /// 给查询用的起始时刻（本地零点）。
  DateTime? get fromInstant => from == null ? null : startOfDay(from!);

  /// 给查询用的结束时刻，**次日零点**（左闭右开）。
  DateTime? get toExclusiveInstant =>
      to == null ? null : startOfDay(to!).add(const Duration(days: 1));

  @override
  bool operator ==(Object other) =>
      other is HistoryFilter &&
      _sameSet(pooperIds, other.pooperIds) &&
      keyword.trim() == other.keyword.trim() &&
      _sameDay(from, other.from) &&
      _sameDay(to, other.to);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(pooperIds),
        keyword.trim(),
        from == null ? null : dayKey(from!),
        to == null ? null : dayKey(to!),
      );

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return isSameDay(a, b);
  }

  @override
  String toString() =>
      'HistoryFilter(poopers=${pooperIds.length}, '
      'kw="${keyword.trim()}", '
      'from=${from == null ? '-' : dayKey(from!)}, '
      'to=${to == null ? '-' : dayKey(to!)})';
}
