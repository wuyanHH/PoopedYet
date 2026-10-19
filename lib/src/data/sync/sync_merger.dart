import '../../domain/record_state.dart' show kPendingAfter;
import '../backup/backup_model.dart';
import 'sync_model.dart';

/// 一次合并动了哪些数据。UI 直接把它念给用户听。
///
/// `Added` = 本地原本没有、这次补进来的；
/// `Updated` = 两端都有、内容被改齐的；
/// `Deduped` = **本来会被当成新条目、被判据拦下来的**。
///
/// 第三个数字是这个功能的核心指标：它指的正是"重复数据"。
class SyncMergeStats {
  const SyncMergeStats({
    this.poopersAdded = 0,
    this.poopersUpdated = 0,
    this.poopersDeduped = 0,
    this.recordsAdded = 0,
    this.recordsUpdated = 0,
    this.recordsDeduped = 0,
    this.notesAdded = 0,
    this.notesUpdated = 0,
    this.notesDeduped = 0,
    this.templatesAdded = 0,
    this.templatesUpdated = 0,
    this.templatesDeduped = 0,
  });

  final int poopersAdded;
  final int poopersUpdated;
  final int poopersDeduped;

  final int recordsAdded;
  final int recordsUpdated;
  final int recordsDeduped;

  final int notesAdded;
  final int notesUpdated;
  final int notesDeduped;

  final int templatesAdded;
  final int templatesUpdated;
  final int templatesDeduped;

  int get added =>
      poopersAdded + recordsAdded + notesAdded + templatesAdded;

  int get updated =>
      poopersUpdated + recordsUpdated + notesUpdated + templatesUpdated;

  /// 拦下来的重复条目数。
  int get deduped =>
      poopersDeduped + recordsDeduped + notesDeduped + templatesDeduped;

  bool get isNoop => added == 0 && updated == 0 && deduped == 0;

  /// 一句人话，给 SnackBar / 状态行直接用。
  String get summary {
    final parts = <String>[];
    if (added > 0) parts.add('新增 $added 项');
    if (updated > 0) parts.add('对齐 $updated 项');
    if (deduped > 0) parts.add('识别重复 $deduped 项');
    if (parts.isEmpty) return '两端已完全一致，无需改动';
    return parts.join('，');
  }
}

/// 合并的完整产物。
class SyncMergeResult {
  const SyncMergeResult({
    required this.snapshot,
    required this.poopersToWrite,
    required this.recordsToWrite,
    required this.notesToWrite,
    required this.templatesToWrite,
    required this.recordIdsToDelete,
    required this.noteIdsToDelete,
    required this.templateIdsToDelete,
    required this.stats,
  });

  /// 合并后的**全量真相**，用于回写云端。
  final SyncSnapshot snapshot;

  /// 本地需要落库的增量（只含真正有变化的条目，不是全量）。
  final List<BackupPooper> poopersToWrite;
  final List<BackupRecord> recordsToWrite;
  final List<BackupNote> notesToWrite;
  final List<BackupNoteTemplate> templatesToWrite;

  /// 本地需要**清掉**的重复条目 id。
  ///
  /// 只包含"本地确实存在、且被判据证实与另一条是同一次拉屎"的记录。
  /// 本地历史脏数据（反复"彻底覆盖"还原留下的重复）靠它清干净 ——
  /// 不清理的话，这些重复每次都会被重新算出来、推到云端，
  /// 别的设备拉下去又变成新的重复，重复会在设备之间繁殖。
  final List<String> recordIdsToDelete;
  final List<String> noteIdsToDelete;
  final List<String> templateIdsToDelete;

  final SyncMergeStats stats;

  bool get hasLocalWrites =>
      poopersToWrite.isNotEmpty ||
      recordsToWrite.isNotEmpty ||
      notesToWrite.isNotEmpty ||
      templatesToWrite.isNotEmpty;

  bool get hasLocalDeletes =>
      recordIdsToDelete.isNotEmpty ||
      noteIdsToDelete.isNotEmpty ||
      templateIdsToDelete.isNotEmpty;

  bool get hasAnyLocalChange => hasLocalWrites || hasLocalDeletes;
}

/// 双向合并引擎。
///
/// **这是一个纯函数**：给定本地快照与云端快照，算出唯一确定的结果。
/// 不碰数据库、不碰网络、不看时钟（除了判定"进行中"是否还新鲜）。
///
/// 之所以坚持纯函数，是因为多端同步最容易翻车的地方就是
/// **两台设备各算各的、算出两个不同结果**，于是云端文件在两端之间
/// 来回翻转，每次同步都"看起来有变化"，永远收敛不了。
/// 只要合并规则只依赖输入内容、不依赖"我是谁"，两端必然算出同一份结果。
///
/// ## 判据
///
/// 识别"这已经是同一条了"分两级，顺序不能换：
///
/// 1. **UUID 精确命中** —— 同一条数据在另一端被编辑过，这是最准的信号。
/// 2. **内容指纹兜底** —— id 对不上（两台设备各自新建的同一次拉屎），
///    退一步按业务语义认：成员 + 开始时刻（秒级）。
///
/// 第 2 级是这个功能能不能用的关键。没有它，同一台手机和另一台手机
/// 各记一次同样的拉屎，合并后就是**两条**，而且会随着每次同步继续繁殖。
abstract final class SyncMerger {
  // ==========================================================================
  //  主入口
  // ==========================================================================

  /// 把本地快照与云端快照合并成一份唯一确定的结果。
  ///
  /// [now] 只用于判定"进行中的记录是不是刚开的"，测试时可注入。
  static SyncMergeResult merge({
    required SyncSnapshot local,
    required SyncSnapshot remote,
    DateTime? now,
  }) {
    final nowTs = now ?? DateTime.now();

    // 被**判据**拦下来的重复条目数（按 UUID 命中的不算功劳，
    // 那是"同一条被编辑"，每次同步都会发生，算进去数字会虚高到没意义）。
    var dedupedPoopers = 0;
    var dedupedRecords = 0;
    var dedupedNotes = 0;
    var dedupedTemplates = 0;

    // ======================================================================
    //  阶段 A —— 人员
    // ======================================================================

    final localPooperById = <String, BackupPooper>{
      for (final p in local.poopers) p.id: p,
    };

    final localPoopersByName = <String, List<BackupPooper>>{};
    for (final p in local.poopers) {
      localPoopersByName.putIfAbsent(_normalizeName(p.name), () => []).add(p);
    }

    final canonicalPoopers = <String, BackupPooper>{
      for (final p in local.poopers) p.id: p,
    };

    /// 云端人员 id → 本地规范 id。
    final pooperRemap = <String, String>{};

    /// 本轮已经被某个云端人员认领过的本地人员。
    final claimedLocalPooperIds = <String>{};

    for (final rp in remote.poopers) {
      BackupPooper? match = localPooperById[rp.id];

      if (match == null) {
        // id 对不上（两台设备各自建了"我"），退一步按**姓名**认人。
        //
        // 但只在本地同名者**唯一**、且本轮还没被别的云端人员认领时才敢认：
        // 本地本来就有两个"老王"的话，随便认一个就是把两个人的记录搅在一起，
        // 那比不合并严重得多 —— 宁可多出一个成员让用户自己去删。
        final candidates =
            localPoopersByName[_normalizeName(rp.name)] ?? const <BackupPooper>[];
        if (candidates.length == 1 &&
            !claimedLocalPooperIds.contains(candidates.first.id)) {
          match = candidates.first;
        }
      }

      if (match == null) {
        // 云端独有的新成员：原样接纳，保留云端 id。
        pooperRemap[rp.id] = rp.id;
        canonicalPoopers.putIfAbsent(rp.id, () => rp);
        continue;
      }

      if (localPooperById[rp.id] == null) dedupedPoopers++;
      claimedLocalPooperIds.add(match.id);
      pooperRemap[rp.id] = match.id;
      canonicalPoopers[match.id] = _mergePooper(
        local: canonicalPoopers[match.id] ?? match,
        remote: rp,
      );
    }

    // ======================================================================
    //  阶段 B —— 打卡记录
    // ======================================================================

    final localRecordById = <String, BackupRecord>{
      for (final r in local.records) r.id: r,
    };

    final localRecordsByFp = <String, List<BackupRecord>>{};
    for (final r in local.records) {
      localRecordsByFp
          .putIfAbsent(_recordFingerprint(r.pooperId, r.startedAt), () => [])
          .add(r);
    }

    final canonicalRecords = <String, BackupRecord>{
      for (final r in local.records) r.id: r,
    };

    /// 云端记录 id → 规范 id。
    final recordRemap = <String, String>{};

    for (final raw in remote.records) {
      // 云端记录引用的成员得先能落到本地。落不到就整条跳过 ——
      // 宁可少一条，也不要写出一条外键悬空的记录（那会让整批写入失败）。
      final pooperId = pooperRemap[raw.pooperId] ?? raw.pooperId;
      if (!canonicalPoopers.containsKey(pooperId)) continue;

      final rr = _recordWith(raw, pooperId: pooperId);
      final byId = localRecordById[rr.id];
      BackupRecord? match = byId;

      if (match == null) {
        // 同一个人、同一秒开始 ⇒ 同一次拉屎。
        // 人不可能在同一秒开始拉两次，所以这个判据不会误伤真的两次记录；
        // 而**刻意不含结束时刻** —— 两端各自补记结束时必然不同，
        // 把它算进指纹，同一次拉屎就会被当成两条，正是要防的重复。
        final candidates = localRecordsByFp[_recordFingerprint(pooperId, rr.startedAt)];
        if (candidates != null && candidates.isNotEmpty) {
          match = candidates.first;
        }
      }

      if (match == null) {
        recordRemap[rr.id] = rr.id;
        canonicalRecords.putIfAbsent(rr.id, () => rr);
        continue;
      }

      if (byId == null) dedupedRecords++;
      recordRemap[rr.id] = match.id;
      canonicalRecords[match.id] = _mergeRecord(
        local: canonicalRecords[match.id] ?? match,
        remote: rr,
        now: nowTs,
      );
    }

    // ======================================================================
    //  阶段 C —— 把记录再收一遍
    // ======================================================================

    // 走到这里，两边交叉产生的重复已经没了。但**本地历史脏数据**还可能有：
    // 反复用"彻底覆盖"和"增量合并"来回还原、或者早年间写入的重复条目。
    //
    // 这些要是被原样上传，别的设备拉下去就变成新的重复 ——
    // 重复会在设备之间**繁殖**，这是最坏的一种 bug。
    //
    // 所以这里按指纹再收敛一次，同指纹只留 **id 字典序最小**的那条。
    // 用 id 排序而不是"留本地"，是为了让两台设备算出同一个结果；
    // 否则云端会在两个 id 之间来回翻转，永远同步不完。
    final recordsByFp = <String, BackupRecord>{};
    final recordDedupeRemap = <String, String>{};

    for (final r in canonicalRecords.values) {
      final fp = _recordFingerprint(r.pooperId, r.startedAt);
      final kept = recordsByFp[fp];
      if (kept == null) {
        recordsByFp[fp] = r;
        continue;
      }
      final keepFirst = kept.id.compareTo(r.id) <= 0;
      final keep = keepFirst ? kept : r;
      final drop = keepFirst ? r : kept;
      recordsByFp[fp] = _mergeRecord(local: keep, remote: drop, now: nowTs);
      recordDedupeRemap[drop.id] = keep.id;
    }

    /// 云端 id / 本地旧 id → 最终规范 id（先过阶段 B，再过阶段 C）。
    String resolveRecordId(String id) {
      var cur = recordRemap[id] ?? id;
      var guard = 0;
      while (recordDedupeRemap.containsKey(cur) && guard++ < 16) {
        cur = recordDedupeRemap[cur]!;
      }
      return cur;
    }

    // ======================================================================
    //  阶段 D —— 备注
    // ======================================================================

    // 本地备注引用的记录可能刚刚在阶段 C 被判重吞掉了，先跟着改嫁到权威记录上。
    final normalizedLocalNotes = <BackupNote>[];
    for (final n in local.notes) {
      final rid = resolveRecordId(n.recordId);
      if (!recordsByFp.containsKey(rid)) continue;
      normalizedLocalNotes.add(rid == n.recordId ? n : _noteWith(n, recordId: rid));
    }

    // 注意这里存的是**原始**本地备注（没有经过 recordId 改嫁）。
    // 后面要用它判断"这条备注到底要不要写回数据库"：如果拿改嫁后的版本去比，
    // 被改嫁过的备注会被误判成"和本地一样、没变化"而漏写，
    // 数据库里就留下指向已消失记录的悬空外键。
    final localNoteById = <String, BackupNote>{
      for (final n in local.notes) n.id: n,
    };

    final localNotesByFp = <String, List<BackupNote>>{};
    for (final n in normalizedLocalNotes) {
      localNotesByFp
          .putIfAbsent(_noteFingerprint(n.recordId, n.notedAt, n.content), () => [])
          .add(n);
    }

    final canonicalNotes = <String, BackupNote>{
      for (final n in normalizedLocalNotes) n.id: n,
    };

    for (final raw in remote.notes) {
      final recordId = resolveRecordId(raw.recordId);
      // 云端备注挂着的记录不在合并结果里（孤儿备注）→ 丢弃，
      // 不制造挂空的外键。
      if (!recordsByFp.containsKey(recordId)) continue;

      final rn = _noteWith(raw, recordId: recordId);
      final byId = localNoteById[rn.id];
      BackupNote? match = byId;

      if (match == null) {
        final candidates =
            localNotesByFp[_noteFingerprint(recordId, rn.notedAt, rn.content)];
        if (candidates != null && candidates.isNotEmpty) {
          match = candidates.first;
        }
      }

      if (match == null) {
        canonicalNotes.putIfAbsent(rn.id, () => rn);
        continue;
      }

      if (byId == null) dedupedNotes++;
      canonicalNotes[match.id] = _mergeNote(
        local: canonicalNotes[match.id] ?? match,
        remote: rn,
      );
    }

    // 备注也收一遍：同一条记录上、同一秒写下的同一句话，只留一条。
    final notesByFp = <String, BackupNote>{};
    final noteDedupeRemap = <String, String>{};
    for (final n in canonicalNotes.values) {
      final fp = _noteFingerprint(n.recordId, n.notedAt, n.content);
      final kept = notesByFp[fp];
      if (kept == null) {
        notesByFp[fp] = n;
        continue;
      }
      final keepFirst = kept.id.compareTo(n.id) <= 0;
      final keep = keepFirst ? kept : n;
      final drop = keepFirst ? n : kept;
      notesByFp[fp] = _mergeNote(local: keep, remote: drop);
      noteDedupeRemap[drop.id] = keep.id;
    }

    // ======================================================================
    //  阶段 E —— 备注模板
    // ======================================================================

    final localTemplateById = <String, BackupNoteTemplate>{
      for (final t in local.templates) t.id: t,
    };

    final localTemplatesByContent = <String, List<BackupNoteTemplate>>{};
    for (final t in local.templates) {
      localTemplatesByContent
          .putIfAbsent(_normalizeContent(t.content), () => [])
          .add(t);
    }

    final canonicalTemplates = <String, BackupNoteTemplate>{
      for (final t in local.templates) t.id: t,
    };

    for (final rt in remote.templates) {
      final byId = localTemplateById[rt.id];
      BackupNoteTemplate? match = byId;

      if (match == null) {
        // 模板在用户眼里就是"一句话"，没有 id 语义，所以直接按内容认。
        final candidates = localTemplatesByContent[_normalizeContent(rt.content)];
        if (candidates != null && candidates.length == 1) {
          match = candidates.first;
        }
      }

      if (match == null) {
        canonicalTemplates.putIfAbsent(rt.id, () => rt);
        continue;
      }

      if (byId == null) dedupedTemplates++;
      canonicalTemplates[match.id] = _mergeTemplate(
        local: canonicalTemplates[match.id] ?? match,
        remote: rt,
      );
    }

    // 本地同一个内容的模板也收一遍（老版本的增量合并按内容去重，
    // 但"彻底覆盖"路径是按 id 直插的，可能留下同内容两条）。
    final templatesByContent = <String, BackupNoteTemplate>{};
    final templateDedupeRemap = <String, String>{};
    for (final t in canonicalTemplates.values) {
      final key = _normalizeContent(t.content);
      final kept = templatesByContent[key];
      if (kept == null) {
        templatesByContent[key] = t;
        continue;
      }
      final keepFirst = kept.id.compareTo(t.id) <= 0;
      final keep = keepFirst ? kept : t;
      final drop = keepFirst ? t : kept;
      templatesByContent[key] = _mergeTemplate(local: keep, remote: drop);
      templateDedupeRemap[drop.id] = keep.id;
    }

    // ======================================================================
    //  阶段 F —— 收敛两个数据库层面的不变式
    // ======================================================================

    // ---- F1：全局恰好一个默认成员 ----------------------------------------
    //
    // 数据库上有 `ux_default_pooper` 部分唯一索引，两个 is_default=1 直接写不进去。
    // 合并时两边各自带着自己的默认，OR 起来必然是多个，必须收敛。
    final pooperList = canonicalPoopers.values.toList()
      ..sort((a, b) {
        final bySort = a.sortOrder.compareTo(b.sortOrder);
        if (bySort != 0) return bySort;
        final byCreated = a.createdAt.compareTo(b.createdAt);
        if (byCreated != 0) return byCreated;
        return a.id.compareTo(b.id);
      });

    String? defaultPooperId;

    // 本机认定的默认优先保留：默认成员是"这台手机一键开屙记给谁"的偏好，
    // 不该被另一台设备的习惯改掉。
    for (final p in pooperList) {
      if (p.isDefault && p.archivedAt == null && localPooperById.containsKey(p.id)) {
        defaultPooperId = p.id;
        break;
      }
    }
    // 本机没有默认（比如新设备首次同步）才接受云端的。
    if (defaultPooperId == null) {
      for (final rp in remote.poopers) {
        if (!rp.isDefault) continue;
        final mapped = pooperRemap[rp.id] ?? rp.id;
        final candidate = canonicalPoopers[mapped];
        if (candidate != null && candidate.archivedAt == null) {
          defaultPooperId = mapped;
          break;
        }
      }
    }
    // 两边都没有活跃默认（默认那位被归档了）→ 按稳定顺序取第一个在用的。
    defaultPooperId ??= pooperList
        .where((p) => p.archivedAt == null)
        .map((p) => p.id)
        .firstOrNullOf();

    final finalPoopers = <BackupPooper>[
      for (final p in pooperList) _pooperWith(p, isDefault: p.id == defaultPooperId),
    ];

    // ---- F2：同一成员至多一条"正在进行中" --------------------------------
    //
    // `ux_active_record` 部分唯一索引只允许一个人有一条 ended_at IS NULL
    // 且 end_unknown = 0 的记录。两台设备各自开着计时再合并，必然撞上。
    final liveByPooper = <String, List<BackupRecord>>{};
    for (final r in recordsByFp.values) {
      if (r.endedAt != null || r.endUnknown) continue;
      if (!canonicalPoopers.containsKey(r.pooperId)) continue;
      liveByPooper.putIfAbsent(r.pooperId, () => []).add(r);
    }

    final finalRecordsById = <String, BackupRecord>{
      for (final r in recordsByFp.values) r.id: r,
    };

    for (final entry in liveByPooper.entries) {
      if (entry.value.length < 2) continue;
      // 谁的开始时间**最晚**，谁就是"当下真的在屙"的那条，早先那条多半是忘了点结束。
      //
      // 用"最晚"而不是"最早"是刻意的：刚点开的那条是用户此刻的意图，
      // 把它标成"未记结束"会让人以为计时丢了，那是这个 App 最不能出的体验事故。
      final sorted = [...entry.value]
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      for (final loser in sorted.skip(1)) {
        finalRecordsById[loser.id] = _recordWith(
          loser,
          endUnknown: true,
          clearEndedAt: true,
        );
      }
    }

    // ======================================================================
    //  阶段 G —— 算出本地要写什么
    // ======================================================================

    // 外键悬空的记录一律不进入结果：它们既写不进库，也不该被推到云端。
    final finalRecordList = finalRecordsById.values
        .where((r) => canonicalPoopers.containsKey(r.pooperId))
        .toList()
      ..sort((a, b) {
        final byStarted = b.startedAt.compareTo(a.startedAt);
        return byStarted != 0 ? byStarted : a.id.compareTo(b.id);
      });

    final writableRecordIds = <String>{for (final r in finalRecordList) r.id};

    final finalNoteList = notesByFp.values
        .where((n) => writableRecordIds.contains(n.recordId))
        .toList()
      ..sort((a, b) {
        final byNoted = a.notedAt.compareTo(b.notedAt);
        return byNoted != 0 ? byNoted : a.id.compareTo(b.id);
      });

    final finalTemplateList = templatesByContent.values.toList()
      ..sort((a, b) {
        final bySort = a.sortOrder.compareTo(b.sortOrder);
        if (bySort != 0) return bySort;
        final byCreated = a.createdAt.compareTo(b.createdAt);
        return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
      });

    final poopersToWrite = <BackupPooper>[
      for (final p in finalPoopers)
        if (localPooperById[p.id] == null ||
            !_samePooperPayload(localPooperById[p.id]!, p))
          p,
    ];

    final recordsToWrite = <BackupRecord>[
      for (final r in finalRecordList)
        if (localRecordById[r.id] == null ||
            !_sameRecordPayload(localRecordById[r.id]!, r))
          r,
    ];

    final notesToWrite = <BackupNote>[
      for (final n in finalNoteList)
        if (localNoteById[n.id] == null ||
            !_sameNotePayload(localNoteById[n.id]!, n))
          n,
    ];

    final templatesToWrite = <BackupNoteTemplate>[
      for (final t in finalTemplateList)
        if (localTemplateById[t.id] == null ||
            !_sameTemplatePayload(localTemplateById[t.id]!, t))
          t,
    ];

    // ======================================================================
    //  统计
    // ======================================================================

    final stats = SyncMergeStats(
      poopersAdded:
          finalPoopers.where((p) => localPooperById[p.id] == null).length,
      poopersUpdated: poopersToWrite
          .where((p) => localPooperById.containsKey(p.id))
          .length,
      poopersDeduped: dedupedPoopers,
      recordsAdded:
          finalRecordList.where((r) => localRecordById[r.id] == null).length,
      recordsUpdated: recordsToWrite
          .where((r) => localRecordById.containsKey(r.id))
          .length,
      recordsDeduped: dedupedRecords,
      notesAdded: finalNoteList.where((n) => localNoteById[n.id] == null).length,
      notesUpdated:
          notesToWrite.where((n) => localNoteById.containsKey(n.id)).length,
      notesDeduped: dedupedNotes,
      templatesAdded:
          finalTemplateList.where((t) => localTemplateById[t.id] == null).length,
      templatesUpdated: templatesToWrite
          .where((t) => localTemplateById.containsKey(t.id))
          .length,
      templatesDeduped: dedupedTemplates,
    );

    // 本地存在、且被更强的那一条取代的重复条目，交给落库环节清掉。
    //
    // 只删"本地本来就有"的：云端刚带来的记录即使被判重，
    // 它本来也没进过本地库，不在这个名单里，不该也无从可删。
    final recordIdsToDelete = <String>[
      for (final id in recordDedupeRemap.keys)
        if (localRecordById.containsKey(id)) id,
    ];
    final noteIdsToDelete = <String>[
      for (final id in noteDedupeRemap.keys)
        if (localNoteById.containsKey(id)) id,
    ];
    final templateIdsToDelete = <String>[
      for (final id in templateDedupeRemap.keys)
        if (localTemplateById.containsKey(id)) id,
    ];

    return SyncMergeResult(
      snapshot: SyncSnapshot(
        poopers: finalPoopers,
        records: finalRecordList,
        notes: finalNoteList,
        templates: finalTemplateList,
      ),
      poopersToWrite: poopersToWrite,
      recordsToWrite: recordsToWrite,
      notesToWrite: notesToWrite,
      templatesToWrite: templatesToWrite,
      recordIdsToDelete: recordIdsToDelete,
      noteIdsToDelete: noteIdsToDelete,
      templateIdsToDelete: templateIdsToDelete,
      stats: stats,
    );
  }

  // ==========================================================================
  //  内容指纹：判断"云端是不是已经和我这边一致"
  // ==========================================================================

  /// 一份快照的**业务内容指纹**。
  ///
  /// 用来回答唯一一个问题：这次合并出来的结果，和云端现存的那份**在业务上**
  /// 是不是同一份？如果一致就不用上传 —— 这是避免"同步风暴"的闸门。
  ///
  /// 刻意**不含 id**：id 是每台设备各自生成的 uuid，跨设备必然不同。
  /// 把它算进去，A 和 B 对同一份数据算出的指纹永远不相等，
  /// 于是两台设备**永远觉得对方有新数据**，每次同步都上传一遍，没完没了。
  /// 这是多端同步最经典的翻车方式，第一版就必须避开。
  ///
  /// 也**不含 isDefault / sortOrder**：这两个是本机偏好（默认记给谁、成员怎么排），
  /// 不该因为另一台设备排序不同就触发上传。
  ///
  /// 但**必须含 endedAt / endUnknown**：用户点"结束"这个动作是要传出去的，
  /// 不然另一台设备永远显示"正在进行中"。
  ///
  /// 引用其他实体时一律用**业务 key**（成员名、成员名+开始时刻）而不是 id，
  /// 理由同上。
  static String contentFingerprint(SyncSnapshot snapshot) {
    final pooperKeyById = <String, String>{};
    for (final p in snapshot.poopers) {
      pooperKeyById[p.id] = _normalizeName(p.name);
    }

    final recordKeyById = <String, String>{};
    for (final r in snapshot.records) {
      final pooperKey = pooperKeyById[r.pooperId] ?? '?';
      recordKeyById[r.id] = '$pooperKey#${_epochSeconds(r.startedAt)}';
    }

    final parts = <String>[
      for (final p in snapshot.poopers)
        'P|${_normalizeName(p.name)}|${p.iconKey ?? ''}|'
            '${p.archivedAt == null ? 0 : 1}|${p.avatarBlobBase64 ?? ''}|'
            '${p.remark ?? ''}',
      for (final r in snapshot.records)
        'R|${recordKeyById[r.id]}|'
            '${r.endedAt == null ? -1 : _epochSeconds(r.endedAt!)}|'
            '${r.endUnknown ? 1 : 0}',
      for (final n in snapshot.notes)
        'N|${recordKeyById[n.recordId] ?? '?'}|'
            '${_epochSeconds(n.notedAt)}|${n.content}',
      for (final t in snapshot.templates)
        'T|${_normalizeContent(t.content)}|${t.useCount}',
    ];

    // 顺序无关：同一个集合必须得到同一个指纹，
    // 否则两端列表顺序不同就会被误判成"有变化"。
    parts.sort();
    return parts.join('\n');
  }

  /// 两份快照在业务上是否等价（可以据此跳过上传）。
  static bool isEquivalent(SyncSnapshot a, SyncSnapshot b) =>
      contentFingerprint(a) == contentFingerprint(b);
}

// ============================================================================
//  逐字段合并规则
// ============================================================================

/// 合并同一个人的两份记录。
///
/// 逐字段取"信息更多"的那一边，而不是简单地"谁后到用谁的" ——
/// 另一端可能只是没填头像/备注，不该把已有的抹掉。
BackupPooper _mergePooper({
  required BackupPooper local,
  required BackupPooper remote,
}) {
  final localName = local.name.trim();
  return BackupPooper(
    // id 收敛到本地那个：跨设备的 uuid 必须归一，本地优先是最稳的解法。
    id: local.id,
    name: localName.isEmpty ? remote.name : local.name,
    iconKey: _firstNonEmpty(local.iconKey, remote.iconKey),
    avatarBlobBase64: local.avatarBlobBase64 ?? remote.avatarBlobBase64,
    remark: _firstNonEmpty(local.remark, remote.remark),
    isDefault: local.isDefault || remote.isDefault,
    // 归档状态：**只要有一边没归档就保持没归档**。
    // 归档的语义是"收起来不用了"，另一端还在往这个人身上记，
    // 说明他显然没被忘掉 —— 让云端的旧归档状态把他藏起来，
    // 在本机用户看来就是"人凭空消失了"。
    archivedAt: local.archivedAt == null || remote.archivedAt == null
        ? null
        : (local.archivedAt!.isBefore(remote.archivedAt!)
            ? local.archivedAt
            : remote.archivedAt),
    sortOrder: local.sortOrder,
    createdAt: local.createdAt.isBefore(remote.createdAt)
        ? local.createdAt
        : remote.createdAt,
  );
}

/// 合并同一次拉屎的两份记录。
///
/// 状态收敛是这里唯一的难点，见下面分支注释。
BackupRecord _mergeRecord({
  required BackupRecord local,
  required BackupRecord remote,
  required DateTime now,
}) {
  final localLive = local.endedAt == null && !local.endUnknown;
  final remoteLive = remote.endedAt == null && !remote.endUnknown;

  DateTime? endedAt;
  var endUnknown = false;

  if (local.endedAt != null || remote.endedAt != null) {
    // 只要有一边记了结束时刻，就以它为准：**结束是一个用户动作**，
    // 做过的动作不会因为另一端还没做就变得没做过。
    //
    // 两边都记了的话取**更早**的那个。取早不取晚是刻意的：
    // 一次拉屎的时长不该因为另一台设备手滑而凭空变长；
    // 而且 min 是对称且幂等的，两端必然收敛到同一个值。
    endedAt = _earliestNonNull([local.endedAt, remote.endedAt]);
    endUnknown = false;
  } else if (localLive != remoteLive) {
    // 一边还在屙，另一边已经明确表过态"没记结束"。
    final live = localLive ? local : remote;
    final fresh = now.difference(live.startedAt) < kPendingAfter;
    if (fresh) {
      // 刚开的计时是真的在进行中，不能被另一端一句"未记结束"抹掉 ——
      // 用户会以为自己刚点的开屙丢了。
      endedAt = null;
      endUnknown = false;
    } else {
      // 挂了超过 2 小时的"进行中"，本机自己也会自动收敛
      //（见 shouldAutoConverge），这时候接受另一端的明确结论，
      // 别让它跨设备永远挂着。
      endedAt = null;
      endUnknown = true;
    }
  } else {
    // 两边都没有结束时刻：要么都是"进行中"，要么都是"未记结束"。
    // OR 是幂等的，重复同步不会把状态越改越偏。
    endedAt = null;
    endUnknown = local.endUnknown || remote.endUnknown;
  }

  return BackupRecord(
    id: local.id,
    pooperId: local.pooperId,
    startedAt: local.startedAt,
    endedAt: endedAt,
    endUnknown: endUnknown,
    createdAt: local.createdAt.isBefore(remote.createdAt)
        ? local.createdAt
        : remote.createdAt,
  );
}

/// 合并同一条备注的两份记录。
BackupNote _mergeNote({required BackupNote local, required BackupNote remote}) {
  final localContent = local.content.trim();
  final remoteContent = remote.content.trim();
  return BackupNote(
    id: local.id,
    recordId: local.recordId,
    // 内容取更长的：备注是手打的，长的那条通常包含短的那条的信息
    //（"顺畅" → "顺畅，昨晚吃了火龙果"）。取短的就是在丢用户写下的字。
    content: remoteContent.length > localContent.length
        ? remote.content
        : local.content,
    notedAt: local.notedAt.isBefore(remote.notedAt)
        ? local.notedAt
        : remote.notedAt,
    createdAt: local.createdAt.isBefore(remote.createdAt)
        ? local.createdAt
        : remote.createdAt,
  );
}

/// 合并同一个模板的两份记录。
BackupNoteTemplate _mergeTemplate({
  required BackupNoteTemplate local,
  required BackupNoteTemplate remote,
}) {
  return BackupNoteTemplate(
    id: local.id,
    content: local.content,
    // 用 max 而**不是相加**：同步会被自动触发（启动、回前台、写完防抖），
    // 相加的话每同步一次使用次数就翻一倍，"常用"排序几天就彻底失真。
    // max 是幂等的 —— 同步一次和同步一百次结果完全一样。
    useCount: local.useCount > remote.useCount ? local.useCount : remote.useCount,
    sortOrder: local.sortOrder < remote.sortOrder
        ? local.sortOrder
        : remote.sortOrder,
    createdAt: local.createdAt.isBefore(remote.createdAt)
        ? local.createdAt
        : remote.createdAt,
  );
}

// ============================================================================
//  载荷比较：决定"这条到底要不要写回本地"
// ============================================================================

// 注意这几个比较**不包含 isDefault / sortOrder** ——
// 那两个是本机偏好，由阶段 F1 单独统一设置，不走增量写入。
bool _samePooperPayload(BackupPooper a, BackupPooper b) =>
    a.name == b.name &&
    a.iconKey == b.iconKey &&
    a.avatarBlobBase64 == b.avatarBlobBase64 &&
    a.remark == b.remark &&
    (a.archivedAt == null) == (b.archivedAt == null);

bool _sameRecordPayload(BackupRecord a, BackupRecord b) =>
    a.pooperId == b.pooperId &&
    _epochSeconds(a.startedAt) == _epochSeconds(b.startedAt) &&
    _epochSecondsOrNull(a.endedAt) == _epochSecondsOrNull(b.endedAt) &&
    a.endUnknown == b.endUnknown;

bool _sameNotePayload(BackupNote a, BackupNote b) =>
    a.recordId == b.recordId &&
    a.content == b.content &&
    _epochSeconds(a.notedAt) == _epochSeconds(b.notedAt);

bool _sameTemplatePayload(BackupNoteTemplate a, BackupNoteTemplate b) =>
    _normalizeContent(a.content) == _normalizeContent(b.content) &&
    a.useCount == b.useCount;

// ============================================================================
//  指纹与工具
// ============================================================================

/// 记录指纹：**同一个人 + 同一秒开始 ⇒ 同一次拉屎**。
///
/// 刻意不含结束时刻（理由见 `merge` 阶段 B 的注释）。
String _recordFingerprint(String pooperId, DateTime startedAt) =>
    '$pooperId#${_epochSeconds(startedAt)}';

/// 备注指纹：挂在同一条记录上、同一秒写下、内容相同 ⇒ 同一条备注。
String _noteFingerprint(String recordId, DateTime notedAt, String content) =>
    '$recordId#${_epochSeconds(notedAt)}#${_normalizeContent(content)}';

/// 归一化到**秒**。
///
/// 必须归一到秒：SQLite 里 DateTime 是按秒存的，写进库再读出来毫秒就没了。
/// 不归一的话，"刚从内存里取出来的记录"和"从库里读出来的同一条记录"
/// 会因为毫秒差异被判成两条，平白制造重复。
int _epochSeconds(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;

int? _epochSecondsOrNull(DateTime? dt) => dt == null ? null : _epochSeconds(dt);

String _normalizeName(String name) => name.trim().toLowerCase();

String _normalizeContent(String content) => content.trim();

String? _firstNonEmpty(String? a, String? b) {
  if (a != null && a.trim().isNotEmpty) return a;
  if (b != null && b.trim().isNotEmpty) return b;
  return a ?? b;
}

DateTime? _earliestNonNull(List<DateTime?> values) {
  DateTime? best;
  for (final v in values) {
    if (v == null) continue;
    if (best == null || v.isBefore(best)) best = v;
  }
  return best;
}

// ---- 复制构造（Backup* 系列是 const 类，没有 copyWith）----

BackupPooper _pooperWith(BackupPooper p, {required bool isDefault}) =>
    BackupPooper(
      id: p.id,
      name: p.name,
      iconKey: p.iconKey,
      avatarBlobBase64: p.avatarBlobBase64,
      remark: p.remark,
      isDefault: isDefault,
      archivedAt: p.archivedAt,
      sortOrder: p.sortOrder,
      createdAt: p.createdAt,
    );

/// 复制一条记录并改动若干字段。
///
/// `clearEndedAt` 是单独一个开关而不是"传 null 进去"：
/// 参数传 null 与"刻意把它清空"在这个模型里是两件不同的事
///（`endedAt == null` 且 `endUnknown == false` 恰恰就是"正在屙"），
/// 混在一起写迟早会把某个状态悄悄改错。
BackupRecord _recordWith(
  BackupRecord r, {
  String? pooperId,
  bool? endUnknown,
  bool clearEndedAt = false,
}) =>
    BackupRecord(
      id: r.id,
      pooperId: pooperId ?? r.pooperId,
      startedAt: r.startedAt,
      endedAt: clearEndedAt ? null : r.endedAt,
      endUnknown: endUnknown ?? r.endUnknown,
      createdAt: r.createdAt,
    );

BackupNote _noteWith(BackupNote n, {String? recordId}) => BackupNote(
      id: n.id,
      recordId: recordId ?? n.recordId,
      content: n.content,
      notedAt: n.notedAt,
      createdAt: n.createdAt,
    );

/// `Iterable.firstOrNull` 的小替身。
///
/// 不用 `package:collection` 的版本：这个文件会被单测直接引用，
/// 少一个 import 就少一处版本耦合。
extension _FirstOrNullOf<T> on Iterable<T> {
  T? firstOrNullOf() => isEmpty ? null : first;
}
