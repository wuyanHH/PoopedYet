import 'package:drift/drift.dart';

import 'database.dart';

/// 编辑一条记录的结果。
///
/// 和 [StartPoopResult] 一样做成 sealed：编辑这件事有好几种"合法但需要
/// 告诉用户"的失败（结束早于开始、目标人已经有进行中的记录），
/// 让它们变成编译器强制处理的分支，而不是冒到 UI 上的 SqliteException。
sealed class RecordEditResult {
  const RecordEditResult();

  /// 是否改成功了。
  bool get ok => this is EditOk;
}

final class EditOk extends RecordEditResult {
  const EditOk();
}

/// 结束时间早于开始时间。这个必须挡住 —— 放进去会让时长变成负数，
/// 统计里就会出现"平均时长 -3 分钟"这种东西。
final class EditEndBeforeStart extends RecordEditResult {
  const EditEndBeforeStart();
}

/// 目标屙屎人已经有一条进行中的记录了。
///
/// 由 `ux_active_record` 唯一索引保证，但那个异常不该给用户看。
final class EditPooperAlreadyActive extends RecordEditResult {
  const EditPooperAlreadyActive(this.existing);

  final PoopRecord existing;
}

/// 记录的编辑操作。
///
/// 和 `record_actions.dart`（新建 / 结束 / 删）分开：那个文件管"记录的生命周期"，
/// 这个管"改一条已经存在的记录"。混在一起会越来越难找。
extension RecordEdits on AppDatabase {
  Future<PoopRecord?> _find(String id) =>
      (select(poopRecords)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 这条记录现在算不算"进行中"。
  bool _isActive(PoopRecord r) => r.endedAt == null && !r.endUnknown;

  /// 找某个屙屎人当前进行中的记录（排除 [exceptRecordId] 自己）。
  Future<PoopRecord?> _activeFor(String pooperId, String exceptRecordId) {
    return (select(poopRecords)
          ..where(
            (t) =>
                t.pooperId.equals(pooperId) &
                t.endedAt.isNull() &
                t.endUnknown.equals(false) &
                t.id.equals(exceptRecordId).not(),
          ))
        .getSingleOrNull();
  }

  /// 改开始时间。
  ///
  /// 如果这条已经有结束时间，新开始时间不能晚于它。
  Future<RecordEditResult> updateStartedAt(String id, DateTime at) async {
    final rec = await _find(id);
    if (rec == null) return const EditOk(); // 已经被删了，当作无事发生

    final end = rec.endedAt;
    if (end != null && end.isBefore(at)) return const EditEndBeforeStart();

    await (update(poopRecords)..where((t) => t.id.equals(id)))
        .write(PoopRecordsCompanion(startedAt: Value(at)));
    return const EditOk();
  }

  /// 改结束时间。
  ///
  /// 会顺手把 `endUnknown` 清掉 —— 不变式是「有结束时间就必然不是未记结束」。
  Future<RecordEditResult> updateEndedAt(String id, DateTime at) async {
    final rec = await _find(id);
    if (rec == null) return const EditOk();
    if (at.isBefore(rec.startedAt)) return const EditEndBeforeStart();

    await (update(poopRecords)..where((t) => t.id.equals(id))).write(
      PoopRecordsCompanion(
        endedAt: Value(at),
        endUnknown: const Value(false),
      ),
    );
    return const EditOk();
  }

  /// 把一条已结束的记录**重新打开**（变回"正在屙"）。
  ///
  /// 对应视觉稿里的"清除结束时间"。这是"手滑点了结束"的补救路径，
  /// 所以要检查唯一索引 —— 这个人可能已经开了新的一条。
  Future<RecordEditResult> reopenRecord(String id) async {
    final rec = await _find(id);
    if (rec == null) return const EditOk();

    final conflict = await _activeFor(rec.pooperId, id);
    if (conflict != null) return EditPooperAlreadyActive(conflict);

    await (update(poopRecords)..where((t) => t.id.equals(id))).write(
      const PoopRecordsCompanion(
        endedAt: Value(null),
        endUnknown: Value(false),
      ),
    );
    return const EditOk();
  }

  /// 换一个人。这条记录的归属不变，只是记到别人头上。
  ///
  /// 如果这条是进行中的，目标人不能已经有进行中的记录。
  Future<RecordEditResult> changePooper(String id, String pooperId) async {
    final rec = await _find(id);
    if (rec == null) return const EditOk();
    if (rec.pooperId == pooperId) return const EditOk();

    if (_isActive(rec)) {
      final conflict = await _activeFor(pooperId, id);
      if (conflict != null) return EditPooperAlreadyActive(conflict);
    }

    await (update(poopRecords)..where((t) => t.id.equals(id)))
        .write(PoopRecordsCompanion(pooperId: Value(pooperId)));
    return const EditOk();
  }

  /// 改一条备注的内容。
  ///
  /// 空内容直接拒绝（不删）—— 想删应该点删除，而不是把内容清空留一条空备注。
  Future<bool> updateNote(String noteId, String content) async {
    final text = content.trim();
    if (text.isEmpty) return false;
    final n = await (update(poopNotes)..where((t) => t.id.equals(noteId)))
        .write(PoopNotesCompanion(content: Value(text)));
    return n > 0;
  }

  /// 改一条备注的**时刻**。
  ///
  /// 需求里备注是"带实时时间"的实体，所以时间本身也应该是可改的 ——
  /// 补记的时候经常是事后才想起来，时刻会写错。
  Future<bool> updateNoteTime(String noteId, DateTime at) async {
    final n = await (update(poopNotes)..where((t) => t.id.equals(noteId)))
        .write(PoopNotesCompanion(notedAt: Value(at)));
    return n > 0;
  }
}
