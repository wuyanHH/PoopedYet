import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/calendar/calendar_math.dart';
import 'package:pooped_yet/src/state/calendar_view.dart';

/// 日历视图状态的转换规则。
///
/// 这三个字段（选中日期 / 可见月份 / 模式）会互相牵动，是最容易出
/// "日历显示 3 月、下面列表还是 2 月"这类错位的地方。所以规则集中在一个
/// notifier 里并在这里逐条钉死。
///
/// 测试里把 `todayProvider` override 成固定的 2026-02-11（周三），
/// 否则跑测试当天的日期一变，断言就全变了。
ProviderContainer _makeContainer() {
  final c = ProviderContainer(
    overrides: [todayProvider.overrideWithValue(DateTime(2026, 2, 11))],
  );
  addTearDown(c.dispose);
  return c;
}

CalendarView _view(ProviderContainer c) => c.read(calendarViewProvider.notifier);
CalendarViewState _state(ProviderContainer c) => c.read(calendarViewProvider);

void main() {
  group('初始状态', () {
    test('默认选中今天、显示本月、月视图', () {
      final c = _makeContainer();
      final s = _state(c);
      expect(s.selectedDate, DateTime(2026, 2, 11));
      expect(s.visibleMonth, DateTime(2026, 2, 1));
      expect(s.mode, CalendarMode.month);
    });
  });

  group('翻月', () {
    test('保持日号', () {
      final c = _makeContainer();
      _view(c).goToMonth(DateTime(2026, 5));
      final s = _state(c);
      expect(s.visibleMonth, DateTime(2026, 5, 1));
      expect(s.selectedDate, DateTime(2026, 5, 11),
          reason: '翻月要保持日号，否则日历和下面的列表会错位');
    });

    test('目标月没有这个日号时钳到月末', () {
      final c = _makeContainer();
      _view(c).selectDay(DateTime(2026, 1, 31));
      _view(c).goToMonth(DateTime(2026, 2));
      expect(_state(c).selectedDate, DateTime(2026, 2, 28));
    });

    test('闰年 1/31 → 2/29', () {
      final c = _makeContainer();
      _view(c).selectDay(DateTime(2024, 1, 31));
      _view(c).goToMonth(DateTime(2024, 2));
      expect(_state(c).selectedDate, DateTime(2024, 2, 29));
    });

    test('prev / next 跨年', () {
      final c = _makeContainer();
      _view(c).goToMonth(DateTime(2026, 1));
      _view(c).prevMonth();
      expect(_state(c).visibleMonth, DateTime(2025, 12, 1));
      expect(_state(c).selectedDate, DateTime(2025, 12, 11));

      _view(c).nextMonth();
      expect(_state(c).visibleMonth, DateTime(2026, 1, 1));
    });

    test('月份归一化：传 2 月 28 号也得到 2 月 1 号', () {
      final c = _makeContainer();
      _view(c).goToMonth(DateTime(2026, 2, 28));
      expect(_state(c).visibleMonth, DateTime(2026, 2, 1));
    });
  });

  group('点某一天', () {
    test('同月内只动选中，不翻月', () {
      final c = _makeContainer();
      _view(c).selectDay(DateTime(2026, 2, 20));
      final s = _state(c);
      expect(s.selectedDate, DateTime(2026, 2, 20));
      expect(s.visibleMonth, DateTime(2026, 2, 1));
    });

    test('点邻格的降级日期会跳月', () {
      final c = _makeContainer();
      // 2026-02 的网格末格是 3/1
      _view(c).selectDay(DateTime(2026, 3, 1));
      final s = _state(c);
      expect(s.selectedDate, DateTime(2026, 3, 1));
      expect(s.visibleMonth, DateTime(2026, 3, 1),
          reason: '点邻格日期应该翻过去，否则用户点了半天没反应');
    });

    test('syncMonth: false 时只动选中', () {
      final c = _makeContainer();
      _view(c).selectDay(DateTime(2026, 3, 1), syncMonth: false);
      expect(_state(c).selectedDate, DateTime(2026, 3, 1));
      expect(_state(c).visibleMonth, DateTime(2026, 2, 1));
    });

    test('时分秒被抹掉', () {
      final c = _makeContainer();
      _view(c).selectDay(DateTime(2026, 2, 20, 13, 45, 30));
      expect(_state(c).selectedDate, DateTime(2026, 2, 20));
    });
  });

  group('翻周', () {
    test('前后一周，并同步可见月份', () {
      final c = _makeContainer();
      _view(c).shiftWeek(1);
      expect(_state(c).selectedDate, DateTime(2026, 2, 18));
      expect(_state(c).visibleMonth, DateTime(2026, 2, 1));

      // 2/11 往后 3 周会跨到 3 月
      _view(c).shiftWeek(2);
      expect(_state(c).selectedDate, DateTime(2026, 3, 4));
      expect(_state(c).visibleMonth, DateTime(2026, 3, 1),
          reason: '跨月时可见月份要跟上');
    });

    test('往前跨年', () {
      final c = _makeContainer();
      _view(c).shiftWeek(-7);
      expect(_state(c).selectedDate, DateTime(2025, 12, 24));
      expect(_state(c).visibleMonth, DateTime(2025, 12, 1));
    });
  });

  group('跳到某一周', () {
    // ⚠ weeksOfMonth 的 month 是 **1-based**（和 DateTime 一致）。
    //   这里先后写过 1，拿到的是 1 月而不是 2 月，白错了两条断言。
    test('weeksOfMonth 的 month 是 1-based', () {
      final feb = weeksOfMonth(2026, 2, WeekStart.monday);
      expect(feb.length, 5);
      expect(feb.first.first, DateTime(2026, 1, 26));
      expect(feb.last.first, DateTime(2026, 2, 23));
    });

    test('保持星期几', () {
      final c = _makeContainer();
      // 选中 2026-02-11 是周三
      final weeks = weeksOfMonth(2026, 2, WeekStart.monday);
      _view(c).goToWeek(weeks.first); // 1/26 – 2/1，周一开头
      final s = _state(c);
      expect(s.selectedDate.weekday, DateTime.wednesday,
          reason: '在周三跳到别的周，应该还落在周三');
      expect(s.selectedDate, DateTime(2026, 1, 28));
      expect(s.visibleMonth, DateTime(2026, 1, 1));
    });

    test('跨月的那一周会切到对应的月份', () {
      final c = _makeContainer();
      final weeks = weeksOfMonth(2026, 2, WeekStart.monday);
      _view(c).goToWeek(weeks.last); // 2/23 – 3/1
      final s = _state(c);
      expect(s.selectedDate.weekday, DateTime.wednesday);
      expect(s.selectedDate, DateTime(2026, 2, 25));
      expect(s.visibleMonth, DateTime(2026, 2, 1));
    });
  });

  group('切换模式', () {
    test('切回月视图时，可见月份对齐到选中日期', () {
      final c = _makeContainer();
      _view(c).setMode(CalendarMode.week);
      _view(c).shiftWeek(6); // 跑到 3 月
      expect(_state(c).visibleMonth, DateTime(2026, 3, 1));

      _view(c).setMode(CalendarMode.month);
      expect(_state(c).visibleMonth, DateTime(2026, 3, 1),
          reason: '从 3 月的那一周切回月视图，不该还停在上次看的月份');
    });

    test('切到周视图时不动选中日期', () {
      final c = _makeContainer();
      _view(c).selectDay(DateTime(2026, 2, 20));
      _view(c).setMode(CalendarMode.week);
      expect(_state(c).selectedDate, DateTime(2026, 2, 20));
      expect(_state(c).mode, CalendarMode.week);
    });

    test('toggle 来回切', () {
      final c = _makeContainer();
      _view(c).toggleMode();
      expect(_state(c).mode, CalendarMode.week);
      _view(c).toggleMode();
      expect(_state(c).mode, CalendarMode.month);
    });
  });

  group('回到今天', () {
    test('从很远的地方回来', () {
      final c = _makeContainer();
      _view(c).goToMonth(DateTime(2024, 8));
      expect(_state(c).visibleMonth, DateTime(2024, 8, 1));

      _view(c).goToday();
      final s = _state(c);
      expect(s.selectedDate, DateTime(2026, 2, 11));
      expect(s.visibleMonth, DateTime(2026, 2, 1));
      expect(s.mode, CalendarMode.month, reason: '回到今天不该改变显示模式');
    });
  });

  group('CalendarViewState', () {
    final s = CalendarViewState(
      selectedDate: DateTime(2026, 2, 11),
      visibleMonth: DateTime(2026, 2, 1),
      mode: CalendarMode.month,
    );

    test('copyWith 只改指定字段', () {
      final w = s.copyWith(mode: CalendarMode.week);
      expect(w.mode, CalendarMode.week);
      expect(w.selectedDate, s.selectedDate);
      expect(w.visibleMonth, s.visibleMonth);
    });

    test('copyWith 不带参数时相等', () {
      expect(s.copyWith(), s);
      expect(s.copyWith().hashCode, s.hashCode);
    });

    test('相等性按值比较', () {
      final same = CalendarViewState(
        selectedDate: DateTime(2026, 2, 11),
        visibleMonth: DateTime(2026, 2, 1),
        mode: CalendarMode.month,
      );
      expect(same, s);
      expect(s.copyWith(mode: CalendarMode.week), isNot(s));
    });
  });

  group('normalizeMonth / clampDayOfMonth', () {
    test('normalizeMonth 归一到 1 号', () {
      expect(normalizeMonth(DateTime(2026, 2, 11)), DateTime(2026, 2, 1));
      expect(normalizeMonth(DateTime(2026, 2, 1)), DateTime(2026, 2, 1));
      expect(normalizeMonth(DateTime(2026, 2, 28)), DateTime(2026, 2, 1));
    });

    test('clampDayOfMonth 钳到月末', () {
      expect(clampDayOfMonth(31, DateTime(2026, 2)), 28);
      expect(clampDayOfMonth(31, DateTime(2024, 2)), 29);
      expect(clampDayOfMonth(15, DateTime(2026, 2)), 15);
      expect(clampDayOfMonth(30, DateTime(2026, 4)), 30);
      expect(clampDayOfMonth(31, DateTime(2026, 4)), 30);
    });
  });
}
