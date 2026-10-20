// drift 和 matcher 都导出了 isNull / isNotNull，撞名。隐藏 drift 的两个 ——
// 列上的 .isNull() / .isNotNull() 是方法调用，不受影响。
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/calendar/calendar_math.dart';
import 'package:pooped_yet/src/data/database.dart';
import 'package:pooped_yet/src/data/queries.dart';
import 'package:pooped_yet/src/state/settings.dart';

/// 日历与记录列表的查询。
///
/// 重点验两件容易错的事：
///   1. **按本地日分组**，不是按 UTC。Drift 存的是 Unix 秒，
///      直接对时间戳取模会按 UTC 切天，国内用户晚上 8 点后的记录会被算到第二天。
///   2. **「正在屙」置顶**，其余按开始时间升序。
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

  Future<void> poop(
    String pid,
    DateTime start, {
    DateTime? end,
    bool endUnknown = false,
  }) async {
    await db.into(db.poopRecords).insert(
          PoopRecordsCompanion.insert(
            pooperId: pid,
            startedAt: start,
            endedAt: Value(end),
            endUnknown: Value(endUnknown),
          ),
        );
  }

  group('countsInRange —— 按本地日分组', () {
    test('同一天的多条按人累加', () async {
      final a = await person('阿狗');
      final b = await person('咪咪', sort: 1);

      await poop(a.id, DateTime(2026, 2, 11, 9, 12), end: DateTime(2026, 2, 11, 9, 26));
      await poop(a.id, DateTime(2026, 2, 11, 13, 40), end: DateTime(2026, 2, 11, 13, 52));
      await poop(b.id, DateTime(2026, 2, 11, 20, 5), endUnknown: true);

      final counts = await db.countsInRange(
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      );

      expect(counts['2026-02-11'], {a.id: 2, b.id: 1});
      expect(counts.length, 1);
    });

    test('区间是左闭右开，边界当天的记录不会漏也不会多', () async {
      final a = await person('阿狗');
      await poop(a.id, DateTime(2026, 1, 31, 23, 59), endUnknown: true);
      await poop(a.id, DateTime(2026, 2, 1, 0, 0), endUnknown: true);
      await poop(a.id, DateTime(2026, 2, 28, 23, 59), endUnknown: true);
      await poop(a.id, DateTime(2026, 3, 1, 0, 0), endUnknown: true);

      final counts = await db.countsInRange(
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      );

      expect(counts.keys.toSet(), {'2026-02-01', '2026-02-28'});
    });

    test('深夜与凌晨的记录落在各自的本地日', () async {
      final a = await person('阿狗');
      await poop(a.id, DateTime(2026, 2, 11, 23, 50), endUnknown: true);
      await poop(a.id, DateTime(2026, 2, 12, 0, 10), endUnknown: true);

      final counts = await db.countsInRange(
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      );

      expect(counts['2026-02-11'], {a.id: 1});
      expect(counts['2026-02-12'], {a.id: 1});
    });

    test('跨零点的一次记录按**开始时间**归属，只算一天', () async {
      final a = await person('阿狗');
      await poop(
        a.id,
        DateTime(2026, 2, 11, 23, 50),
        end: DateTime(2026, 2, 12, 0, 5),
      );

      final counts = await db.countsInRange(
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      );

      expect(counts['2026-02-11'], {a.id: 1});
      expect(counts.containsKey('2026-02-12'), isFalse);
    });

    test('空区间返回空 map，不抛异常', () async {
      final counts = await db.countsInRange(
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      );
      expect(counts, isEmpty);
    });
  });

  group('monthGridCounts —— 网格范围而不是自然月', () {
    test('网格首尾露出的上下月日期也要有计数', () async {
      final a = await person('阿狗');

      // 从网格实际边界推导，不手写日期 ——
      // 手写过一次 3/3，但 2026-02 的网格只到 3/1（5 行 × 7 = 35 天），白写一条。
      final grid = monthGridDays(2026, 2, WeekStart.monday);
      final first = grid.first;
      final last = grid.last;
      expect(first.month, 1, reason: '2 月网格首格应落在 1 月');
      expect(last.month, 3, reason: '2 月网格末格应落在 3 月');

      await poop(a.id, DateTime(first.year, first.month, first.day, 10),
          endUnknown: true);
      await poop(a.id, DateTime(last.year, last.month, last.day, 10),
          endUnknown: true);

      final counts = await db.monthGridCounts(
        DateTime(2026, 2, 1),
        WeekStart.monday,
      );

      expect(counts.containsKey(dayKey(first)), isTrue,
          reason: '网格里露出的 ${dayKey(first)} 也应该显示徽标');
      expect(counts.containsKey(dayKey(last)), isTrue,
          reason: '网格里露出的 ${dayKey(last)} 也应该显示徽标');
    });

    test('网格之外的记录不会被算进来', () async {
      final a = await person('阿狗');
      final grid = monthGridDays(2026, 2, WeekStart.monday);

      final before = addDays(grid.first, -1);
      final after = addDays(grid.last, 1);
      await poop(a.id, DateTime(before.year, before.month, before.day, 10),
          endUnknown: true);
      await poop(a.id, DateTime(after.year, after.month, after.day, 10),
          endUnknown: true);

      final counts = await db.monthGridCounts(
        DateTime(2026, 2, 1),
        WeekStart.monday,
      );

      expect(counts.containsKey(dayKey(before)), isFalse);
      expect(counts.containsKey(dayKey(after)), isFalse);
    });
  });

  group('recordsOn —— 排序与完整性', () {
    test('「正在屙」置顶，其余按开始时间倒序（默认）', () async {
      final a = await person('阿狗');
      final now = DateTime(2026, 2, 11, 15, 0);

      // 09:12 已完成 / 13:40 已完成 / 14:50 正在屙
      await poop(a.id, DateTime(2026, 2, 11, 9, 12),
          end: DateTime(2026, 2, 11, 9, 26));
      await poop(a.id, DateTime(2026, 2, 11, 13, 40),
          end: DateTime(2026, 2, 11, 13, 52));
      await poop(a.id, DateTime(2026, 2, 11, 14, 50));

      final list = await db.recordsOn(DateTime(2026, 2, 11), now: now);

      expect(list.length, 3);
      expect(list.first.record.startedAt, DateTime(2026, 2, 11, 14, 50),
          reason: '正在屙的要置顶，因为它需要用户立刻操作');
      // 默认 sortOrder 是 desc —— 当天列表的常态是"最新的在最上面"。
      expect(list[1].record.startedAt, DateTime(2026, 2, 11, 13, 40));
      expect(list[2].record.startedAt, DateTime(2026, 2, 11, 9, 12));
    });

    test('显式 asc 时其余升序，但「正在屙」照样置顶', () async {
      final a = await person('阿狗');
      final now = DateTime(2026, 2, 11, 15, 0);

      await poop(a.id, DateTime(2026, 2, 11, 9, 12),
          end: DateTime(2026, 2, 11, 9, 26));
      await poop(a.id, DateTime(2026, 2, 11, 13, 40),
          end: DateTime(2026, 2, 11, 13, 52));
      await poop(a.id, DateTime(2026, 2, 11, 14, 50));

      final list = await db.recordsOn(
        DateTime(2026, 2, 11),
        now: now,
        sortOrder: RecordSortOrder.asc,
      );

      expect(list.first.record.startedAt, DateTime(2026, 2, 11, 14, 50),
          reason: '置顶优先于排序方向');
      expect(list[1].record.startedAt, DateTime(2026, 2, 11, 9, 12));
      expect(list[2].record.startedAt, DateTime(2026, 2, 11, 13, 40));
    });

    test('备注按时刻升序，且挂在正确的记录上', () async {
      final a = await person('阿狗');
      final r1 = await db.into(db.poopRecords).insertReturning(
            PoopRecordsCompanion.insert(
              pooperId: a.id,
              startedAt: DateTime(2026, 2, 11, 9, 12),
              endedAt: Value(DateTime(2026, 2, 11, 9, 26)),
            ),
          );
      final r2 = await db.into(db.poopRecords).insertReturning(
            PoopRecordsCompanion.insert(
              pooperId: a.id,
              startedAt: DateTime(2026, 2, 11, 13, 40),
              endedAt: Value(DateTime(2026, 2, 11, 13, 52)),
            ),
          );

      // 故意乱序插入
      for (final (rid, text, at) in [
        (r1.id, '后写的', DateTime(2026, 2, 11, 9, 20)),
        (r1.id, '先写的', DateTime(2026, 2, 11, 9, 14)),
        (r2.id, '另一条的', DateTime(2026, 2, 11, 13, 45)),
      ]) {
        await db.into(db.poopNotes).insert(
              PoopNotesCompanion.insert(
                recordId: rid,
                content: text,
                notedAt: at,
              ),
            );
      }

      final list = await db.recordsOn(DateTime(2026, 2, 11));
      final first = list.firstWhere((d) => d.record.id == r1.id);
      final second = list.firstWhere((d) => d.record.id == r2.id);

      expect(first.notes.map((n) => n.content), ['先写的', '后写的']);
      expect(second.notes.map((n) => n.content), ['另一条的']);
    });

    test('没有备注的记录不会丢', () async {
      final a = await person('阿狗');
      await poop(a.id, DateTime(2026, 2, 11, 9, 12),
          end: DateTime(2026, 2, 11, 9, 26));

      final list = await db.recordsOn(DateTime(2026, 2, 11));
      expect(list.length, 1);
      expect(list.single.notes, isEmpty);
    });

    test('只返回这一天的', () async {
      final a = await person('阿狗');
      await poop(a.id, DateTime(2026, 2, 10, 9), endUnknown: true);
      await poop(a.id, DateTime(2026, 2, 11, 9), endUnknown: true);
      await poop(a.id, DateTime(2026, 2, 12, 9), endUnknown: true);

      final list = await db.recordsOn(DateTime(2026, 2, 11));
      expect(list.length, 1);
      expect(list.single.record.startedAt.day, 11);
    });

    test('已归档的人的记录仍然查得到', () async {
      final a = await person('阿狗');
      await poop(a.id, DateTime(2026, 2, 11, 9), endUnknown: true);
      await db.archivePooper(a.id);

      final list = await db.recordsOn(DateTime(2026, 2, 11));
      expect(list.length, 1, reason: '归档保留历史，日历和列表都还要能看到');
      expect(list.single.pooper.name, '阿狗');
    });
  });

  group('settleStaleRecords —— 自动收敛', () {
    test('超过 24 小时的挂起记录被收敛为「未记结束」并落库', () async {
      final a = await person('阿狗');
      await poop(a.id, DateTime(2026, 2, 10, 9, 0)); // 现在看是 30 小时前

      final now = DateTime(2026, 2, 11, 15, 0);
      await db.settleStaleRecords(now: now);

      final r = await db.select(db.poopRecords).getSingle();
      expect(r.endUnknown, isTrue, reason: '要真的写进库，不能只在内存里改');

      // 收敛之后这个人应该能开新记录了
      await poop(a.id, DateTime(2026, 2, 11, 15, 30));
      expect((await db.select(db.poopRecords).get()).length, 2);
    });

    test('未到 24 小时的不会被收敛', () async {
      final a = await person('阿狗');
      await poop(a.id, DateTime(2026, 2, 11, 9, 0));

      await db.settleStaleRecords(now: DateTime(2026, 2, 11, 15, 0));

      final r = await db.select(db.poopRecords).getSingle();
      expect(r.endUnknown, isFalse);
    });

    test('已结束的不会被碰', () async {
      final a = await person('阿狗');
      await poop(a.id, DateTime(2026, 2, 10, 9, 0),
          end: DateTime(2026, 2, 10, 9, 14));

      await db.settleStaleRecords(now: DateTime(2026, 2, 11, 15, 0));

      final r = await db.select(db.poopRecords).getSingle();
      expect(r.endUnknown, isFalse);
      expect(r.endedAt, isNotNull);
    });

    test('没有挂起记录时不报错', () async {
      await db.settleStaleRecords(now: DateTime(2026, 2, 11));
    });
  });

  group('dayKey / parseDayKey', () {
    test('往返一致', () {
      for (final d in [
        DateTime(2026, 2, 11),
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31),
        DateTime(2024, 2, 29),
      ]) {
        expect(parseDayKey(dayKey(d)), d);
      }
    });

    test('补零到固定宽度，字典序就是时间序', () {
      expect(dayKey(DateTime(2026, 2, 1)), '2026-02-01');
      expect(dayKey(DateTime(2026, 11, 30)), '2026-11-30');
      expect(dayKey(DateTime(999, 1, 1)), '0999-01-01');

      final keys = ['2026-11-30', '2026-02-01', '2026-02-10']..sort();
      expect(keys, ['2026-02-01', '2026-02-10', '2026-11-30']);
    });
  });
}
