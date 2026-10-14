import '../data/database.dart';

/// 一次记录的四副面孔。
///
/// **「没有结束时间」不等于「正在屙」** —— 这是整个数据模型里最容易搞错的地方。
/// 不区分的话，用户忘点一次结束，那条记录就会永远挂在进行中，
/// 还会被 `ux_active_record` 唯一索引挡住下一次记录。
///
/// 判定逻辑见 [recordStateOf]。视觉规范见 `docs/design-system.md` 第 10 节。
enum RecordState {
  /// 正在屙：还没结束，且没超过阈值。**只有这个状态配脉冲动画。**
  active,

  /// 待确认：超过阈值仍未结束，需要用户回答"还在屙吗"。
  ///
  /// 不做脉冲 —— 脉冲会让人以为记录还在正常进行，反而不去处理。
  pending,

  /// 未记结束：用户明确表示没记结束时间。中性灰，**不用红色** ——
  /// 它不是错误，只是没记。用红色会让人有负罪感，而这是个手帐类产品。
  endUnknown,

  /// 已完成：有结束时间。
  done,
}

/// 超过这个时长仍未结束，就进入 [RecordState.pending]。
///
/// 默认 2 小时。短了会频繁打扰（拉肚子时可能真的待得久），
/// 长了就失去提醒意义。见 `docs/design-system.md` 待定项第 4 条。
const Duration kPendingAfter = Duration(hours: 2);

/// 超过这个时长仍未结束，自动收敛为 [RecordState.endUnknown]。
///
/// 「不会一直挂着」是给用户的承诺，见视觉稿 ④ 的那行提示。
const Duration kAutoConvergeAfter = Duration(hours: 24);

/// 判定一条记录当前处于哪个状态。
///
/// 判定顺序**不能换**：
/// 1. 先看 [PoopRecord.endUnknown] —— 用户明确表过态，优先级最高
/// 2. 再看 [PoopRecord.endedAt] —— 有结束时间就是已完成
/// 3. 最后才按时间阈值在 active / pending 之间分
RecordState recordStateOf(
  PoopRecord r, {
  required DateTime now,
  Duration pendingAfter = kPendingAfter,
}) {
  if (r.endUnknown) return RecordState.endUnknown;
  if (r.endedAt != null) return RecordState.done;

  final elapsed = now.difference(r.startedAt);
  return elapsed >= pendingAfter ? RecordState.pending : RecordState.active;
}

/// 是否该自动收敛成「未记结束」。
///
/// 在打开 App 时批量扫一遍超阈值的记录并落库 —— 只靠弹窗提醒是不够的，
/// 用户可能一直不打开 App。
bool shouldAutoConverge(
  PoopRecord r, {
  required DateTime now,
  Duration after = kAutoConvergeAfter,
}) {
  if (r.endUnknown || r.endedAt != null) return false;
  return now.difference(r.startedAt) >= after;
}

/// 将时间对齐截断到分钟精度（清除秒与毫秒）。
///
/// 业务规则：拉屎时间一律按分钟来计算（例如 12:00 - 12:00 是 0 分钟，12:00 - 12:01 是 1 分钟）。
DateTime toMinutePrecision(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);

/// 按分钟维度计算两个时间点之间的历时（分钟数）。
///
/// 严格满足：
/// - 12:00 到 12:00 为 0 分钟
/// - 12:00 到 12:01 为 1 分钟
/// 若 [end] 早于 [start] 则安全返回 0。
int minutesBetween(DateTime start, DateTime end) {
  final s = toMinutePrecision(start);
  final e = toMinutePrecision(end);
  final diff = e.difference(s).inMinutes;
  return diff < 0 ? 0 : diff;
}

/// 这条记录的时长；没有结束时间时返回 null。
///
/// **`endUnknown` 的记录时长是"不详"，不是 0** —— 统计时必须排除它们，
/// 否则平均值会被这些 0 拉偏。
///
/// 业务规则：时长一律按分钟精度计算（如 12:00 - 12:00 为 0 分钟，12:00 - 12:01 为 1 分钟）。
Duration? durationOf(PoopRecord r) {
  final end = r.endedAt;
  if (end == null) return null;
  final m = minutesBetween(r.startedAt, end);
  return Duration(minutes: m);
}

/// 把时长格式化成界面文案。
///
/// - `14 分钟`
/// - `1 小时 3 分`
/// - `2 小时`（整点不显示"0 分"）
String formatDuration(Duration d) {
  final totalMinutes = d.inMinutes;
  if (totalMinutes < 60) return '$totalMinutes 分钟';

  final h = d.inHours;
  final m = totalMinutes - h * 60;
  return m == 0 ? '$h 小时' : '$h 小时 $m 分';
}

/// 记录卡右侧「时长」那一列的文案，四种状态各有各的说法。
///
/// 「时长必须在阈值处停住，不能一直涨到"已 3 天"」—— 见设计规范第 10 节。
String durationLabel(PoopRecord r, {required DateTime now}) {
  switch (recordStateOf(r, now: now)) {
    case RecordState.active:
      final m = minutesBetween(r.startedAt, now);
      return '已 ${formatDuration(Duration(minutes: m))}';
    case RecordState.pending:
      // 停住，不报真实经过时间 —— 报"已 8 小时"会让人焦虑且没有信息量
      return '已超过 ${formatDuration(kPendingAfter)}';
    case RecordState.endUnknown:
      return '时长不详';
    case RecordState.done:
      return formatDuration(durationOf(r)!);
  }
}

/// 记录卡时间行右半段的文案（`09:12 → ???` 里的 `???`）。
String endLabel(PoopRecord r, {required DateTime now}) {
  switch (recordStateOf(r, now: now)) {
    case RecordState.active:
      return '正在屙';
    case RecordState.pending:
      return '？';
    case RecordState.endUnknown:
      return '未记结束';
    case RecordState.done:
      final e = r.endedAt!;
      return '${e.hour.toString().padLeft(2, '0')}:'
          '${e.minute.toString().padLeft(2, '0')}';
  }
}

/// `HH:mm`
String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
