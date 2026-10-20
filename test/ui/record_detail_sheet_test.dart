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

    testWidgets('没有备注时只给空态提示，不画空列表', (tester) async {
      await pump(tester);

      // 现在的空态是标题右侧那句「可选填」，而不是一段"还没有备注"的占位列表。
      expect(find.text('详细文字备注'), findsOneWidget);
      expect(find.text('可选填'), findsOneWidget);

      // 一条备注都没有时，页面上唯一那个垃圾桶图标应该属于底部「删除」按钮；
      // 备注行各自也带一个，所以一旦画出空行，这里就会变成两个。
      expect(
        find.byIcon(LucideIcons.trash2),
        findsOneWidget,
        reason: '没有备注就不该渲染任何备注行',
      );
    });
  });

  // ⚠ 这里曾经有两条对准「现在结束 / 没记结束时间」两个小按钮的用例。
  //   那两个按钮在 v0.2.4 重构记录详情时被移除，用例却一直留着 ——
  //   于是它们长期失败，也让"测试全绿"失去可信度。现在改成对准**当前**行为：
  //   底部主按钮在记录进行中时是「完成打卡」，且它必须真的写库，
  //   而不是像曾经那样只关掉弹层（那正是用户报的"点了完成不生效"）。
  group('结束记录', () {
    setUp(() async {
      // 把它改成进行中
      await (db.update(db.poopRecords)..where((t) => t.id.equals(recordId)))
          .write(const PoopRecordsCompanion(endedAt: Value(null)));
    });

    testWidgets('进行中：主按钮是「完成打卡」，点了真的写进 ended_at', (tester) async {
      await pump(tester);

      // 进行中的记录，底部主按钮必须是"真的结束"，不能只是关掉弹层 ——
      // 「点了完成不生效」就是这么来的。
      // 起始时间固定在 2026-10-12，跑测试时早已超过 2 小时阈值，
      // 所以状态多半是 pending（挂了很久、待确认）；active 也一样算进行中。
      expect(find.text('完成打卡'), findsOneWidget);
      await tester.ensureVisible(find.text('完成打卡'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成打卡'));
      await tester.pumpAndSettle();

      final r = await reload();
      expect(r.endedAt, isNotNull, reason: '点「完成打卡」必须真的结束这条记录');
      expect(r.endUnknown, isFalse, reason: '不变式：有结束时间就必然不是「未记结束」');
    });

    testWidgets('已结束：底部换成「关闭」，点了只关弹层、不覆盖原结束时间', (tester) async {
      final fixedEnd = DateTime(2026, 10, 12, 9, 26);
      await (db.update(db.poopRecords)..where((t) => t.id.equals(recordId)))
          .write(PoopRecordsCompanion(endedAt: Value(fixedEnd)));
      await pump(tester);

      // 已完成时那颗按钮不再叫「完成」—— 它什么都不做，只是关掉弹层，
      // 顶着个焦糖色主按钮写「完成」会让用户以为能再结束一次。
      expect(find.text('关闭'), findsOneWidget);
      expect(find.text('完成打卡'), findsNothing);

      await tester.ensureVisible(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      expect(
        (await reload()).endedAt,
        fixedEnd,
        reason: '已结束的记录，点「关闭」只是关弹层，不该把结束时间改成"现在"',
      );
    });

    testWidgets('「未记结束」不提供「完成打卡」——补个"现在结束"会把时长算歪', (tester) async {
      // 「未记结束」同样没有 endedAt，但它不是进行中：
      // 给一条 2026-10-12 的记录补一个"现在结束"，时长会从"不详"变成"整整一周"。
      await (db.update(db.poopRecords)..where((t) => t.id.equals(recordId)))
          .write(const PoopRecordsCompanion(
        endedAt: Value(null),
        endUnknown: Value(true),
      ));
      await pump(tester);

      expect(find.text('完成打卡'), findsNothing);
      expect(find.text('关闭'), findsOneWidget);
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

      // 提交按钮的文案是「添加备注」（不是旧版的「添加这条备注」）。
      await tester.ensureVisible(find.text('添加备注'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加备注'));
      await tester.pumpAndSettle();

      final notes = await db.select(db.poopNotes).get();
      expect(notes.length, 1);
      expect(notes.single.content, '昨晚火锅太辣了');
      expect(notes.single.recordId, recordId);
    });

    testWidgets('点过的快捷标签使用次数 +1', (tester) async {
      // ⚠ 这条用例原本叫「手打的备注会沉淀成模板」，但那个说法在当前实现里
      //   并不成立：详情页手打备注只 `addNote`、没有 `bumpNoteTemplate`
      //   （补录页调了，新建页也没调）。三处口径不一致，属于待确认的产品决策，
      //   所以这里只把**确定成立**的那半条钉住：点标签会给它记一次使用次数。
      //
      //   注意 useCount 目前是"只写不读"：noteTemplatesProvider 只按
      //   sortOrder / createdAt 排序，并没有拿 useCount 做"常用往前提"。
      NoteTemplate templateOf(List<NoteTemplate> all, String content) =>
          all.firstWhere((t) => t.content == content);

      final before = templateOf(await db.select(db.noteTemplates).get(), '很顺畅');

      await pump(tester);
      final chip = find.byKey(const ValueKey('noteChip:很顺畅'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      final after = templateOf(await db.select(db.noteTemplates).get(), '很顺畅');
      expect(after.useCount, before.useCount + 1);
      expect(after.id, before.id, reason: '已有模板只加次数，不该复制出一条新的');
    });

    testWidgets('点快捷标签直接给记录打上主题，不再往输入框里塞顿号串', (tester) async {
      await pump(tester);

      // 与旧版最大的区别：点标签 = 立刻给这条记录挂上该主题并落库，
      // 输入框只负责自定义长文字，两者互不干扰。
      final chip = find.byKey(const ValueKey('noteChip:拉肚子'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(
        (await db.select(db.poopNotes).get()).map((n) => n.content),
        contains('拉肚子'),
        reason: '点标签应当直接写库',
      );

      final field =
          tester.widget<TextField>(find.byKey(const ValueKey('noteInput')));
      expect(field.controller!.text, isEmpty, reason: '标签不该再往输入框里塞文字');
    });

    testWidgets('同一条快捷标签点两次 = 选中再卸下，库里不留痕', (tester) async {
      await pump(tester);
      final chip = find.byKey(const ValueKey('noteChip:拉肚子'));

      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(
        await db.select(db.poopNotes).get(),
        hasLength(1),
        reason: '第一次点是打上标签',
      );

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(
        await db.select(db.poopNotes).get(),
        isEmpty,
        reason: '第二次点是卸下该标签',
      );
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
