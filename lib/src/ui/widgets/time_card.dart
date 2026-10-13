import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 弹层里的「开始 / 结束」方卡。
///
/// 记录详情（⑤）和补录（⑧）都要用，所以抽出来 ——
/// 两处各写一份的话，字号、圆角、"空态描边更深"这些细节迟早会不一样。
class TimeCard extends StatelessWidget {
  const TimeCard({
    super.key,
    required this.label,
    required this.value,
    required this.action,
    this.onTap,
    this.empty = false,
  });

  /// 「开始」「结束」。
  final String label;

  /// 已经格式化好的时刻，或空态文案。
  final String value;

  /// 底下那行小字（「改日期」「补填」「清除」…）。
  final String action;

  final VoidCallback? onTap;

  /// 空态：值用弱化色、描边更深，一眼看出"这里还没填"。
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: empty ? t.line : t.lineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: t.ink3, letterSpacing: 0.6),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: empty ? t.ink3 : t.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              action,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: onTap == null ? t.ink4 : t.brandInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
