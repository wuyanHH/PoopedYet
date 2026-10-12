// drift 和 matcher 都导出 isNull / isNotNull，隐藏 drift 的那两个。
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pooped_yet/src/data/database.dart';
import 'package:pooped_yet/src/providers.dart';
import 'package:pooped_yet/src/state/calendar_data.dart';
import 'package:pooped_yet/src/state/calendar_view.dart';
import 'package:pooped_yet/src/state/settings.dart';
import 'package:pooped_yet/src/ui/records/record_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记录详情弹层。
///
/// 重点不是"画出来了没有"，而是**点了之后库里真的变了吗** ——
/// 这个弹层有七八个写入点，每一个都可能接错（比如把 endUnknown 忘了清）。
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late String recordId;
  late String otherId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    final me = await db.into(db.poopers).insertReturning(
          PoopersCompanion.insert(name: '我', isDefault: const Value(true)),
        );
    final other = await db.into(db.poopers).insertReturning(
          PoopersCompanion.insert(name: '阿狗', sortOrder: const Value(1)),
        );
    otherId = other.id;

    final r = await db.into(db.poopRecords).insertReturning(
          PoopRecordsCompanion.insert(
            pooperId: me.id,
            startedAt: DateTime(2026, 10, 12, 9, 12),
            endedAt: Value(DateTime(2026, 10, 12, 9, 26)),
          ),
        );
    recordId = r.id;
  });
  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester) async {
    // ⚠ 默认测试视口是 800×600，而这个弹层内容很高 ——
    //   底部按钮会落在视口外，tap 打不中。用接近真机的尺寸：
    //   1080×2400 @2.625 → 411×914 逻辑像素。
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
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordDetailSheet(recordId: recordId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<PoopRecord> reload() =>
      (db.select(db.poopRecords)..where((t) => t.id.equals(recordId)))
          .getSingle();

  group('内容正确', () {
    testWidgets('显示日期、人与起止时刻', (tester) async {
      await pump(tester);

      expect(find.text('2026年10月12日'), findsOneWidget);
      // 头像用姓名首字兜底，所以「我」会同时出现在头像里和 chip 上
      expect(find.text('我'), findsWidgets);
      expect(find.text('09:12'), findsOneWidget);
      expect(find.text('09:26'), findsOneWidget);
      // 时长是「时间」那一节的附属信息，文案是「时长 14 分钟」
      expect(find.textContaining('14 分钟'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('没有备注时给出提示，不画空列表', (tester) async {
      await pump(tester);
      expect(find.text('还没有备注'), findsOneWidget);
    });
  });

  group('结束一条进行中的记录', () {
    setUp(() async {
      // 把它改成进行中
      await (db.update(db.poopRecords)..where((t) => t.id.equals(recordId)))
          .write(const PoopRecordsCompanion(endedAt: Value(null)));
    });

    testWidgets('「现在结束」写进 ended_at', (tester) async {
      await pump(tester);

      expect(find.text('现在结束'), findsOneWidget);
      await tester.tap(find.text('现在结束'));
      await tester.pumpAndSettle();

      expect((await reload()).endedAt, isNotNull);
    });

    testWidgets('「没记结束时间」写进 end_unknown', (tester) async {
      await pump(tester);

      await tester.tap(find.text('没记结束时间'));
      await tester.pumpAndSettle();

      final r = await reload();
      expect(r.endUnknown, isTrue);
      expect(r.endedAt, isNull, reason: '这个状态的定义就是没有结束时间');
    });
  });

  group('改屙屎人', () {
    testWidgets('点另一个人写进库里', (tester) async {
      await pump(tester);

      await tester.tap(find.text('阿狗'));
      await tester.pumpAndSettle();

      expect((await reload()).pooperId, otherId);
    });

    testWidgets('★ 换到一个正在屙的人会被拒绝，并说人话', (tester) async {
      // 让阿狗先开一条进行中的
      await db.into(db.poopRecords).insert(
            PoopRecordsCompanion.insert(
              pooperId: otherId,
              startedAt: DateTime(2026, 10, 12, 13, 40),
            ),
          );
      // 把本记录也改成进行中，这样换人才会撞唯一索引
      await (db.update(db.poopRecords)..where((t) => t.id.equals(recordId)))
          .write(const PoopRecordsCompanion(endedAt: Value(null)));

      await pump(tester);
      await tester.tap(find.text('阿狗'));
      await tester.pumpAndSettle();

      expect(find.textContaining('已经有一条进行中的记录'), findsOneWidget,
          reason: '不能把 SqliteException 丢给用户看');
      final r = await reload();
      expect(r.pooperId, isNot(otherId), reason: '拒绝了就不能改');
    });
  });

  group('备注增删', () {
    testWidgets('写一条备注并提交，落到库里', (tester) async {
      await pump(tester);

      await tester.enterText(find.byKey(const ValueKey('noteInput')), '昨晚火锅太辣了');
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加这条备注'));
      await tester.pumpAndSettle();

      final notes = await db.select(db.poopNotes).get();
      expect(notes.length, 1);
      expect(notes.single.content, '昨晚火锅太辣了');
      expect(notes.single.recordId, recordId);
    });

    testWidgets('手打的备注会沉淀成模板（下次不用再打）', (tester) async {
      final before = (await db.select(db.noteTemplates).get()).length;

      await pump(tester);
      await tester.enterText(find.byKey(const ValueKey('noteInput')), '新说法');
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加这条备注'));
      await tester.pumpAndSettle();

      final after = await db.select(db.noteTemplates).get();
      expect(after.length, before + 1);
      expect(after.map((t) => t.content), contains('新说法'));
    });

    testWidgets('点快捷备注会追加进输入框，不是各自生成一条', (tester) async {
      await pump(tester);

      // 模板里自带「拉肚子」「很顺畅」
      await tester.tap(find.byKey(const ValueKey('noteChip:拉肚子')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('noteChip:很顺畅')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byKey(const ValueKey('noteInput')));
      expect(field.controller!.text, '拉肚子、很顺畅');

      // 还没提交，库里应该一条都没有
      expect(await db.select(db.poopNotes).get(), isEmpty);
    });

    testWidgets('同一条快捷备注点两次不会重复追加', (tester) async {
      await pump(tester);
      final chip = find.byKey(const ValueKey('noteChip:拉肚子'));
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byKey(const ValueKey('noteInput')));
      expect(field.controller!.text, '拉肚子');
    });

    testWidgets('删备注', (tester) async {
      await db.into(db.poopNotes).insert(
            PoopNotesCompanion.insert(
              recordId: recordId,
              content: '要被删掉的',
              notedAt: DateTime(2026, 10, 12, 9, 14),
            ),
          );
      await pump(tester);

      expect(find.text('要被删掉的'), findsOneWidget);
      // 备注行右侧的删除图标
      // 备注行的删除图标（Lucide，不是 Material 的）
      await tester.tap(find.byIcon(LucideIcons.trash2).first);
      await tester.pumpAndSettle();

      expect(await db.select(db.poopNotes).get(), isEmpty);
    });
  });

  group('删除记录', () {
    testWidgets('要确认，确认后连备注一起删掉', (tester) async {
      await db.into(db.poopNotes).insert(
            PoopNotesCompanion.insert(
              recordId: recordId,
              content: 'x',
              notedAt: DateTime(2026, 10, 12, 9, 14),
            ),
          );
      await pump(tester);

      await tester.ensureVisible(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('删除这条记录？'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();

      expect(await db.select(db.poopRecords).get(), isEmpty);
      expect(await db.select(db.poopNotes).get(), isEmpty, reason: '备注要级联删掉');
    });

    testWidgets('取消就什么都不做', (tester) async {
      await pump(tester);

      await tester.ensureVisible(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();

      expect(await db.select(db.poopRecords).get(), hasLength(1));
    });
  });

  group('记录已经不在了', () {
    testWidgets('不白屏、不报错', (tester) async {
      recordId = 'this-id-does-not-exist';
      await pump(tester);

      expect(find.text('这条记录已经不在了'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
