import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/data/database.dart';
import 'package:pooped_yet/src/domain/record_state.dart';

/// 记录状态机。
///
/// 这块的核心是一个容易搞错的区分：**「没有结束时间」不等于「正在屙」**。
/// 不做这个区分，用户忘点一次结束，记录会永远挂在进行中，
/// 还会被 `ux_active_record` 唯一索引挡住下一次记录 —— 永久卡死。
PoopRecord _rec({
  DateTime? startedAt,
  DateTime? endedAt,
  bool endUnknown = false,
}) {
  return PoopRecord(
    id: 'r1',
    pooperId: 'p1',
    startedAt: startedAt ?? DateTime(2026, 2, 11, 9, 12),
    endedAt: endedAt,
    endUnknown: endUnknown,
    createdAt: DateTime(2026, 2, 11, 9, 12),
  );
}

void main() {
  group('recordStateOf', () {
    test('有结束时间 = 已完成，与经过多久无关', () {
      final r = _rec(endedAt: DateTime(2026, 2, 11, 9, 26));
      for (final now in [
        DateTime(2026, 2, 11, 9, 30),
        DateTime(2026, 3, 1),
        DateTime(2030, 1, 1),
      ]) {
        expect(recordStateOf(r, now: now), RecordState.done);
      }
    });

    test('endUnknown 的优先级最高', () {
      // 即使过了一个月，也不该变成 pending
      final r = _rec(endUnknown: true);
      expect(
        recordStateOf(r, now: DateTime(2026, 3, 15)),
        RecordState.endUnknown,
      );
    });

    // 不变式是 `endedAt != null ⇒ endUnknown == false`，但万一数据坏了，
    // 判定必须是确定的，不能随调用顺序变。
    test('数据坏了（两者同时存在）时判定仍然确定', () {
      final r = _rec(
        endedAt: DateTime(2026, 2, 11, 9, 26),
        endUnknown: true,
      );
      expect(recordStateOf(r, now: DateTime(2026, 2, 11, 10)), RecordState.endUnknown);
    });

    test('未结束且未超阈值 = 正在屙', () {
      final r = _rec(startedAt: DateTime(2026, 2, 11, 9, 12));
      expect(
        recordStateOf(r, now: DateTime(2026, 2, 11, 9, 13)),
        RecordState.active,
      );
      expect(
        recordStateOf(r, now: DateTime(2026, 2, 11, 11, 11)),
        RecordState.active,
      );
    });

    test('阈值边界：正好 2 小时算「待确认」（>= 而非 >）', () {
      final r = _rec(startedAt: DateTime(2026, 2, 11, 9, 0));
      expect(
        recordStateOf(r, now: DateTime(2026, 2, 11, 10, 59, 59)),
        RecordState.active,
      );
      expect(
        recordStateOf(r, now: DateTime(2026, 2, 11, 11, 0)),
        RecordState.pending,
      );
      expect(
        recordStateOf(r, now: DateTime(2026, 2, 11, 11, 0, 1)),
        RecordState.pending,
      );
    });

    test('阈值可覆盖', () {
      final r = _rec(startedAt: DateTime(2026, 2, 11, 9, 0));
      expect(
        recordStateOf(
          r,
          now: DateTime(2026, 2, 11, 9, 30),
          pendingAfter: const Duration(minutes: 20),
        ),
        RecordState.pending,
      );
    });

    test('跨零点仍然按经过时长算', () {
      final r = _rec(startedAt: DateTime(2026, 2, 11, 23, 50));
      expect(
        recordStateOf(r, now: DateTime(2026, 2, 12, 0, 30)),
        RecordState.active,
      );
      expect(
        recordStateOf(r, now: DateTime(2026, 2, 12, 5, 0)),
        RecordState.pending,
      );
    });
  });

  group('shouldAutoConverge', () {
    test('超过 24 小时才收敛', () {
      final r = _rec(startedAt: DateTime(2026, 2, 11, 9, 0));
      expect(
        shouldAutoConverge(r, now: DateTime(2026, 2, 12, 8, 59)),
        isFalse,
      );
      expect(
        shouldAutoConverge(r, now: DateTime(2026, 2, 12, 9, 0)),
        isTrue,
      );
    });

    test('已结束或已标记的不会被收敛', () {
      expect(
        shouldAutoConverge(
          _rec(endedAt: DateTime(2026, 2, 11, 9, 26)),
          now: DateTime(2030, 1, 1),
        ),
        isFalse,
      );
      expect(
        shouldAutoConverge(_rec(endUnknown: true), now: DateTime(2030, 1, 1)),
        isFalse,
      );
    });
  });

  group('durationOf', () {
    test('有结束时间才有值', () {
      expect(durationOf(_rec(endedAt: DateTime(2026, 2, 11, 9, 26))),
          const Duration(minutes: 14));
      expect(durationOf(_rec()), isNull);
      expect(durationOf(_rec(endUnknown: true)), isNull);
    });

    test('结束早于开始（数据脏）时返回 0 而不是负数', () {
      final r = _rec(
        startedAt: DateTime(2026, 2, 11, 9, 26),
        endedAt: DateTime(2026, 2, 11, 9, 12),
      );
      expect(durationOf(r), Duration.zero);
    });
  });

  group('formatDuration', () {
    test('一小时以内只报分钟', () {
      expect(formatDuration(const Duration(minutes: 0)), '0 分钟');
      expect(formatDuration(const Duration(minutes: 14)), '14 分钟');
      expect(formatDuration(const Duration(minutes: 59)), '59 分钟');
    });

    test('整点不显示「0 分」', () {
      expect(formatDuration(const Duration(hours: 1)), '1 小时');
      expect(formatDuration(const Duration(hours: 2)), '2 小时');
    });

    test('带零头', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 3)), '1 小时 3 分');
      expect(formatDuration(const Duration(hours: 3, minutes: 45)), '3 小时 45 分');
    });
  });

  group('四副面孔的文案', () {
    final started = DateTime(2026, 2, 11, 9, 12);

    test('正在屙', () {
      final r = _rec(startedAt: started);
      final now = DateTime(2026, 2, 11, 9, 18);
      expect(recordStateOf(r, now: now), RecordState.active);
      expect(durationLabel(r, now: now), '已 6 分钟');
      expect(endLabel(r, now: now), '正在屙');
    });

    test('待确认：时长必须停在阈值，不能涨到「已 8 小时」', () {
      final r = _rec(startedAt: started);
      final now = DateTime(2026, 2, 11, 17, 35); // 真实经过 8 小时 23 分
      expect(recordStateOf(r, now: now), RecordState.pending);
      expect(durationLabel(r, now: now), '已超过 2 小时');
      expect(endLabel(r, now: now), '？');
    });

    test('未记结束：说「不详」而不是「0 分钟」', () {
      final r = _rec(startedAt: started, endUnknown: true);
      expect(durationLabel(r, now: DateTime(2026, 2, 12)), '时长不详');
      expect(endLabel(r, now: DateTime(2026, 2, 12)), '未记结束');
    });

    test('已完成', () {
      final r = _rec(startedAt: started, endedAt: DateTime(2026, 2, 11, 9, 26));
      final now = DateTime(2026, 2, 11, 10);
      expect(durationLabel(r, now: now), '14 分钟');
      expect(endLabel(r, now: now), '09:26');
    });
  });

  group('hhmm', () {
    test('补零', () {
      expect(hhmm(DateTime(2026, 2, 11, 9, 5)), '09:05');
      expect(hhmm(DateTime(2026, 2, 11, 21, 5)), '21:05');
      expect(hhmm(DateTime(2026, 2, 11, 0, 0)), '00:00');
      expect(hhmm(DateTime(2026, 2, 11, 23, 59)), '23:59');
    });
  });

  group('常量取值', () {
    test('阈值是 2 小时 / 24 小时', () {
      expect(kPendingAfter, const Duration(hours: 2));
      expect(kAutoConvergeAfter, const Duration(hours: 24));
      expect(kAutoConvergeAfter, greaterThan(kPendingAfter));
    });
  });
}
