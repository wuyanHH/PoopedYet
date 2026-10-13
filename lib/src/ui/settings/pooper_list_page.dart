import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../data/pooper_actions.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../theme/tokens.dart';
import '../widgets/pooper_avatar.dart';
import '../widgets/settings_widgets.dart';
import 'pooper_edit_page.dart';

/// 屙屎人管理（视觉稿 ⑪）。
///
/// 能做：新增、改、拖拽排序、设为默认、归档、取消归档、彻底删除。
///
/// **「删除」默认是归档**：删人会连带几百条历史记录一起消失，
/// 那是不可接受的数据丢失。彻底删除藏在归档区的「危险操作」里。
class PooperListPage extends ConsumerWidget {
  const PooperListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final all = ref.watch(allPoopersProvider).value ?? const <Pooper>[];

    final active = all.where((p) => p.archivedAt == null).toList();
    final archived = all.where((p) => p.archivedAt != null).toList();

    return SettingsScaffold(
      title: '屙屎人',
      actions: [
        InkWell(
          onTap: () => _openEdit(context, ref, null),
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(LucideIcons.plus, size: 19, color: t.brandInk),
          ),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (active.isEmpty)
            _EmptyPoopers()
          else
            _ActiveList(
              poopers: active,
              onEdit: (p) => _openEdit(context, ref, p),
              onReorder: (ids) =>
                  ref.read(databaseProvider).reorderPoopers(ids),
              onChanged: () => _refresh(ref),
            ),

          if (active.isNotEmpty) ...[
            const SettingsSectionLabel('说明'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '长按可以拖动排序。排序决定日历徽标的先后 —— '
                '按人排而不是按次数排，日期格上的头像位置才不会天天跳。',
                style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
              ),
            ),
          ],

          if (archived.isNotEmpty) ...[
            const SettingsSectionLabel('已归档'),
            SettingsCard(
              children: [
                for (final p in archived)
                  SettingsRow(
                    leading: LucideIcons.users,
                    title: p.name,
                    subtitle: '历史记录仍保留，日历与统计照常计入',
                    trailing: TextButton(
                      onPressed: () async {
                        await ref.read(databaseProvider).unarchivePooper(p.id);
                        _refresh(ref);
                      },
                      child: const Text('恢复'),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Text(
                '归档的人不出现在「谁在屙」里，但历史一条都没少 —— '
                '所以日历上的次数不会莫名变少。',
                style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void _refresh(WidgetRef ref) {
    ref.invalidate(allPoopersProvider);
    ref.invalidate(activePoopersProvider);
    ref.invalidate(monthBadgesProvider);
    ref.invalidate(weekBadgesProvider);
    ref.invalidate(dayRecordsProvider);
  }

  static Future<void> _openEdit(
    BuildContext context,
    WidgetRef ref,
    Pooper? pooper,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PooperEditPage(pooper: pooper)),
    );
    _refresh(ref);
  }
}

class _ActiveList extends StatelessWidget {
  const _ActiveList({
    required this.poopers,
    required this.onEdit,
    required this.onReorder,
    required this.onChanged,
  });

  final List<Pooper> poopers;
  final ValueChanged<Pooper> onEdit;
  final Future<void> Function(List<String>) onReorder;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(PoopRadii.card),
        border: Border.all(color: t.lineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: poopers.length,
        // 用 onReorderItem 而不是已废弃的 onReorder：
        // **它已经把 newIndex 按"移除旧位置"调整过了**，
        // 所以这里不能再自己 `if (newIndex > oldIndex) newIndex -= 1` ——
        // 那是 onReorder 时代的老写法，配 onReorderItem 会变成多减一位。
        onReorderItem: (oldIndex, newIndex) {
          final ids = poopers.map((p) => p.id).toList();
          final moved = ids.removeAt(oldIndex);
          ids.insert(newIndex, moved);
          onReorder(ids).then((_) => onChanged());
        },
        itemBuilder: (context, i) {
          final p = poopers[i];
          return _PooperRow(
            key: ValueKey(p.id),
            pooper: p,
            index: i,
            onTap: () => onEdit(p),
            onChanged: onChanged,
          );
        },
      ),
    );
  }
}

class _PooperRow extends ConsumerWidget {
  const _PooperRow({
    super.key,
    required this.pooper,
    required this.index,
    required this.onTap,
    required this.onChanged,
  });

  final Pooper pooper;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (index > 0)
          Divider(height: 1, thickness: 1, color: t.lineSoft, indent: 16),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 6, 11),
            child: Row(
              children: [
                PooperAvatar(pooper: pooper, size: 38, radius: 13, iconSize: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pooper.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: t.ink,
                              ),
                            ),
                          ),
                          if (pooper.isDefault) ...[
                            const SizedBox(width: 7),
                            _DefaultBadge(),
                          ],
                        ],
                      ),
                      if (pooper.remark != null && pooper.remark!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          pooper.remark!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: t.ink3),
                        ),
                      ],
                    ],
                  ),
                ),
                // 长按这个把手拖动排序
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(LucideIcons.gripVertical, size: 16, color: t.ink4),
                  ),
                ),
                _RowMenu(
                  pooper: pooper,
                  onChanged: onChanged,
                  onEdit: onTap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: t.brandSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '默认',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: t.brandInk,
        ),
      ),
    );
  }
}

/// 每行右侧的「…」菜单。
class _RowMenu extends ConsumerWidget {
  const _RowMenu({
    required this.pooper,
    required this.onChanged,
    required this.onEdit,
  });

  final Pooper pooper;
  final VoidCallback onChanged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final db = ref.read(databaseProvider);

    return PopupMenuButton<String>(
      icon: Icon(LucideIcons.ellipsisVertical, size: 17, color: t.ink3),
      splashRadius: 18,
      onSelected: (v) async {
        switch (v) {
          case 'default':
            await db.setDefaultPooper(pooper.id);
          case 'edit':
            onEdit();
            return;
          case 'archive':
            await db.archivePooper(pooper.id);
        }
        onChanged();
      },
      itemBuilder: (ctx) => [
        if (!pooper.isDefault)
          const PopupMenuItem(value: 'default', child: Text('设为默认')),
        const PopupMenuItem(value: 'edit', child: Text('编辑')),
        const PopupMenuItem(value: 'archive', child: Text('归档（保留历史）')),
      ],
    );
  }
}

class _EmptyPoopers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: t.paperDeep,
              borderRadius: BorderRadius.circular(26),
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.users, size: 32, color: t.ink3),
          ),
          const SizedBox(height: 14),
          Text(
            '还没有屙屎人',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '点右上角加一个。家里几个人就加几个，\n'
            '日历上会用头像区分各自拉了几次。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
          ),
        ],
      ),
    );
  }
}
