import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';

/// 纯粹的自定义多行备注输入器。
///
/// 专职负责输入个性化的长文字说明，不再耦合快捷药丸与顿号追加，
/// 快捷标签逻辑统一交由外层的标签池直接交互。
class NoteComposer extends StatefulWidget {
  const NoteComposer({
    super.key,
    required this.onSubmit,
    this.hint = '写点自定义备注说明...',
    this.maxLength = 200,
  });

  /// 用户点「添加」时回调。返回后组件会清空。
  final Future<void> Function(String text) onSubmit;

  final String hint;
  final int maxLength;

  @override
  State<NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends State<NoteComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onChanged() => setState(() {});

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _scrollToVisible();
    }
  }

  void _scrollToVisible() {
    // 延迟等键盘弹起与软键盘避让计算生效后，将整个输入框及下方的「添加备注」按钮完整滚动到视口中
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          alignment: 1.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
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
    final text = _controller.text;
    final canSubmit = text.trim().isNotEmpty && !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('noteInput'),
          controller: _controller,
          focusNode: _focusNode,
          onTap: _scrollToVisible,
          scrollPadding: const EdgeInsets.only(bottom: 120),
          maxLines: null,
          minLines: 2,
          maxLength: widget.maxLength,
          textInputAction: TextInputAction.newline,
          style: TextStyle(fontSize: 13.5, height: 1.45, color: t.ink),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(fontSize: 13, color: t.ink3),
            filled: true,
            fillColor: t.surface,
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
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${text.characters.length}/${widget.maxLength}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: text.characters.length >= widget.maxLength
                    ? t.danger
                    : t.ink3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canSubmit ? _submit : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                constraints: const BoxConstraints(minHeight: 34),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  gradient: canSubmit ? t.brandGradient : null,
                  color: canSubmit ? null : t.brandSoft,
                  borderRadius: BorderRadius.circular(PoopRadii.pill),
                  border: canSubmit
                      ? null
                      : Border.all(
                          color: t.brand.withValues(alpha: 0.22),
                          width: 0.9,
                        ),
                  boxShadow: canSubmit ? t.brandShadow : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_busy)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else ...[
                      Icon(
                        LucideIcons.plus,
                        size: 13,
                        color: canSubmit
                            ? Colors.white
                            : t.brandInk.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      '添加备注',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: canSubmit
                            ? Colors.white
                            : t.brandInk.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
