import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';

/// 全局统一的微悬浮圆形展开/收起按钮：
/// - 纯圆形设计，带微投影与细腻描边；
/// - 内部包含 180° 顺滑旋转的 chevronDown 图标（折叠态向下，展开态向上）；
/// - 支持轻触微缩动画与触觉反馈。
class ExpandToggleButton extends StatefulWidget {
  const ExpandToggleButton({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    this.size = 24.0,
    this.semanticLabel,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final double size;
  final String? semanticLabel;

  @override
  State<ExpandToggleButton> createState() => _ExpandToggleButtonState();
}

class _ExpandToggleButtonState extends State<ExpandToggleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final iconSize = (widget.size * 0.55).clamp(12.0, 18.0);
    final tooltipText = widget.semanticLabel ?? (widget.isExpanded ? '收起完整内容' : '展开完整内容');

    return Tooltip(
      message: tooltipText,
      preferBelow: false,
      verticalOffset: 16,
      waitDuration: const Duration(milliseconds: 200),
      triggerMode: TooltipTriggerMode.longPress,
      child: Semantics(
        button: true,
        label: tooltipText,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onToggle();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.90 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: t.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: t.line.withValues(alpha: 0.85),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : const Color(0x185E422A),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedRotation(
                  turns: widget.isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.fastEaseInToSlowEaseOut,
                  child: Icon(
                    LucideIcons.chevronDown,
                    size: iconSize,
                    color: _pressed ? t.brandInk : t.ink3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
