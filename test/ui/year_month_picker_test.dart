import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pooped_yet/src/calendar/calendar_math.dart';
import 'package:pooped_yet/src/state/calendar_data.dart';
import 'package:pooped_yet/src/state/settings.dart';
import 'package:pooped_yet/src/ui/calendar/year_month_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 年月 / 周选择器的**接线**测试。
///
/// 状态转换本身在 `test/state/calendar_view_test.dart` 里已经逐条钉死了；
/// 这里盯的是另一件事：**点标题能不能弹出选择器、选完能不能把结果用上**。
///
/// 为什么要有这一层：这两处接线原本只在模拟器上靠手点验证过 ——
/// 手点不可复现，改一行 UI 就可能悄悄断掉，而 CI 不会响。
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    // ⚠ 周选择器要读「每周起始日」，也就是要 `sharedPrefsProvider`。
    //   不 mock 的话它会抛 UnimplementedError —— 而**年月选择器不需要**，
    //   所以第一版只有周选择器的两条测试挂了。这个依赖是靠测试才发现的。
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// 把选择器挂在一个按钮后面，和真实用法一致（`showModalBottomSheet` + 取返回值）。
  ///
  /// [result] 用来接弹层的返回值 —— 结果只能从调用点拿，
  /// 而调用点在 widget 树里，所以用 ValueNotifier 传进去而不是搞全局变量。
  Widget host({
    required ValueNotifier<Object?> result,
    required Future<DateTime?> Function(BuildContext) openMonth,
    required Future<WeekRange?> Function(BuildContext) openWeek,
    Set<int> monthsWithRecords = const {1, 3, 7},
    bool useMonth = true,
  }) {
    return ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        // 选择器上的"有记录"小点靠这个；不 override 它会去连真数据库。
        monthsWithRecordsProvider(2026)
            .overrideWith((ref) async => monthsWithRecords),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Column(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    result.value = useMonth
                        ? await openMonth(ctx)
                        : await openWeek(ctx);
                  },
                  child: const Text('open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  late ValueNotifier<Object?> result;
  setUp(() => result = ValueNotifier<Object?>(null));
  tearDown(() => result.dispose());

  group('年月选择器', () {
    testWidgets('点开后能选到一个月份，返回值是那个月的 1 号', (tester) async {
      await tester.pumpWidget(host(
        result: result,
        openMonth: (ctx) =>
            showYearMonthPickerSheet(ctx, current: DateTime(2026, 10, 12)),
        openWeek: (_) async => null,
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('跳到哪个月'), findsOneWidget);
      expect(find.text('3月'), findsOneWidget);

      await tester.tap(find.text('3月'));
      await tester.pumpAndSettle();

      expect(result.value, DateTime(2026, 3, 1),
          reason: '返回目标月的 1 号，调用方再交给 goToMonth');
      expect(find.text('跳到哪个月'), findsNothing, reason: '选完弹层要收起来');
    });

    testWidgets('「回到今天」返回今天的月份', (tester) async {
      await tester.pumpWidget(host(
        result: result,
        // 故意给一个和今天不同的月份，确保返回的是"今天"而不是 current
        openMonth: (ctx) =>
            showYearMonthPickerSheet(ctx, current: DateTime(2020, 1, 1)),
        openWeek: (_) async => null,
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final todayBtn = find.textContaining('回到今天');
      expect(todayBtn, findsOneWidget);

      await tester.tap(todayBtn);
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(result.value, DateTime(now.year, now.month, 1));
    });

    testWidgets('关闭返回 null —— 调用方据此不动状态', (tester) async {
      await tester.pumpWidget(host(
        result: result,
        openMonth: (ctx) =>
            showYearMonthPickerSheet(ctx, current: DateTime(2026, 10, 12)),
        openWeek: (_) async => null,
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(result.value, isNull);
    });

    testWidgets('12 个月都在，不因数据为空而少画', (tester) async {
      await tester.pumpWidget(host(
        result: result,
        openMonth: (ctx) =>
            showYearMonthPickerSheet(ctx, current: DateTime(2026, 10, 12)),
        openWeek: (_) async => null,
        monthsWithRecords: const {},
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (var m = 1; m <= 12; m++) {
        expect(find.text('$m月'), findsOneWidget, reason: '$m月 没画出来');
      }
    });
  });

  group('周选择器', () {
    testWidgets('点开后能选到一周，返回值带正确的区间', (tester) async {
      await tester.pumpWidget(host(
        result: result,
        useMonth: false,
        openMonth: (_) async => null,
        openWeek: (ctx) =>
            showWeekPickerSheet(ctx, current: DateTime(2026, 2, 11)),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('跳到哪一周'), findsOneWidget);
      // 2026年2月按网格行切是 5 周（首行跨到 1 月）
      expect(find.text('第 1 周'), findsOneWidget);
      expect(find.text('第 5 周'), findsOneWidget);
      expect(find.text('第 6 周'), findsNothing);

      await tester.tap(find.text('第 2 周'));
      await tester.pumpAndSettle();

      final w = result.value;
      expect(w, isA<WeekRange>());
      expect((w! as WeekRange).first, DateTime(2026, 2, 2));
      expect((w as WeekRange).last, DateTime(2026, 2, 8));
    });

    testWidgets('跨月的那一周被标记出来', (tester) async {
      await tester.pumpWidget(host(
        result: result,
        useMonth: false,
        openMonth: (_) async => null,
        openWeek: (ctx) =>
            showWeekPickerSheet(ctx, current: DateTime(2026, 2, 11)),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 2026-02 的网格首行 1/26–2/1、末行 2/23–3/1 都跨月
      expect(find.text('1/26 – 2/1'), findsOneWidget);
      expect(find.text('2/23 – 3/1'), findsOneWidget);
      expect(find.byIcon(LucideIcons.calendarRange), findsNWidgets(2),
          reason: '两个跨月周各带一个图标');
    });
  });
}
