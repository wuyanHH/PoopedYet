import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../state/settings.dart';
import '../backup/backup_service.dart';
import '../backup/webdav_client.dart';
import '../backup/webdav_config.dart';
import '../database.dart';
import 'sync_merger.dart';
import 'sync_model.dart';

/// 一次同步为什么没干活。
enum SyncSkipReason {
  /// 还没配 WebDAV。用户没启用云同步，不该报错。
  notConfigured,

  /// 配了，但用户把自动同步关掉了（手动同步不会走到这里）。
  disabled,

  /// 上一次同步还没跑完。静默跳过，不排队 ——
  /// 排队的话用户连点五次会产生五次上传，那是纯粹的流量浪费。
  alreadyRunning,

  /// 数据库是空的、云端也没有文件，没什么可同步的。
  nothingToDo,
}

/// 一次同步的结论。
class SyncOutcome {
  const SyncOutcome({
    required this.success,
    required this.message,
    this.skipped = false,
    this.skipReason,
    this.stats,
    this.remoteExisted = false,
    this.uploaded = false,
    this.finishedAt,
  });

  final bool success;
  final String message;
  final bool skipped;
  final SyncSkipReason? skipReason;

  /// 本次合并动了多少数据。跳过时为空。
  final SyncMergeStats? stats;

  /// 云端是否已经存在同步文件（false = 这次是首同步的开局）。
  final bool remoteExisted;

  /// 本次是否把合并结果写回了云端。
  ///
  /// 为 false 且 [success] 为 true 时，说明两端本来就一致 ——
  /// 这是最常见的情况，也是"不重复上传"的体现。
  final bool uploaded;

  final DateTime? finishedAt;

  factory SyncOutcome.skipped(SyncSkipReason reason, String message) =>
      SyncOutcome(
        success: true,
        message: message,
        skipped: true,
        skipReason: reason,
      );

  factory SyncOutcome.failure(String message) =>
      SyncOutcome(success: false, message: message);

  /// 给状态行用的一句话。
  String get statusLine {
    if (skipped) return message;
    if (!success) return message;
    final tail = uploaded ? '已回写云端' : '云端无需改动';
    final detail = stats?.summary ?? '';
    return detail.isEmpty ? tail : '$detail · $tail';
  }
}

/// 双向同步的编排层。
///
/// 分工很清楚：**合并怎么算**在 [SyncMerger]（纯函数），
/// **什么时候算、算完怎么落库**在这里。
class SyncService {
  SyncService();

  /// 同一时刻只允许一个同步在跑。
  ///
  /// 自动同步有三条触发路径（启动、回前台、写完防抖），它们完全可能重叠；
  /// 两个同步并行跑到最后会各传一份文件，后传的把先传的盖掉。
  bool _running = false;

  bool get isRunning => _running;

  static const String _kDeviceIdKey = 'sync.deviceId';

  /// 执行一次完整的双向同步：**先拉取合并，再把合并结果推回去**。
  ///
  /// 顺序不能反。先推后拉的话，本地会把云端另一台设备刚写的数据覆盖掉，
  /// 那次数据就永远找不回来了。
  Future<SyncOutcome> syncNow({
    required AppDatabase db,
    required SharedPreferences prefs,
    required WebDavConfig config,
  }) async {
    if (!config.isConfigured) {
      return SyncOutcome.skipped(
        SyncSkipReason.notConfigured,
        '尚未配置 WebDAV 服务器',
      );
    }
    if (_running) {
      return SyncOutcome.skipped(
        SyncSkipReason.alreadyRunning,
        '上一次同步还在进行中',
      );
    }

    _running = true;
    try {
      return await _run(db: db, prefs: prefs, config: config);
    } catch (e) {
      return SyncOutcome.failure('同步失败：$e');
    } finally {
      _running = false;
    }
  }

  Future<SyncOutcome> _run({
    required AppDatabase db,
    required SharedPreferences prefs,
    required WebDavConfig config,
  }) async {
    final client = WebDavClient(config: config);
    const backupService = BackupService();

    // ------------------------------------------------------------------
    //  1. 取云端那一份
    // ------------------------------------------------------------------
    String? remoteRaw;
    try {
      remoteRaw = await client.downloadFileIfExists(fileName: kSyncFileName);
    } on HttpException catch (e) {
      return SyncOutcome.failure('读取云端同步文件失败：${e.message}');
    }

    SyncEnvelope? remoteEnvelope;
    if (remoteRaw != null) {
      try {
        remoteEnvelope = SyncEnvelope.decode(remoteRaw);
      } catch (e) {
        // 云端文件损坏时**绝不能**当成"云端是空的"继续往下走 ——
        // 那等于拿本地数据把它覆盖掉，另一台设备的数据就没了。
        // 宁可这次同步失败，让用户先去看一眼云端到底怎么了。
        return SyncOutcome.failure(
          '云端同步文件无法解析，已中止本次同步以免把云端覆盖成空：$e',
        );
      }
    }

    final remoteSnapshot = remoteEnvelope?.snapshot ?? SyncSnapshot.empty;
    final remoteExisted = remoteEnvelope != null;

    // 协议版本比本机高：本次**只拉不推**。
    // 更高版本可能带了本机不认识的字段，把合并结果写回去会把它们吃掉。
    final remoteProtocolNewer = remoteEnvelope != null &&
        remoteEnvelope.meta.protocol > kSyncProtocolVersion;

    // ------------------------------------------------------------------
    //  2. 事务内：读本地 → 合并 → 落库
    // ------------------------------------------------------------------
    //
    // 三件事必须在**同一个事务**里做完。拆开的话，用户正好在中间点了一次
    // "开屙"，就会以一份过期的本地快照为依据算出合并结果，
    // 把那条刚写进去的记录盖掉 —— 而这种丢数据是无声的，最难查。
    late SyncMergeResult mergeResult;
    await db.transaction(() async {
      final localBackup = await backupService.createBackupData(
        db: db,
        // 设置项不参与同步：主题、字号、周起始日是本机偏好，
        // 跟着云走会让两台设备互相改对方的界面。
        settings: const Settings(),
        includeSettings: false,
      );

      mergeResult = SyncMerger.merge(
        local: SyncSnapshot.fromBackupData(localBackup),
        remote: remoteSnapshot,
      );

      await _applyToDatabase(db, mergeResult);
    });

    // ------------------------------------------------------------------
    //  3. 决定要不要回写云端
    // ------------------------------------------------------------------
    var uploaded = false;

    if (!remoteProtocolNewer) {
      // 只有在"合并结果与云端现存那份在业务上确实不同"时才上传。
      //
      // 这是防同步风暴的最后一道闸门：自动同步会被启动、回前台、
      // 写完防抖反复触发，每次都无条件上传的话，同一个文件一天会被
      // 重写几十次，流量和云端配额都白烧。
      final alreadyEquivalent = remoteExisted &&
          SyncMerger.isEquivalent(mergeResult.snapshot, remoteSnapshot);

      if (!alreadyEquivalent) {
        final deviceId = await _ensureDeviceId(prefs);
        final envelope = SyncEnvelope(
          snapshot: mergeResult.snapshot,
          meta: SyncMeta(
            protocol: kSyncProtocolVersion,
            // 修订号只增不减，用来在云端文件里回溯"最后一次是谁写的"。
            revision: (remoteEnvelope?.meta.revision ?? 0) + 1,
            deviceId: deviceId,
            deviceName: _deviceName(deviceId),
            syncedAt: DateTime.now(),
          ),
        );

        await client.uploadFile(
          fileName: kSyncFileName,
          content: envelope.toPrettyJson(),
        );
        uploaded = true;
      }
    }

    final stats = mergeResult.stats;
    final message = remoteProtocolNewer
        ? '云端文件来自更新版本，本次只拉取未回写'
        : (stats.isNoop && !uploaded ? '两端已完全一致' : stats.summary);

    return SyncOutcome(
      success: true,
      message: message,
      stats: stats,
      remoteExisted: remoteExisted,
      uploaded: uploaded,
      finishedAt: DateTime.now(),
    );
  }

  // ==========================================================================
  //  落库
  // ==========================================================================

  Future<void> _applyToDatabase(AppDatabase db, SyncMergeResult result) async {
    // ---- 1. 人员 ----
    //
    // 刻意**不用** insertOnConflictUpdate：那个会连带把 is_default 一起写进去，
    // 而 is_default 上有部分唯一索引（ux_default_pooper），
    // 写入过程中短暂出现两个 true 就会直接报错中断整次同步。
    // 这里改成"判断存在性后分别 insert / update"，并且完全不碰 is_default，
    // 默认成员的收敛统一放到最后一步做。
    for (final p in result.poopersToWrite) {
      final exists = await (db.select(db.poopers)..where((t) => t.id.equals(p.id)))
              .getSingleOrNull() !=
          null;

      final fields = PoopersCompanion(
        id: drift.Value(p.id),
        name: drift.Value(p.name),
        iconKey: drift.Value(p.iconKey),
        avatarBlob: drift.Value(p.avatarBlob),
        remark: drift.Value(p.remark),
        archivedAt: drift.Value(p.archivedAt),
        sortOrder: drift.Value(p.sortOrder),
        createdAt: drift.Value(p.createdAt),
      );

      if (exists) {
        await (db.update(db.poopers)..where((t) => t.id.equals(p.id)))
            .write(fields);
      } else {
        await db.into(db.poopers).insert(fields);
      }
    }

    // ---- 2. 记录 ----
    //
    // 顺序讲究：**先把"从进行中变成非进行中"的落地，再插新的进行中记录**。
    // 反过来的话，ux_active_record 会在中间态把插入挡回来，整次同步失败。
    final liveHolder = <String, String>{};
    for (final row in await (db.select(db.poopRecords)
          ..where((t) => t.endedAt.isNull() & t.endUnknown.equals(false)))
        .get()) {
      liveHolder[row.pooperId] = row.id;
    }

    final ordered = [...result.recordsToWrite]..sort((a, b) {
        final aLive = a.endedAt == null && !a.endUnknown;
        final bLive = b.endedAt == null && !b.endUnknown;
        if (aLive == bLive) return 0;
        return aLive ? 1 : -1;
      });

    for (final r in ordered) {
      var endedAt = r.endedAt;
      var endUnknown = r.endUnknown;
      final isLive = endedAt == null && !endUnknown;

      if (isLive) {
        final holder = liveHolder[r.pooperId];
        if (holder != null && holder != r.id) {
          // 最后一道防线。合并阶段已经收敛过一次"一人只能有一条进行中"，
          // 但用户完全可能就在刚才那几百毫秒里点了一次"开屙" ——
          // 那时本地那条才是当下真的在屙，这条让位。
          endUnknown = true;
        } else {
          liveHolder[r.pooperId] = r.id;
        }
      } else if (liveHolder[r.pooperId] == r.id) {
        // 这条不再是进行中了：把占位让出来，好让后面的记录能占上。
        liveHolder.remove(r.pooperId);
      }

      await db.into(db.poopRecords).insertOnConflictUpdate(
            PoopRecordsCompanion.insert(
              id: drift.Value(r.id),
              pooperId: r.pooperId,
              startedAt: r.startedAt,
              endedAt: drift.Value(endedAt),
              endUnknown: drift.Value(endUnknown),
              createdAt: drift.Value(r.createdAt),
            ),
          );
    }

    // ---- 3. 备注 ----
    //
    // 必须排在记录之后：备注的 record_id 是外键，记录还没落地就写备注
    // 会被外键约束挡回来。
    for (final n in result.notesToWrite) {
      await db.into(db.poopNotes).insertOnConflictUpdate(
            PoopNotesCompanion.insert(
              id: drift.Value(n.id),
              recordId: n.recordId,
              content: n.content,
              notedAt: n.notedAt,
              createdAt: drift.Value(n.createdAt),
            ),
          );
    }

    // ---- 4. 清掉重复 ----
    //
    // 顺序不能反：**必须先写完备注**（把它们改嫁到保留下来的那条记录上），
    // 再删记录。反过来的话，删记录时外键的 CASCADE 会把刚改嫁好的备注
    // 一起带走，用户写的字就没了。
    if (result.noteIdsToDelete.isNotEmpty) {
      await (db.delete(db.poopNotes)
            ..where((t) => t.id.isIn(result.noteIdsToDelete)))
          .go();
    }
    if (result.recordIdsToDelete.isNotEmpty) {
      await (db.delete(db.poopRecords)
            ..where((t) => t.id.isIn(result.recordIdsToDelete)))
          .go();
    }
    if (result.templateIdsToDelete.isNotEmpty) {
      await (db.delete(db.noteTemplates)
            ..where((t) => t.id.isIn(result.templateIdsToDelete)))
          .go();
    }

    // ---- 5. 模板 ----
    for (final t in result.templatesToWrite) {
      await db.into(db.noteTemplates).insertOnConflictUpdate(
            NoteTemplatesCompanion.insert(
              id: drift.Value(t.id),
              content: t.content,
              useCount: drift.Value(t.useCount),
              sortOrder: drift.Value(t.sortOrder),
              createdAt: drift.Value(t.createdAt),
            ),
          );
    }

    // ---- 6. 默认成员收敛 ----
    //
    // 只在"确实要换人"时才动，避免每次同步都全表写一遍 is_default
    //（那会触发一轮没必要的表更新事件，进而拉起下一轮防抖同步）。
    final targetDefaultId = _firstOrNull(
      result.snapshot.poopers.where((p) => p.isDefault).map((p) => p.id),
    );

    if (targetDefaultId != null) {
      final currentDefault = await (db.select(db.poopers)
            ..where((t) => t.isDefault.equals(true)))
          .getSingleOrNull();

      if (currentDefault?.id != targetDefaultId) {
        // 先清空再设置，中间态不违反唯一索引。
        await db.update(db.poopers).write(
              const PoopersCompanion(isDefault: drift.Value(false)),
            );
        await (db.update(db.poopers)..where((t) => t.id.equals(targetDefaultId)))
            .write(const PoopersCompanion(isDefault: drift.Value(true)));
      }
    }

    // 万一合并结果里一个可用默认都没有（两边都没标记），补一个，
    // 不然主页那个"一键开屙"不知道该记给谁。
    await db.ensureDefaultPooper();
  }

  // ==========================================================================
  //  设备标识
  // ==========================================================================

  /// 本机设备 id，首次同步时生成一次并长期保留。
  ///
  /// 它不参与合并判断（合并完全靠内容），只写进云端文件供排查 ——
  /// 将来要是同步出了问题，看一眼云端文件就知道最后是谁写的。
  Future<String> _ensureDeviceId(SharedPreferences prefs) async {
    final existing = prefs.getString(_kDeviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final id = const Uuid().v4();
    await prefs.setString(_kDeviceIdKey, id);
    return id;
  }

  String _deviceName(String deviceId) {
    final short = deviceId.length >= 4 ? deviceId.substring(0, 4) : deviceId;
    return '${Platform.operatingSystem}·$short';
  }
}

T? _firstOrNull<T>(Iterable<T> items) => items.isEmpty ? null : items.first;
