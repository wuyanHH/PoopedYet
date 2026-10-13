import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../calendar/calendar_math.dart';
import '../../state/calendar_data.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../widgets/settings_widgets.dart';
import 'note_template_page.dart';
import 'pooper_list_page.dart';

/// 设置主页（视觉稿 ⑩）。
///
/// **只放能真正工作的项**。摆一排点了没反应的入口，比空着更糟 ——
/// 用户会以为是坏了。还没做的（统计、备份导出、节假日数据管理）
/// 等做完了再加进来。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final settings = ref.watch(settingsProvider);
    final s = ref.read(settingsProvider.notifier);

    final poopers = ref.watch(activePoopersProvider).value ?? const [];
    final templates = ref.watch(noteTemplatesProvider).value ?? const [];

    return SettingsScaffold(
      title: '设置',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ---------------- 人员与备注 ----------------
          const SettingsSectionLabel('人员与备注'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.users,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '屙屎人',
                subtitle: poopers.isEmpty
                    ? '还没有'
                    : poopers.map((p) => p.name).join('、'),
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const PooperListPage()),
              ),
              SettingsRow(
                leading: LucideIcons.tags,
                leadingColor: t.brandInk,
                leadingBackground: t.brandSoft,
                title: '默认备注',
                subtitle: '${templates.length} 条 · 记一次时的快捷选项',
                trailing: const SettingsChevron(),
                onTap: () => _push(context, const NoteTemplatePage()),
              ),
            ],
          ),

          // ---------------- 日历 ----------------
          const SettingsSectionLabel('日历'),
          SettingsCard(
            children: [
              SettingsRow(
                title: '每周起始日',
                subtitle: '日历第一列是周一还是周日',
                trailing: SettingsSegmented<WeekStart>(
                  options: const [('周一', WeekStart.monday), ('周日', WeekStart.sunday)],
                  value: settings.weekStart,
                  onChanged: s.setWeekStart,
                ),
              ),
              SettingsRow(
                title: '日历字号',
                subtitle: '系统字号放大时，日历最多跟到 1.3×',
                trailing: SettingsSegmented<CalendarTextSize>(
                  options: const [
                    ('小', CalendarTextSize.small),
                    ('中', CalendarTextSize.medium),
                    ('大', CalendarTextSize.large),
                  ],
                  value: settings.calendarTextSize,
                  onChanged: s.setCalendarTextSize,
                ),
              ),
              SettingsRow(
                title: '格内显示头像与次数',
                subtitle: '关闭后日期格更清爽',
                trailing: SettingsSwitch(
                  value: settings.showBadges,
                  onChanged: s.setShowBadges,
                ),
              ),
              SettingsRow(
                title: '显示休 / 班角标',
                subtitle: '法定假日与调休上班日',
                trailing: SettingsSwitch(
                  value: settings.showHolidayTags,
                  onChanged: s.setShowHolidayTags,
                ),
              ),
              SettingsRow(
                title: '周末日期用焦糖色',
                trailing: SettingsSwitch(
                  value: settings.weekendBrandColor,
                  onChanged: s.setWeekendBrandColor,
                ),
              ),
              SettingsRow(
                title: '隐藏已归档的屙屎人',
                subtitle: '默认不隐藏 —— 归档的人历史仍在，'
                    '隐藏会让日历次数看起来莫名变少',
                trailing: SettingsSwitch(
                  value: settings.hideArchivedPoopers,
                  onChanged: s.setHideArchivedPoopers,
                ),
              ),
            ],
          ),

          // ---------------- 关于 ----------------
          const SettingsSectionLabel('关于'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.info,
                title: '版本',
                trailing: const SettingsValue(_version),
              ),
              SettingsRow(
                leading: LucideIcons.notebookPen,
                title: '开源许可',
                subtitle: '得意黑字体等第三方组件',
                trailing: const SettingsChevron(),
                // Flutter 内置的许可页。得意黑的 OFL 文本在 main() 里
                // 通过 LicenseRegistry 注册，所以这里能列出来。
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: '屙了么 PoopedYet',
                  applicationVersion: _version,
                ),
              ),
            ],
          ),

          if (kDebugMode) ...[
            const SettingsSectionLabel('开发'),
            SettingsCard(
              children: [
                SettingsRow(
                  leading: LucideIcons.triangleAlert,
                  leadingColor: t.danger,
                  title: '演示数据',
                  subtitle: '长按主页标题「屙了么」也能打开',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static const _version = '0.1.0';

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
