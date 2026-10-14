import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';

/// 弹出全局统一精致的「撤销删除」悬浮通知卡片。
///
/// 严格遵循手帐温润设计系统：
///   - 抛弃突兀的黑底弹窗，采用纯净自适应的白玉卡片（`t.surface`）；
///   - 柔和高级的暖调弥散阴影，与日历卡片、记录卡片完全同源；
///   - 字体与图标采用设计系统标准令牌（`t.ink`、`t.ink3`、`t.danger`、`t.brandFill`）。
void showUndoSnackBar(
  BuildContext context, {
  required String title,
  String subtitle = '若为误触，可立即恢复此记录',
  required VoidCallback onUndo,
}) {
  final t = context.tokens;
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 4),
      content: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: t.lineSoft.withValues(alpha: t.isDark ? 0.35 : 0.85),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: t.isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0x184A2810),
              blurRadius: 18,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: t.isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : const Color(0x0C000000),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左侧状态图标微徽章（柔和朱砂红微底）
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: t.danger.withValues(alpha: t.isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: t.danger.withValues(alpha: t.isDark ? 0.4 : 0.22),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.trash2,
                size: 17,
                color: t.danger,
              ),
            ),
            const SizedBox(width: 12),

            // 中间文案（与整体界面层级一致的墨黑与辅文字）
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.ink3,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // 右侧「撤销」胶囊按钮（品牌强调色）
            _UndoButton(
              tokens: t,
              onTap: () {
                HapticFeedback.mediumImpact();
                messenger.hideCurrentSnackBar();
                onUndo();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _UndoButton extends StatefulWidget {
  const _UndoButton({
    required this.tokens,
    required this.onTap,
  });

  final PoopTokens tokens;
  final VoidCallback onTap;

  @override
  State<_UndoButton> createState() => _UndoButtonState();
}

class _UndoButtonState extends State<_UndoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
          decoration: BoxDecoration(
            color: t.brandFill,
            borderRadius: BorderRadius.circular(PoopRadii.pill),
            boxShadow: [
              BoxShadow(
                color: t.brandFill.withValues(alpha: 0.32),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.undo2,
                size: 13.5,
                color: Colors.white,
              ),
              SizedBox(width: 4.5),
              Text(
                '撤销',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
