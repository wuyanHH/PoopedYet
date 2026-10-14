import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/data/database.dart';
import 'package:pooped_yet/src/data/queries.dart';
import 'package:pooped_yet/src/domain/history_filter.dart';
import 'package:pooped_yet/src/providers.dart';
import 'package:pooped_yet/src/state/calendar_data.dart';
import 'package:pooped_yet/src/state/history.dart';
import 'package:pooped_yet/src/state/settings.dart';
import 'package:pooped_yet/src/ui/history/history_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 历史页与筛选（视觉稿 ⑥⑦）。
///
/// 分组逻辑（[groupByDay]）单独测，因为它是个纯函数，
/// 而"日期分组错位"在界面上看着就是"莫名其妙多了一个日期标题"。
/// 顶部筛选 chip 的 key。
///
/// 抽成函数是因为屙屎人名字在**记录卡上也会出现** ——
/// 单靠 `find.text('阿狗')` 会同时命中 chip 和卡片，finder 歧义。
ValueKey<String> _chipKey(String pooperId) => ValueKey('historyChip:$pooperId');

void main() {
  group('groupByDay', () {
    RecordDetail d(DateTime at, {String name = '我'}) => RecordDetail(
          record: PoopRecord(
            id: 'r${at.millisecondsSinceEpoch}',
            pooperId: 'p',
            startedAt: at,
            endedAt: at.add(const Duration(minutes: 10)),
            endUnknown: false,
            createdAt: at,
          ),
          pooper: Pooper(
            id: 'p',
            name: name,
            iconKey: null,
            avatarBlob: null,
            remark: null,
            isDefault: true,
            archivedAt: null,
            sortOrder: 0,
            createdAt: DateTime(2026),
          ),
          notes: const [],
        );

    test('同一天归一组，不同天分开', () {
      final groups = groupByDay([
        d(DateTime(2026, 10, 12, 21)),
        d(DateTime(2026, 10, 12, 9)),
        d(DateTime(2026, 10, 11, 20)),
      ]);
      expect(groups, hasLength(2));
      expect(groups[0].$2, hasLength(2));
      expect(groups[1].$2, hasLength(1));
    });

    test('保持传入顺序（不自己排序）', () {
      // 调用方已经按时间倒序给了，这里不该重排
      final groups = groupByDay([
        d(DateTime(2026, 10, 12, 21)),
        d(DateTime(2026, 10, 12, 9)),
      ]);
      expect(groups.single.$2.first.record.startedAt.hour, 21);
    });

    test('空输入返回空', () {
      expect(groupByDay(const []), isEmpty);
    });

    test('跨月跨年各成一组', () {
      final groups = groupByDay([
        d(DateTime(2027, 1, 1, 9)),
        d(DateTime(2026, 12, 31, 23)),
      ]);
      expect(groups, hasLength(2));
    });
  });

  group('dayLabelCn', () {
    test('中文日期 + 星期', () {
      // 2026-10-12 是周一
      expect(dayLabelCn(DateTime(2026, 10, 12)), '10月12日 周一');
      expect(dayLabelCn(DateTime(2026, 10, 18)), '10月18日 周日');
    });
  });

  group('历史页', () {
    late AppDatabase db;
    late SharedPreferences prefs;
    late String meId;
    late String dogId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      final me = await db.into(db.poopers).insertReturning(
            PoopersCompanion.insert(name: '我', isDefault: const Value(true)),
          );
      final dog = await db.into(db.poopers).insertReturning(
            PoopersCompanion.insert(name: '阿狗', sortOrder: const Value(1)),
          );
      meId = me.id;
      dogId = dog.id;
    });
    tearDown(() async => db.close());

    Future<void> rec(String pid, DateTime start, {String? note}) async {
      final r = await db.into(db.poopRecords).insertReturning(
            PoopRecordsCompanion.insert(
              pooperId: pid,
              startedAt: start,
              endedAt: Value(start.add(const Duration(minutes: 10))),
            ),
          );
      if (note != null) {
        await db.into(db.poopNotes).insert(
              PoopNotesCompanion.insert(
                recordId: r.id,
                content: note,
                notedAt: start.add(const Duration(minutes: 2)),
              ),
            );
      }
    }

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            holidaysProvider
                .overrideWith((ref) async => const <String, Holiday>{}),
          ],
          child: const MaterialApp(home: HistoryPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('空状态', (tester) async {
      await pump(tester);
      expect(find.text('还没有任何记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('按日期分组显示，日期倒序', (tester) async {
      await rec(meId, DateTime(2026, 10, 12, 21));
      await rec(meId, DateTime(2026, 10, 12, 9));
      await rec(meId, DateTime(2026, 10, 11, 20));
      await pump(tester);

      expect(find.text('10月12日 周一'), findsOneWidget);
      expect(find.text('10月11日 周日'), findsOneWidget);
      expect(find.text('2 次'), findsOneWidget, reason: '12 号有两条');
      expect(find.text('1 次'), findsOneWidget);
      expect(find.text('共 3 条'), findsOneWidget);
    });

    testWidgets('顶部按人筛选：点「阿狗」只剩他的', (tester) async {
      await rec(meId, DateTime(2026, 10, 12, 9));
      await rec(dogId, DateTime(2026, 10, 11, 9));
      await pump(tester);

      expect(find.text('共 2 条'), findsOneWidget);

      await tester.tap(find.byKey(_chipKey(dogId)));
      await tester.pumpAndSettle();

      expect(find.text('共 1 条'), findsOneWidget);
    });

    testWidgets('「全部」清掉人员筛选', (tester) async {
      await rec(meId, DateTime(2026, 10, 12, 9));
      await rec(dogId, DateTime(2026, 10, 11, 9));
      await pump(tester);

      await tester.tap(find.byKey(_chipKey(dogId)));
      await tester.pumpAndSettle();
      expect(find.text('共 1 条'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('historyChip:all')));
      await tester.pumpAndSettle();
      expect(find.text('共 2 条'), findsOneWidget);
    });

    testWidgets('筛选后出现条件摘要和「清空」', (tester) async {
      await rec(meId, DateTime(2026, 10, 12, 9), note: '火锅');
      await pump(tester);

      expect(find.text('清空'), findsNothing);

      // 用**关键词**触发摘要，而不是按人 ——
      // 只选一个人时摘要是不显示的：顶部那条 chips 已经把"选了谁"
      // 摆在明面上了，摘要只负责显示 chips 上看不到的条件（关键词、日期范围）。
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HistoryPage)),
      );
      container.read(historyFilterProvider.notifier).setKeyword('火锅');
      await tester.pumpAndSettle();

      expect(find.text('清空'), findsOneWidget);
      expect(find.textContaining('火锅'), findsWidgets,
          reason: '摘要要显示当前生效的关键词');
    });

    testWidgets('摘要里的「清空」清掉全部条件', (tester) async {
      await rec(meId, DateTime(2026, 10, 12, 9), note: '火锅');
      await rec(dogId, DateTime(2026, 10, 11, 9), note: '正常');
      await pump(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HistoryPage)),
      );
      container.read(historyFilterProvider.notifier).setKeyword('火锅');
      await tester.pumpAndSettle();
      expect(find.text('共 1 条'), findsOneWidget);

      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();

      expect(find.text('共 2 条'), findsOneWidget);
      expect(find.text('清空'), findsNothing);
    });

    testWidgets('备注会显示在卡片上', (tester) async {
      await rec(meId, DateTime(2026, 10, 12, 9), note: '昨晚吃火锅了');
      await pump(tester);
      expect(find.text('昨晚吃火锅了'), findsOneWidget);
    });

    testWidgets('筛不到结果时给出清空入口', (tester) async {
      await rec(meId, DateTime(2026, 10, 12, 9));
      await pump(tester);

      await tester.tap(find.byKey(_chipKey(dogId)));
      await tester.pumpAndSettle();

      // 阿狗没有记录 -> 空状态（注意共享的筛选状态）
      expect(find.text('没有符合条件的记录'), findsOneWidget);
      expect(find.text('清空筛选条件'), findsOneWidget);
    });
  });

  group('HistoryFilterNotifier', () {
    ProviderContainer make() {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('初始为空条件', () {
      expect(make().read(historyFilterProvider).isEmpty, isTrue);
    });

    test('togglePooper 来回切', () {
      final c = make();
      final n = c.read(historyFilterProvider.notifier);
      n.togglePooper('x');
      expect(c.read(historyFilterProvider).pooperIds, {'x'});
      n.togglePooper('x');
      expect(c.read(historyFilterProvider).pooperIds, isEmpty);
    });

    test('setPoopers 直接替换（「全部」用）', () {
      final c = make();
      final n = c.read(historyFilterProvider.notifier);
      n.togglePooper('x');
      n.togglePooper('y');
      expect(c.read(historyFilterProvider).pooperIds, {'x', 'y'});
      n.setPoopers({});
      expect(c.read(historyFilterProvider).pooperIds, isEmpty);
    });

    test('apply 会归一化（反过来填的区间被交换）', () {
      final c = make();
      c.read(historyFilterProvider.notifier).apply(
            HistoryFilter(
              from: DateTime(2026, 10, 20),
              to: DateTime(2026, 10, 5),
            ),
          );
      final f = c.read(historyFilterProvider);
      expect(f.from, DateTime(2026, 10, 5));
      expect(f.to, DateTime(2026, 10, 20));
    });

    test('clear 清空一切', () {
      final c = make();
      final n = c.read(historyFilterProvider.notifier);
      n.setKeyword('x');
      n.togglePooper('a');
      n.setFrom(DateTime(2026));
      n.clear();
      expect(c.read(historyFilterProvider).isEmpty, isTrue);
    });

    test('setFrom(null) 是清空而不是设成 null 日期', () {
      final c = make();
      final n = c.read(historyFilterProvider.notifier);
      n.setFrom(DateTime(2026, 1, 1));
      expect(c.read(historyFilterProvider).from, isNotNull);
      n.setFrom(null);
      expect(c.read(historyFilterProvider).from, isNull);
    });
  });
}
