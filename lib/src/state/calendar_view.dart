import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calendar/calendar_math.dart';

/// 日历的显示模式。
enum CalendarMode { month, week }

/// 日历的视图状态。
///
/// 三个字段会互相牵动 —— 翻月要动选中日期、点邻格的日期要跳月、
/// 切到周视图又由选中日期决定看哪一周。所以把它们放在**一个** notifier 里，
/// 转换规则集中在一处并写测试，而不是散在 UI 的 onTap 里各改各的。
class CalendarViewState {
  const CalendarViewState({
    required this.selectedDate,
    required this.visibleMonth,
    required this.mode,
  });

  /// 选中日期。决定下方记录列表显示哪一天，也决定周视图显示哪一周。
  final DateTime selectedDate;

  /// 月视图显示的月份。**恒为当月 1 号**，避免出现 2 月 30 日这种值。
  final DateTime visibleMonth;

  final CalendarMode mode;

  CalendarViewState copyWith({
    DateTime? selectedDate,
    DateTime? visibleMonth,
    CalendarMode? mode,
  }) {
    return CalendarViewState(
      selectedDate: selectedDate ?? this.selectedDate,
      visibleMonth: visibleMonth ?? this.visibleMonth,
      mode: mode ?? this.mode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarViewState &&
      selectedDate == other.selectedDate &&
      visibleMonth == other.visibleMonth &&
      mode == other.mode;

  @override
  int get hashCode => Object.hash(selectedDate, visibleMonth, mode);

  @override
  String toString() =>
      'CalendarViewState(${dayKey(selectedDate)}, '
      '${visibleMonth.year}-${visibleMonth.month}, ${mode.name})';
}

/// 把任意日期归一成它所在月的 1 号。
DateTime normalizeMonth(DateTime d) => DateTime(d.year, d.month);

/// 在 [month] 这个月里，找到和 [dayOfMonth] 最接近的合法日号。
///
/// 用于翻月时"保持日号"：1/31 翻到 2 月只能是 2/28。
int clampDayOfMonth(int dayOfMonth, DateTime month) {
  final last = daysInMonth(month.year, month.month);
  return dayOfMonth > last ? last : dayOfMonth;
}

/// 今天。单独抽出来是为了两件事：
///
/// 1. **可测**：转换规则不该依赖跑测试时的真实日期，测试里 override 掉就行。
/// 2. **跨零点**：`DateTime.now()` 会变，但 provider 不会自己重跑。
///    真正要做的是在 App 从后台恢复时 `ref.invalidate(todayProvider)`。
final todayProvider = Provider<DateTime>((ref) => startOfDay(DateTime.now()));

/// 日历视图状态的转换规则。
class CalendarView extends Notifier<CalendarViewState> {
  @override
  CalendarViewState build() {
    final today = ref.watch(todayProvider);

    // 每次状态变化打一行日志。**只在 debug 构建里**。
    //
    // 为什么值得常驻：日历的状态是三向耦合的（选中日期 / 可见月份 / 模式），
    // 真机上出了问题很难从画面上看出是哪一步转错了。
    // 有了这行，`adb logcat | grep CAL` 就能看到完整轨迹 ——
    // 而且它也是 UI 自动化验证的唯一观察窗口
    // （Flutter 画在 canvas 上，uiautomator 读不到界面文字）。
    if (kDebugMode) {
      listenSelf((prev, next) => debugPrint('[CAL] $prev -> $next'));
    }

    return CalendarViewState(
      selectedDate: today,
      visibleMonth: normalizeMonth(today),
      mode: CalendarMode.month,
    );
  }

  /// 点日历上的某一天。
  ///
  /// [syncMonth] 为 true 时，如果这天不在当前显示的月份，就把日历翻过去 ——
  /// 点邻格那些降级日期时应该跳月，否则用户点了半天没反应。
  void selectDay(DateTime d, {bool syncMonth = true}) {
    final day = startOfDay(d);
    state = state.copyWith(
      selectedDate: day,
      visibleMonth: syncMonth ? normalizeMonth(day) : state.visibleMonth,
    );
  }

  /// 跳到某个月。**保持日号**，让记录列表跟着日历一起走。
  ///
  /// 不保持日号的话会出现"日历显示 3 月、下面列表还是 2 月 11 日"的错位。
  void goToMonth(DateTime month) {
    final m = normalizeMonth(month);
    state = state.copyWith(
      visibleMonth: m,
      selectedDate: DateTime(
        m.year,
        m.month,
        clampDayOfMonth(state.selectedDate.day, m),
        state.selectedDate.hour,
        state.selectedDate.minute,
      ),
    );
  }

  void prevMonth() => goToMonth(addMonths(state.visibleMonth, -1));
  void nextMonth() => goToMonth(addMonths(state.visibleMonth, 1));

  /// 跳到某一周。**保持星期几** —— 用户在周三，跳到别的周也应该落在周三。
  void goToWeek(WeekRange week) {
    final delta = (state.selectedDate.weekday - week.first.weekday + 7) % 7;
    final target = addDays(week.first, delta);
    state = state.copyWith(
      selectedDate: target,
      visibleMonth: normalizeMonth(target),
    );
  }

  void shiftWeek(int weeks) {
    final target = addDays(state.selectedDate, weeks * 7);
    state = state.copyWith(
      selectedDate: target,
      visibleMonth: normalizeMonth(target),
    );
  }

  void prevWeek() => shiftWeek(-1);
  void nextWeek() => shiftWeek(1);

  /// 回到今天。
  void goToday() {
    final today = ref.read(todayProvider);
    state = state.copyWith(
      selectedDate: today,
      visibleMonth: normalizeMonth(today),
    );
  }

  /// 切换月 / 周视图。
  ///
  /// 切到月视图时把显示月份对齐到选中日期 —— 否则从"3 月的那一周"
  /// 切回月视图，可能还停在上次看的 1 月。
  void setMode(CalendarMode mode) {
    state = state.copyWith(
      mode: mode,
      visibleMonth: mode == CalendarMode.month
          ? normalizeMonth(state.selectedDate)
          : state.visibleMonth,
    );
  }

  void toggleMode() => setMode(
        state.mode == CalendarMode.month ? CalendarMode.week : CalendarMode.month,
      );
}

final calendarViewProvider = NotifierProvider<CalendarView, CalendarViewState>(
  CalendarView.new,
);
