import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/calendar/calendar_math.dart';

/// 一年里每个月的「1 号是周几」是固定的，把它写死在测试里，
/// 这样如果有人改了偏移算法，失败信息能直接指到哪个月错了。
///
/// 2026 年的关键事实：**3 月 / 8 月 / 11 月需要 6 行网格**。
const _rows2026MondayFirst = <int, int>{
  1: 5,
  2: 5,
  3: 6, // 1 号周日，前置 6 格 + 31 天 = 37 → 6 行
  4: 5,
  5: 5,
  6: 5,
  7: 5,
  8: 6, // 1 号周六，前置 5 格 + 31 天 = 36 → 6 行
  9: 5,
  10: 5,
  11: 6, // 1 号周日，前置 6 格 + 30 天 = 36 → 6 行
  12: 5,
};

void main() {
  group('月份网格行数', () {
    test('2026 年逐月行数全部对得上（含 3 个 6 行月份）', () {
      for (final entry in _rows2026MondayFirst.entries) {
        expect(
          monthGridRows(2026, entry.key, WeekStart.monday),
          entry.value,
          reason: '2026 年 ${entry.key} 月应为 ${entry.value} 行',
        );
      }
    });

    // 这是那个真 bug 的回归护栏。
    //
    // 旧实现把循环写成 `for (i = 0; i < 35; i++)`，永远 5 行 35 格，
    // 于是 2026 年 3/8/11 月各丢掉最后一整个星期。
    // 之所以一直没发现：视觉稿的样例月份是 2 月（周日开头 + 28 天 = 34 格），
    // 正好落在 5 行以内 —— 用刚好合适的数据验证，等于没验证。
    test('6 行月份的格数必须是 42，不能是 35', () {
      for (final m in [3, 8, 11]) {
        expect(
          monthCellCount(2026, m, WeekStart.monday),
          42,
          reason: '2026 年 $m 月有 6 行，写死 35 会丢掉最后一整周',
        );
        expect(monthGridDays(2026, m, WeekStart.monday).length, 42);
      }
    });

    test('网格必须完整覆盖当月每一天', () {
      for (var m = 1; m <= 12; m++) {
        final days = monthGridDays(2026, m, WeekStart.monday);
        final inMonth = days.where((d) => d.month == m).toList();
        expect(
          inMonth.length,
          daysInMonth(2026, m),
          reason: '2026 年 $m 月的网格漏了本月日期',
        );
        // 本月日期必须连续且从 1 号到月末
        expect(inMonth.first.day, 1);
        expect(inMonth.last.day, daysInMonth(2026, m));
      }
    });

    test('行数只可能是 5 或 6', () {
      for (var y = 2020; y <= 2032; y++) {
        for (var m = 1; m <= 12; m++) {
          for (final ws in WeekStart.values) {
            final rows = monthGridRows(y, m, ws);
            expect(rows, anyOf(5, 6), reason: '$y-$m ($ws) 出来 $rows 行');
          }
        }
      }
    });

    // 写上面那条断言时它失败过，暴露了一个设计缺口：
    // 28 天且 1 号正好是每周起始日的月份，自然只有 4 行。
    // 放任 4 行会让日历卡高度在 4/5/6 之间跳，所以钳到 5 行。
    test('自然只有 4 行的月份会被钳到 5 行', () {
      // 2021-02-01 是周一，28 天 → 自然 4 行
      expect(naturalMonthGridRows(2021, 2, WeekStart.monday), 4);
      expect(monthGridRows(2021, 2, WeekStart.monday), 5);

      // 2026-02-01 是周日，28 天 → 周日作首列时自然 4 行
      expect(naturalMonthGridRows(2026, 2, WeekStart.sunday), 4);
      expect(monthGridRows(2026, 2, WeekStart.sunday), 5);

      // 同一时刻的周一作首列视图是 5 行（1 号排在最后一列）
      expect(naturalMonthGridRows(2026, 2, WeekStart.monday), 5);
    });

    test('钳制不会漏掉任何本月日期', () {
      for (final ws in WeekStart.values) {
        for (final (y, m) in [(2021, 2), (2026, 2), (2027, 2), (2015, 2)]) {
          final days = monthGridDays(y, m, ws);
          final inMonth = days.where((d) => d.year == y && d.month == m);
          expect(inMonth.length, daysInMonth(y, m),
              reason: '$y-$m ($ws) 钳制后漏了日期');
        }
      }
    });

    test('跨 400 年也不崩，且格数自洽', () {
      for (var y = 1900; y <= 2300; y += 7) {
        for (var m = 1; m <= 12; m++) {
          final days = monthGridDays(y, m, WeekStart.monday);
          expect(days.length % 7, 0);
          expect(days.length, monthCellCount(y, m, WeekStart.monday));
          expect(days.length, inInclusiveRange(35, 42));
        }
      }
    });
  });

  group('网格起始偏移', () {
    test('2026-02-01 是周日，周一作首列时前面空 6 格', () {
      expect(leadingBlanks(2026, 2, WeekStart.monday), 6);
      expect(monthGridStart(2026, 2, WeekStart.monday), DateTime(2026, 1, 26));
    });

    test('2026-06-01 是周一，前面不空格', () {
      expect(leadingBlanks(2026, 6, WeekStart.monday), 0);
      expect(monthGridStart(2026, 6, WeekStart.monday), DateTime(2026, 6, 1));
    });

    test('周日作首列时偏移整体前移一位', () {
      for (var m = 1; m <= 12; m++) {
        final mon = leadingBlanks(2026, m, WeekStart.monday);
        final sun = leadingBlanks(2026, m, WeekStart.sunday);
        expect(sun, (mon + 1) % 7, reason: '2026 年 $m 月');
      }
    });
  });

  group('日期运算', () {
    test('addDays 跨月跨年正确', () {
      expect(addDays(DateTime(2026, 2, 28), 1), DateTime(2026, 3, 1));
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 31));
    });

    test('闰年 2 月 29 天', () {
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2100, 2), 28); // 百年不闰
      expect(daysInMonth(2000, 2), 29); // 四百年又闰
    });

    test('addMonths 会把日号钳到目标月末，不溢出到下个月', () {
      // 1/31 加一个月应该是 2/28，而不是 3/3
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
      expect(addMonths(DateTime(2026, 3, 31), -1), DateTime(2026, 2, 28));
      // 正常情况不受影响
      expect(addMonths(DateTime(2026, 1, 15), 1), DateTime(2026, 2, 15));
    });

    test('addMonths 跨年', () {
      expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
      expect(addMonths(DateTime(2026, 2, 15), -3), DateTime(2025, 11, 15));
      expect(addMonths(DateTime(2026, 6, 15), 18), DateTime(2027, 12, 15));
    });

    test('isSameDay 忽略时分秒', () {
      expect(
        isSameDay(DateTime(2026, 2, 11, 0, 0), DateTime(2026, 2, 11, 23, 59)),
        isTrue,
      );
      expect(isSameDay(DateTime(2026, 2, 11), DateTime(2026, 2, 12)), isFalse);
    });
  });

  group('周视图', () {
    test('weekStartOf 取到本周周一', () {
      // 2026-02-11 是周三
      expect(weekStartOf(DateTime(2026, 2, 11), WeekStart.monday),
          DateTime(2026, 2, 9));
      // 周一本身应返回自己
      expect(weekStartOf(DateTime(2026, 2, 9), WeekStart.monday),
          DateTime(2026, 2, 9));
      // 周日应回到本周一（而不是跳到下周一）
      expect(weekStartOf(DateTime(2026, 2, 15), WeekStart.monday),
          DateTime(2026, 2, 9));
    });

    test('周日作首列时 weekStartOf 结果不同', () {
      expect(weekStartOf(DateTime(2026, 2, 11), WeekStart.sunday),
          DateTime(2026, 2, 8));
    });

    test('weekDaysOf 恒为 7 天且首尾相接', () {
      for (var d = 1; d <= 28; d++) {
        final days = weekDaysOf(DateTime(2026, 2, d), WeekStart.monday);
        expect(days.length, 7);
        expect(days.first.weekday, DateTime.monday);
        expect(days.last.difference(days.first).inDays, 6);
        expect(days.contains(startOfDay(DateTime(2026, 2, d))), isTrue);
      }
    });

    test('weeksOfMonth 的每一周都落在网格内，且与网格行对齐', () {
      for (var m = 1; m <= 12; m++) {
        final days = monthGridDays(2026, m, WeekStart.monday);
        final weeks = weeksOfMonth(2026, m, WeekStart.monday);
        expect(weeks.length, monthGridRows(2026, m, WeekStart.monday));
        for (var i = 0; i < weeks.length; i++) {
          expect(weeks[i].first, days[i * 7]);
          expect(weeks[i].last, days[i * 7 + 6]);
        }
      }
    });

    // 周列表是按**网格行**切的，不是按「这一周的周一属于哪个月」。
    //
    // 曾经想按后者切（这样 2026 年 2 月会得到漂亮的 4 周：2/2–2/8 … 2/23–3/1），
    // 但那会让 2026 年 1 月的 1/1–1/4 不属于任何一周 —— 1 月的网格首行是
    // 12/29–1/4，它的周一在 12 月，于是被划给 12 月，1 月 1~4 号就再也点不到了。
    //
    // 网格行切法保证「当月每一天都至少属于一周」，这是正确性要求；
    // 代价是首行（如 1/26–2/1）大部分是上个月，靠日期区间文案消除歧义。
    test('按网格行切，保证当月每一天都落在某一周里', () {
      for (var m = 1; m <= 12; m++) {
        final weeks = weeksOfMonth(2026, m, WeekStart.monday);
        for (var d = 1; d <= daysInMonth(2026, m); d++) {
          final day = DateTime(2026, m, d);
          expect(
            weeks.any((w) => w.contains(day)),
            isTrue,
            reason: '2026-$m-$d 不属于任何一周，周选择器点不到它',
          );
        }
      }
    });

    test('2026 年 2 月是 5 周，首行跨到 1 月', () {
      final weeks = weeksOfMonth(2026, 2, WeekStart.monday);
      expect(weeks.length, 5);
      expect(weeks.first.first, DateTime(2026, 1, 26));
      expect(weeks.first.label(), '1/26 – 2/1');
      expect(weeks.first.spansTwoMonths, isTrue);
    });

    test('跨月的那一周会被正确标记', () {
      // 2026 年 2 月最后一周是 2/23 – 3/1
      final weeks = weeksOfMonth(2026, 2, WeekStart.monday);
      final last = weeks.last;
      expect(last.spansTwoMonths, isTrue);
      expect(last.label(), '2/23 – 3/1');
      expect(last.labelCn(), '2月23日 – 3月1日');
      expect(last.contains(DateTime(2026, 3, 1)), isTrue);
      expect(last.contains(DateTime(2026, 3, 2)), isFalse);
    });

    test('非跨月周的文案', () {
      // 网格行：0=1/26–2/1, 1=2/2–2/8, 2=2/9–2/15, ...
      final weeks = weeksOfMonth(2026, 2, WeekStart.monday);
      expect(weeks[2].label(), '2/9 – 2/15');
      expect(weeks[2].labelCn(), '2月9日 – 15日');
      expect(weeks[2].spansTwoMonths, isFalse);
    });
  });
}
