import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/calendar/calendar_math.dart';
import 'package:pooped_yet/src/calendar/layout.dart';
import 'package:pooped_yet/src/data/database.dart';
import 'package:pooped_yet/src/data/queries.dart';
import 'package:pooped_yet/src/state/calendar_view.dart';
import 'package:pooped_yet/src/state/settings.dart';
import 'package:pooped_yet/src/ui/calendar/calendar_grid.dart';
import 'package:pooped_yet/src/ui/calendar/day_cell.dart';

/// 日历网格的排版测试。
///
/// 这个文件盯的是**溢出**：格子是固定的 58px 高、约 46px 宽，
/// 里面塞了日期 + 休/班角标 + 头像 + 次数 + `+N`。
/// 字号一放大、次数一到两位数，就容易画到隔壁格子上 ——
/// 这种问题在模拟器上不一定看得见（可能只是"有点挤"），得用测试钉死。
void main() {
  Pooper fakePooper(String id, String name, {int? archived}) => Pooper(
        id: id,
        name: name,
        iconKey: null,
        avatarBlob: null,
        remark: null,
        isDefault: false,
        archivedAt: archived == null ? null : DateTime(2026, 1, 1),
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      );

  Widget host({
    required List<DateTime> days,
    DateTime? monthAnchor,
    CalendarViewState? view,
    Settings? settings,
    Map<String, List<PooperCount>>? badges,
    Map<String, Holiday>? holidays,
    bool weekMode = false,
    double textScale = 1.0,
  }) {
    final v = view ??
        CalendarViewState(
          selectedDate: DateTime(2026, 2, 11),
          visibleMonth: DateTime(2026, 2, 1),
          mode: weekMode ? CalendarMode.week : CalendarMode.month,
        );

    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SingleChildScrollView(
            child: CalendarGrid(
              days: days,
              monthAnchor: monthAnchor,
              view: v,
              settings: settings ?? const Settings(),
              badges: badges ?? const {},
              holidays: holidays ?? const {},
              today: DateTime(2026, 2, 11),
              weekMode: weekMode,
              onSelectDay: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('渲染不溢出不报错', () {
    testWidgets('月视图：35 格（5 行）', (tester) async {
      await tester.pumpWidget(host(
        days: monthGridDays(2026, 2, WeekStart.monday),
        monthAnchor: DateTime(2026, 2, 1),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DayCell), findsNWidgets(35));
      expect(tester.takeException(), isNull);
    });

    testWidgets('月视图：42 格（6 行）—— 8 月这种月份', (tester) async {
      await tester.pumpWidget(host(
        days: monthGridDays(2026, 8, WeekStart.monday),
        monthAnchor: DateTime(2026, 8, 1),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DayCell), findsNWidgets(42),
          reason: '写死 35 格会丢掉最后一整周');
      expect(tester.takeException(), isNull);
    });

    testWidgets('周视图：7 格', (tester) async {
      await tester.pumpWidget(host(
        days: weekDaysOf(DateTime(2026, 2, 11), WeekStart.monday),
        weekMode: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DayCell), findsNWidgets(7));
      expect(tester.takeException(), isNull);
    });

    testWidgets('周日作首列也能渲染', (tester) async {
      await tester.pumpWidget(host(
        days: monthGridDays(2026, 2, WeekStart.sunday),
        monthAnchor: DateTime(2026, 2, 1),
        settings: const Settings(weekStart: WeekStart.sunday),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('徽标密度', () {
    testWidgets('超过 2 个屙屎人时显示 +N', (tester) async {
      final badges = {
        '2026-02-11': [
          PooperCount(pooper: fakePooper('a', '阿狗'), count: 2),
          PooperCount(pooper: fakePooper('b', '咪咪'), count: 1),
          PooperCount(pooper: fakePooper('c', '小土豆'), count: 3),
        ],
      };
      await tester.pumpWidget(host(
        days: monthGridDays(2026, 2, WeekStart.monday),
        monthAnchor: DateTime(2026, 2, 1),
        badges: badges,
      ));
      await tester.pumpAndSettle();

      expect(find.text('+1'), findsOneWidget,
          reason: '3 个人只放得下 2 行，多的用 +1 收尾');
      expect(tester.takeException(), isNull);
    });

    testWidgets('两位数次数不溢出（靠 FittedBox 缩）', (tester) async {
      // ⚠ 次数特意用 >31 的数字，避免和日期数字撞车 ——
      //    用 14 的话 find.text('14') 会同时命中"14 号"那一格。
      final badges = {
        '2026-02-11': [
          PooperCount(pooper: fakePooper('a', '阿狗'), count: 47),
          PooperCount(pooper: fakePooper('b', '咪咪'), count: 88),
        ],
      };
      await tester.pumpWidget(host(
        days: monthGridDays(2026, 2, WeekStart.monday),
        monthAnchor: DateTime(2026, 2, 1),
        badges: badges,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('47'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
    });

    testWidgets('已归档的人显示为降级但仍出现', (tester) async {
      final badges = {
        '2026-02-11': [
          PooperCount(pooper: fakePooper('a', '阿狗', archived: 1), count: 1),
        ],
      };
      await tester.pumpWidget(host(
        days: monthGridDays(2026, 2, WeekStart.monday),
        monthAnchor: DateTime(2026, 2, 1),
        badges: badges,
      ));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('休 / 班角标', () {
    testWidgets('休 和 班 都能画出来', (tester) async {
      final days = monthGridDays(2026, 2, WeekStart.monday);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final kind in HolidayKind.values)
                  DayCell(
                    date: DateTime(2026, 2, 15),
                    inMonth: true,
                    isToday: false,
                    isSelected: false,
                    isWeekend: true,
                    badges: const [],
                    holiday: kind,
                  ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('休'), findsOneWidget);
      expect(find.text('班'), findsOneWidget);
      expect(days.length, 35);
    });

    testWidgets('网格按节假日表画出休 / 班', (tester) async {
      await tester.pumpWidget(host(
        days: monthGridDays(2026, 2, WeekStart.monday),
        monthAnchor: DateTime(2026, 2, 1),
        holidays: {
          // 2026 春节：2/14 是补班（班），2/15–2/23 放假（休）
          '2026-02-14': const Holiday(
              date: '2026-02-14', name: '春节', isOffDay: false),
          '2026-02-15': const Holiday(
              date: '2026-02-15', name: '春节', isOffDay: true),
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('班'), findsOneWidget, reason: 'isOffDay=false 是补班');
      expect(find.text('休'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('关掉角标开关就不画', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DayCell(
            date: DateTime(2026, 2, 15),
            inMonth: true,
            isToday: false,
            isSelected: false,
            isWeekend: true,
            badges: const [],
            holiday: HolidayKind.off,
            showHolidayTags: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('休'), findsNothing);
    });
  });

  group('字号放大不挤爆格子', () {
    for (final scale in [1.0, 1.15, 1.3, 2.0]) {
      testWidgets('系统字号 $scale× 下渲染正常', (tester) async {
        await tester.pumpWidget(host(
          days: monthGridDays(2026, 8, WeekStart.monday), // 6 行，最挤的情况
          monthAnchor: DateTime(2026, 8, 1),
          textScale: scale,
          badges: {
            '2026-08-12': [
              PooperCount(pooper: fakePooper('a', '阿狗'), count: 14),
              PooperCount(pooper: fakePooper('b', '咪咪'), count: 9),
            ],
          },
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: '$scale× 下日历格溢出了');
      });
    }

    testWidgets('日期数字确实被放大（钳制不是没生效）', (tester) async {
      await tester.pumpWidget(host(
        days: monthGridDays(2026, 2, WeekStart.monday),
        monthAnchor: DateTime(2026, 2, 1),
        textScale: 1.25,
      ));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(DayCell).first,
          matching: find.text('26'),
        ),
      );
      expect(text.style!.fontSize, 14.5,
          reason: '基准字号写在 style 里，实际渲染尺寸由 textScaler 乘出来');

      // ⚠ 要从**格子内部**往上读 MediaQuery ——
      //   从 CalendarGrid 往上读到的是测试自己套的那层，
      //   验证不了"网格内部把倍率钳住了"这件事。
      final inner = MediaQuery.textScalerOf(
        tester.element(find.byType(DayCell).first),
      );
      expect(inner.scale(14.5), closeTo(14.5 * 1.25, 0.01));
    });

    testWidgets('系统字号 2.0× 时网格内部只跟到 1.3×', (tester) async {
      await tester.pumpWidget(host(
        days: monthGridDays(2026, 2, WeekStart.monday),
        monthAnchor: DateTime(2026, 2, 1),
        textScale: 2.0,
      ));
      await tester.pumpAndSettle();

      final inner = MediaQuery.textScalerOf(
        tester.element(find.byType(DayCell).first),
      );
      expect(inner.scale(14.5), closeTo(14.5 * kMaxSystemScale, 0.01),
          reason: '2.0× 必须被钳到 1.3×，否则 6 行月份会把记录列表挤没');
    });
  });

  group('布局计算（纯函数）', () {
    test('1.0 到 1.3 倍都不需要撑高格子', () {
      for (final s in [1.0, 1.15, 1.25, 1.3]) {
        expect(cellHeightFor(s), kBaseCellHeight,
            reason: '$s× 时 58px 就够了，不该无谓地撑高');
      }
    });

    test('超过约 1.35 倍才需要撑高', () {
      expect(cellHeightFor(1.5), greaterThan(kBaseCellHeight));
      expect(cellHeightFor(2.0), greaterThan(cellHeightFor(1.5)));
    });

    test('系统倍率被钳到 1.3', () {
      expect(effectiveCalendarScale(2.0, 1.0), kMaxSystemScale);
      expect(effectiveCalendarScale(1.15, 1.0), 1.15,
          reason: '1.15 在钳制线以下，原样保留');
    });

    test('用户手选的字号叠加在系统之上，但总倍率有上限', () {
      // 1.3 × 1.15 = 1.495，**本来就压在 1.5 以内**，所以这里不是被 clamp 到 1.5，
      // 而是算出来就是 1.495。写 closeTo 而不是相等，是因为浮点。
      expect(effectiveCalendarScale(1.3, 1.15), closeTo(1.495, 1e-9));
      expect(effectiveCalendarScale(1.3, 1.15), lessThanOrEqualTo(kMaxTotalScale));
      expect(effectiveCalendarScale(1.0, 1.15), 1.15);
      expect(effectiveCalendarScale(1.0, 0.9), closeTo(0.9, 1e-9));
    });

    test('异常输入被兜住', () {
      expect(effectiveCalendarScale(double.nan, 1.0), 1.0);
      expect(effectiveCalendarScale(0, 1.0), 1.0);
      expect(effectiveCalendarScale(1.0, 0), 1.0);
    });
  });
}
