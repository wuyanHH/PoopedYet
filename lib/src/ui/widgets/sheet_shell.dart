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
    this.maxHeightFactor = 0.86,
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

  /// 最高占屏幕的比例。默认 0.86，留出一点让用户知道下面还有东西。
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxH = MediaQuery.sizeOf(context).height * maxHeightFactor;

    Widget body = child;
    if (scrollable) {
      body = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        // 键盘弹起来时输入框会被遮住，所以内边距要跟着 viewInsets 走。
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: child,
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: t.paper,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PoopRadii.sheet),
          ),
          boxShadow: PoopShadows.s3,
        ),
        padding: const EdgeInsets.only(top: 10, bottom: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: displayStyle(
                            size: 16,
                            letterSpacing: 0.4,
                            color: t.ink,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: t.ink3,
                              height: 1.4,
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
            body,
          ],
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
          const Spacer(),
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
