import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/data/database.dart';
import 'package:pooped_yet/src/data/record_actions.dart';
import 'package:pooped_yet/src/data/record_edits.dart';

/// 记录编辑的约束边界。
///
/// 这些方法不只是"改一个字段"——它们各自挡着一类会污染数据的情况：
/// 结束早于开始（时长变负数）、换人换到一个已经有进行中记录的人（撞唯一索引）、
/// 重新打开一条已经有人接着开了的记录。**边界才是它们存在的理由**。
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
  });
  tearDown(() async => db.close());

  Future<Pooper> person(String name, {int sort = 0}) => db
      .into(db.poopers)
      .insertReturning(
        PoopersCompanion.insert(name: name, sortOrder: Value(sort)),
      );

  Future<PoopRecord> rec(
    String pid, {
    DateTime? start,
    DateTime? end,
    bool endUnknown = false,
  }) {
    return db.into(db.poopRecords).insertReturning(
          PoopRecordsCompanion.insert(
            pooperId: pid,
            startedAt: start ?? DateTime(2026, 2, 11, 9, 12),
            endedAt: Value(end),
            endUnknown: Value(endUnknown),
          ),
        );
  }

  Future<PoopRecord> reload(String id) =>
      (db.select(db.poopRecords)..where((t) => t.id.equals(id))).getSingle();

  group('updateStartedAt', () {
    test('正常改', () async {
      final a = await person('阿狗');
      final r = await rec(a.id, end: DateTime(2026, 2, 11, 9, 26));

      final res = await db.updateStartedAt(r.id, DateTime(2026, 2, 11, 8, 0));

      expect(res.ok, isTrue);
      expect((await reload(r.id)).startedAt, DateTime(2026, 2, 11, 8, 0));
    });

    test('新开始时间晚于结束时间 → 拒绝', () async {
      final a = await person('阿狗');
      final r = await rec(a.id, end: DateTime(2026, 2, 11, 9, 26));

      final res = await db.updateStartedAt(r.id, DateTime(2026, 2, 11, 10, 0));

      expect(res, isA<EditEndBeforeStart>());
      expect((await reload(r.id)).startedAt, DateTime(2026, 2, 11, 9, 12),
          reason: '拒绝了就不能留半截改动');
    });

    test('等于结束时间是允许的（时长为 0）', () async {
      final a = await person('阿狗');
      final end = DateTime(2026, 2, 11, 9, 26);
      final r = await rec(a.id, end: end);

      expect((await db.updateStartedAt(r.id, end)).ok, isTrue);
    });

    test('进行中的记录不受结束时间约束', () async {
      final a = await person('阿狗');
      final r = await rec(a.id);

      expect(
        (await db.updateStartedAt(r.id, DateTime(2026, 3, 1))).ok,
        isTrue,
      );
    });

    test('记录已被删掉时静默成功（不抛）', () async {
      expect((await db.updateStartedAt('nope', DateTime(2026, 1, 1))).ok, isTrue);
    });
  });

  group('updateEndedAt', () {
    test('正常改，并清掉「未记结束」标记', () async {
      final a = await person('阿狗');
      final r = await rec(a.id, endUnknown: true);

      final res = await db.updateEndedAt(r.id, DateTime(2026, 2, 11, 9, 26));

      expect(res.ok, isTrue);
      final after = await reload(r.id);
      expect(after.endedAt, DateTime(2026, 2, 11, 9, 26));
      expect(after.endUnknown, isFalse,
          reason: '不变式：有结束时间就必然不是「未记结束」');
    });

    test('结束早于开始 → 拒绝', () async {
      final a = await person('阿狗');
      final r = await rec(a.id, start: DateTime(2026, 2, 11, 9, 12));

      final res = await db.updateEndedAt(r.id, DateTime(2026, 2, 11, 9, 0));

      expect(res, isA<EditEndBeforeStart>());
      expect((await reload(r.id)).endedAt, isNull);
    });
  });

  group('reopenRecord', () {
    test('已结束的能重新打开', () async {
      final a = await person('阿狗');
      final r = await rec(a.id, end: DateTime(2026, 2, 11, 9, 26));

      final res = await db.reopenRecord(r.id);

      expect(res.ok, isTrue);
      final after = await reload(r.id);
      expect(after.endedAt, isNull);
      expect(after.endUnknown, isFalse);
    });

    test('★ 这个人已经又开了一条时，拒绝重开', () async {
      final a = await person('阿狗');
      final old = await rec(a.id, end: DateTime(2026, 2, 11, 9, 26));
      final fresh = await rec(a.id, start: DateTime(2026, 2, 11, 13, 40));

      final res = await db.reopenRecord(old.id);

      expect(res, isA<EditPooperAlreadyActive>());
      expect((res as EditPooperAlreadyActive).existing.id, fresh.id,
          reason: '要告诉用户是谁挡住了，UI 才能说人话');
      expect((await reload(old.id)).endedAt, isNotNull, reason: '拒绝后不能改');
    });

    test('「未记结束」的也能重新打开', () async {
      final a = await person('阿狗');
      final r = await rec(a.id, endUnknown: true);
      expect((await db.reopenRecord(r.id)).ok, isTrue);
      expect((await reload(r.id)).endUnknown, isFalse);
    });
  });

  group('changePooper', () {
    test('已结束的记录可以随便换人，即使对方正在屙', () async {
      final a = await person('阿狗');
      final b = await person('咪咪', sort: 1);
      final done = await rec(a.id, end: DateTime(2026, 2, 11, 9, 26));
      await rec(b.id, start: DateTime(2026, 2, 11, 13, 40));

      final res = await db.changePooper(done.id, b.id);

      expect(res.ok, isTrue, reason: '已结束的记录不占"进行中"的名额');
      expect((await reload(done.id)).pooperId, b.id);
    });

    test('★ 进行中的记录换到一个正在屙的人 → 拒绝', () async {
      final a = await person('阿狗');
      final b = await person('咪咪', sort: 1);
      final mine = await rec(a.id, start: DateTime(2026, 2, 11, 9, 12));
      final theirs = await rec(b.id, start: DateTime(2026, 2, 11, 9, 40));

      final res = await db.changePooper(mine.id, b.id);

      expect(res, isA<EditPooperAlreadyActive>());
      expect((res as EditPooperAlreadyActive).existing.id, theirs.id);
      expect((await reload(mine.id)).pooperId, a.id, reason: '拒绝后不能改');
    });

    test('换到自己身上是空操作', () async {
      final a = await person('阿狗');
      final r = await rec(a.id);
      expect((await db.changePooper(r.id, a.id)).ok, isTrue);
    });
  });

  group('备注', () {
    test('改内容', () async {
      final a = await person('阿狗');
      final r = await rec(a.id, end: DateTime(2026, 2, 11, 9, 26));
      final n = await db.into(db.poopNotes).insertReturning(
            PoopNotesCompanion.insert(
              recordId: r.id,
              content: '旧内容',
              notedAt: DateTime(2026, 2, 11, 9, 14),
            ),
          );

      expect(await db.updateNote(n.id, '新内容'), isTrue);
      final after = await (db.select(db.poopNotes)
            ..where((t) => t.id.equals(n.id)))
          .getSingle();
      expect(after.content, '新内容');
    });

    test('内容前后空格被裁掉', () async {
      final a = await person('阿狗');
      final r = await rec(a.id, end: DateTime(2026, 2, 11, 9, 26));
      final n = await db.into(db.poopNotes).insertReturning(
            PoopNotesCompanion.insert(
              recordId: r.id,
              content: 'x',
              notedAt: DateTime(2026, 2, 11, 9, 14),
            ),
          );

      await db.updateNote(n.id, '  有空格  ');
      final after = await (db.select(db.poopNotes)
            ..where((t) => t.id.equals(n.id)))
          .getSingle();
      expect(after.content, '有空格');
    });

    test('★ 空内容被拒绝，且不删掉原来那条', () async {
      final a = await person('阿狗');
      final r = await rec(a.id, end: DateTime(2026, 2, 11, 9, 26));
      final n = await db.into(db.poopNotes).insertReturning(
            PoopNotesCompanion.insert(
              recordId: r.id,
              content: '还在',
              notedAt: DateTime(2026, 2, 11, 9, 14),
            ),
          );

      expect(await db.updateNote(n.id, '   '), isFalse);
      final after = await (db.select(db.poopNotes)
            ..where((t) => t.id.equals(n.id)))
          .getSingle();
      expect(after.content, '还在',
          reason: '想删应该点删除，而不是把内容清空留一条空备注');
    });

    test('改时刻', () async {
      final a = await person('阿狗');
      final r = await rec(a.id, end: DateTime(2026, 2, 11, 9, 26));
      final n = await db.into(db.poopNotes).insertReturning(
            PoopNotesCompanion.insert(
              recordId: r.id,
              content: 'x',
              notedAt: DateTime(2026, 2, 11, 9, 14),
            ),
          );

      expect(await db.updateNoteTime(n.id, DateTime(2026, 2, 11, 9, 30)), isTrue);
      final after = await (db.select(db.poopNotes)
            ..where((t) => t.id.equals(n.id)))
          .getSingle();
      expect(after.notedAt, DateTime(2026, 2, 11, 9, 30));
    });

    test('改不存在的备注返回 false', () async {
      expect(await db.updateNote('nope', 'x'), isFalse);
      expect(await db.updateNoteTime('nope', DateTime(2026, 1, 1)), isFalse);
    });
  });

  group('和唯一索引配合', () {
    test('换人之后，这个人的进行中名额被正确占用/释放', () async {
      final a = await person('阿狗');
      final b = await person('咪咪', sort: 1);
      final r = await rec(a.id, start: DateTime(2026, 2, 11, 9, 12));

      // 把进行中的记录从 a 换到 b
      expect((await db.changePooper(r.id, b.id)).ok, isTrue);

      // 现在 a 空出来了，可以开新的
      final res = await db.startPoop(pooperId: a.id, at: DateTime(2026, 2, 11, 13));
      expect(res, isA<StartPoopOk>());

      // 而 b 被占着，开不了
      final blocked = await db.startPoop(pooperId: b.id, at: DateTime(2026, 2, 11, 14));
      expect(blocked, isA<StartPoopAlreadyActive>());
    });
  });
}
