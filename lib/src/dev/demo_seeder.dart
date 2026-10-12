import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../data/database.dart';

/// **仅开发用**的演示数据生成器。
///
/// 存在的理由：空日历看不出对错。要验证网格行数、休/班角标、头像徽标、
/// 四种记录状态，日历上就得有真实形状的数据。
///
/// ⚠ 会**清空**现有记录与屙屎人。只在 debug 构建里挂出来。
class DemoSeeder {
  DemoSeeder(this.db, {math.Random? random})
      : _rnd = random ?? math.Random(20260211); // 固定种子，每次生成同一批

  final AppDatabase db;
  final math.Random _rnd;

  static const _names = ['我', '阿狗', '咪咪', '小土豆'];
  static const _icons = ['user', 'dog', 'cat', 'rabbit'];
  static const _notes = [
    '开冲，很顺畅',
    '昨晚火锅太辣了，有点拉肚子',
    '蹲了半天没拉出来',
    '带薪摸鱼',
    '刷手机忘了时间',
    '总算顺畅了，吃了火龙果',
    '有点干，得多喝水',
    '急，差点没赶上',
  ];

  /// 生成演示数据。[anchor] 一般是"今天"。
  Future<void> run({DateTime? anchor}) async {
    final today = anchor ?? DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    await db.transaction(() async {
      // 记录必须按顺序删：备注 → 记录 → 人（外键是 RESTRICT，不能直接删人）
      await db.delete(db.poopNotes).go();
      await db.delete(db.poopRecords).go();
      await db.delete(db.poopers).go();

      // ---- 屙屎人 ----
      final ids = <String>[];
      for (var i = 0; i < _names.length; i++) {
        final p = await db.into(db.poopers).insertReturning(
              PoopersCompanion.insert(
                name: _names[i],
                iconKey: Value(_icons[i]),
                isDefault: Value(i == 0),
                sortOrder: Value(i),
              ),
            );
        ids.add(p.id);
      }

      // ---- 记录：往前铺 60 天 ----
      // 让日历上"这个月"和"上个月"都有东西，方便翻月时看效果。
      for (var back = 0; back < 60; back++) {
        final day = todayStart.subtract(Duration(days: back));

        // 每天 0~3 次，周末略多（在家时间多）
        final weekend = day.weekday >= DateTime.saturday;
        final times = _rnd.nextInt(weekend ? 4 : 3);
        if (times == 0) continue;

        // 同一天内按时间先后排，避免插入顺序看着乱
        final minutes = <int>[];
        for (var i = 0; i < times; i++) {
          minutes.add(6 * 60 + _rnd.nextInt(16 * 60)); // 06:00 – 22:00
        }
        minutes.sort();

        for (var i = 0; i < times; i++) {
          final start = DateTime(
            day.year,
            day.month,
            day.day,
          ).add(Duration(minutes: minutes[i]));
          final who = ids[_rnd.nextInt(ids.length)];

          // 20% 概率"没记结束时间"，用来验证那个状态的样子
          final forgot = _rnd.nextDouble() < 0.20;
          final dur = 3 + _rnd.nextInt(20); // 3 – 22 分钟

          PoopRecord rec;
          try {
            rec = await db.into(db.poopRecords).insertReturning(
                  PoopRecordsCompanion.insert(
                    pooperId: who,
                    startedAt: start,
                    endedAt: forgot
                        ? const Value(null)
                        : Value(start.add(Duration(minutes: dur))),
                    endUnknown: Value(forgot),
                  ),
                );
          } on Exception {
            // 同一个人同一天不能有两条"进行中"（唯一索引），跳过
            continue;
          }

          // 40% 概率带一条备注
          if (_rnd.nextDouble() < 0.40) {
            await db.into(db.poopNotes).insert(
                  PoopNotesCompanion.insert(
                    recordId: rec.id,
                    content: _notes[_rnd.nextInt(_notes.length)],
                    notedAt: start.add(Duration(minutes: 2 + _rnd.nextInt(6))),
                  ),
                );
          }
        }
      }
    });
  }
}
