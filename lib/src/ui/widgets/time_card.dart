import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';

/// 弹层里的精致「开始 / 结束」手帐时间卡片。
///
/// 记录详情、补录和新建记录复用此组件，具备：
/// - 16px 圆角与柔和纸面微阴影
/// - 顶部：图标 + 标签 + 右上角微型操作药丸胶囊
/// - 核心时间：得意黑 SmileySans 展翅大字
/// - 物理弹性按压反馈（Bounce Motion）
class TimeCard extends StatefulWidget {
  const TimeCard({
    super.key,
    required this.label,
    required this.value,
    required this.action,
    this.onTap,
    this.empty = false,
    this.icon = LucideIcons.clock,
  });

  /// 「开始」「结束」。
  final String label;

  /// 已经格式化好的时刻，或空态文案。
  final String value;

  /// 右上角微操作胶囊文案（「改时间」「补填」「清除」…）。
  final String action;

  final VoidCallback? onTap;

  /// 空态：值用弱化色、描边更深，一眼看出"这里还没填"。
  final bool empty;

  final IconData icon;

  @override
  State<TimeCard> createState() => _TimeCardState();
}

class _TimeCardState extends State<TimeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDone = !widget.empty;

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.empty ? t.line : t.lineSoft,
              width: widget.empty ? 1.2 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A2D1B0D),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部行：图标（两端统一使用品牌焦糖色，绝对对称协调） + 标签 + 右侧操作小胶囊
              Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 13,
                    color: t.brandInk,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.ink3,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  // 右侧动作胶囊（替代干瘪纯文本）
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: t.paperDeep,
                      borderRadius: BorderRadius.circular(PoopRadii.pill),
                    ),
                    child: Text(
                      widget.action,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: t.ink3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 主时间文字（采用 32px 固定高度锁定，彻底根除有无结束时间引起的卡片高度跳动！）
              SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: isDone
                      ? Text(
                          widget.value,
                          style: displayStyle(
                            size: 23,
                            letterSpacing: 0.5,
                            color: t.ink,
                          ),
                        )
                      : Text(
                          widget.value,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: t.ink3,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
