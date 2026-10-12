import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../state/calendar_data.dart';
import '../../theme/tokens.dart';

/// 备注输入件：快捷 chip + 多行文本域 + 字数 + 添加。
///
/// 需求原文：「可以给每次拉屎添加备注，可以是多条备注，备注也有实时的时间和备注信息」。
///
/// 所以这里的分工是：
///   - **文本域承担"能写长"** —— 单行输入框写不下「昨晚火锅太辣了，今天肚子一直咕噜响」
///   - **chip 承担"快速"** —— 常见情况（拉肚子 / 很顺畅）不该让人打字
///   - **chip 是追加进文本域，不是各自生成一条**，提交时整段存成**一条**带时刻的备注
///
/// 见 `docs/design-system.md` §9c。
class NoteComposer extends ConsumerStatefulWidget {
  const NoteComposer({
    super.key,
    required this.onSubmit,
    this.hint = '写点什么…快捷备注点一下会追加到这里',
    this.maxLength = 200,
  });

  /// 用户点「添加」时回调。返回后组件会清空。
  final Future<void> Function(String text) onSubmit;

  final String hint;
  final int maxLength;

  @override
  ConsumerState<NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends ConsumerState<NoteComposer> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 字数要实时显示，所以每次输入都 setState。文本量很小，无所谓。
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  /// 把快捷备注追加到文本域。
  ///
  /// 用中文顿号连接，而不是空格 —— 「拉肚子、带薪摸鱼」读起来是并列的几条，
  /// 「拉肚子 带薪摸鱼」看着像一句话。已存在就不重复追加。
  void _append(String text) {
    final cur = _controller.text.trim();
    if (cur.contains(text)) return;

    final next = cur.isEmpty ? text : '$cur、$text';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      await widget.onSubmit(text);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final templates =
        ref.watch(noteTemplatesProvider).value ?? const <NoteTemplate>[];
    final text = _controller.text;
    final canSubmit = text.trim().isNotEmpty && !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (templates.isNotEmpty) ...[
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final tpl in templates)
                GestureDetector(
                  // 有 key 才测得准：chip 的文字和输入框里的文字会撞车，
                  // 单靠 find.text 会同时命中两个。
                  key: ValueKey('noteChip:${tpl.content}'),
                  onTap: () => _append(tpl.content),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: t.brandSoft,
                      borderRadius: BorderRadius.circular(PoopRadii.pill),
                      border: Border.all(color: const Color(0x1F9A5219)),
                    ),
                    child: Text(
                      tpl.content,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.brandInk,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
        ],
        TextField(
          key: const ValueKey('noteInput'),
          controller: _controller,
          maxLines: null,
          minLines: 3,
          maxLength: widget.maxLength,
          textInputAction: TextInputAction.newline,
          style: TextStyle(fontSize: 13.5, height: 1.5, color: t.ink),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(fontSize: 13, color: t.ink3),
            filled: true,
            fillColor: t.surface,
            // 内置计数器样式太抢眼，关掉自己画。
            counterText: '',
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.brandInk, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${text.characters.length}/${widget.maxLength}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: text.characters.length >= widget.maxLength
                    ? t.danger
                    : t.ink3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: canSubmit ? _submit : null,
              child: Opacity(
                opacity: canSubmit ? 1 : 0.4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: t.brandFill,
                    borderRadius: BorderRadius.circular(PoopRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.plus,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      const Text(
                        '添加这条备注',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
