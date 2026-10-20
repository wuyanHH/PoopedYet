import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../calendar/calendar_math.dart';
import '../../data/database.dart';
import '../../data/update/apk_downloader.dart';
import '../../data/update/app_version.dart';
import '../../state/backup_state.dart';
import '../../state/calendar_data.dart';
import '../../state/calendar_view.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/smooth_page_route.dart';
import '../widgets/update_download_banner.dart';
import 'about_app_page.dart';
import 'backup/data_backup_page.dart';
import 'backup/webdav_sync_page.dart';
import 'calendar_settings_page.dart';
import 'note_template_page.dart';
import 'pooper_list_page.dart';
import 'theme_settings_page.dart';
import 'widget_manager_page.dart';
import 'widget_notification_page.dart';

/// 设置主页。
///
/// 遵循「总控概览 + 状态回显 + 细节下沉」设计原则：
/// 1. 生活记录档案（高频业务 · 第一级直达且支持快捷加号）
/// 2. 界面与偏好（外观主题、日历与打卡视图收敛二级页，状态动态回显）
/// 3. 系统扩展与数据（小组件与灵动胶囊、数据备份、WebDAV云同步）
/// 4. 软件信息与支持（版本更新与关于）
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final settings = ref.watch(settingsProvider);

    final poopers = ref.watch(activePoopersProvider).value ?? const [];
    final templates = ref.watch(noteTemplatesProvider).value ?? const [];
    final webDavConfig = ref.watch(webDavConfigProvider);
    final download = ref.watch(updateDownloadProvider);

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: '设置',
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + bottomInset),
        children: [
          // 应用内更新正在下载/已就绪时展示浮动条
          const UpdateDownloadBanner(),

          // ---------------- 1. 生活记录档案 (核心高频) ----------------
          const SettingsSectionLabel('生活记录档案'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.users,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '屙屎人管理',
                subtitleWidget: _buildPoopersPreview(context, poopers),
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const PooperListPage()),
              ),
              SettingsRow(
                leading: LucideIcons.tags,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '便便感受标签',
                subtitleWidget: _buildTemplatesPreview(context, templates),
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const NoteTemplatePage()),
              ),
            ],
          ),

          // ---------------- 2. 界面与显示 ----------------
          const SettingsSectionLabel('界面与显示'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.palette,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '外观与主题',
                subtitle: switch (settings.themeMode) {
                  AppThemeMode.system => '跟随系统 · ${settings.themeColor.label}',
                  AppThemeMode.light => '浅色暖纸 · ${settings.themeColor.label}',
                  AppThemeMode.dark => '暗夜深咖 · ${settings.themeColor.label}',
                },
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const ThemeSettingsPage()),
              ),
              SettingsRow(
                leading: LucideIcons.calendar,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '日历与打卡视图',
                subtitle:
                    '${settings.defaultCalendarMode == CalendarMode.month ? '月历' : '周历'} · '
                    '周${settings.weekStart == WeekStart.monday ? '一' : '日'}起始 · '
                    '${settings.recordSortOrder == RecordSortOrder.desc ? '时间倒序' : '时间正序'}',
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const CalendarSettingsPage()),
              ),
            ],
          ),

          // ---------------- 3. 组件与通知 ----------------
          const SettingsSectionLabel('组件与通知'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.layoutGrid,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '桌面小组件',
                subtitle: '防社死暗号模式 · 2×2 / 4×2 / 4×4 组件管理',
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const WidgetManagerPage()),
              ),
              SettingsRow(
                leading: LucideIcons.sparkles,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '通知与实时胶囊',
                subtitle: settings.liveIslandEnabled
                    ? '实时胶囊已开启 · 锁屏与原子岛跳秒'
                    : '实时胶囊已停用 · 纯离线无通知',
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const WidgetNotificationPage()),
              ),
            ],
          ),

          // ---------------- 4. 数据与同步 ----------------
          const SettingsSectionLabel('数据与同步'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.database,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '数据备份与恢复',
                subtitle: '本地 JSON 导出与导入 · 剪贴板备份',
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const DataBackupPage()),
              ),
              SettingsRow(
                leading: LucideIcons.cloud,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: 'WebDAV 云同步',
                subtitle: webDavConfig.isConfigured
                    ? (webDavConfig.lastSyncAt != null
                        ? '已配置 · 上次同步：${DateFormat('MM-dd HH:mm').format(webDavConfig.lastSyncAt!)}'
                        : '已配置 · 坚果云/Nextcloud等')
                    : '支持坚果云、Nextcloud、群晖等私有云',
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const WebDavSyncPage()),
              ),
            ],
          ),

          // ---------------- 5. 软件信息与支持 ----------------
          const SettingsSectionLabel('软件信息与支持'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.cloudDownload,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '检查新版本',
                subtitle: download.isDownloading
                    ? '正在后台下载 v${download.release?.versionName ?? ''} · ${download.percent}%'
                    : download.isCompleted
                        ? 'v${download.release?.versionName ?? ''} 安装包已就绪，点击安装'
                        : '当前版本 $kAppVersionLabel',
                trailing: const SettingsChevron(),
                onTap: () => AboutAppPage.handleCheckUpdate(context, ref),
              ),
              SettingsRow(
                leading: LucideIcons.info,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '关于屙了么',
                subtitle: '更新日志 · 自动更新 · 开源协议',
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const AboutAppPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(smoothPageRoute(page));
  }

  Widget _buildPoopersPreview(BuildContext context, List<Pooper> poopers) {
    final t = context.tokens;
    if (poopers.isEmpty) {
      return Text('暂无成员，点击添加', style: TextStyle(fontSize: 12, color: t.ink3));
    }

    final displayPoopers = poopers.take(3).toList();
    final remaining = poopers.length - displayPoopers.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in displayPoopers) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: p.isDefault ? t.brandSoft : t.paperDeep,
                borderRadius: BorderRadius.circular(PoopRadii.pill),
                border: Border.all(
                  color: p.isDefault
                      ? t.brandInk.withValues(alpha: 0.25)
                      : t.lineSoft,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p.isDefault) ...[
                    Icon(LucideIcons.star, size: 10, color: t.brandInk),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          p.isDefault ? FontWeight.w700 : FontWeight.w500,
                      color: p.isDefault ? t.brandInk : t.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
          ],
          if (remaining > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: t.paperDeep,
                borderRadius: BorderRadius.circular(PoopRadii.pill),
                border: Border.all(color: t.lineSoft, width: 0.8),
              ),
              child: Text(
                '+$remaining',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: t.ink3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplatesPreview(
    BuildContext context,
    List<NoteTemplate> templates,
  ) {
    final t = context.tokens;
    if (templates.isEmpty) {
      return Text('暂无标签，点击添加', style: TextStyle(fontSize: 12, color: t.ink3));
    }

    final displayTemplates = templates.take(3).toList();
    final remaining = templates.length - displayTemplates.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in displayTemplates) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: t.paperDeep,
                borderRadius: BorderRadius.circular(PoopRadii.pill),
                border: Border.all(color: t.lineSoft, width: 0.8),
              ),
              child: Text(
                item.content,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: t.ink2,
                ),
              ),
            ),
            const SizedBox(width: 5),
          ],
          if (remaining > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: t.paperDeep,
                borderRadius: BorderRadius.circular(PoopRadii.pill),
                border: Border.all(color: t.lineSoft, width: 0.8),
              ),
              child: Text(
                '+$remaining',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: t.ink3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
