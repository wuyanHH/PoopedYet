import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/data/database.dart';
import 'package:pooped_yet/src/data/note_template_actions.dart';
import 'package:pooped_yet/src/data/pooper_actions.dart';

/// 屙屎人与备注模板的管理操作。
///
/// 重点在几个"看起来只是改个字段、其实有约束"的地方：
/// 默认人的唯一性、nullable 字段的「不改」vs「清空」、以及重名。
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
  });
  tearDown(() async => db.close());

  group('createPooper', () {
    test('第一个自动成为默认 —— 否则新建完没人可选', () async {
      final p = await db.createPooper(name: '我');
      expect(p.isDefault, isTrue);
      expect(p.sortOrder, 0);
    });

    test('第二个不自动成为默认', () async {
      await db.createPooper(name: '我');
      final b = await db.createPooper(name: '阿狗');
      expect(b.isDefault, isFalse);
      expect(b.sortOrder, 1, reason: '排在后面');
    });

    test('makeDefault: true 会把旧的默认顶掉（不撞唯一索引）', () async {
      final a = await db.createPooper(name: '我');
      final b = await db.createPooper(name: '阿狗', makeDefault: true);

      final all = await db.select(db.poopers).get();
      expect(all.where((p) => p.isDefault).single.id, b.id);
      expect(all.firstWhere((p) => p.id == a.id).isDefault, isFalse);
    });

    test('名字去空白', () async {
      final p = await db.createPooper(name: '  阿狗  ');
      expect(p.name, '阿狗');
    });

    test('空名字被拒', () async {
      expect(() => db.createPooper(name: '   '), throwsArgumentError);
    });

    test('归档的人不占 sortOrder 的号', () async {
      final a = await db.createPooper(name: '我');
      await db.createPooper(name: '阿狗');
      await db.archivePooper(a.id);

      // 剩下阿狗；新建的应排在它后面
      final c = await db.createPooper(name: '咪咪');
      expect(c.sortOrder, greaterThan(1));
    });
  });

  group('updatePooper', () {
    test('只改传进来的字段，其余不动', () async {
      final p = await db.createPooper(name: '阿狗', iconKey: 'dog', remark: '早起');

      await db.updatePooper(p.id, name: '阿狗狗');

      final after =
          await (db.select(db.poopers)..where((t) => t.id.equals(p.id)))
              .getSingle();
      expect(after.name, '阿狗狗');
      expect(after.iconKey, 'dog', reason: '没传就不该被清掉');
      expect(after.remark, '早起');
    });

    test('★ 清空要用显式开关 —— 传 null 区分不了「不改」和「清空」', () async {
      final p = await db.createPooper(name: '阿狗', iconKey: 'dog', remark: '早起');

      // 只传 name，icon 和 remark 必须原样保留
      await db.updatePooper(p.id, name: '阿狗2');
      var after = await (db.select(db.poopers)..where((t) => t.id.equals(p.id)))
          .getSingle();
      expect(after.iconKey, 'dog');
      expect(after.remark, '早起');

      // 显式清空
      await db.updatePooper(p.id, clearIcon: true, clearRemark: true);
      after = await (db.select(db.poopers)..where((t) => t.id.equals(p.id)))
          .getSingle();
      expect(after.iconKey, isNull);
      expect(after.remark, isNull);
    });

    test('换图标', () async {
      final p = await db.createPooper(name: '阿狗', iconKey: 'dog');
      await db.updatePooper(p.id, iconKey: 'cat');
      final after = await (db.select(db.poopers)..where((t) => t.id.equals(p.id)))
          .getSingle();
      expect(after.iconKey, 'cat');
    });
  });

  group('reorderPoopers', () {
    test('按给定顺序落库', () async {
      final a = await db.createPooper(name: 'A');
      final b = await db.createPooper(name: 'B');
      final c = await db.createPooper(name: 'C');

      await db.reorderPoopers([c.id, a.id, b.id]);

      final ordered = await db.activePoopers();
      expect(ordered.map((p) => p.name), ['C', 'A', 'B']);
    });

    test('空列表不报错', () async {
      await db.reorderPoopers([]);
    });
  });

  group('isNameTaken', () {
    test('自己不算占名', () async {
      final a = await db.createPooper(name: '阿狗');
      expect(await db.isNameTaken('阿狗', exceptId: a.id), isFalse);
      expect(await db.isNameTaken('阿狗'), isTrue);
      expect(await db.isNameTaken('咪咪'), isFalse);
    });

    test('空名字不算', () async {
      expect(await db.isNameTaken('  '), isFalse);
    });
  });

  group('备注模板', () {
    test('建库时已灌入默认模板', () async {
      final all = await db.select(db.noteTemplates).get();
      expect(all.map((t) => t.content), contains('拉肚子'));
    });

    test('新建排在最后', () async {
      final before = (await db.select(db.noteTemplates).get()).length;
      final t = await db.createNoteTemplate('蹲坑看剧');
      expect(t.sortOrder, before);
    });

    test('重复内容不新建，直接返回已有的', () async {
      final before = (await db.select(db.noteTemplates).get()).length;
      final t = await db.createNoteTemplate('拉肚子');
      final after = (await db.select(db.noteTemplates).get()).length;

      expect(after, before, reason: '不该多出一条一模一样的 chip');
      expect(t.content, '拉肚子');
    });

    test('空内容被拒', () async {
      expect(() => db.createNoteTemplate('  '), throwsArgumentError);
    });

    test('改内容', () async {
      final t = await db.createNoteTemplate('旧');
      expect(await db.updateNoteTemplate(t.id, '新'), isTrue);
      final after = await (db.select(db.noteTemplates)
            ..where((x) => x.id.equals(t.id)))
          .getSingle();
      expect(after.content, '新');
    });

    test('★ 改成和另一条一样会被拒 —— 否则界面上出现两条相同 chip', () async {
      final a = await db.createNoteTemplate('甲');
      final b = await db.createNoteTemplate('乙');

      expect(await db.updateNoteTemplate(b.id, '甲'), isFalse);
      final after = await (db.select(db.noteTemplates)
            ..where((x) => x.id.equals(b.id)))
          .getSingle();
      expect(after.content, '乙', reason: '拒绝了就不能改');
      expect(a.id, isNotEmpty);
    });

    test('改成自己原来的内容是允许的', () async {
      final a = await db.createNoteTemplate('甲');
      expect(await db.updateNoteTemplate(a.id, '甲'), isTrue);
    });

    test('空内容被拒', () async {
      final a = await db.createNoteTemplate('甲');
      expect(await db.updateNoteTemplate(a.id, '   '), isFalse);
    });

    test('★ 删模板不影响已经写下的备注', () async {
      final p = await db.createPooper(name: '我');
      final r = await db.into(db.poopRecords).insertReturning(
            PoopRecordsCompanion.insert(
              pooperId: p.id,
              startedAt: DateTime(2026, 10, 12, 9, 12),
            ),
          );
      await db.into(db.poopNotes).insert(
            PoopNotesCompanion.insert(
              recordId: r.id,
              content: '拉肚子',
              notedAt: DateTime(2026, 10, 12, 9, 14),
            ),
          );

      final tpl = await (db.select(db.noteTemplates)
            ..where((t) => t.content.equals('拉肚子')))
          .getSingle();
      await db.deleteNoteTemplate(tpl.id);

      expect(await db.select(db.poopNotes).get(), hasLength(1),
          reason: '备注是独立实体，删模板只是不再提供快捷入口');
    });

    test('拖拽排序', () async {
      final all = await db.select(db.noteTemplates).get();
      final reversed = all.reversed.map((t) => t.id).toList();
      await db.reorderNoteTemplates(reversed);

      final after = await (db.select(db.noteTemplates)
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();
      expect(after.first.content, all.last.content);
    });

    test('按使用次数重排（显式动作，不是自动）', () async {
      final all = await db.select(db.noteTemplates).get();
      final target = all.last;
      await (db.update(db.noteTemplates)..where((t) => t.id.equals(target.id)))
          .write(const NoteTemplatesCompanion(useCount: Value(99)));

      await db.sortNoteTemplatesByUse();

      final after = await (db.select(db.noteTemplates)
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();
      expect(after.first.id, target.id);
    });
  });
}
