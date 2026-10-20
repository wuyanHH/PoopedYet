import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/data/database.dart';
import 'package:pooped_yet/src/data/queries.dart';
import 'package:pooped_yet/src/domain/record_state.dart';
import 'package:pooped_yet/src/state/calendar_data.dart';
import 'package:pooped_yet/src/theme/tokens.dart';
import 'package:pooped_yet/src/ui/records/record_card.dart';

/// 记录卡四种状态的**渲染契约**。
///
/// 状态判定本身在 `test/domain/record_state_test.dart` 里逐条钉死了；
/// 这里盯的是另一半：**判出来的状态有没有正确地变成用户看到的样子**。
///
/// 四种状态必须一眼分得开 —— 尤其是「未记结束」不能长得像「正在屙」，
/// 否则用户会以为记录还在跑，不去处理它。
void main() {
  final t = PoopTokens.light;
  final today = DateTime(2026, 2, 11, 15, 0);

  Pooper person({String? archived}) => Pooper(
        id: 'p1',
        name: '阿狗',
        iconKey: null,
        avatarBlob: null,
        remark: null,
        isDefault: true,
        archivedAt: archived == null ? null : DateTime(2026, 1, 1),
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      );

  RecordDetail detail({
    DateTime? startedAt,
    DateTime? endedAt,
    bool endUnknown = false,
    List<PoopNote> notes = const [],
  }) {
    return RecordDetail(
      record: PoopRecord(
        id: 'r1',
        pooperId: 'p1',
        startedAt: startedAt ?? DateTime(2026, 2, 11, 9, 12),
        endedAt: endedAt,
        endUnknown: endUnknown,
        createdAt: DateTime(2026, 2, 11, 9, 12),
      ),
      pooper: person(),
      notes: notes,
    );
  }

  Future<void> pump(WidgetTester tester, RecordDetail d) async {
    await tester.pumpWidget(
      // RecordCard 是 ConsumerStatefulWidget：它会读备注模板，把备注分成
      // 「便便感受标签」和「自定义文字备注」两类来渲染。早先还没有这层依赖，
      // 用例直接 pump 就行；现在不包 ProviderScope 会在 build 阶段抛
      // `Bad state: No ProviderScope found`，整个文件的 9 条会一起挂。
      //
      // 这里把模板 override 成空表：所有备注一律按「自定义文字备注」渲染，
      // 这些用例关心的四种状态文案就不受分类规则影响。
      ProviderScope(
        overrides: [
          noteTemplatesProvider.overrideWith((ref) => const <NoteTemplate>[]),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Theme(
              data: ThemeData(extensions: [t]),
              child: RecordCard(detail: d, now: today),
            ),
          ),
        ),
      ),
    );
    // 第二次 pump：让 FutureProvider 的首个值落地后重建一次。
    await tester.pump();
    await tester.pump();
  }

  group('正在屙', () {
    testWidgets('显示「正在屙」和实时时长', (tester) async {
      await pump(tester, detail(startedAt: DateTime(2026, 2, 11, 14, 54)));

      expect(find.text('正在屙'), findsOneWidget);
      expect(find.text('已 6 分钟'), findsOneWidget);
      expect(find.text('14:54'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('时长随时长增长（这是"实时"的含义）', (tester) async {
      await pump(tester, detail(startedAt: DateTime(2026, 2, 11, 14, 30)));
      expect(find.text('已 30 分钟'), findsOneWidget);
    });
  });

  group('待确认', () {
    testWidgets('显示「？」和停住的时长，不显示真实经过时间', (tester) async {
      // 09:12 开始，现在 15:00 —— 真实经过 5 小时 48 分
      await pump(tester, detail(startedAt: DateTime(2026, 2, 11, 9, 12)));

      expect(find.text('？'), findsOneWidget);
      expect(find.text('已超过 2 小时'), findsOneWidget,
          reason: '时长必须停在阈值，报「已 5 小时 48 分」只会让人焦虑且没信息量');
      expect(find.textContaining('5 小时'), findsNothing);
    });
  });

  group('未记结束', () {
    testWidgets('显示「未记结束」和「时长不详」，不说 0 分钟', (tester) async {
      await pump(
        tester,
        detail(startedAt: DateTime(2026, 2, 11, 9, 12), endUnknown: true),
      );

      expect(find.text('未记结束'), findsOneWidget);
      expect(find.text('时长不详'), findsOneWidget);
      expect(find.textContaining('0 分钟'), findsNothing);
    });
  });

  group('已完成', () {
    testWidgets('显示起止时刻和时长', (tester) async {
      await pump(
        tester,
        detail(
          startedAt: DateTime(2026, 2, 11, 9, 12),
          endedAt: DateTime(2026, 2, 11, 9, 26),
        ),
      );

      expect(find.text('09:12'), findsOneWidget);
      expect(find.text('09:26'), findsOneWidget);
      expect(find.text('14 分钟'), findsOneWidget);
    });
  });

  group('备注', () {
    testWidgets('多条备注各带自己的时刻，按时刻排', (tester) async {
      await pump(
        tester,
        detail(
          endedAt: DateTime(2026, 2, 11, 9, 26),
          notes: [
            PoopNote(
              id: 'n1',
              recordId: 'r1',
              content: '开冲，很顺畅',
              notedAt: DateTime(2026, 2, 11, 9, 14),
              createdAt: DateTime(2026, 2, 11, 9, 14),
            ),
            PoopNote(
              id: 'n2',
              recordId: 'r1',
              content: '昨晚火锅太辣了',
              notedAt: DateTime(2026, 2, 11, 9, 20),
              createdAt: DateTime(2026, 2, 11, 9, 20),
            ),
          ],
        ),
      );

      expect(find.text('09:14'), findsOneWidget);
      expect(find.text('开冲，很顺畅'), findsOneWidget);
      expect(find.text('09:20'), findsOneWidget);
      expect(find.text('昨晚火锅太辣了'), findsOneWidget);
    });

    testWidgets('没有备注时不画备注区', (tester) async {
      await pump(tester, detail(endedAt: DateTime(2026, 2, 11, 9, 26)));
      expect(find.text('09:14'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('已归档的人', () {
    testWidgets('卡片上标出来，但仍然显示历史', (tester) async {
      final d = RecordDetail(
        record: PoopRecord(
          id: 'r1',
          pooperId: 'p1',
          startedAt: DateTime(2026, 2, 11, 9, 12),
          endedAt: DateTime(2026, 2, 11, 9, 26),
          endUnknown: false,
          createdAt: DateTime(2026, 2, 11, 9, 12),
        ),
        pooper: person(archived: '2026-01-01'),
        notes: const [],
      );
      await pump(tester, d);

      expect(find.text('已归档'), findsOneWidget);
      expect(find.text('阿狗'), findsOneWidget, reason: '归档不是删除，历史照样看得到');
    });
  });

  group('四种状态互不混淆', () {
    testWidgets('「未记结束」和「正在屙」的文案完全不同', (tester) async {
      await pump(tester, detail(startedAt: DateTime(2026, 2, 11, 9, 12)));
      final pendingText = find.text('？');
      expect(pendingText, findsOneWidget);

      await pump(
        tester,
        detail(startedAt: DateTime(2026, 2, 11, 9, 12), endUnknown: true),
      );
      expect(find.text('？'), findsNothing, reason: '不该和待确认撞脸');
      expect(find.text('未记结束'), findsOneWidget);
    });
  });

  group('recordStateOf 与卡片一致', () {
    testWidgets('卡片渲染的状态和纯函数判定一致', (tester) async {
      for (final (rec, expected) in [
        (_rec(startedAt: DateTime(2026, 2, 11, 14, 54)), RecordState.active),
        (_rec(startedAt: DateTime(2026, 2, 11, 9, 12)), RecordState.pending),
        (_rec(endUnknown: true), RecordState.endUnknown),
        (
          _rec(endedAt: DateTime(2026, 2, 11, 9, 26)),
          RecordState.done
        ),
      ]) {
        expect(recordStateOf(rec, now: today), expected);
      }
    });
  });
}

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
