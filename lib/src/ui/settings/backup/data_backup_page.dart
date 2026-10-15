import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/backup/backup_model.dart';
import '../../../data/backup/backup_service.dart';
import '../../../providers.dart';
import '../../../state/backup_state.dart';
import '../../../state/calendar_data.dart';
import '../../../state/settings.dart';
import '../../../theme/tokens.dart';
import '../../widgets/settings_widgets.dart';

/// 本地数据备份与恢复页面。
class DataBackupPage extends ConsumerStatefulWidget {
  const DataBackupPage({super.key});

  @override
  ConsumerState<DataBackupPage> createState() => _DataBackupPageState();
}

class _DataBackupPageState extends ConsumerState<DataBackupPage> {
  bool _loading = false;
  List<LocalBackupFileInfo> _localBackups = [];

  @override
  void initState() {
    super.initState();
    _loadLocalBackups();
  }

  Future<void> _loadLocalBackups() async {
    final service = ref.read(backupServiceProvider);
    final list = await service.listLocalBackups();
    if (mounted) {
      setState(() => _localBackups = list);
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

  // ==========================================================================
  // ==========================================================================
  //  导出动作（支持按分类精确勾选）
  // ==========================================================================

  Future<_BackupCategoryFilter?> _showExportCategoryDialog() async {
    final t = context.tokens;
    var poopers = true;
    var records = true;
    var templates = true;
    var settings = true;

    return showDialog<_BackupCategoryFilter>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final hasAny = poopers || records || templates || settings;

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
                        child: Icon(LucideIcons.download, size: 18, color: t.brandInk),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '选择备份导出分类',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: t.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '请勾选本次需要打包导出的数据分类：',
                    style: TextStyle(fontSize: 12.5, color: t.ink3),
                  ),
                  const SizedBox(height: 10),
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
                          subtitle: '包含所有成员头像、昵称与默认人',
                          checked: poopers,
                          onChanged: (v) => setDialogState(() => poopers = v ?? true),
                        ),
                        Divider(height: 1, thickness: 0.8, color: t.lineSoft),
                        _CategoryCheckboxRow(
                          icon: LucideIcons.clock,
                          title: '打卡记录与备注',
                          subtitle: '包含如厕起止时间、时长与记录备注',
                          checked: records,
                          onChanged: (v) => setDialogState(() => records = v ?? true),
                        ),
                        Divider(height: 1, thickness: 0.8, color: t.lineSoft),
                        _CategoryCheckboxRow(
                          icon: LucideIcons.tags,
                          title: '便便感受标签',
                          subtitle: '包含常用打卡模板标签与排序',
                          checked: templates,
                          onChanged: (v) => setDialogState(() => templates = v ?? true),
                        ),
                        Divider(height: 1, thickness: 0.8, color: t.lineSoft),
                        _CategoryCheckboxRow(
                          icon: LucideIcons.slidersHorizontal,
                          title: '应用偏好设置',
                          subtitle: '包含周起始日、日历字号与主题外观',
                          checked: settings,
                          onChanged: (v) => setDialogState(() => settings = v ?? true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        child: Text('取消', style: TextStyle(color: t.ink3)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: t.brandInk,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(PoopRadii.pill),
                          ),
                        ),
                        onPressed: hasAny
                            ? () => Navigator.of(ctx).pop(
                                  _BackupCategoryFilter(
                                    poopers: poopers,
                                    records: records,
                                    templates: templates,
                                    settings: settings,
                                  ),
                                )
                            : null,
                        child: const Text('开始导出'),
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

  Future<void> _exportToFile() async {
    final filter = await _showExportCategoryDialog();
    if (filter == null) return;

    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      final settings = ref.read(settingsProvider);
      final service = ref.read(backupServiceProvider);
      final webDavConfig = ref.read(webDavConfigProvider);

      final data = await service.createBackupData(
        db: db,
        settings: settings,
        webDavConfig: webDavConfig,
        includePoopers: filter.poopers,
        includeRecords: filter.records,
        includeTemplates: filter.templates,
        includeSettings: filter.settings,
      );
      final file = await service.exportToFile(data);
      await _loadLocalBackups();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '已成功导出备份文件：${file.path.split(Platform.pathSeparator).last}',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '立即分享',
              textColor: Colors.white,
              onPressed: () => service.shareBackupFile(file.path),
            ),
          ),
        );
    } catch (e) {
      if (mounted) _showSnack('导出失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareLocalFile(LocalBackupFileInfo item) async {
    try {
      final service = ref.read(backupServiceProvider);
      await service.shareBackupFile(
        item.file.path,
        title: '分享备份文件：${item.name}',
      );
    } catch (e) {
      if (mounted) _showSnack('分享失败：$e', isError: true);
    }
  }

  Future<void> _copyJsonToClipboard() async {
    final filter = await _showExportCategoryDialog();
    if (filter == null) return;

    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      final settings = ref.read(settingsProvider);
      final service = ref.read(backupServiceProvider);
      final webDavConfig = ref.read(webDavConfigProvider);

      final data = await service.createBackupData(
        db: db,
        settings: settings,
        webDavConfig: webDavConfig,
        includePoopers: filter.poopers,
        includeRecords: filter.records,
        includeTemplates: filter.templates,
        includeSettings: filter.settings,
      );
      await service.copyToClipboard(data);

      if (!mounted) return;
      _showSnack('备份 JSON 已复制到剪贴板，可粘贴保存');
    } catch (e) {
      if (mounted) _showSnack('复制失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ==========================================================================
  //  导入动作（深浅色完美适配 + 按分类精确恢复）
  // ==========================================================================
  // ==========================================================================

  Future<void> _importFromFilePicker() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(backupServiceProvider);
      final content = await service.pickBackupFileContent();
      if (!mounted) return;
      if (content == null) {
        return; // 用户取消选择
      }
      final data = service.readBackupFromJsonString(content);
      _showRestoreDialog(data, sourceLabel: '外部导入文件');
    } catch (e) {
      if (mounted) _showSnack('解析失败：所选文件非有效备份 JSON', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importFromClipboard() async {
    final service = ref.read(backupServiceProvider);
    try {
      final data = await service.readFromClipboard();
      if (!mounted) return;
      if (data == null) {
        _showSnack('剪贴板中未找到有效备份数据文本', isError: true);
        return;
      }
      _showRestoreDialog(data, sourceLabel: '剪贴板');
    } catch (e) {
      if (mounted) _showSnack('解析失败：格式非有效备份 JSON', isError: true);
    }
  }

  Future<void> _importFromFile(LocalBackupFileInfo item) async {
    final service = ref.read(backupServiceProvider);
    try {
      final data = await service.readBackupFromFile(item.file);
      if (!mounted) return;
      _showRestoreDialog(data, sourceLabel: item.name);
    } catch (e) {
      if (mounted) _showSnack('读取失败：$e', isError: true);
    }
  }

  void _showRestoreDialog(BackupData data, {required String sourceLabel}) {
    final t = context.tokens;
    final meta = data.metadata;
    final createdStr = DateFormat('yyyy-MM-dd HH:mm').format(meta.createdAt);

    // 默认如果备份中含对应数据则勾选，不含则禁用
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
                        child: Icon(LucideIcons.archiveRestore, size: 18, color: t.brandInk),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '恢复备份数据',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: t.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 备份来源与时间
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
                            '来源：$sourceLabel',
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
                    '• 增量合并：保留本地数据，仅补充不存在的项\n'
                    '• 彻底覆盖：仅清空所选分类并完全恢复为备份',
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
    setState(() => _loading = true);
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
      _showSnack(overrideAll ? '已按所选分类彻底覆盖恢复！' : '已按所选分类增量合并完成！');
    } catch (e) {
      if (mounted) _showSnack('恢复失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteLocalFile(LocalBackupFileInfo item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除本地备份'),
        content: Text('确定删除备份文件「${item.name}」吗？'),
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
      final service = ref.read(backupServiceProvider);
      await service.deleteLocalBackup(item.file);
      await _loadLocalBackups();
      if (mounted) _showSnack('已删除本地备份');
    }
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
    final poopers = ref.watch(allPoopersProvider).value ?? const [];
    final templates = ref.watch(noteTemplatesProvider).value ?? const [];
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: '数据备份与恢复',
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + bottomInset),
        children: [
          // ---------------- 当前设备数据现状 ----------------
          const SettingsSectionLabel('当前数据统计'),
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
              child: Row(
                children: [
                  Expanded(
                    child: _StatColumn(
                      label: '屙屎人员',
                      value: '${poopers.length}',
                      unit: '人',
                    ),
                  ),
                  Container(width: 1, height: 32, color: t.lineSoft),
                  Expanded(
                    child: _StatColumn(
                      label: '常用模板',
                      value: '${templates.length}',
                      unit: '条',
                    ),
                  ),
                  Container(width: 1, height: 32, color: t.lineSoft),
                  Expanded(
                    child: _StatColumn(
                      label: '本地备份',
                      value: '${_localBackups.length}',
                      unit: '份',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- 导出备份 ----------------
          const SettingsSectionLabel('导出备份'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.download,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '生成并保存本地文件',
                subtitle: '保存到本地备份目录，生成独立 JSON 文件',
                trailing: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const SettingsChevron(),
                onTap: _loading ? null : _exportToFile,
              ),
              SettingsRow(
                leading: LucideIcons.copy,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '复制备份 JSON 到剪贴板',
                subtitle: '文本格式，方便直接粘贴到微信/备忘录保存',
                trailing: const SettingsChevron(),
                onTap: _loading ? null : _copyJsonToClipboard,
              ),
            ],
          ),

          // ---------------- 导入恢复 ----------------
          const SettingsSectionLabel('恢复与导入'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.folderOpen,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '从本地文件选取导入',
                subtitle: '调起系统文件管理器选取 .json 备份文件并恢复',
                trailing: const SettingsChevron(),
                onTap: _loading ? null : _importFromFilePicker,
              ),
              SettingsRow(
                leading: LucideIcons.clipboardPaste,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '从剪贴板粘贴导入',
                subtitle: '读取剪贴板的 JSON 备份文本并恢复',
                trailing: const SettingsChevron(),
                onTap: _loading ? null : _importFromClipboard,
              ),
            ],
          ),

          // ---------------- 本地历史备份文件列表 ----------------
          SettingsSectionLabel('本地备份文件 (${_localBackups.length})'),
          if (_localBackups.isEmpty)
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
                  '暂无本地备份文件，点击上方即可创建',
                  style: TextStyle(fontSize: 13, color: t.ink3),
                ),
              ),
            )
          else
            SettingsCard(
              children: [
                for (final item in _localBackups)
                  _LocalBackupRow(
                    item: item,
                    onRestore: () => _importFromFile(item),
                    onShare: () => _shareLocalFile(item),
                    onDelete: () => _deleteLocalFile(item),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: t.ink3, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: t.brandInk,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(fontSize: 11, color: t.ink3),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocalBackupRow extends StatelessWidget {
  const _LocalBackupRow({
    required this.item,
    required this.onRestore,
    required this.onShare,
    required this.onDelete,
  });

  final LocalBackupFileInfo item;
  final VoidCallback onRestore;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final meta = item.metadata;
    final subtitle = meta != null
        ? '${item.formattedDate} · ${meta.recordCount}条记录 · ${item.formattedSize}'
        : '${item.formattedDate} · ${item.formattedSize}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.brandSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(LucideIcons.fileArchive, size: 18, color: t.brandInk),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: t.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // 紧凑型微操作按钮组（分享、应用恢复、删除，紧密相邻不散漫）
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 分享按钮
              _CompactActionButton(
                icon: LucideIcons.share2,
                color: t.ink2,
                backgroundColor: t.paperDeep,
                tooltip: '分享此备份文件',
                onTap: onShare,
              ),
              const SizedBox(width: 5),
              // 2. 应用/恢复按钮（采用清晰有力的恢复/应用语义图标）
              _CompactActionButton(
                icon: LucideIcons.archiveRestore,
                color: t.brandInk,
                backgroundColor: t.brandSoft,
                tooltip: '应用并恢复此备份',
                onTap: onRestore,
              ),
              const SizedBox(width: 5),
              // 3. 删除按钮
              _CompactActionButton(
                icon: LucideIcons.trash2,
                color: t.ink4,
                backgroundColor: t.paperDeep,
                tooltip: '删除备份文件',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 紧凑微按钮组件，避免默认 IconButton 冗余的 48px padding 导致按钮间距过大
class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

/// 备份分类选择筛选器
class _BackupCategoryFilter {
  const _BackupCategoryFilter({
    required this.poopers,
    required this.records,
    required this.templates,
    required this.settings,
  });

  final bool poopers;
  final bool records;
  final bool templates;
  final bool settings;
}

/// 对话框内部可勾选的分类条目行
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
