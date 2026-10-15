import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/backup/backup_model.dart';
import '../../../data/backup/webdav_client.dart';
import '../../../data/backup/webdav_config.dart';
import '../../../providers.dart';
import '../../../state/backup_state.dart';
import '../../../state/calendar_data.dart';
import '../../../state/settings.dart';
import '../../../theme/tokens.dart';
import '../../widgets/settings_widgets.dart';

/// WebDAV 云同步配置与同步管理页面。
class WebDavSyncPage extends ConsumerStatefulWidget {
  const WebDavSyncPage({super.key});

  @override
  ConsumerState<WebDavSyncPage> createState() => _WebDavSyncPageState();
}

class _WebDavSyncPageState extends ConsumerState<WebDavSyncPage> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _folderCtrl;
  bool _allowSelfSigned = false;
  bool _obscurePass = true;

  bool _testing = false;
  bool _syncing = false;
  bool _loadingRemoteFiles = false;
  List<WebDavRemoteFile> _remoteFiles = [];

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(webDavConfigProvider);
    _urlCtrl = TextEditingController(text: cfg.serverUrl);
    _userCtrl = TextEditingController(text: cfg.username);
    _passCtrl = TextEditingController(text: cfg.password);
    _folderCtrl = TextEditingController(
      text: cfg.remotePath.trim().isEmpty
          ? kDefaultRemoteFolder
          : cfg.remotePath.trim(),
    );
    _allowSelfSigned = cfg.allowSelfSignedCert;

    if (cfg.isConfigured) {
      _loadRemoteFiles();
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _folderCtrl.dispose();
    super.dispose();
  }

  WebDavConfig _buildCurrentConfig() {
    final folderText = _folderCtrl.text.trim();
    return WebDavConfig(
      serverUrl: _urlCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
      remotePath: folderText.isEmpty ? kDefaultRemoteFolder : folderText,
      allowSelfSignedCert: _allowSelfSigned,
      lastSyncAt: ref.read(webDavConfigProvider).lastSyncAt,
      lastSyncStatus: ref.read(webDavConfigProvider).lastSyncStatus,
    );
  }

  Future<void> _saveConfig() async {
    final cfg = _buildCurrentConfig();
    await ref.read(webDavConfigProvider.notifier).updateConfig(cfg);
    if (mounted) {
      _showSnack('WebDAV 配置已保存');
    }
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      final cfg = _buildCurrentConfig();
      final client = WebDavClient(config: cfg);
      final res = await client.testConnection();

      if (!mounted) return;
      if (res.success) {
        _showSnack('✓ ${res.message}');
        await _saveConfig();
        await _loadRemoteFiles();
      } else {
        _showSnack('✗ ${res.message}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _loadRemoteFiles() async {
    final cfg = ref.read(webDavConfigProvider);
    if (!cfg.isConfigured) return;

    setState(() => _loadingRemoteFiles = true);
    try {
      final client = ref.read(webDavClientProvider);
      final list = await client.listRemoteBackups();
      // 按修改时间倒序排列，若时间相同或为空则按文件名倒序，确保最新备份排在最前
      list.sort((a, b) {
        if (a.modifiedAt != null && b.modifiedAt != null) {
          return b.modifiedAt!.compareTo(a.modifiedAt!);
        }
        return b.name.compareTo(a.name);
      });
      if (mounted) {
        setState(() => _remoteFiles = list);
      }
    } catch (_) {
      // 容错处理
    } finally {
      if (mounted) setState(() => _loadingRemoteFiles = false);
    }
  }

  // ==========================================================================
  //  云端备份与恢复
  // ==========================================================================

  Future<void> _uploadBackupToCloud() async {
    final cfg = ref.read(webDavConfigProvider);
    if (!cfg.isConfigured) {
      _showSnack('请先完善并保存 WebDAV 服务器配置', isError: true);
      return;
    }

    setState(() => _syncing = true);
    try {
      final db = ref.read(databaseProvider);
      final settings = ref.read(settingsProvider);
      final service = ref.read(backupServiceProvider);
      final client = ref.read(webDavClientProvider);

      // 生成完整备份
      final backup = await service.createBackupData(
        db: db,
        settings: settings,
        webDavConfig: ref.read(webDavConfigProvider),
      );
      final jsonStr = backup.toPrettyJson();

      final timestamp =
          DateFormat('yyyyMMdd_HHmmss').format(backup.metadata.createdAt);
      final fileName = 'pooped_yet_backup_$timestamp.json';

      // 上传单份标准时间戳归档文件，不再重复生成冗余的 latest 复制文件
      await client.uploadFile(fileName: fileName, content: jsonStr);

      await ref.read(webDavConfigProvider.notifier).updateSyncResult(
            success: true,
            status: '已成功备份到云端 ($timestamp)',
          );

      await _loadRemoteFiles();

      if (!mounted) return;
      _showSnack('✓ 数据已成功备份上传至 WebDAV 云端！');
    } catch (e) {
      if (mounted) _showSnack('上传失败：$e', isError: true);
      await ref.read(webDavConfigProvider.notifier).updateSyncResult(
            success: false,
            status: '备份失败：$e',
          );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _restoreFromRemoteFile(WebDavRemoteFile file) async {
    setState(() => _syncing = true);
    try {
      final client = ref.read(webDavClientProvider);
      final content = await client.downloadFile(fileName: file.name);
      final service = ref.read(backupServiceProvider);
      final data = service.readBackupFromJsonString(content);

      if (!mounted) return;
      _showRestoreDialog(data, fileName: file.name);
    } catch (e) {
      if (mounted) _showSnack('拉取云端备份失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showRestoreDialog(BackupData data, {required String fileName}) {
    final t = context.tokens;
    final meta = data.metadata;
    final createdStr = DateFormat('yyyy-MM-dd HH:mm').format(meta.createdAt);

    var restorePoopers = data.poopers.isNotEmpty;
    var restoreRecords = data.records.isNotEmpty || data.notes.isNotEmpty;
    var restoreTemplates = data.templates.isNotEmpty;
    var restoreSettings = data.settings != null;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final hasAnySelected = (restorePoopers && data.poopers.isNotEmpty) ||
              (restoreRecords && (data.records.isNotEmpty || data.notes.isNotEmpty)) ||
              (restoreTemplates && data.templates.isNotEmpty) ||
              (restoreSettings && data.settings != null);

          return Dialog(
            backgroundColor: t.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: t.lineSoft),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: t.brandSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(LucideIcons.cloudDownload, size: 18, color: t.brandInk),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '从 WebDAV 恢复',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: t.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 文件名与时间
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: t.paperDeep,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '文件：$fileName',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.ink2),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          createdStr,
                          style: TextStyle(fontSize: 11, color: t.ink3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '请勾选需要恢复的数据分类：',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.ink2),
                  ),
                  const SizedBox(height: 8),
                  // 可选分类卡片
                  Container(
                    decoration: BoxDecoration(
                      color: t.paperDeep,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.lineSoft.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      children: [
                        _CategoryCheckboxRow(
                          icon: LucideIcons.users,
                          title: '屙屎人员名单',
                          subtitle: data.poopers.isEmpty
                              ? '未包含成员数据'
                              : '共 ${meta.pooperCount} 位成员',
                          checked: restorePoopers && data.poopers.isNotEmpty,
                          enabled: data.poopers.isNotEmpty,
                          onChanged: (v) => setDialogState(() => restorePoopers = v ?? true),
                        ),
                        Divider(height: 1, thickness: 0.8, color: t.lineSoft),
                        _CategoryCheckboxRow(
                          icon: LucideIcons.clock,
                          title: '打卡记录与备注',
                          subtitle: (data.records.isEmpty && data.notes.isEmpty)
                              ? '未包含打卡数据'
                              : '共 ${meta.recordCount} 条记录，${meta.noteCount} 条备注',
                          checked: restoreRecords && (data.records.isNotEmpty || data.notes.isNotEmpty),
                          enabled: data.records.isNotEmpty || data.notes.isNotEmpty,
                          onChanged: (v) => setDialogState(() => restoreRecords = v ?? true),
                        ),
                        Divider(height: 1, thickness: 0.8, color: t.lineSoft),
                        _CategoryCheckboxRow(
                          icon: LucideIcons.tags,
                          title: '便便感受标签',
                          subtitle: data.templates.isEmpty
                              ? '未包含标签数据'
                              : '共 ${meta.templateCount} 条常用模板',
                          checked: restoreTemplates && data.templates.isNotEmpty,
                          enabled: data.templates.isNotEmpty,
                          onChanged: (v) => setDialogState(() => restoreTemplates = v ?? true),
                        ),
                        Divider(height: 1, thickness: 0.8, color: t.lineSoft),
                        _CategoryCheckboxRow(
                          icon: LucideIcons.slidersHorizontal,
                          title: '应用偏好设置',
                          subtitle: data.settings == null
                              ? '未包含设置数据'
                              : '包含周起始日、日历字号与主题',
                          checked: restoreSettings && data.settings != null,
                          enabled: data.settings != null,
                          onChanged: (v) => setDialogState(() => restoreSettings = v ?? true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 模式提示文案，完全自适应深浅色
                  Text(
                    '• 增量合并：保留当前手机数据，补齐缺失项\n'
                    '• 彻底覆盖：仅清空所选分类并完全还原云端备份',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: t.ink3,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('取消', style: TextStyle(color: t.ink3)),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: t.brandSoft,
                          foregroundColor: t.brandInk,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(PoopRadii.pill),
                          ),
                        ),
                        onPressed: hasAnySelected
                            ? () {
                                Navigator.of(ctx).pop();
                                _performRestore(
                                  data,
                                  overrideAll: false,
                                  restorePoopers: restorePoopers,
                                  restoreRecords: restoreRecords,
                                  restoreTemplates: restoreTemplates,
                                  restoreSettings: restoreSettings,
                                );
                              }
                            : null,
                        child: const Text('增量合并'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: t.danger,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(PoopRadii.pill),
                          ),
                        ),
                        onPressed: hasAnySelected
                            ? () {
                                Navigator.of(ctx).pop();
                                _performRestore(
                                  data,
                                  overrideAll: true,
                                  restorePoopers: restorePoopers,
                                  restoreRecords: restoreRecords,
                                  restoreTemplates: restoreTemplates,
                                  restoreSettings: restoreSettings,
                                );
                              }
                            : null,
                        child: const Text('彻底覆盖'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _performRestore(
    BackupData data, {
    required bool overrideAll,
    bool restorePoopers = true,
    bool restoreRecords = true,
    bool restoreTemplates = true,
    bool restoreSettings = true,
  }) async {
    setState(() => _syncing = true);
    try {
      final db = ref.read(databaseProvider);
      final prefs = ref.read(sharedPrefsProvider);
      final service = ref.read(backupServiceProvider);

      await service.restoreBackupData(
        db: db,
        data: data,
        prefs: prefs,
        overrideAll: overrideAll,
        restorePoopers: restorePoopers,
        restoreRecords: restoreRecords,
        restoreTemplates: restoreTemplates,
        restoreSettings: restoreSettings,
      );

      _refreshAllProviders();
      ref.invalidate(webDavConfigProvider);

      if (!mounted) return;
      _showSnack(overrideAll ? '已按所选分类完全恢复云端备份！' : '云端所选分类增量合并完成！');
    } catch (e) {
      if (mounted) _showSnack('恢复失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _deleteRemoteFile(WebDavRemoteFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除云端备份'),
        content: Text('确定从 WebDAV 删除备份文件「${file.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.tokens.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        final client = ref.read(webDavClientProvider);
        await client.deleteRemoteFile(file.name);
        await _loadRemoteFiles();
        if (mounted) _showSnack('已删除云端备份');
      } catch (e) {
        if (mounted) _showSnack('删除失败：$e', isError: true);
      }
    }
  }

  void _refreshAllProviders() {
    ref.invalidate(activePoopersProvider);
    ref.invalidate(allPoopersProvider);
    ref.invalidate(noteTemplatesProvider);
    ref.invalidate(monthBadgesProvider);
    ref.invalidate(weekBadgesProvider);
    ref.invalidate(dayRecordsProvider);
    ref.invalidate(staleRecordsProvider);
    ref.invalidate(settingsProvider);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? context.tokens.danger : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cfg = ref.watch(webDavConfigProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: 'WebDAV 云同步',
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + bottomInset),
        children: [
          // ---------------- 同步状态与一键同步 ----------------
          const SettingsSectionLabel('同步状态'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.lineSoft),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A2D1B0D),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: cfg.isConfigured ? t.live : t.ink4,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cfg.isConfigured ? '已配置 WebDAV' : '尚未配置服务器',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                      const Spacer(),
                      if (cfg.lastSyncAt != null)
                        Text(
                          DateFormat('MM-dd HH:mm').format(cfg.lastSyncAt!),
                          style: TextStyle(fontSize: 12, color: t.ink3),
                        ),
                    ],
                  ),
                  if (cfg.lastSyncStatus != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      cfg.lastSyncStatus!,
                      style: TextStyle(fontSize: 12, color: t.ink2),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: t.brandFill,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _syncing || _testing ? null : _uploadBackupToCloud,
                          icon: _syncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.cloudUpload, size: 16),
                          label: Text(_syncing ? '正在同步...' : '立即备份到云端'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _testing || _syncing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('测试连接'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ---------------- 服务器配置 ----------------
          const SettingsSectionLabel('服务器配置'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.lineSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FormField(
                    label: '服务器地址 (URL)',
                    hint: '例如 https://dav.jianguoyun.com/dav/',
                    controller: _urlCtrl,
                  ),
                  const SizedBox(height: 12),
                  _FormField(
                    label: '账号 / 用户名',
                    hint: 'WebDAV 登录用户名或邮箱',
                    controller: _userCtrl,
                  ),
                  const SizedBox(height: 12),
                  _FormField(
                    label: '密码 / 应用授权码',
                    hint: '坚果云等推荐使用应用授权密码',
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: 17,
                        color: t.ink3,
                      ),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormField(
                    label: '云端保存文件夹',
                    hint: '默认 $kDefaultRemoteFolder（留空自动使用默认）',
                    controller: _folderCtrl,
                    suffixIcon: _folderCtrl.text.trim() != kDefaultRemoteFolder
                        ? IconButton(
                            tooltip: '恢复默认文件夹',
                            icon: Icon(LucideIcons.rotateCcw, size: 16, color: t.ink3),
                            onPressed: () => setState(
                              () => _folderCtrl.text = kDefaultRemoteFolder,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '允许自签名证书',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                              ),
                            ),
                            Text(
                              '自建 NAS 或无公网证书时开启',
                              style: TextStyle(fontSize: 11.5, color: t.ink3),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _allowSelfSigned,
                        onChanged: (v) => setState(() => _allowSelfSigned = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonal(
                    onPressed: _saveConfig,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('保存配置'),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- 云端备份历史 ----------------
          Padding(
            padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                Text(
                  '云端备份 (${_remoteFiles.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.ink2,
                  ),
                ),
                const Spacer(),
                if (_loadingRemoteFiles)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  GestureDetector(
                    onTap: _loadRemoteFiles,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.refreshCw, size: 13, color: t.brandInk),
                        const SizedBox(width: 4),
                        Text(
                          '刷新',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.brandInk,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (_remoteFiles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.lineSoft),
                ),
                alignment: Alignment.center,
                child: Text(
                  cfg.isConfigured ? '云端目录尚无备份文件' : '请先配置并保存 WebDAV 信息',
                  style: TextStyle(fontSize: 13, color: t.ink3),
                ),
              ),
            )
          else
            SettingsCard(
              children: [
                for (var i = 0; i < _remoteFiles.length; i++)
                  _RemoteBackupRow(
                    file: _remoteFiles[i],
                    isLatest: i == 0,
                    onRestore: () => _restoreFromRemoteFile(_remoteFiles[i]),
                    onDelete: () => _deleteRemoteFile(_remoteFiles[i]),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.suffixIcon,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: t.ink2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: t.paperDeep,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  style: TextStyle(fontSize: 13.5, color: t.ink),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(fontSize: 12.5, color: t.ink4),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (suffixIcon != null) suffixIcon!,
            ],
          ),
        ),
      ],
    );
  }
}

class _RemoteBackupRow extends StatelessWidget {
  const _RemoteBackupRow({
    required this.file,
    required this.isLatest,
    required this.onRestore,
    required this.onDelete,
  });

  final WebDavRemoteFile file;
  final bool isLatest;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final modStr = file.modifiedAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(file.modifiedAt!)
        : '时间未知';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isLatest ? t.liveSoft : t.brandSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              LucideIcons.cloud,
              size: 18,
              color: isLatest ? t.live : t.brandInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                    ),
                    if (isLatest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: t.liveSoft,
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: t.live.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '最新',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: t.live,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$modStr · ${file.formattedSize}',
                  style: TextStyle(fontSize: 11.5, color: t.ink3),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '从云端恢复',
            icon: Icon(LucideIcons.cloudDownload, size: 18, color: t.brandInk),
            onPressed: onRestore,
          ),
          IconButton(
            tooltip: '删除云端备份',
            icon: Icon(LucideIcons.trash2, size: 17, color: t.ink4),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// WebDAV 恢复弹窗中可勾选的分类条目行
class _CategoryCheckboxRow extends StatelessWidget {
  const _CategoryCheckboxRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.checked,
    this.enabled = true,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final effectiveTitleColor = enabled ? t.ink : t.ink4;
    final effectiveSubColor = enabled ? t.ink3 : t.ink4.withValues(alpha: 0.6);
    final effectiveIconColor = enabled ? (checked ? t.brandInk : t.ink3) : t.ink4;

    return InkWell(
      onTap: enabled ? () => onChanged(!checked) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
        child: Row(
          children: [
            Icon(icon, size: 16, color: effectiveIconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: effectiveTitleColor,
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: effectiveSubColor),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: checked,
              onChanged: enabled ? onChanged : null,
              activeColor: t.brandInk,
              checkColor: Colors.white,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
