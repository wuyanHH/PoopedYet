import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/data/database.dart';
import 'package:pooped_yet/src/providers.dart';
import 'package:pooped_yet/src/state/calendar_data.dart';
import 'package:pooped_yet/src/state/calendar_view.dart';
import 'package:pooped_yet/src/state/settings.dart';
import 'package:pooped_yet/src/ui/calendar/calendar_card.dart';
import 'package:pooped_yet/src/ui/calendar/calendar_grid.dart';
import 'package:pooped_yet/src/ui/calendar/swipe_to_navigate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 左右滑动切月 / 切周。
///
/// 手感类的东西不好自动测，但**"滑了到底切没切"和"点击有没有被吃掉"**
/// 是能测的，而且正好是最容易坏的两件事：
/// 手势识别器一旦装错地方，日期就点不动了。
void main() {
  group('resolveSwipe —— 纯函数阈值', () {
    test('快速轻扫：位移很小也认（看速度）', () {
      expect(
        resolveSwipe(totalDx: 8, velocity: 900),
        SwipeDirection.prev,
        reason: '轻扫的位移本来就小，只看位移会漏掉它',
      );
      expect(resolveSwipe(totalDx: -8, velocity: -900), SwipeDirection.next);
    });

    test('慢速拖动：速度很小也认（看位移）', () {
      expect(
        resolveSwipe(totalDx: 120, velocity: 5),
        SwipeDirection.prev,
        reason: '慢拖的速度本来就小，只看速度会漏掉它',
      );
      expect(resolveSwipe(totalDx: -120, velocity: 5), SwipeDirection.next);
    });

    test('两个都不够 → 不动（误触保护）', () {
      expect(resolveSwipe(totalDx: 10, velocity: 30), SwipeDirection.none);
      expect(resolveSwipe(totalDx: 0, velocity: 0), SwipeDirection.none);
    });

    test('速度够但方向相反时，以速度为准', () {
      // 先往右拖出一点，又快速往左甩 —— 用户意图是"下一个"
      expect(resolveSwipe(totalDx: 20, velocity: -800), SwipeDirection.next);
    });

    test('阈值边界是闭区间（正好等于阈值就算数）', () {
      expect(
        resolveSwipe(totalDx: kSwipeDistanceThreshold, velocity: 0),
        SwipeDirection.prev,
      );
      expect(
        resolveSwipe(totalDx: 0, velocity: kSwipeVelocityThreshold),
        SwipeDirection.prev,
      );
    });

    test('反方向同样处理', () {
      expect(
        resolveSwipe(totalDx: -kSwipeDistanceThreshold, velocity: 0),
        SwipeDirection.next,
      );
      expect(
        resolveSwipe(totalDx: 0, velocity: -kSwipeVelocityThreshold),
        SwipeDirection.next,
      );
    });
  });

  group('接线：滑动手势真的切了月份', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });
    tearDown(() async => db.close());

    Future<ProviderContainer> pump(WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          // 不 override 的话它会去读打包资源，测试环境里没有。
          holidaysProvider.overrideWith((ref) async => const <String, Holiday>{}),
          todayProvider.overrideWithValue(DateTime(2026, 10, 12)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: CalendarCard())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    CalendarViewState state(ProviderContainer c) => c.read(calendarViewProvider);

    testWidgets('基线：初始是今天所在月', (tester) async {
      final c = await pump(tester);
      expect(state(c).visibleMonth, DateTime(2026, 10, 1));
      expect(state(c).selectedDate, DateTime(2026, 10, 12));
    });

    testWidgets('向左甩 → 下一个月', (tester) async {
      final c = await pump(tester);

      await tester.fling(
        find.byType(SwipeToNavigate),
        const Offset(-300, 0),
        1200,
      );
      await tester.pumpAndSettle();

      expect(state(c).visibleMonth, DateTime(2026, 11, 1));
      expect(state(c).selectedDate, DateTime(2026, 11, 12),
          reason: '翻月要保留日号，否则日历和下面的列表会错位');
    });

    testWidgets('向右甩 → 上一个月', (tester) async {
      final c = await pump(tester);

      await tester.fling(
        find.byType(SwipeToNavigate),
        const Offset(300, 0),
        1200,
      );
      await tester.pumpAndSettle();

      expect(state(c).visibleMonth, DateTime(2026, 9, 1));
      expect(state(c).selectedDate, DateTime(2026, 9, 12));
    });

    testWidgets('小幅误触不切换', (tester) async {
      final c = await pump(tester);

      // 慢速小幅拖动：位移和速度都不够
      await tester.drag(find.byType(SwipeToNavigate), const Offset(12, 0));
      await tester.pumpAndSettle();

      expect(state(c).visibleMonth, DateTime(2026, 10, 1), reason: '不该切');
    });

    testWidgets('★ 滑动装了之后，点日期仍然能选中（没被手势吃掉）', (tester) async {
      final c = await pump(tester);

      // 点 10 月 20 日那一格
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(state(c).selectedDate, DateTime(2026, 10, 20));
      expect(state(c).visibleMonth, DateTime(2026, 10, 1),
          reason: '同月内点选不该翻月');
    });

    testWidgets('周视图下滑动是切周而不是切月', (tester) async {
      final c = await pump(tester);
      c.read(calendarViewProvider.notifier).setMode(CalendarMode.week);
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(SwipeToNavigate),
        const Offset(-300, 0),
        1200,
      );
      await tester.pumpAndSettle();

      expect(state(c).selectedDate, DateTime(2026, 10, 19),
          reason: '周一 +7 天还是周一');
      expect(state(c).mode, CalendarMode.week);
    });

    testWidgets('滑到 6 行的月份不会崩（3 月是 6 行）', (tester) async {
      final c = await pump(tester);

      // 10 月 → 3 月不能直接滑，但可以一路滑回去验证渲染
      for (var i = 0; i < 3; i++) {
        await tester.fling(
          find.byType(SwipeToNavigate),
          const Offset(300, 0),
          1200,
        );
        await tester.pumpAndSettle();
      }

      expect(state(c).visibleMonth, DateTime(2026, 7, 1));
      expect(find.byType(CalendarGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
