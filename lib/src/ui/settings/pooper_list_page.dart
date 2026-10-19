import 'dart:ui';

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
import '../widgets/smooth_page_route.dart';
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

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: '屙屎人',
      actions: [
        Tooltip(
          message: '新增屙屎人',
          preferBelow: true,
          verticalOffset: 24,
          waitDuration: const Duration(milliseconds: 200),
          triggerMode: TooltipTriggerMode.longPress,
          child: InkWell(
            onTap: () => _openEdit(context, ref, null),
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(LucideIcons.plus, size: 19, color: t.brandInk),
            ),
          ),
        ),
      ],
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + bottomInset),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await ref.read(databaseProvider).unarchivePooper(p.id);
                            _refresh(ref);
                          },
                          child: const Text('恢复'),
                        ),
                        const SizedBox(width: 4),
                        _ActionButton(
                          icon: LucideIcons.trash2,
                          tooltip: '彻底删除（含全部记录）',
                          isDanger: true,
                          onTap: () => _confirmPurge(context, ref, p),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Text(
                '归档的成员不出现在打卡选择列表中，但所有历史记录均完整保留 —— '
                '所以日历上的次数不会莫名变少。真要连记录一起清掉，用右侧的删除。',
                style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 彻底删除确认：**先把要删多少条记录摆出来**。
  ///
  /// 不报数字的确认框等于没确认 —— 用户点下去之前得知道自己在损失什么。
  static Future<void> _confirmPurge(
    BuildContext context,
    WidgetRef ref,
    Pooper pooper,
  ) async {
    final db = ref.read(databaseProvider);
    final recordCount = await db.countRecordsOf(pooper.id);
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('彻底删除「${pooper.name}」？'),
        content: Text(
          recordCount > 0
              ? 'TA 名下的 $recordCount 条记录会一并删掉，删除后无法恢复。\n\n'
                  '如果只是不想再在打卡列表里看到他，请改用「恢复」旁边的归档 —— '
                  '历史记录会完整保留。'
              : '「${pooper.name}」名下还没有任何记录，删除后无法恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              recordCount > 0 ? '永久删除 $recordCount 条' : '永久删除',
              style: TextStyle(color: context.tokens.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final deleted = await db.purgePooperAndDetachWidgets(pooper.id);
    _refresh(ref);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            deleted > 0
                ? '已删除「${pooper.name}」及其 $deleted 条记录'
                : '已删除「${pooper.name}」',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
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
      smoothPageRoute(PooperEditPage(pooper: pooper)),
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
    final isDark = t.isDark;

    final cardRadius = BorderRadius.circular(PoopRadii.card);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: cardRadius,
        border: Border.all(color: t.lineSoft),
        boxShadow: [
          BoxShadow(
            color: t.isDark
                ? Colors.black.withValues(alpha: 0.2)
                : const Color(0x082D1B0D),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        clipBehavior: Clip.antiAlias,
        child: DragBoundary(
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: poopers.length,
            dragBoundaryProvider: (context) => DragBoundary.forRectOf(context),
            proxyDecorator: (child, index, animation) {
              final p = (index >= 0 && index < poopers.length)
                  ? poopers[index]
                  : null;
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final animValue =
                      Curves.easeInOutCubic.transform(animation.value);
                  final elevation = lerpDouble(0, 12, animValue)!;
                  return Material(
                    color: t.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: cardRadius,
                      side: BorderSide(
                        color: t.brand.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    elevation: elevation,
                    shadowColor: isDark
                        ? Colors.black.withValues(alpha: 0.6)
                        : const Color(0x38000000),
                    clipBehavior: Clip.antiAlias,
                    child: ClipRRect(
                      borderRadius: cardRadius,
                      child: p != null
                          ? _PooperRowContent(
                              pooper: p,
                              isDragging: true,
                              borderRadius: cardRadius,
                            )
                          : child,
                    ),
                  );
                },
              );
            },
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
                total: poopers.length,
                onTap: () => onEdit(p),
                onChanged: onChanged,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PooperRow extends ConsumerWidget {
  const _PooperRow({
    super.key,
    required this.pooper,
    required this.index,
    required this.total,
    required this.onTap,
    required this.onChanged,
  });

  final Pooper pooper;
  final int index;
  final int total;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final db = ref.read(databaseProvider);

    final r = PoopRadii.card;
    BorderRadius rowRadius;
    if (total <= 1) {
      rowRadius = BorderRadius.circular(r);
    } else if (index == 0) {
      rowRadius = BorderRadius.vertical(top: Radius.circular(r));
    } else if (index == total - 1) {
      rowRadius = BorderRadius.vertical(bottom: Radius.circular(r));
    } else {
      rowRadius = BorderRadius.zero;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (index > 0)
          Divider(
            height: 1,
            thickness: 1,
            color: t.lineSoft,
            indent: 16,
            endIndent: 16,
          ),
        _PooperRowContent(
          pooper: pooper,
          index: index,
          borderRadius: rowRadius,
          onTap: onTap,
          onArchive: () => _confirmArchive(context, ref),
          onSetDefault: () async {
            await db.setDefaultPooper(pooper.id);
            onChanged();
          },
        ),
      ],
    );
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('归档「${pooper.name}」？'),
        content: const Text(
          '归档后不再出现在新建选择列表中，桌面上绑定他的小组件会自动改为跟随默认成员；'
          '日历历史记录与统计照常保留，可随时在列表下方恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '确认归档',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // 走带清理的版本：归档之后还要把指向 TA 的小组件绑定一并收回，
    // 否则那些组件会静默变成「显示默认成员」，用户只会觉得头像不对。
    await ref.read(databaseProvider).archivePooperAndDetachWidgets(pooper.id);
    onChanged();
  }
}

/// 成员行的核心内容组件，复用于普通列表与拖拽高亮代理卡片。
class _PooperRowContent extends StatelessWidget {
  const _PooperRowContent({
    required this.pooper,
    this.index,
    this.borderRadius,
    this.onTap,
    this.onArchive,
    this.onSetDefault,
    this.isDragging = false,
  });

  final Pooper pooper;
  final int? index;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onSetDefault;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    Widget handle = Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
      child: Icon(
        LucideIcons.gripVertical,
        size: 17,
        color: isDragging ? t.brandInk : t.ink4,
      ),
    );

    if (!isDragging && index != null) {
      handle = ReorderableDragStartListener(
        index: index!,
        child: handle,
      );
    }

    final rowContent = Padding(
      padding: const EdgeInsets.fromLTRB(10, 11, 12, 11),
      child: Row(
        children: [
          // 1. 拖动排序把手（移至最左侧，符合国际通用列表规范，杜绝误触）
          handle,

          // 2. 成员头像
          PooperAvatar(pooper: pooper, size: 40, radius: 13, iconSize: 19),
          const SizedBox(width: 12),

          // 3. 成员姓名与备注信息
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
                    const SizedBox(width: 6),
                    if (pooper.isDefault)
                      _DefaultBadge()
                    else if (!isDragging && onSetDefault != null)
                      GestureDetector(
                        onTap: onSetDefault,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: t.paperDeep,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.star,
                                size: 10,
                                color: t.ink3,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '设为默认',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: t.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (pooper.remark != null && pooper.remark!.isNotEmpty) ...[
                  const SizedBox(height: 2.5),
                  Text(
                    pooper.remark!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: t.ink3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 4. 外露的快捷操作按钮区：编辑 + 归档
          if (!isDragging) ...[
            _ActionButton(
              icon: LucideIcons.pencil,
              tooltip: '编辑',
              onTap: onTap ?? () {},
            ),
            const SizedBox(width: 6),
            _ActionButton(
              icon: LucideIcons.archive,
              tooltip: '归档',
              isDanger: true,
              onTap: onArchive ?? () {},
            ),
          ],
        ],
      ),
    );

    // 拖拽悬浮卡片无需水波纹，彻底消除拖拽中的直角高亮干扰
    if (isDragging) {
      return rowContent;
    }

    final effectiveRadius = borderRadius ?? BorderRadius.zero;
    return ClipRRect(
      borderRadius: effectiveRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        child: rowContent,
      ),
    );
  }
}

/// 外露的操作微按钮
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = widget.isDanger
        ? t.danger.withValues(alpha: 0.12)
        : t.brandSoft;
    final fg = widget.isDanger ? t.danger : t.brandInk;

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1.0,
          duration: PoopMotions.pressDuration,
          curve: PoopMotions.pressCurve,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isDanger
                    ? t.danger.withValues(alpha: 0.22)
                    : t.brandInk.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 15, color: fg),
          ),
        ),
      ),
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
              color: t.brandSoft,
              borderRadius: BorderRadius.circular(26),
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.users, size: 32, color: t.brandInk),
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
