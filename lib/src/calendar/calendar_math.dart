/// 日历网格的日期数学。
///
/// 这个文件刻意做成**纯函数、零 Flutter 依赖**，因为它是最容易出错、
/// 出错又最难发现的一块。`test/calendar/calendar_math_test.dart` 里
/// 有 2026 年全年 12 个月的逐月断言。
///
/// ## 这里修掉过的真 bug
///
/// 早期视觉稿把网格写死成 35 格（5 行）：
///
/// ```dart
/// for (var i = 0; i < 35; i++) { ... }   // ← 错的
/// ```
///
/// 但一个月要几行取决于「1 号是周几」和「这个月有多少天」。
/// 2026 年有 **3 个月需要 6 行**（3 月 / 8 月 / 11 月），每个月会丢掉最后一整个星期：
///
/// | 月份 | 1 号 | 前置空位 | 天数 | 行数 | 后果 |
/// |---|---|---|---|---|---|
/// | 3 月 | 周日 | 6 | 31 | **6** | 丢掉 3/25–3/31 |
/// | 8 月 | 周六 | 5 | 31 | **6** | 丢掉 8/25–8/31 |
/// | 11 月 | 周日 | 6 | 30 | **6** | 丢掉 11/24–11/30 |
///
/// 之所以一直没暴露，是因为视觉稿的样例月份是 2026 年 2 月 ——
/// 周日开头 + 28 天 = 34 格，**正好落在 5 行以内**。
/// 用刚好合适的数据去验证，等于没验证。
library;

/// 每周从哪天开始。设计里这是可配置项（见设计规范「每周起始日」）。
enum WeekStart {
  monday(DateTime.monday),
  sunday(DateTime.sunday);

  const WeekStart(this.dartWeekday);

  /// 对应 `DateTime.monday` / `DateTime.sunday` 的常量值。
  final int dartWeekday;
}

/// 把 `DateTime` 归一到当天零点（本地时区）。
///
/// **不要**用 `DateTime.now().subtract(Duration(hours: ...))` 之类的算法来取日期，
/// 跨夏令时会偏一小时，日期就错了。
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// `yyyy-MM-dd` 的本地日期键。
///
/// 日历聚合、按天分组都用它做 map 的键。
/// **必须用本地日期**：Drift 把 DateTime 存成 Unix 秒（UTC 基准），
/// 直接对时间戳取模分组会按 UTC 切天，国内用户晚上 8 点之后的记录会被算到第二天。
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// [dayKey] 的逆运算。
DateTime parseDayKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// 两个时刻是否落在同一天（本地时区）。
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 加减天数。
///
/// 用「显式构造日期」而不是 `add(Duration(days: n))`：
/// 后者在跨夏令时的时区会偏一小时，进而落到前一天或后一天。
/// 国内没有夏令时，但用户出国后历史记录会整体错位 —— 现在写对是免费的。
DateTime addDays(DateTime d, int n) =>
    DateTime(d.year, d.month, d.day + n, d.hour, d.minute);

/// 加减月份，并把日号钳制到目标月的合法范围内。
///
/// `2026-01-31` 加一个月得到 `2026-02-28`（而不是溢到 3 月 3 日）。
DateTime addMonths(DateTime d, int n) {
  final total = d.year * 12 + (d.month - 1) + n;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return DateTime(y, m, day, d.hour, d.minute);
}

/// 某月 1 号之前需要补几个空格子（周一作首列时为 0~6）。
int leadingBlanks(int year, int month, WeekStart weekStart) {
  final first = DateTime(year, month, 1);
  return (first.weekday - weekStart.dartWeekday + 7) % 7;
}

/// 某月有多少天。
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// 日历网格允许的最少行数。
///
/// **为什么要有下限**：28 天且 1 号正好落在每周起始日的月份，
/// 自然行数只有 **4**。实例：
/// - 2021 年 2 月（周一作首列，1 号是周一，28 天）
/// - **2026 年 2 月（周日作首列，1 号是周日，28 天）** —— 正是视觉稿的样例月份
///
/// 如果放任 4 行，日历卡高度会在 4/5/6 行之间跳（跨 122px），
/// 左右滑动切月时非常明显。钳到 5 行后只剩 5/6 两种，跳动减半，
/// 而且多出来的那一行本来就是下个月的降级日期，视觉上不突兀。
const int minMonthGridRows = 5;

/// 日历网格最多 6 行。数学上的上界：前置 6 格 + 31 天 = 37 格 → 6 行。
const int maxMonthGridRows = 6;

/// 某月**自然**需要几行（可能是 4/5/6）。
///
/// 一般不直接用这个，用 [monthGridRows]。留出来是为了写测试和排查。
int naturalMonthGridRows(int year, int month, WeekStart weekStart) {
  final cells = leadingBlanks(year, month, weekStart) + daysInMonth(year, month);
  return (cells + 6) ~/ 7; // ceil(cells / 7)
}

/// 某月的日历网格实际用几行 —— **只可能是 5 或 6**。
///
/// 这是那个 bug 的修复点。任何时候都不要把它换成常量 5：
/// 2026 年有 3 个月（3/8/11 月）自然需要 6 行，写死 5 会丢掉最后一整周。
/// 反过来也不要放任它掉到 4 行，见 [minMonthGridRows]。
int monthGridRows(int year, int month, WeekStart weekStart) {
  final natural = naturalMonthGridRows(year, month, weekStart);
  if (natural < minMonthGridRows) return minMonthGridRows;
  if (natural > maxMonthGridRows) return maxMonthGridRows;
  return natural;
}

/// 某月网格里第一个格子对应的日期（通常是上个月的末尾几天）。
DateTime monthGridStart(int year, int month, WeekStart weekStart) =>
    DateTime(year, month, 1 - leadingBlanks(year, month, weekStart));

/// 某月网格的全部日期，长度恒为 `monthGridRows(...) * 7`（35 或 42）。
///
/// 这个列表**包含**上个月末尾和下个月开头的补位日期 ——
/// 它们在视觉上是降级的（`a11y-dim-ok`），但必须画出来，否则网格会缺角。
List<DateTime> monthGridDays(int year, int month, WeekStart weekStart) {
  final rows = monthGridRows(year, month, weekStart);
  final start = monthGridStart(year, month, weekStart);
  return List<DateTime>.generate(
    rows * 7,
    (i) => addDays(start, i),
    growable: false,
  );
}

/// 给定日期所在周的起始日（已归一到零点）。
DateTime weekStartOf(DateTime d, WeekStart weekStart) {
  final day = startOfDay(d);
  final delta = (day.weekday - weekStart.dartWeekday + 7) % 7;
  return addDays(day, -delta);
}

/// 给定日期所在周的 7 天。
List<DateTime> weekDaysOf(DateTime d, WeekStart weekStart) {
  final start = weekStartOf(d, weekStart);
  return List<DateTime>.generate(7, (i) => addDays(start, i), growable: false);
}

/// 某月内所有完整的「周」（按 [weekStart] 切分，与整个月的网格对齐）。
///
/// 用于「跳到哪一周」选择器：跨月的那一周会同时包含两个月，
/// 点它时需要把日历切到 [WeekRange.first] 所在的月份。
class WeekRange {
  const WeekRange(this.first, this.last);

  final DateTime first;
  final DateTime last;

  /// 显示用的区间文案，如 `2/9 – 2/15`；跨月时是 `2/23 – 3/1`。
  ///
  /// 同月时**仍然重复月份**：纯数字的 `2/9 – 15` 一眼看不出 15 是哪个月。
  String label() => '${first.month}/${first.day} – ${last.month}/${last.day}';

  /// 中文区间，同月时省掉后一个月份：`2月9日 – 15日` / `2月23日 – 3月1日`。
  ///
  /// 中文里省掉同月是习惯用法，读起来不别扭（和上面的数字写法不同）。
  String labelCn() => first.month == last.month
      ? '${first.month}月${first.day}日 – ${last.day}日'
      : '${first.month}月${first.day}日 – ${last.month}月${last.day}日';

  /// 这一周是否横跨两个月。跨月时点它会同时影响两个月的徽标统计。
  bool get spansTwoMonths => first.month != last.month;

  /// 这一周是否包含 [d]。
  bool contains(DateTime d) =>
      !startOfDay(d).isBefore(first) && !startOfDay(d).isAfter(last);

  @override
  String toString() => 'WeekRange($label())';

  @override
  bool operator ==(Object other) =>
      other is WeekRange && first == other.first && last == other.last;

  @override
  int get hashCode => Object.hash(first, last);
}

/// 把某月按网格行切成若干个 [WeekRange]。
///
/// 注意这里**按网格行**切，不按 ISO 周号 —— 这样它和日历上看到的行一一对应，
/// 用户点「第 2 周」跳过去的就是他刚才看到的那一行。
///
/// **序号就用返回列表的下标 + 1**，不要另外算 ——
/// 单独算一套序号，迟早会和真实行号对不上。
List<WeekRange> weeksOfMonth(int year, int month, WeekStart weekStart) {
  final rows = monthGridRows(year, month, weekStart);
  final start = monthGridStart(year, month, weekStart);
  return List<WeekRange>.generate(rows, (i) {
    final first = addDays(start, i * 7);
    return WeekRange(first, addDays(first, 6));
  }, growable: false);
}

/// 整月网格的总格数（35 或 42）。写测试时用它比写 35 安全。
int monthCellCount(int year, int month, WeekStart weekStart) =>
    monthGridRows(year, month, weekStart) * 7;
