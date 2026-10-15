import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../data/note_template_actions.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../theme/tokens.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/undo_snack_bar.dart';

/// 便便感受管理（原排便主题）。
///
/// 这里管的是新建或修改记录时出现的核心便便状态/感受选项。
/// 删掉一条感受标签**不会**影响已经写下的记录 —— 那些是独立成表的实体。
class NoteTemplatePage extends ConsumerWidget {
  const NoteTemplatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final list =
        ref.watch(noteTemplatesProvider).value ?? const <NoteTemplate>[];
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: '便便感受',
      actions: [
        // 1. 顶部快捷功能按钮：按使用频次一键排序
        if (list.length > 1)
          Tooltip(
            message: '按使用频次重新排序',
            preferBelow: true,
            verticalOffset: 24,
            waitDuration: const Duration(milliseconds: 200),
            triggerMode: TooltipTriggerMode.longPress,
            child: InkWell(
              onTap: () async {
                HapticFeedback.lightImpact();
                final db = ref.read(databaseProvider);
                await db.sortNoteTemplatesByUse();
                ref.invalidate(noteTemplatesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(
                        content: const Text('已按使用频次重新排序'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: t.ink,
                      ),
                    );
                }
              },
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  LucideIcons.arrowUpDown,
                  size: 18,
                  color: t.brandInk,
                ),
              ),
            ),
          ),
        // 2. 顶部新增按钮
        Tooltip(
          message: '新增便便感受标签',
          preferBelow: true,
          verticalOffset: 24,
          waitDuration: const Duration(milliseconds: 200),
          triggerMode: TooltipTriggerMode.longPress,
          child: InkWell(
            onTap: () => _promptNew(context, ref),
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
          if (list.isEmpty)
            _EmptyTemplates()
          else
            _TemplateListCard(
              templates: list,
              onEdit: (tpl) => edit(context, ref, tpl),
              onReorder: (ids) =>
                  ref.read(databaseProvider).reorderNoteTemplates(ids),
              onChanged: () => ref.invalidate(noteTemplatesProvider),
            ),

          if (list.isNotEmpty) ...[
            const SettingsSectionLabel('说明'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '长按把手可以拖动排序。排序决定打卡与补录时标签的展示先后 —— '
                '常用的排在前面，记录时更顺手。\n'
                '删掉一条感受不会影响已经打卡的记录，历史数据独立保留。',
                style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _promptNew(BuildContext context, WidgetRef ref) async {
    final text = await _promptText(context, title: '新建便便感受', initial: '');
    if (text == null) return;
    await ref.read(databaseProvider).createNoteTemplate(text);
    ref.invalidate(noteTemplatesProvider);
  }

  static Future<String?> _promptText(
    BuildContext context, {
    required String title,
    required String initial,
  }) async {
    final t = context.tokens;
    final controller = TextEditingController(text: initial);

    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: t.paper,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: t.lineSoft),
          ),
          title: Text(
            title,
            style: displayStyle(
              size: 18,
              letterSpacing: 0.5,
              color: t.ink,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            style: TextStyle(fontSize: 14.5, color: t.ink),
            decoration: InputDecoration(
              hintText: '比如：很顺畅、拉肚子、干硬、成型',
              hintStyle: TextStyle(fontSize: 13, color: t.ink3),
              filled: true,
              fillColor: t.surface,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.lineSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.lineSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.brandInk, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                '取消',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: t.ink3,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: t.brandFill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(ctx).pop(text.isEmpty ? null : text);
              },
              child: const Text(
                '保存',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  /// 供子组件复用。
  static Future<void> edit(
    BuildContext context,
    WidgetRef ref,
    NoteTemplate tpl,
  ) async {
    final text = await _promptText(
      context,
      title: '修改便便感受',
      initial: tpl.content,
    );
    if (text == null) return;
    final ok =
        await ref.read(databaseProvider).updateNoteTemplate(tpl.id, text);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('已经有一条相同的便便感受了'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    ref.invalidate(noteTemplatesProvider);
  }
}

/// 列表卡片：与屙屎人列表完全一致的 ReorderableListView 架构，统一交互与视觉质感
class _TemplateListCard extends StatelessWidget {
  const _TemplateListCard({
    required this.templates,
    required this.onEdit,
    required this.onReorder,
    required this.onChanged,
  });

  final List<NoteTemplate> templates;
  final ValueChanged<NoteTemplate> onEdit;
  final Future<void> Function(List<String> idsInOrder) onReorder;
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
            itemCount: templates.length,
            dragBoundaryProvider: (context) => DragBoundary.forRectOf(context),
            proxyDecorator: (child, index, animation) {
              final tpl = (index >= 0 && index < templates.length)
                  ? templates[index]
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
                      child: tpl != null
                          ? _TemplateRowContent(
                              template: tpl,
                              isDragging: true,
                              borderRadius: cardRadius,
                            )
                          : child,
                    ),
                  );
                },
              );
            },
            onReorderItem: (oldIndex, newIndex) {
              final ids = templates.map((p) => p.id).toList();
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              onReorder(ids).then((_) => onChanged());
            },
            itemBuilder: (context, i) {
              final tpl = templates[i];
              return _TemplateRow(
                key: ValueKey(tpl.id),
                template: tpl,
                index: i,
                total: templates.length,
                onTap: () => onEdit(tpl),
                onChanged: onChanged,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TemplateRow extends ConsumerWidget {
  const _TemplateRow({
    super.key,
    required this.template,
    required this.index,
    required this.total,
    required this.onTap,
    required this.onChanged,
  });

  final NoteTemplate template;
  final int index;
  final int total;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

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
        _TemplateRowContent(
          template: template,
          index: index,
          borderRadius: rowRadius,
          onTap: onTap,
          onDelete: () => _confirmDelete(context, ref),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final backupTpl = template;
    await db.deleteNoteTemplate(template.id);
    onChanged();
    if (context.mounted) {
      showUndoSnackBar(
        context,
        title: '已删除便便感受「${template.content}」',
        subtitle: '若为误触，可立即恢复此项',
        onUndo: () async {
          await db.restoreNoteTemplate(backupTpl);
          onChanged();
        },
      );
    }
  }
}

/// 每一行的核心内容，复用于普通列表与拖拽高亮代理卡片。
class _TemplateRowContent extends StatelessWidget {
  const _TemplateRowContent({
    required this.template,
    this.index,
    this.borderRadius,
    this.onTap,
    this.onDelete,
    this.isDragging = false,
  });

  final NoteTemplate template;
  final int? index;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
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
          // 1. 拖拽把手
          handle,

          // 2. 便便感受标签药丸胶囊
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
            decoration: BoxDecoration(
              color: t.brandSoft,
              borderRadius: BorderRadius.circular(PoopRadii.pill),
              border: Border.all(
                color: t.brandInk.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.tag,
                  size: 12.5,
                  color: t.brandInk,
                ),
                const SizedBox(width: 5),
                Text(
                  template.content,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.brandInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 3. 使用频次计数
          if (template.useCount > 0)
            Text(
              '已用 ${template.useCount} 次',
              style: TextStyle(
                fontSize: 11,
                color: t.ink3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          const Spacer(),

          // 4. 外露的操作微按钮区：编辑 + 删除（与屙屎人列表统一）
          if (!isDragging) ...[
            _ActionButton(
              icon: LucideIcons.pencil,
              tooltip: '编辑',
              onTap: onTap ?? () {},
            ),
            const SizedBox(width: 6),
            _ActionButton(
              icon: LucideIcons.trash2,
              tooltip: '删除',
              isDanger: true,
              onTap: onDelete ?? () {},
            ),
          ],
        ],
      ),
    );

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

/// 统一样式的操作微按钮（编辑、删除），与屙屎人列表保持 100% 相同的设计系统质感
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

class _EmptyTemplates extends StatelessWidget {
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
            child: Icon(LucideIcons.tags, size: 32, color: t.brandInk),
          ),
          const SizedBox(height: 14),
          Text(
            '还没有便便感受',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '加几条常用的排便状态与感受标签（如很顺畅、拉肚子、便秘等），\n'
            '打卡与补录时一键点选。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
          ),
        ],
      ),
    );
  }
}
