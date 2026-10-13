import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../data/note_template_actions.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../theme/tokens.dart';
import '../widgets/settings_widgets.dart';

/// 默认备注管理（视觉稿 ⑬）。
///
/// 需求原文：「可以设置一些默认备注（比如拉肚子之类），也要支持手动增添」。
///
/// 这里管的是**记一次时出现的快捷选项**。删掉一条模板
/// **不会**影响已经写下的备注 —— 那些是独立成表的实体。
class NoteTemplatePage extends ConsumerWidget {
  const NoteTemplatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final list = ref.watch(noteTemplatesProvider).value ?? const <NoteTemplate>[];

    return SettingsScaffold(
      title: '默认备注',
      actions: [
        InkWell(
          onTap: () => _promptNew(context, ref),
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
          if (list.isEmpty)
            Padding(
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
                    child: Icon(LucideIcons.tags, size: 32, color: t.ink3),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '还没有默认备注',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '加几条常用的，记一次时点一下就填进去了。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
                  ),
                ],
              ),
            )
          else ...[
            SettingsCard(
              children: [
                for (final tpl in list)
                  _TemplateRow(template: tpl),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '长按拖动排序。顺序就是「记一次」里那一排 chip 的顺序。',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: t.ink3,
                        height: 1.6,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(databaseProvider)
                          .sortNoteTemplatesByUse();
                      ref.invalidate(noteTemplatesProvider);
                    },
                    child: const Text('按常用排序'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Text(
                '删掉一条模板不会影响已经写下的备注 —— '
                '那些是独立保存的，一条都不会少。',
                style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _promptNew(BuildContext context, WidgetRef ref) async {
    final text = await _promptText(context, title: '加一条默认备注', initial: '');
    if (text == null) return;
    await ref.read(databaseProvider).createNoteTemplate(text);
    ref.invalidate(noteTemplatesProvider);
  }

  static Future<String?> _promptText(
    BuildContext context, {
    required String title,
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: '比如：拉肚子'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final t = controller.text.trim();
              Navigator.of(ctx).pop(t.isEmpty ? null : t);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 供子组件复用。
  static Future<void> edit(
    BuildContext context,
    WidgetRef ref,
    NoteTemplate tpl,
  ) async {
    final text = await _promptText(context, title: '改备注', initial: tpl.content);
    if (text == null) return;
    final ok = await ref.read(databaseProvider).updateNoteTemplate(tpl.id, text);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('已经有一条一样的了'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    ref.invalidate(noteTemplatesProvider);
  }
}

class _TemplateRow extends ConsumerWidget {
  const _TemplateRow({required this.template});

  final NoteTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    return InkWell(
      onTap: () => NoteTemplatePage.edit(context, ref, template),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 6, 11),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: t.brandSoft,
                borderRadius: BorderRadius.circular(PoopRadii.pill),
                border: Border.all(color: const Color(0x1F9A5219)),
              ),
              child: Text(
                template.content,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: t.brandInk,
                ),
              ),
            ),
            const Spacer(),
            if (template.useCount > 0)
              Text(
                '用过 ${template.useCount} 次',
                style: TextStyle(
                  fontSize: 11,
                  color: t.ink3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () async {
                await ref
                    .read(databaseProvider)
                    .deleteNoteTemplate(template.id);
                ref.invalidate(noteTemplatesProvider);
              },
              icon: Icon(LucideIcons.trash2, size: 15, color: t.ink4),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
