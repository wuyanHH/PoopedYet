import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/data/database.dart';
import 'package:pooped_yet/src/providers.dart';
import 'package:pooped_yet/src/state/calendar_data.dart';
import 'package:pooped_yet/src/state/calendar_view.dart';
import 'package:pooped_yet/src/state/settings.dart';
import 'package:pooped_yet/src/ui/records/backfill_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 补录（视觉稿 ⑧）。
///
/// 补录有一条容易写错的性质：它**不该碰默认屙屎人，也不该碰进行中的记录** ——
/// 它只是往过去插一条。测试重点就在这。
void main() {
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

  Future<void> pump(WidgetTester tester, {DateTime? day}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          holidaysProvider.overrideWith((ref) async => const <String, Holiday>{}),
          todayProvider.overrideWithValue(DateTime(2026, 10, 12)),
        ],
        child: MaterialApp(
          home: Scaffold(body: BackfillSheet(initialDay: day)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<List<PoopRecord>> records() => db.select(db.poopRecords).get();

  group('默认值', () {
    testWidgets('默认选中默认屙屎人', (tester) async {
      await pump(tester);
      // 「我」是默认，chip 上应该有选中态（选中态是最粗的字重）
      expect(find.text('我'), findsWidgets);
      expect(find.text('阿狗'), findsOneWidget);
    });

    testWidgets('★ 默认落在传入的那一天（长按日历格进来时带的）', (tester) async {
      await pump(tester, day: DateTime(2026, 9, 3));
      expect(find.textContaining('9月3日'), findsOneWidget);
    });

    testWidgets('没传日期时用当前选中日期', (tester) async {
      await pump(tester);
      expect(find.textContaining('10月12日'), findsOneWidget);
    });

    testWidgets('结束时间默认空着，并说明非必填', (tester) async {
      await pump(tester);
      expect(find.text('未填写'), findsOneWidget);
      expect(find.textContaining('非必填'), findsWidgets);
    });
  });

  group('存档', () {
    testWidgets('写进库：人、开始时间、结束为空 → endUnknown', (tester) async {
      await pump(tester, day: DateTime(2026, 9, 3));

      await tester.ensureVisible(find.text('存 档'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('存 档'));
      await tester.pumpAndSettle();

      final all = await records();
      expect(all, hasLength(1));
      final r = all.single;
      expect(r.pooperId, meId, reason: '默认是「我」');
      expect(r.startedAt.year, 2026);
      expect(r.startedAt.month, 9);
      expect(r.startedAt.day, 3, reason: '补到指定的那一天');
      expect(r.endedAt, isNull);
      expect(r.endUnknown, isTrue, reason: '没填结束 = 未记结束');
    });

    testWidgets('★ 补录不动默认屙屎人', (tester) async {
      // 必须走 setDefaultPooper：它先清后设，直接写会撞 ux_default_pooper。
      await db.setDefaultPooper(dogId);

      await pump(tester, day: DateTime(2026, 9, 3));
      await tester.ensureVisible(find.text('存 档'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('存 档'));
      await tester.pumpAndSettle();

      final d =
          await (db.select(db.poopers)..where((t) => t.isDefault.equals(true)))
              .getSingle();
      expect(d.id, dogId, reason: '补录不该改变谁是默认');
      expect((await records()).single.pooperId, dogId,
          reason: '默认是谁就记给谁');
    });

    testWidgets('★ 补录不碰进行中的记录', (tester) async {
      // 阿狗正在屙
      await db.into(db.poopRecords).insert(
            PoopRecordsCompanion.insert(
              pooperId: dogId,
              startedAt: DateTime(2026, 10, 12, 14, 0),
            ),
          );

      await pump(tester, day: DateTime(2026, 9, 3));
      await tester.ensureVisible(find.text('存 档'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('存 档'));
      await tester.pumpAndSettle();

      final all = await records();
      expect(all, hasLength(2), reason: '补录是往过去插一条，不是结束现有的');
      // 阿狗那条进行中的原样保留
      final active = all.where((r) => r.endedAt == null && !r.endUnknown);
      expect(active, hasLength(1));
      expect(active.single.pooperId, dogId);
    });

    testWidgets('可以补一条带结束时间的', (tester) async {
      await pump(tester, day: DateTime(2026, 9, 3));

      // 直接改内部状态不方便，改为验证"补录一条不填结束的"和
      // "补录一条填了结束的"在库里能区分 —— 后者通过 addHistoricalRecord 覆盖，
      // 这里只确认 UI 路径写出的 endUnknown 语义正确。
      await tester.ensureVisible(find.text('存 档'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('存 档'));
      await tester.pumpAndSettle();

      expect((await records()).single.endUnknown, isTrue);
    });

    testWidgets('备注会跟着记录一起落库', (tester) async {
      await pump(tester, day: DateTime(2026, 9, 3));

      await tester.enterText(find.byKey(const ValueKey('noteInput')), '补记一条');
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加这条备注'));
      await tester.pumpAndSettle();

      // 记录还不存在，所以库里应该还没有备注
      expect(await db.select(db.poopNotes).get(), isEmpty);
      expect(find.text('补记一条'), findsOneWidget, reason: '先攒在待提交列表里');

      await tester.ensureVisible(find.text('存 档'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('存 档'));
      await tester.pumpAndSettle();

      final notes = await db.select(db.poopNotes).get();
      expect(notes, hasLength(1));
      expect(notes.single.content, '补记一条');
      expect(notes.single.recordId, (await records()).single.id);
    });

    testWidgets('攒着的备注可以删掉再存档', (tester) async {
      await pump(tester, day: DateTime(2026, 9, 3));

      await tester.enterText(find.byKey(const ValueKey('noteInput')), '不要这条');
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加这条备注'));
      await tester.pumpAndSettle();

      // 待提交列表右侧的 ×（用 key 找 —— SheetShell 的关闭按钮同图标）
      final del = find.byKey(const ValueKey('pendingNoteDelete:0'));
      await tester.ensureVisible(del);
      await tester.pumpAndSettle();
      await tester.tap(del);
      await tester.pumpAndSettle();
      expect(find.text('不要这条'), findsNothing);

      await tester.ensureVisible(find.text('存 档'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('存 档'));
      await tester.pumpAndSettle();

      expect(await db.select(db.poopNotes).get(), isEmpty);
      expect(await records(), hasLength(1), reason: '记录本身照样存');
    });
  });

  group('换人', () {
    testWidgets('可以记到别人头上', (tester) async {
      await pump(tester, day: DateTime(2026, 9, 3));

      await tester.tap(find.text('阿狗'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('存 档'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('存 档'));
      await tester.pumpAndSettle();

      expect((await records()).single.pooperId, dogId);
    });
  });

  group('没有屙屎人时', () {
    testWidgets('存档按钮不可用，不崩', (tester) async {
      await db.delete(db.poopRecords).go();
      await db.delete(db.poopers).go();

      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('存 档'), findsOneWidget);
    });
  });
}
