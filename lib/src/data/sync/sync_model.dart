import 'dart:convert';

import '../backup/backup_model.dart';

/// 云端同步文件的**固定文件名**。
///
/// 刻意和 `pooped_yet_backup_<时间戳>.json` 那套归档文件分开，两者服务的目标不同：
///
/// - 归档文件是"某个时刻的快照"，只增不改、只读不写，服务于"回到过去某一版"；
/// - 同步文件是"当前合并后的真相"，每次覆盖写，服务于多端收敛。
///
/// 混在一起用的话，同步会不停往云端堆文件，而用户面对几十个时间戳文件
/// 根本不知道该拉哪一个 —— 更糟的是，随便拉一个旧的可能把新数据盖回去。
const String kSyncFileName = 'pooped_yet_sync.json';

/// 同步协议版本。
///
/// 客户端看到更高版本的协议号时应当**只读不写**：
/// 新版本可能带了它不认识的字段，硬写回去会把那些字段吃掉。
const int kSyncProtocolVersion = 1;

/// 同步文件里 `sync` 段的元信息。
///
/// 这一段**不参与**内容比较（见 `SyncMerger.contentFingerprint`）——
/// 它只用来排查"到底是哪台设备、第几次覆盖了云端"，不是业务数据。
class SyncMeta {
  const SyncMeta({
    this.protocol = kSyncProtocolVersion,
    this.revision = 0,
    this.deviceId = '',
    this.deviceName = '',
    this.syncedAt,
  });

  final int protocol;

  /// 单调递增的写入次数，仅用于日志与排查。
  final int revision;

  /// 本机设备标识（首次使用时生成一次，存 SharedPreferences）。
  final String deviceId;

  /// 人类可读的设备名，仅用于展示。
  final String deviceName;

  /// 这份文件被写下的时刻。
  final DateTime? syncedAt;

  SyncMeta copyWith({
    int? protocol,
    int? revision,
    String? deviceId,
    String? deviceName,
    DateTime? syncedAt,
  }) {
    return SyncMeta(
      protocol: protocol ?? this.protocol,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'protocol': protocol,
        'revision': revision,
        'deviceId': deviceId,
        'deviceName': deviceName,
        if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
      };

  factory SyncMeta.fromJson(Map<String, dynamic> json) {
    return SyncMeta(
      protocol: json['protocol'] as int? ?? kSyncProtocolVersion,
      revision: json['revision'] as int? ?? 0,
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      syncedAt: json['syncedAt'] is String
          ? DateTime.tryParse(json['syncedAt'] as String)
          : null,
    );
  }
}

/// 参与同步的四类业务数据的一份快照。
///
/// 它就是 `BackupData` 去掉"设置"之后的业务内核 ——
/// 主题、日历字号、周起始日这些是**本机偏好**，跟着云走会让两台设备互相改对方的界面。
class SyncSnapshot {
  const SyncSnapshot({
    required this.poopers,
    required this.records,
    required this.notes,
    required this.templates,
  });

  final List<BackupPooper> poopers;
  final List<BackupRecord> records;
  final List<BackupNote> notes;
  final List<BackupNoteTemplate> templates;

  static const SyncSnapshot empty = SyncSnapshot(
    poopers: [],
    records: [],
    notes: [],
    templates: [],
  );

  bool get isEmpty =>
      poopers.isEmpty && records.isEmpty && notes.isEmpty && templates.isEmpty;

  bool get isNotEmpty => !isEmpty;

  factory SyncSnapshot.fromBackupData(BackupData data) => SyncSnapshot(
        poopers: data.poopers,
        records: data.records,
        notes: data.notes,
        templates: data.templates,
      );

  /// 复原成 `BackupData`，好复用现有的 JSON 序列化实现。
  BackupData toBackupData(SyncMeta meta) => BackupData(
        metadata: BackupMetadata(
          version: kBackupFormatVersion,
          app: kBackupAppId,
          createdAt: meta.syncedAt ?? DateTime.now(),
          pooperCount: poopers.length,
          recordCount: records.length,
          noteCount: notes.length,
          templateCount: templates.length,
        ),
        poopers: poopers,
        records: records,
        notes: notes,
        templates: templates,
      );
}

/// 同步文件 = 业务数据 + 同步元信息。
///
/// 序列化时把 `sync` 段并到 `BackupData` 的 JSON 顶层，
/// 所以**用旧版本的"本地备份文件"解析器也能读它**（只是会忽略 sync 段）。
/// 这是刻意的：同步文件万一被用户当成普通备份导入，也不该报错。
class SyncEnvelope {
  const SyncEnvelope({required this.snapshot, required this.meta});

  final SyncSnapshot snapshot;
  final SyncMeta meta;

  Map<String, dynamic> toJson() => {
        ...snapshot.toBackupData(meta).toJson(),
        'sync': meta.toJson(),
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory SyncEnvelope.fromJson(Map<String, dynamic> json) {
    final data = BackupData.fromJson(json);
    final syncRaw = json['sync'];
    return SyncEnvelope(
      snapshot: SyncSnapshot.fromBackupData(data),
      meta: syncRaw is Map<String, dynamic>
          ? SyncMeta.fromJson(syncRaw)
          : const SyncMeta(),
    );
  }

  /// 从云端拿到的原始文本解析。
  factory SyncEnvelope.decode(String raw) {
    final dynamic parsed = jsonDecode(raw);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('云端同步文件格式不正确（必须为 JSON 对象）');
    }
    return SyncEnvelope.fromJson(parsed);
  }
}
