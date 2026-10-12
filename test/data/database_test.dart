// drift 和 matcher 都导出了顶层 `isNull`，会撞名。
// 隐藏 drift 那个：列上的 `t.archivedAt.isNull()` 是**方法调用**，不受影响。
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/data/database.dart';

/// 数据层的护栏。
///
/// 这里断言的都是**设计评审里拍板过的决策**，不是随便写的 happy path：
/// 归档而不是删除、默认人的唯一性与转移、`endUnknown` 不挡住新记录、
/// 外键 restrict 阻止静默数据丢失。这些一旦被人"顺手改回去"，测试会立刻响。
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // 触发建库（onCreate 里的索引和默认备注种子都在这里跑）
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() async => db.close());

  Future<Pooper> newPooper(
    String name, {
    bool isDefault = false,
    int sortOrder = 0,
  }) {
    return db.into(db.poopers).insertReturning(
          PoopersCompanion.insert(
            name: name,
            isDefault: Value(isDefault),
            sortOrder: Value(sortOrder),
          ),
        );
  }

  Future<String> newRecord(
    String pooperId, {
    required DateTime startedAt,
    DateTime? endedAt,
    bool endUnknown = false,
  }) async {
    final r = await db.into(db.poopRecords).insertReturning(
          PoopRecordsCompanion.insert(
            pooperId: pooperId,
            startedAt: startedAt,
            endedAt: Value(endedAt),
            endUnknown: Value(endUnknown),
          ),
        );
    return r.id;
  }

  group('建库', () {
    test('默认备注种子已灌入，且首次建库不报错', () async {
      final templates = await db.select(db.noteTemplates).get();
      expect(templates.map((t) => t.content), contains('拉肚子'));
      expect(templates.map((t) => t.content), contains('很顺畅'));
      expect(templates.length, greaterThanOrEqualTo(5));
    });

    test('外键约束是打开的（不开的话 restrict 形同虚设）', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.data.values.first, 1);
    });
  });

  group('ensureDefaultPooper', () {
    test('空库时静默建一个「我」并设为默认', () async {
      final p = await db.ensureDefaultPooper();
      expect(p.name, '我');
      expect(p.isDefault, isTrue);
      expect(p.archivedAt, isNull);

      final all = await db.select(db.poopers).get();
      expect(all.length, 1);
    });

    test('已有默认时不会重复建人（幂等）', () async {
      await newPooper('阿狗', isDefault: true);
      final first = await db.ensureDefaultPooper();
      final second = await db.ensureDefaultPooper();

      expect(first.name, '阿狗');
      expect(second.id, first.id);
      expect((await db.select(db.poopers).get()).length, 1);
    });

    test('有活人但没人是默认时，提升最早创建的那个', () async {
      final a = await newPooper('阿狗', sortOrder: 0);
      await newPooper('咪咪', sortOrder: 1);

      final p = await db.ensureDefaultPooper();

      expect(p.id, a.id);
      expect(p.isDefault, isTrue);
      // 不能凭空多建人
      expect((await db.select(db.poopers).get()).length, 2);
    });
  });

  group('归档而不是删除', () {
    test('归档默认人会自动把默认转移给别人', () async {
      final a = await newPooper('阿狗', isDefault: true, sortOrder: 0);
      final b = await newPooper('咪咪', sortOrder: 1);

      await db.archivePooper(a.id);

      final alive = await db.activePoopers();
      expect(alive.length, 1);
      expect(alive.single.id, b.id);
      expect(alive.single.isDefault, isTrue);
    });

    test('★ 归档掉最后一个人后，ensureDefaultPooper 会补一个新的', () async {
      // 这条是关键：说明"一个屙屎人都没有"不是首启专属状态。
      // 如果 ensureDefaultPooper 只在首启跑（if (isFirstRun)），这里就会坏。
      final a = await newPooper('阿狗', isDefault: true);
      await db.archivePooper(a.id);

      expect(await db.activePoopers(), isEmpty);

      final fresh = await db.ensureDefaultPooper();
      expect(fresh.isDefault, isTrue);
      expect(fresh.name, '我');
      // 归档的人还在，没被删掉
      expect((await db.select(db.poopers).get()).length, 2);
    });

    test('归档会保留他的历史记录', () async {
      final a = await newPooper('阿狗', isDefault: true);
      await newRecord(a.id, startedAt: DateTime(2026, 2, 11, 9, 12));

      await db.archivePooper(a.id);

      expect((await db.select(db.poopRecords).get()).length, 1);
    });

    test('取消归档可以恢复', () async {
      final a = await newPooper('阿狗', isDefault: true);
      await db.archivePooper(a.id);
      await db.unarchivePooper(a.id);

      final alive = await db.activePoopers();
      expect(alive.length, 1);
      expect(alive.single.id, a.id);
    });
  });

  group('默认人的唯一性', () {
    test('同时插入两个默认会被唯一索引挡住', () async {
      await newPooper('阿狗', isDefault: true);
      await expectLater(
        newPooper('咪咪', isDefault: true),
        throwsA(isA<SqliteException>()),
      );
    });

    test('setDefaultPooper 先清后设，不会中途违反索引', () async {
      final a = await newPooper('阿狗', isDefault: true);
      final b = await newPooper('咪咪');

      await db.setDefaultPooper(b.id);

      final all = await db.select(db.poopers).get();
      expect(all.where((p) => p.isDefault).single.id, b.id);
      expect(all.firstWhere((p) => p.id == a.id).isDefault, isFalse);
    });
  });

  group('进行中记录的唯一性', () {
    test('同一人不能有两条进行中的记录', () async {
      final a = await newPooper('阿狗', isDefault: true);
      await newRecord(a.id, startedAt: DateTime(2026, 2, 11, 9, 12));

      await expectLater(
        newRecord(a.id, startedAt: DateTime(2026, 2, 11, 13, 40)),
        throwsA(isA<SqliteException>()),
      );
    });

    // ★★ 这是整份测试里最重要的一条。
    //
    // 「没有结束时间」有两种：还在屙（ended_at IS NULL, end_unknown = 0）
    // 和没记结束（ended_at IS NULL, end_unknown = 1）。
    // 唯一索引的条件里如果漏掉 `end_unknown = 0`，后者会被当成进行中，
    // 于是用户忘点一次结束，这个人就永远开不了新记录 —— 永久卡死。
    test('★「未记结束」的旧记录不该挡住新记录', () async {
      final a = await newPooper('阿狗', isDefault: true);

      // 一次忘了结束、已收敛为「未记结束」的旧记录
      await newRecord(
        a.id,
        startedAt: DateTime(2026, 1, 1, 9, 0),
        endUnknown: true,
      );

      // 现在应该能正常开新记录
      await newRecord(a.id, startedAt: DateTime(2026, 2, 11, 9, 12));

      expect((await db.select(db.poopRecords).get()).length, 2);
    });

    test('已结束的记录不占名额', () async {
      final a = await newPooper('阿狗', isDefault: true);
      await newRecord(
        a.id,
        startedAt: DateTime(2026, 2, 11, 9, 12),
        endedAt: DateTime(2026, 2, 11, 9, 26),
      );
      await newRecord(a.id, startedAt: DateTime(2026, 2, 11, 13, 40));

      expect((await db.select(db.poopRecords).get()).length, 2);
    });

    test('不同人可以同时进行中', () async {
      final a = await newPooper('阿狗', isDefault: true);
      final b = await newPooper('咪咪');
      await newRecord(a.id, startedAt: DateTime(2026, 2, 11, 9, 12));
      await newRecord(b.id, startedAt: DateTime(2026, 2, 11, 9, 30));

      expect((await db.select(db.poopRecords).get()).length, 2);
    });
  });

  group('删除的安全性', () {
    test('外键 restrict 挡住直接删人', () async {
      final a = await newPooper('阿狗', isDefault: true);
      await newRecord(a.id, startedAt: DateTime(2026, 2, 11, 9, 12));

      await expectLater(
        (db.delete(db.poopers)..where((t) => t.id.equals(a.id))).go(),
        throwsA(isA<SqliteException>()),
      );
      // 记录必须还在
      expect((await db.select(db.poopRecords).get()).length, 1);
    });

    test('purgePooper 明确删除并返回条数', () async {
      final a = await newPooper('阿狗', isDefault: true);
      // 注意：不能建两条都"进行中"的 —— 那会被 ux_active_record 挡住。
      // 这里故意用一条已结束 + 一条「未记结束」，顺便覆盖两种终态。
      await newRecord(
        a.id,
        startedAt: DateTime(2026, 2, 11, 9, 12),
        endedAt: DateTime(2026, 2, 11, 9, 26),
      );
      await newRecord(
        a.id,
        startedAt: DateTime(2026, 2, 12, 9, 12),
        endUnknown: true,
      );

      final deleted = await db.purgePooper(a.id);

      expect(deleted, 2);
      expect(await db.select(db.poopers).get(), isEmpty);
      expect(await db.select(db.poopRecords).get(), isEmpty);
    });

    test('删记录会级联删掉它的备注', () async {
      final a = await newPooper('阿狗', isDefault: true);
      final rid = await newRecord(a.id, startedAt: DateTime(2026, 2, 11, 9, 12));
      await db.into(db.poopNotes).insert(
            PoopNotesCompanion.insert(
              recordId: rid,
              content: '开冲，很顺畅',
              notedAt: DateTime(2026, 2, 11, 9, 14),
            ),
          );

      await (db.delete(db.poopRecords)..where((t) => t.id.equals(rid))).go();

      expect(await db.select(db.poopNotes).get(), isEmpty);
    });
  });
}
