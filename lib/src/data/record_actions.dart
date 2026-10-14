import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../widget/widget_snapshot_service.dart';
import 'database.dart';
import 'queries.dart';

/// 「一键开屙」的结果。
///
/// 做成 sealed 而不是抛异常，是**逼调用方处理"这个人还在屙"的情况** ——
/// 数据库那边有 `ux_active_record` 唯一索引拦着，但那个异常不该冒到 UI 上，
/// 用户要看到的是一句人话，不是一个 SqliteException。
sealed class StartPoopResult {
  const StartPoopResult();
}

/// 开裆成功。
class StartPoopOk extends StartPoopResult {
  const StartPoopOk(this.record);
  final PoopRecord record;
}

/// 这个人（或所有人）已经有一条进行中的记录。
class StartPoopAlreadyActive extends StartPoopResult {
  const StartPoopAlreadyActive(this.existing);
  final PoopRecord existing;
}

/// 一个屙屎人都没有，而且自动建档也失败了（理论上不该发生）。
class StartPoopNoPooper extends StartPoopResult {
  const StartPoopNoPooper();
}

/// 记录的增删改。
extension RecordActions on AppDatabase {
  /// 一键开屙。
  ///
  /// [pooperId] 为 null 时用默认屙屎人。
  /// [autoSettlePrevious] 为 true 时，若存在未结束记录，自动将其收敛结束，解除卡死限制并允许立即新建。
  Future<StartPoopResult> startPoop({
    String? pooperId,
    DateTime? at,
    bool autoSettlePrevious = true,
  }) async {
    final now = at ?? DateTime.now();

    final String targetId;
    if (pooperId != null) {
      targetId = pooperId;
    } else {
      final me = await ensureDefaultPooper();
      targetId = me.id;
    }

    // 先把超过 24 小时还挂着的收敛成「未记结束」。
    await settleStaleRecords(now: now);

    final existingList = await (select(poopRecords)
          ..where(
            (t) =>
                t.pooperId.equals(targetId) &
                t.endedAt.isNull() &
                t.endUnknown.equals(false),
          ))
        .get();
    if (existingList.isNotEmpty) {
      if (autoSettlePrevious) {
        for (final existing in existingList) {
          final diff = now.difference(existing.startedAt);
          if (diff.inHours >= 1) {
            await markEndUnknown(existing.id);
          } else {
            await endPoop(existing.id, at: now);
          }
        }
      } else {
        return StartPoopAlreadyActive(existingList.first);
      }
    }

    final rec = await into(poopRecords).insertReturning(
      PoopRecordsCompanion.insert(pooperId: targetId, startedAt: now),
    );
    unawaited(WidgetSyncManager.sync(this));
    return StartPoopOk(rec);
  }

  /// 结束一次记录。
  Future<void> endPoop(String recordId, {DateTime? at}) async {
    await (update(poopRecords)..where((t) => t.id.equals(recordId))).write(
      PoopRecordsCompanion(
        endedAt: Value(at ?? DateTime.now()),
        // 不变式：有结束时间就必然不是"未记结束"
        endUnknown: const Value(false),
      ),
    );
    unawaited(WidgetSyncManager.sync(this));
  }

  /// 标记成「未记结束」。
  ///
  /// 注意会把 `endedAt` 清掉 —— 这个状态的定义就是"没有结束时间"。
  Future<void> markEndUnknown(String recordId) async {
    await (update(poopRecords)..where((t) => t.id.equals(recordId))).write(
      const PoopRecordsCompanion(
        endedAt: Value(null),
        endUnknown: Value(true),
      ),
    );
    unawaited(WidgetSyncManager.sync(this));
  }

  /// 补录一条历史记录。
  ///
  /// 补录**不碰**默认屙屎人，也不碰进行中的记录 —— 它只是往过去插一条。
  /// 所以这里不走 [startPoop] 的那套唯一性检查。
  Future<PoopRecord> addHistoricalRecord({
    required String pooperId,
    required DateTime startedAt,
    DateTime? endedAt,
    bool endUnknown = false,
  }) async {
    assert(
      !(endedAt != null && endUnknown),
      '不变式：有结束时间就不能同时是「未记结束」',
    );
    final rec = await into(poopRecords).insertReturning(
      PoopRecordsCompanion.insert(
        pooperId: pooperId,
        startedAt: startedAt,
        endedAt: Value(endedAt),
        endUnknown: Value(endUnknown),
      ),
    );
    unawaited(WidgetSyncManager.sync(this));
    return rec;
  }

  /// 加一条备注。
  Future<void> addNote(
    String recordId,
    String content, {
    DateTime? at,
  }) async {
    final text = content.trim();
    if (text.isEmpty) return;
    await into(poopNotes).insert(
      PoopNotesCompanion.insert(
        recordId: recordId,
        content: text,
        notedAt: at ?? DateTime.now(),
      ),
    );
    unawaited(WidgetSyncManager.sync(this));
  }

  /// 删一条备注。
  Future<void> deleteNote(String noteId) async {
    await (delete(poopNotes)..where((t) => t.id.equals(noteId))).go();
    unawaited(WidgetSyncManager.sync(this));
  }

  /// 删一条记录（备注会被外键级联删掉）。
  Future<void> deleteRecord(String recordId) async {
    await (delete(poopRecords)..where((t) => t.id.equals(recordId))).go();
    unawaited(WidgetSyncManager.sync(this));
  }

  /// 还原/恢复一条记录（用于撤销删除）。
  ///
  /// 会完整无损地恢复记录本身以及原本包含的所有历史备注。
  Future<void> restoreRecord(RecordDetail detail) async {
    final r = detail.record;
    await into(poopRecords).insert(
      PoopRecordsCompanion(
        id: Value(r.id),
        pooperId: Value(r.pooperId),
        startedAt: Value(r.startedAt),
        endedAt: Value(r.endedAt),
        endUnknown: Value(r.endUnknown),
        createdAt: Value(r.createdAt),
      ),
      mode: InsertMode.insertOrReplace,
    );

    for (final n in detail.notes) {
      await into(poopNotes).insert(
        PoopNotesCompanion(
          id: Value(n.id),
          recordId: Value(n.recordId),
          content: Value(n.content),
          notedAt: Value(n.notedAt),
          createdAt: Value(n.createdAt),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
    unawaited(WidgetSyncManager.sync(this));
  }

  /// 把默认备注模板的使用次数 +1。
  ///
  /// 用来让常用的往前提。先按内容找，找不到就现插一条 ——
  /// 用户手打的备注也应该沉淀成模板，下次一句话都不用打。
  Future<void> bumpNoteTemplate(String content) async {
    final text = content.trim();
    if (text.isEmpty) return;

    final existing = await (select(noteTemplates)
          ..where((t) => t.content.equals(text)))
        .getSingleOrNull();

    if (existing == null) {
      final all = await select(noteTemplates).get();
      final maxSort =
          all.isEmpty ? 0 : all.map((t) => t.sortOrder).reduce(math.max);
      await into(noteTemplates).insert(
        NoteTemplatesCompanion.insert(
          content: text,
          sortOrder: Value(maxSort + 1),
        ),
      );
      return;
    }

    await (update(noteTemplates)..where((t) => t.id.equals(existing.id)))
        .write(NoteTemplatesCompanion(useCount: Value(existing.useCount + 1)));
  }
}
