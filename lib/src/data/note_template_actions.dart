import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'database.dart';

/// 默认备注模板的增删改。
///
/// 需求原文：「可以设置一些默认备注（比如拉肚子之类），也要支持手动增添」——
/// 这个文件就是那句话的后半段。
extension NoteTemplateActions on AppDatabase {
  /// 新建一条模板。内容会去空白；重复内容直接返回已有那条（不报错）。
  Future<NoteTemplate> createNoteTemplate(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) throw ArgumentError('备注内容不能为空');

    final existing = await (select(noteTemplates)
          ..where((t) => t.content.equals(trimmed)))
        .getSingleOrNull();
    if (existing != null) return existing;

    return transaction(() async {
      final all = await select(noteTemplates).get();
      final nextSort =
          all.isEmpty ? 0 : all.map((t) => t.sortOrder).reduce(math.max) + 1;

      return into(noteTemplates).insertReturning(
        NoteTemplatesCompanion.insert(
          content: trimmed,
          sortOrder: Value(nextSort),
        ),
      );
    });
  }

  /// 改内容。返回 false 表示空内容被拒绝或者这条已经没了。
  ///
  /// 改名之后**不能**和已有的另一条撞成一样，否则界面上会出现两条一模一样的 chip。
  Future<bool> updateNoteTemplate(String id, String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;

    final dup = await (select(noteTemplates)
          ..where((t) => t.content.equals(trimmed) & t.id.equals(id).not()))
        .getSingleOrNull();
    if (dup != null) return false;

    final n = await (update(noteTemplates)..where((t) => t.id.equals(id)))
        .write(NoteTemplatesCompanion(content: Value(trimmed)));
    return n > 0;
  }

  /// 删一条模板。
  ///
  /// **不影响已经写下的备注** —— 那些是独立成表的实体，
  /// 删模板只是不再提供快捷入口，历史记录一条都不会少。
  Future<void> deleteNoteTemplate(String id) async {
    await (delete(noteTemplates)..where((t) => t.id.equals(id))).go();
  }

  /// 恢复/还原一条模板（用于撤销删除）。
  Future<void> restoreNoteTemplate(NoteTemplate tpl) async {
    await into(noteTemplates).insert(
      NoteTemplatesCompanion(
        id: Value(tpl.id),
        content: Value(tpl.content),
        useCount: Value(tpl.useCount),
        sortOrder: Value(tpl.sortOrder),
        createdAt: Value(tpl.createdAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 按给定顺序重排。
  Future<void> reorderNoteTemplates(List<String> idsInOrder) async {
    await transaction(() async {
      for (var i = 0; i < idsInOrder.length; i++) {
        await (update(noteTemplates)..where((t) => t.id.equals(idsInOrder[i])))
            .write(NoteTemplatesCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// 把模板顺序恢复成"常用在前"。
  ///
  /// 用户手动排过顺序之后，`useCount` 就不该自动生效了 ——
  /// 那是两套互相打架的排序依据。所以做成一个**显式动作**，而不是后台自动重排。
  Future<void> sortNoteTemplatesByUse() async {
    await transaction(() async {
      final all = await select(noteTemplates).get();
      final sorted = [...all]
        ..sort((a, b) {
          final byUse = b.useCount.compareTo(a.useCount);
          return byUse != 0 ? byUse : a.sortOrder.compareTo(b.sortOrder);
        });
      for (var i = 0; i < sorted.length; i++) {
        await (update(noteTemplates)..where((t) => t.id.equals(sorted[i].id)))
            .write(NoteTemplatesCompanion(sortOrder: Value(i)));
      }
    });
  }
}
