import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/data/database.dart';
import 'package:pooped_yet/src/data/queries.dart';
import 'package:pooped_yet/src/domain/history_filter.dart';

/// 历史检索（视觉稿 ⑥⑦）。
///
/// 重点在三处最容易错的地方：
///   1. **时间范围是"含结束那天"的** —— 选到 10/12 却不含 10/12 的记录，用户会懵
///   2. **LIKE 的通配符要转义** —— 搜「50%」不该变成"以 50 开头"
///   3. **空集合 = 不限**，不是"谁都不选"
void main() {
  late AppDatabase db;
  late String meId;
  late String dogId;
  late String catId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();

    final me = await db.into(db.poopers).insertReturning(
          PoopersCompanion.insert(name: '我', isDefault: const Value(true)),
        );
    final dog = await db.into(db.poopers).insertReturning(
          PoopersCompanion.insert(name: '阿狗', sortOrder: const Value(1)),
        );
    final cat = await db.into(db.poopers).insertReturning(
          PoopersCompanion.insert(name: '咪咪', sortOrder: const Value(2)),
        );
    meId = me.id;
    dogId = dog.id;
    catId = cat.id;
  });
  tearDown(() async => db.close());

  /// 插一条记录，可选带备注。
  ///
  /// ⚠ 默认给一个结束时间。**不填结束就等于"进行中"**，
  /// 而 `ux_active_record` 唯一索引限制"一个人同时只能有一条进行中的" ——
  /// 不给结束时间的话，给同一个人插第二条就会被数据库挡下来。
  /// （第一次就是这么挂的：索引是对的，是这里的测试数据不合法。）
  Future<void> rec(
    String pid,
    DateTime start, {
    String? note,
    String? note2,
    DateTime? end,
    bool active = false,
  }) async {
    final r = await db.into(db.poopRecords).insertReturning(
          PoopRecordsCompanion.insert(
            pooperId: pid,
            startedAt: start,
            endedAt: Value(
              active ? null : (end ?? start.add(const Duration(minutes: 10))),
            ),
          ),
        );
    for (final (i, n) in [note, note2].whereType<String>().indexed) {
      await db.into(db.poopNotes).insert(
            PoopNotesCompanion.insert(
              recordId: r.id,
              content: n,
              notedAt: start.add(Duration(minutes: i + 1)),
            ),
          );
    }
  }

  Future<List<String>> names(HistoryFilter f) async {
    final list = await db.searchRecords(f);
    return [for (final d in list) d.pooper.name];
  }

  group('基本检索', () {
    test('空条件返回全部，按时间倒序', () async {
      await rec(meId, DateTime(2026, 10, 1, 9));
      await rec(dogId, DateTime(2026, 10, 5, 9));
      await rec(catId, DateTime(2026, 10, 3, 9));

      final list = await db.searchRecords(const HistoryFilter());
      expect(list.map((d) => d.record.startedAt.day), [5, 3, 1],
          reason: '时间线最新的在最上面');
    });

    test('空库里返回空，不报错', () async {
      expect(await db.searchRecords(const HistoryFilter()), isEmpty);
      expect(await db.countRecords(const HistoryFilter()), 0);
    });

    test('带出人与备注', () async {
      await rec(meId, DateTime(2026, 10, 1, 9), note: '开冲');
      final d = (await db.searchRecords(const HistoryFilter())).single;
      expect(d.pooper.name, '我');
      expect(d.notes.map((n) => n.content), ['开冲']);
    });
  });

  group('按人筛选', () {
    setUp(() async {
      await rec(meId, DateTime(2026, 10, 1, 9));
      await rec(dogId, DateTime(2026, 10, 2, 9));
      await rec(catId, DateTime(2026, 10, 3, 9));
    });

    test('★ 空集合 = 不限（不是"谁都不选"）', () async {
      expect(await names(const HistoryFilter()), hasLength(3));
    });

    test('选一个人', () async {
      expect(await names(HistoryFilter(pooperIds: {dogId})), ['阿狗']);
    });

    test('选多个人', () async {
      final r = await names(HistoryFilter(pooperIds: {dogId, catId}));
      expect(r, ['咪咪', '阿狗']);
    });

    test('选一个不存在的人返回空', () async {
      expect(await names(const HistoryFilter(pooperIds: {'nope'})), isEmpty);
    });
  });

  group('时间范围', () {
    setUp(() async {
      await rec(meId, DateTime(2026, 10, 1, 0, 30)); // 月初凌晨
      await rec(meId, DateTime(2026, 10, 5, 12));
      await rec(meId, DateTime(2026, 10, 10, 23, 30)); // 深夜
      await rec(meId, DateTime(2026, 10, 11, 0, 30));
    });

    test('★ 结束那天是「含」的 —— 到 10/10 要包含 10/10 23:30', () async {
      final r = await db.searchRecords(
        HistoryFilter(to: DateTime(2026, 10, 10)),
      );
      expect(r.map((d) => d.record.startedAt.day), [10, 5, 1],
          reason: '23:30 那条约等于被漏掉，用户会以为数据丢了');
    });

    test('起始那天也是「含」的 —— 从 10/10 要包含 10/10 00:30 之后', () async {
      final r = await db.searchRecords(
        HistoryFilter(from: DateTime(2026, 10, 10)),
      );
      expect(r.map((d) => d.record.startedAt.day), [11, 10]);
    });

    test('单日区间', () async {
      final r = await db.searchRecords(
        HistoryFilter(
          from: DateTime(2026, 10, 10),
          to: DateTime(2026, 10, 10),
        ),
      );
      expect(r, hasLength(1));
      expect(r.single.record.startedAt.hour, 23);
    });

    test('只给 from', () async {
      final r = await db.searchRecords(
        HistoryFilter(from: DateTime(2026, 10, 5)),
      );
      expect(r.map((d) => d.record.startedAt.day), [11, 10, 5]);
    });

    test('区间之外返回空', () async {
      final r = await db.searchRecords(
        HistoryFilter(
          from: DateTime(2026, 9, 1),
          to: DateTime(2026, 9, 30),
        ),
      );
      expect(r, isEmpty);
    });

    test('区间含时分秒也按整天算', () async {
      final r = await db.searchRecords(
        HistoryFilter(
          from: DateTime(2026, 10, 10, 18, 0),
          to: DateTime(2026, 10, 10, 19, 0),
        ),
      );
      expect(r, hasLength(1), reason: '用户选日期时不该被时分秒意外过滤');
    });
  });

  group('关键词', () {
    setUp(() async {
      await rec(meId, DateTime(2026, 10, 1, 9), note: '昨晚吃火锅了');
      await rec(dogId, DateTime(2026, 10, 2, 9), note: '很正常');
      await rec(catId, DateTime(2026, 10, 3, 9), note: '有点干');
      await rec(meId, DateTime(2026, 10, 4, 9), note: '火锅again', note2: '辣');
    });

    test('按备注内容搜', () async {
      final r = await db.searchRecords(const HistoryFilter(keyword: '火锅'));
      expect(r, hasLength(2));
    });

    test('★ 也搜屙屎人名字', () async {
      final r = await db.searchRecords(const HistoryFilter(keyword: '阿狗'));
      expect(r, hasLength(1));
      expect(r.single.pooper.name, '阿狗');
    });

    test('一条记录有多条备注时，命中任意一条都算，且不重复', () async {
      final r = await db.searchRecords(const HistoryFilter(keyword: '辣'));
      expect(r, hasLength(1), reason: 'EXISTS 子查询保证不会因多条备注而重复');
    });

    test('搜不到返回空', () async {
      expect(
        await db.searchRecords(const HistoryFilter(keyword: '不存在的词')),
        isEmpty,
      );
    });

    test('前后空格被忽略', () async {
      final r = await db.searchRecords(const HistoryFilter(keyword: '  火锅  '));
      expect(r, hasLength(2));
    });

    test('★ 通配符被转义 —— 搜 % 不该匹配所有', () async {
      await rec(meId, DateTime(2026, 10, 5, 9), note: '50% 含水');
      await rec(meId, DateTime(2026, 10, 6, 9), note: '完全不含');

      final r = await db.searchRecords(const HistoryFilter(keyword: '%'));
      expect(r, hasLength(1), reason: '不转义的话 % 会匹配所有记录');
      expect(r.single.notes.single.content, contains('50%'));
    });

    test('★ 下划线也被转义', () async {
      await rec(meId, DateTime(2026, 10, 5, 9), note: 'a_b');
      await rec(meId, DateTime(2026, 10, 6, 9), note: 'axb');

      final r = await db.searchRecords(const HistoryFilter(keyword: 'a_b'));
      expect(r, hasLength(1), reason: '_ 不转义会匹配任意单字符');
      expect(r.single.notes.single.content, 'a_b');
    });

    test('反斜杠本身也能搜', () async {
      await rec(meId, DateTime(2026, 10, 5, 9), note: r'路径 C:\temp');
      await rec(meId, DateTime(2026, 10, 6, 9), note: '无关');
      final r = await db.searchRecords(HistoryFilter(keyword: r'\'));
      expect(r, hasLength(1));
    });
  });

  group('组合条件', () {
    setUp(() async {
      await rec(meId, DateTime(2026, 10, 1, 9), note: '火锅');
      await rec(dogId, DateTime(2026, 10, 2, 9), note: '火锅');
      await rec(dogId, DateTime(2026, 10, 3, 9), note: '正常');
      await rec(catId, DateTime(2026, 10, 20, 9), note: '火锅');
    });

    test('人 + 关键词', () async {
      final r = await db.searchRecords(
        HistoryFilter(pooperIds: {dogId}, keyword: '火锅'),
      );
      expect(r, hasLength(1));
      expect(r.single.record.startedAt.day, 2);
    });

    test('人 + 关键词 + 时间范围', () async {
      final r = await db.searchRecords(
        HistoryFilter(
          pooperIds: {dogId, catId, meId},
          keyword: '火锅',
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 10),
        ),
      );
      expect(r.map((d) => d.record.startedAt.day), [2, 1],
          reason: '10/20 那条应在范围外');
    });

    test('条件互斥时返回空', () async {
      final r = await db.searchRecords(
        HistoryFilter(pooperIds: {meId}, keyword: '正常'),
      );
      expect(r, isEmpty);
    });
  });

  group('limit 与 count', () {
    setUp(() async {
      for (var i = 1; i <= 10; i++) {
        await rec(meId, DateTime(2026, 10, i, 9));
      }
    });

    test('limit 截断结果', () async {
      expect(await db.searchRecords(const HistoryFilter(), limit: 3),
          hasLength(3));
    });

    test('★ count 不受 limit 影响（否则会显示成"共 500 条"）', () async {
      expect(await db.countRecords(const HistoryFilter()), 10);
    });

    test('count 也遵守筛选条件', () async {
      expect(
        await db.countRecords(HistoryFilter(from: DateTime(2026, 10, 6))),
        5,
      );
    });
  });

  group('归档的人', () {
    test('归档后他的历史照样能搜到', () async {
      await rec(dogId, DateTime(2026, 10, 2, 9), note: '火锅');
      await db.archivePooper(dogId);

      final r = await db.searchRecords(const HistoryFilter(keyword: '火锅'));
      expect(r, hasLength(1));
      expect(r.single.pooper.name, '阿狗');
      expect(r.single.pooper.archivedAt, isNotNull,
          reason: 'UI 据此显示「已归档」标记');
    });
  });

  group('HistoryFilter 值语义', () {
    test('★ 相等性按值 —— Riverpod family 靠它判断要不要重查', () {
      const a = HistoryFilter(pooperIds: {'x', 'y'}, keyword: '火锅');
      const b = HistoryFilter(pooperIds: {'y', 'x'}, keyword: '火锅');
      expect(a, b, reason: '集合顺序不该影响相等性');
      expect(a.hashCode, b.hashCode);
    });

    test('关键词前后空格不算差异', () {
      expect(
        const HistoryFilter(keyword: '火锅'),
        const HistoryFilter(keyword: '  火锅  '),
      );
    });

    test('日期只比到天，不比时分秒', () {
      expect(
        HistoryFilter(from: DateTime(2026, 10, 1, 9)),
        HistoryFilter(from: DateTime(2026, 10, 1, 23, 59)),
      );
    });

    test('空集合与有内容不等', () {
      expect(const HistoryFilter(), isNot(const HistoryFilter(pooperIds: {'x'})));
    });

    test('isEmpty / activeCount', () {
      expect(const HistoryFilter().isEmpty, isTrue);
      expect(const HistoryFilter().activeCount, 0);

      expect(const HistoryFilter(keyword: 'a').activeCount, 1);
      expect(const HistoryFilter(pooperIds: {'x'}).activeCount, 1);
      expect(HistoryFilter(from: DateTime(2026, 1, 1)).activeCount, 1);
      expect(
        HistoryFilter(from: DateTime(2026, 1, 1), to: DateTime(2026, 2, 1))
            .activeCount,
        1,
        reason: '起止算同一个"时间范围"条件',
      );
      expect(
        const HistoryFilter(pooperIds: {'x'}, keyword: 'a').activeCount,
        2,
      );
    });

    test('★ normalized 会把反过来的区间交换过来', () {
      final f = HistoryFilter(
        from: DateTime(2026, 10, 20),
        to: DateTime(2026, 10, 5),
      ).normalized();
      expect(f.from, DateTime(2026, 10, 5));
      expect(f.to, DateTime(2026, 10, 20));
    });

    test('normalized 归一到零点', () {
      final f = HistoryFilter(
        from: DateTime(2026, 10, 5, 13),
        to: DateTime(2026, 10, 20, 8),
      ).normalized();
      expect(f.from, DateTime(2026, 10, 5));
      expect(f.to, DateTime(2026, 10, 20));
    });

    test('toExclusiveInstant 是次日零点', () {
      final f = HistoryFilter(to: DateTime(2026, 10, 10));
      expect(f.toExclusiveInstant, DateTime(2026, 10, 11));
      expect(f.fromInstant, isNull);
    });

    test('copyWith 能显式清空日期', () {
      final f = HistoryFilter(from: DateTime(2026, 1, 1)).copyWith();
      expect(f.from, isNotNull);
      expect(HistoryFilter(from: DateTime(2026, 1, 1)).copyWith(clearFrom: true).from,
          isNull);
    });

    test('togglePooper 来回切', () {
      var f = const HistoryFilter();
      f.togglePooper('x', (v) => f = v);
      expect(f.pooperIds, {'x'});
      f.togglePooper('x', (v) => f = v);
      expect(f.pooperIds, isEmpty);
    });
  });
}
