import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';

/// 所有底部弹层的统一外壳：拖拽把手 + 标题 + 关闭按钮 + 圆角顶。
///
/// 抽出来是因为年月选择器、周选择器、记录详情、记一次都要这一套。
/// 各写一份的话，圆角/内边距/关闭按钮的位置迟早会各不相同。
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.scrollable = false,
    this.maxHeightFactor = 0.85,
    this.bottomBar,
  });

  final String title;

  /// 标题下面的一行小字（可选）。
  final String? subtitle;

  final Widget child;

  /// 内容超高时是否允许滚动。
  ///
  /// 记录详情弹层内容很长（人 + 时间 + 备注列表 + 输入框 + 按钮），
  /// 手机上必然超高，必须能滚。
  final bool scrollable;

  /// 最高占屏幕的比例。默认 0.85，留出舒适视觉间距与防超出保护。
  final double maxHeightFactor;

  /// 吸附固定在弹层底部的操作栏（不参与内容滚动，确保不被长内容遮挡，自带系统小白条安全区避让）。
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final viewInsetsBottom = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;

    // 计算弹层的最大允许高度（防超出屏幕顶部）
    final maxSheetHeight = (screenHeight - mediaQuery.padding.top) * maxHeightFactor;

    // 底部安全间距：键盘弹起时由外层 padding 统一避让，键盘未弹起时给系统手势横条留出舒适间距
    final effectiveBottomSpacing = bottomBar == null
        ? (bottomPadding > 0 ? bottomPadding + 12.0 : 16.0)
        : 0.0;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxSheetHeight,
          minHeight: 180.0, // 兜底最小高度，彻底根除虚拟机/模拟器环境下内容高度塌陷为0导致变灰不见的严重bug
        ),
        child: Material(
          color: t.paper,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PoopRadii.sheet),
          ),
          elevation: 6,
          shadowColor: t.isDark ? Colors.black54 : const Color(0x332D1B0D),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: displayStyle(
                              size: 17,
                              letterSpacing: 0.4,
                              color: t.ink,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: t.ink3,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(LucideIcons.x, size: 18, color: t.ink2),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              if (scrollable)
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: effectiveBottomSpacing),
                      child: child,
                    ),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.only(bottom: effectiveBottomSpacing),
                  child: child,
                ),
              if (bottomBar != null)
                Container(
                  decoration: BoxDecoration(
                    color: t.paper,
                    border: Border(
                      top: BorderSide(color: t.lineSoft, width: 1.0),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    bottomPadding > 0 ? bottomPadding + 10.0 : 16.0,
                  ),
                  child: bottomBar!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹层里的小节标签（「谁在屙」「时间」「备注」…）。
class SheetFieldLabel extends StatelessWidget {
  const SheetFieldLabel({super.key, required this.text, this.trailing});

  final String text;

  /// 右侧的附属信息，如「2 条」「时长 14 分钟」。
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: t.ink2,
              letterSpacing: 0.6,
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(fontSize: 11.5, color: t.ink3),
            ),
        ],
      ),
    );
  }
}

/// 弹层底部的次要按钮（描边、无填充）。
class SheetGhostButton extends StatelessWidget {
  const SheetGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.danger = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  /// 危险操作（删除）用红色描边 + 红字。
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = danger ? t.danger : t.ink2;
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: danger ? t.danger : t.line),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
