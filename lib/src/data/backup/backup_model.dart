import 'dart:convert';
import 'dart:typed_data';

import '../tables.dart';

/// 备份数据版本号。
const int kBackupFormatVersion = 1;

/// 应用备份标识。
const String kBackupAppId = 'pooped_yet';

/// 备份元数据。
class BackupMetadata {
  const BackupMetadata({
    required this.version,
    required this.app,
    required this.createdAt,
    required this.pooperCount,
    required this.recordCount,
    required this.noteCount,
    required this.templateCount,
    this.deviceInfo,
  });

  final int version;
  final String app;
  final DateTime createdAt;
  final int pooperCount;
  final int recordCount;
  final int noteCount;
  final int templateCount;
  final String? deviceInfo;

  Map<String, dynamic> toJson() => {
        'version': version,
        'app': app,
        'createdAt': createdAt.toIso8601String(),
        'pooperCount': pooperCount,
        'recordCount': recordCount,
        'noteCount': noteCount,
        'templateCount': templateCount,
        if (deviceInfo != null) 'deviceInfo': deviceInfo,
      };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      version: json['version'] as int? ?? 1,
      app: json['app'] as String? ?? kBackupAppId,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      pooperCount: json['pooperCount'] as int? ?? 0,
      recordCount: json['recordCount'] as int? ?? 0,
      noteCount: json['noteCount'] as int? ?? 0,
      templateCount: json['templateCount'] as int? ?? 0,
      deviceInfo: json['deviceInfo'] as String?,
    );
  }
}

/// 屙屎人员数据备份对象。
class BackupPooper {
  const BackupPooper({
    required this.id,
    required this.name,
    this.iconKey,
    this.avatarBlobBase64,
    this.remark,
    required this.isDefault,
    this.archivedAt,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? iconKey;
  final String? avatarBlobBase64;
  final String? remark;
  final bool isDefault;
  final DateTime? archivedAt;
  final int sortOrder;
  final DateTime createdAt;

  Uint8List? get avatarBlob => avatarBlobBase64 == null
      ? null
      : base64Decode(avatarBlobBase64!);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'avatarBlobBase64': avatarBlobBase64,
        'remark': remark,
        'isDefault': isDefault,
        'archivedAt': archivedAt?.toIso8601String(),
        'sortOrder': sortOrder,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BackupPooper.fromJson(Map<String, dynamic> json) {
    return BackupPooper(
      id: json['id'] as String? ?? newId(),
      name: json['name'] as String? ?? '无名',
      iconKey: json['iconKey'] as String?,
      avatarBlobBase64: json['avatarBlobBase64'] as String?,
      remark: json['remark'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      archivedAt: json['archivedAt'] != null
          ? DateTime.tryParse(json['archivedAt'] as String)
          : null,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// 打卡记录数据备份对象。
class BackupRecord {
  const BackupRecord({
    required this.id,
    required this.pooperId,
    required this.startedAt,
    this.endedAt,
    required this.endUnknown,
    required this.createdAt,
  });

  final String id;
  final String pooperId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool endUnknown;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'pooperId': pooperId,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'endUnknown': endUnknown,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BackupRecord.fromJson(Map<String, dynamic> json) {
    return BackupRecord(
      id: json['id'] as String? ?? newId(),
      pooperId: json['pooperId'] as String? ?? '',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'] as String)
          : null,
      endUnknown: json['endUnknown'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// 备注数据备份对象。
class BackupNote {
  const BackupNote({
    required this.id,
    required this.recordId,
    required this.content,
    required this.notedAt,
    required this.createdAt,
  });

  final String id;
  final String recordId;
  final String content;
  final DateTime notedAt;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recordId': recordId,
        'content': content,
        'notedAt': notedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory BackupNote.fromJson(Map<String, dynamic> json) {
    return BackupNote(
      id: json['id'] as String? ?? newId(),
      recordId: json['recordId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      notedAt: DateTime.tryParse(json['notedAt'] as String? ?? '') ??
          DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// 快捷模板备份对象。
class BackupNoteTemplate {
  const BackupNoteTemplate({
    required this.id,
    required this.content,
    required this.useCount,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String content;
  final int useCount;
  final int sortOrder;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'useCount': useCount,
        'sortOrder': sortOrder,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BackupNoteTemplate.fromJson(Map<String, dynamic> json) {
    return BackupNoteTemplate(
      id: json['id'] as String? ?? newId(),
      content: json['content'] as String? ?? '',
      useCount: json['useCount'] as int? ?? 0,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// 完整的应用全量备份包。
class BackupData {
  const BackupData({
    required this.metadata,
    this.settings,
    required this.poopers,
    required this.records,
    required this.notes,
    required this.templates,
  });

  final BackupMetadata metadata;
  final Map<String, dynamic>? settings;
  final List<BackupPooper> poopers;
  final List<BackupRecord> records;
  final List<BackupNote> notes;
  final List<BackupNoteTemplate> templates;

  Map<String, dynamic> toJson() => {
        'metadata': metadata.toJson(),
        if (settings != null) 'settings': settings,
        'poopers': poopers.map((e) => e.toJson()).toList(),
        'records': records.map((e) => e.toJson()).toList(),
        'notes': notes.map((e) => e.toJson()).toList(),
        'templates': templates.map((e) => e.toJson()).toList(),
      };

  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final metaRaw = json['metadata'];
    final meta = metaRaw is Map<String, dynamic>
        ? BackupMetadata.fromJson(metaRaw)
        : BackupMetadata(
            version: 1,
            app: kBackupAppId,
            createdAt: DateTime.now(),
            pooperCount: (json['poopers'] as List?)?.length ?? 0,
            recordCount: (json['records'] as List?)?.length ?? 0,
            noteCount: (json['notes'] as List?)?.length ?? 0,
            templateCount: (json['templates'] as List?)?.length ?? 0,
          );

    final poopersList = (json['poopers'] as List?)
            ?.map((e) => BackupPooper.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <BackupPooper>[];

    final recordsList = (json['records'] as List?)
            ?.map((e) => BackupRecord.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <BackupRecord>[];

    final notesList = (json['notes'] as List?)
            ?.map((e) => BackupNote.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <BackupNote>[];

    final templatesList = (json['templates'] as List?)
            ?.map((e) => BackupNoteTemplate.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <BackupNoteTemplate>[];

    final settingsMap = json['settings'] is Map<String, dynamic>
        ? json['settings'] as Map<String, dynamic>
        : null;

    return BackupData(
      metadata: meta,
      settings: settingsMap,
      poopers: poopersList,
      records: recordsList,
      notes: notesList,
      templates: templatesList,
    );
  }
}
