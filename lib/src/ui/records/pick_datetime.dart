import 'package:flutter/material.dart';

/// 依次弹「日期」和「时间」，返回合并后的时刻。
///
/// **任何一步取消都返回 null**，调用方据此保持原值不动 ——
/// 中途取消却把日期改了、时间没改，是最让人恼火的一类 bug。
///
/// 两个选择器都是 Material 的，中文界面靠 `flutter_localizations`
/// （见 `app.dart` 的 localizationsDelegates）。**不配那一段会冒出英文界面**。
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final now = DateTime.now();
  final first = firstDate ?? DateTime(now.year - 5);
  final last = lastDate ?? DateTime(now.year + 2, 12, 31);

  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    helpText: '选日期',
    cancelText: '取消',
    confirmText: '确定',
  );
  if (date == null) return null;
  if (!context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    helpText: '选时间',
    cancelText: '取消',
    confirmText: '确定',
    // 24 小时制：这个 App 的时间轴全是 09:12 / 21:05 这种写法，
    // 混进 AM/PM 会和列表里其它地方对不上。
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
