import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/settings.dart';
import '../../widget/widget_snapshot_service.dart';
import '../database.dart';
import 'backup_model.dart';
import 'webdav_config.dart';

/// 本地备份文件信息。
class LocalBackupFileInfo {
  const LocalBackupFileInfo({
    required this.file,
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
    this.metadata,
  });

  final File file;
  final String name;
  final int sizeBytes;
  final DateTime modifiedAt;
  final BackupMetadata? metadata;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate =>
      DateFormat('yyyy-MM-dd HH:mm').format(modifiedAt);
}

/// 备份与恢复服务。
class BackupService {
  const BackupService();

  // ==========================================================================
  //  创建备份数据
  // ==========================================================================

  /// 从当前数据库和设置生成完整备份对象。
  Future<BackupData> createBackupData({
    required AppDatabase db,
    required Settings settings,
    WebDavConfig? webDavConfig,
  }) async {
    // 1. 查询全部人员（含归档）
    final pooperRows = await db.select(db.poopers).get();
    final poopers = pooperRows
        .map(
          (p) => BackupPooper(
            id: p.id,
            name: p.name,
            iconKey: p.iconKey,
            avatarBlobBase64:
                p.avatarBlob != null ? base64Encode(p.avatarBlob!) : null,
            remark: p.remark,
            isDefault: p.isDefault,
            archivedAt: p.archivedAt,
            sortOrder: p.sortOrder,
            createdAt: p.createdAt,
          ),
        )
        .toList();

    // 2. 查询全部记录
    final recordRows = await db.select(db.poopRecords).get();
    final records = recordRows
        .map(
          (r) => BackupRecord(
            id: r.id,
            pooperId: r.pooperId,
            startedAt: r.startedAt,
            endedAt: r.endedAt,
            endUnknown: r.endUnknown,
            createdAt: r.createdAt,
          ),
        )
        .toList();

    // 3. 查询全部备注
    final noteRows = await db.select(db.poopNotes).get();
    final notes = noteRows
        .map(
          (n) => BackupNote(
            id: n.id,
            recordId: n.recordId,
            content: n.content,
            notedAt: n.notedAt,
            createdAt: n.createdAt,
          ),
        )
        .toList();

    // 4. 查询全部模板
    final templateRows = await db.select(db.noteTemplates).get();
    final templates = templateRows
        .map(
          (t) => BackupNoteTemplate(
            id: t.id,
            content: t.content,
            useCount: t.useCount,
            sortOrder: t.sortOrder,
            createdAt: t.createdAt,
          ),
        )
        .toList();

    // 5. 序列化应用设置与同步配置
    final settingsMap = <String, dynamic>{
      'weekStart': settings.weekStart.name,
      'showBadges': settings.showBadges,
      'showHolidayTags': settings.showHolidayTags,
      'weekendBrandColor': settings.weekendBrandColor,
      'hideArchivedPoopers': settings.hideArchivedPoopers,
      'calendarTextSize': settings.calendarTextSize.name,
      'themeMode': settings.themeMode.name,
      'themeColor': settings.themeColor.name,
      if (webDavConfig != null && webDavConfig.isConfigured)
        'webDav': {
          'serverUrl': webDavConfig.serverUrl,
          'username': webDavConfig.username,
          'password': webDavConfig.password,
          'remotePath': webDavConfig.remotePath,
          'allowSelfSignedCert': webDavConfig.allowSelfSignedCert,
        },
    };

    final now = DateTime.now();
    final metadata = BackupMetadata(
      version: kBackupFormatVersion,
      app: kBackupAppId,
      createdAt: now,
      pooperCount: poopers.length,
      recordCount: records.length,
      noteCount: notes.length,
      templateCount: templates.length,
    );

    return BackupData(
      metadata: metadata,
      settings: settingsMap,
      poopers: poopers,
      records: records,
      notes: notes,
      templates: templates,
    );
  }

  // ==========================================================================
  //  还原备份数据
  // ==========================================================================

  /// 将备份包还原入库。
  /// [overrideAll] 为 true 时清空并完全覆盖现有数据；为 false 时安全增量合并。
  Future<void> restoreBackupData({
    required AppDatabase db,
    required BackupData data,
    required SharedPreferences prefs,
    required bool overrideAll,
  }) async {
    await db.transaction(() async {
      if (overrideAll) {
        // ---- 彻底清空旧数据（按外键依赖逆序：备注 -> 记录 -> 人员 -> 模板）----
        await db.delete(db.poopNotes).go();
        await db.delete(db.poopRecords).go();
        await db.delete(db.poopers).go();
        await db.delete(db.noteTemplates).go();

        // 规范化人员数据：防御性规整 isDefault，保证 ux_default_pooper 唯一索引绝不报错
        var assignedDefault = false;
        final sanitizedPoopers = data.poopers.map((p) {
          final shouldBeDefault = !assignedDefault && p.isDefault && p.archivedAt == null;
          if (shouldBeDefault) assignedDefault = true;
          return (pooper: p, isDefault: shouldBeDefault);
        }).toList();

        // 插入所有人员
        await db.batch((b) {
          for (final item in sanitizedPoopers) {
            final p = item.pooper;
            b.insert(
              db.poopers,
              PoopersCompanion.insert(
                id: drift.Value(p.id),
                name: p.name,
                iconKey: drift.Value(p.iconKey),
                avatarBlob: drift.Value(p.avatarBlob),
                remark: drift.Value(p.remark),
                isDefault: drift.Value(item.isDefault),
                archivedAt: drift.Value(p.archivedAt),
                sortOrder: drift.Value(p.sortOrder),
                createdAt: drift.Value(p.createdAt),
              ),
            );
          }
        });

        // 规范化记录数据：同一成员至多保留一条活跃未结束记录，更早的收敛为未记结束
        final activePooperRecorded = <String>{};
        final sortedRecords = [...data.records]
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt)); // 最新的排在前面

        final sanitizedRecords = sortedRecords.map((r) {
          final isLive = r.endedAt == null && !r.endUnknown;
          if (isLive) {
            if (activePooperRecorded.contains(r.pooperId)) {
              // 该成员已有更新的活跃记录，此条历史自动收敛为未记结束
              return (record: r, endUnknown: true);
            }
            activePooperRecorded.add(r.pooperId);
          }
          return (record: r, endUnknown: r.endUnknown);
        }).toList();

        // 插入所有记录
        await db.batch((b) {
          for (final item in sanitizedRecords) {
            final r = item.record;
            b.insert(
              db.poopRecords,
              PoopRecordsCompanion.insert(
                id: drift.Value(r.id),
                pooperId: r.pooperId,
                startedAt: r.startedAt,
                endedAt: drift.Value(r.endedAt),
                endUnknown: drift.Value(item.endUnknown),
                createdAt: drift.Value(r.createdAt),
              ),
            );
          }
        });

        // 插入所有备注
        await db.batch((b) {
          for (final n in data.notes) {
            b.insert(
              db.poopNotes,
              PoopNotesCompanion.insert(
                id: drift.Value(n.id),
                recordId: n.recordId,
                content: n.content,
                notedAt: n.notedAt,
                createdAt: drift.Value(n.createdAt),
              ),
            );
          }
        });

        // 插入所有模板
        await db.batch((b) {
          for (final t in data.templates) {
            b.insert(
              db.noteTemplates,
              NoteTemplatesCompanion.insert(
                id: drift.Value(t.id),
                content: t.content,
                useCount: drift.Value(t.useCount),
                sortOrder: drift.Value(t.sortOrder),
                createdAt: drift.Value(t.createdAt),
              ),
            );
          }
        });
      } else {
        // ---- 增量合并模式 ----
        // 1. 合并人员（按 id，若存在则更新，若不存在则插入）
        final existingPooperIds = (await (db.selectOnly(db.poopers)
                  ..addColumns([db.poopers.id]))
                .map((r) => r.read(db.poopers.id)!)
                .get())
            .toSet();

        // 检查本地是否已存在活跃的默认成员，防止增量合并时违反 ux_default_pooper 唯一索引
        final localHasDefault = (await db.activePoopers()).any((p) => p.isDefault);

        for (final p in data.poopers) {
          final shouldKeepDefault = p.isDefault && (!localHasDefault || existingPooperIds.contains(p.id));
          final comp = PoopersCompanion.insert(
            id: drift.Value(p.id),
            name: p.name,
            iconKey: drift.Value(p.iconKey),
            avatarBlob: drift.Value(p.avatarBlob),
            remark: drift.Value(p.remark),
            isDefault: drift.Value(shouldKeepDefault),
            archivedAt: drift.Value(p.archivedAt),
            sortOrder: drift.Value(p.sortOrder),
            createdAt: drift.Value(p.createdAt),
          );
          if (existingPooperIds.contains(p.id)) {
            await (db.update(db.poopers)..where((t) => t.id.equals(p.id)))
                .write(comp);
          } else {
            await db.into(db.poopers).insert(comp);
          }
        }

        // 2. 合并记录（若 id 不存在则插入）
        final existingRecordIds = (await (db.selectOnly(db.poopRecords)
                  ..addColumns([db.poopRecords.id]))
                .map((r) => r.read(db.poopRecords.id)!)
                .get())
            .toSet();

        // 收集本地当前各成员是否有正在进行中的记录，防止增量导入时撞上 ux_active_record 唯一索引
        final livePooperSet = (await (db.selectOnly(db.poopRecords)
                  ..addColumns([db.poopRecords.pooperId])
                  ..where(db.poopRecords.endedAt.isNull() & db.poopRecords.endUnknown.equals(false)))
                .map((r) => r.read(db.poopRecords.pooperId)!)
                .get())
            .toSet();

        for (final r in data.records) {
          if (!existingRecordIds.contains(r.id)) {
            var endUnknown = r.endUnknown;
            final isLive = r.endedAt == null && !r.endUnknown;
            if (isLive) {
              if (livePooperSet.contains(r.pooperId)) {
                // 本地或同批次该成员已有进行中记录，自动收敛为未记结束以规避冲突
                endUnknown = true;
              } else {
                livePooperSet.add(r.pooperId);
              }
            }

            await db.into(db.poopRecords).insert(
                  PoopRecordsCompanion.insert(
                    id: drift.Value(r.id),
                    pooperId: r.pooperId,
                    startedAt: r.startedAt,
                    endedAt: drift.Value(endUnknown ? null : r.endedAt),
                    endUnknown: drift.Value(endUnknown),
                    createdAt: drift.Value(r.createdAt),
                  ),
                );
          }
        }

        // 3. 合并备注
        final existingNoteIds = (await (db.selectOnly(db.poopNotes)
                  ..addColumns([db.poopNotes.id]))
                .map((r) => r.read(db.poopNotes.id)!)
                .get())
            .toSet();

        for (final n in data.notes) {
          if (!existingNoteIds.contains(n.id)) {
            await db.into(db.poopNotes).insert(
                  PoopNotesCompanion.insert(
                    id: drift.Value(n.id),
                    recordId: n.recordId,
                    content: n.content,
                    notedAt: n.notedAt,
                    createdAt: drift.Value(n.createdAt),
                  ),
                );
          }
        }

        // 4. 合并模板（按内容 content 去重）
        final existingTplContents = (await (db.selectOnly(db.noteTemplates)
                  ..addColumns([db.noteTemplates.content]))
                .map((r) => r.read(db.noteTemplates.content)!)
                .get())
            .toSet();

        for (final t in data.templates) {
          if (!existingTplContents.contains(t.content)) {
            await db.into(db.noteTemplates).insert(
                  NoteTemplatesCompanion.insert(
                    id: drift.Value(t.id),
                    content: t.content,
                    useCount: drift.Value(t.useCount),
                    sortOrder: drift.Value(t.sortOrder),
                    createdAt: drift.Value(t.createdAt),
                  ),
                );
            existingTplContents.add(t.content);
          }
        }
      }

      // 确保至少有一个可用的默认屙屎人
      await db.ensureDefaultPooper();
    });

    // 还原应用设置
    if (data.settings != null && overrideAll) {
      final s = data.settings!;
      if (s['weekStart'] is String) {
        prefs.setString('settings.weekStart', s['weekStart'] as String);
      }
      if (s['showBadges'] is bool) {
        prefs.setBool('settings.showBadges', s['showBadges'] as bool);
      }
      if (s['showHolidayTags'] is bool) {
        prefs.setBool('settings.showHolidayTags', s['showHolidayTags'] as bool);
      }
      if (s['weekendBrandColor'] is bool) {
        prefs.setBool(
            'settings.weekendBrandColor', s['weekendBrandColor'] as bool);
      }
      if (s['hideArchivedPoopers'] is bool) {
        prefs.setBool(
            'settings.hideArchivedPoopers', s['hideArchivedPoopers'] as bool);
      }
      if (s['calendarTextSize'] is String) {
        prefs.setString(
            'settings.calendarTextSize', s['calendarTextSize'] as String);
      }
      if (s['themeMode'] is String) {
        prefs.setString('settings.themeMode', s['themeMode'] as String);
      }
      if (s['themeColor'] is String) {
        prefs.setString('settings.themeColor', s['themeColor'] as String);
      }
      if (s['webDav'] is Map<String, dynamic>) {
        final davMap = s['webDav'] as Map<String, dynamic>;
        final cfg = WebDavConfig(
          serverUrl: davMap['serverUrl'] as String? ?? '',
          username: davMap['username'] as String? ?? '',
          password: davMap['password'] as String? ?? '',
          remotePath: davMap['remotePath'] as String? ?? kDefaultRemoteFolder,
          allowSelfSignedCert: davMap['allowSelfSignedCert'] as bool? ?? false,
        );
        await cfg.save(prefs);
      }
    }

    // 还原完成后主动触发小组件最新快照同步
    unawaited(WidgetSyncManager.sync(db));
  }

  // ==========================================================================
  //  本地文件管理与目录
  // ==========================================================================

  /// 获取本地备份文件夹。
  Future<Directory> getBackupDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${docs.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// 导出备份到本地 JSON 文件。
  Future<File> exportToFile(BackupData data, {String? customFileName}) async {
    final dir = await getBackupDirectory();
    final timestamp =
        DateFormat('yyyyMMdd_HHmmss').format(data.metadata.createdAt);
    final fileName = customFileName ?? 'pooped_yet_backup_$timestamp.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(data.toPrettyJson(), flush: true);
    return file;
  }

  /// 获取本地历史备份文件列表。
  Future<List<LocalBackupFileInfo>> listLocalBackups() async {
    final dir = await getBackupDirectory();
    if (!await dir.exists()) return [];

    final list = <LocalBackupFileInfo>[];
    final entities = await dir.list().toList();

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        final stat = await entity.stat();
        final name = entity.path.split(Platform.pathSeparator).last;
        BackupMetadata? meta;

        try {
          final content = await entity.readAsString();
          final parsed = jsonDecode(content) as Map<String, dynamic>;
          if (parsed['metadata'] is Map<String, dynamic>) {
            meta = BackupMetadata.fromJson(
                parsed['metadata'] as Map<String, dynamic>);
          }
        } catch (_) {
          // 容错处理损坏的文件
        }

        list.add(
          LocalBackupFileInfo(
            file: entity,
            name: name,
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
            metadata: meta,
          ),
        );
      }
    }

    list.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return list;
  }

  /// 从指定文件读取备份数据。
  Future<BackupData> readBackupFromFile(File file) async {
    final str = await file.readAsString();
    return readBackupFromJsonString(str);
  }

  /// 从 JSON 字符串解析备份数据并校验。
  BackupData readBackupFromJsonString(String jsonStr) {
    final dynamic raw = jsonDecode(jsonStr);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('备份数据格式不正确（必须为有效 JSON 对象）');
    }
    return BackupData.fromJson(raw);
  }

  /// 删除单个本地备份文件。
  Future<void> deleteLocalBackup(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ==========================================================================
  //  剪贴板与系统原生文件分享/导入互操作
  // ==========================================================================

  static const _backupChannel = MethodChannel('com.poopedyet.app/backup');

  /// 将备份 JSON 复制到系统剪贴板。
  Future<void> copyToClipboard(BackupData data) async {
    final jsonStr = data.toPrettyJson();
    await Clipboard.setData(ClipboardData(text: jsonStr));
  }

  /// 从系统剪贴板读取并解析备份数据。
  Future<BackupData?> readFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return null;
    return readBackupFromJsonString(text);
  }

  /// 调起系统分享菜单，安全共享备份文件至微信/QQ/网盘/文件管理等。
  Future<void> shareBackupFile(String filePath, {String? title}) async {
    try {
      await _backupChannel.invokeMethod('shareFile', {
        'filePath': filePath,
        'title': title ?? '分享屙了么备份文件',
      });
    } on MissingPluginException {
      // 桌面端或非安卓环境兼容回退
    }
  }

  /// 调起系统标准文件选择器，选取并直接读取备份 JSON 内容。
  Future<String?> pickBackupFileContent() async {
    try {
      final dynamic content =
          await _backupChannel.invokeMethod('pickFile');
      if (content is String && content.trim().isNotEmpty) {
        return content.trim();
      }
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
