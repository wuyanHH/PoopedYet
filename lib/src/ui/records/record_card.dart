import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/queries.dart';
import '../../domain/record_state.dart';
import '../../theme/tokens.dart';
import '../widgets/pooper_avatar.dart';

/// 一条记录的卡片。
///
/// 四种状态各有各的样子，**必须一眼分得开**（见 `docs/design-system.md` 第 10 节）：
///
/// | 状态 | 时间行 | 时长列 | 视觉 |
/// |---|---|---|---|
/// | 正在屙 | `21:05 → ● 正在屙` | `已 6 分钟` | 苔绿脉冲点 + 卡片左缘一道绿线 |
/// | 待确认 | `09:12 → ？` | `已超过 2 小时` | 琥珀，**不脉冲** |
/// | 未记结束 | `09:30 → 未记结束` | `时长不详` | 灰，无强调 |
/// | 已完成 | `09:12 → 09:26` | `14 分钟` | 常规 |
///
/// 待确认**刻意不脉冲**：脉冲会让人以为记录还在正常进行，反而不去处理它。
class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.detail,
    required this.now,
    this.onTap,
  });

  final RecordDetail detail;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = detail.record;
    final state = recordStateOf(r, now: now);

    // 状态色：只有"正在屙"用绿、待确认用琥珀，其余都走中性色。
    // 「未记结束」用灰色而不是红色 —— 它不是错误，只是没记。
    final (Color accent, bool showEdge) = switch (state) {
      RecordState.active => (t.live, true),
      RecordState.pending => (t.pending, true),
      RecordState.endUnknown => (t.ink3, false),
      RecordState.done => (t.ink3, false),
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.lineSoft),
          boxShadow: PoopShadows.s1,
        ),
        // 左缘那道竖线用 foregroundDecoration 的 border 只画左边 ——
        // 直接给 Container 加 Border 会四边都画。
        foregroundDecoration: showEdge
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border(left: BorderSide(color: accent, width: 3)),
              )
            : null,
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PooperAvatar.md(
              detail.pooper,
              dimmed: detail.pooper.archivedAt != null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          detail.pooper.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: t.ink,
                          ),
                        ),
                      ),
                      if (detail.pooper.archivedAt != null) ...[
                        const SizedBox(width: 5),
                        Text(
                          '已归档',
                          style: TextStyle(fontSize: 10, color: t.ink4),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        durationLabel(r, now: now),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: state == RecordState.done
                              ? t.ink2
                              : accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _TimeRow(
                    start: hhmm(r.startedAt),
                    end: endLabel(r, now: now),
                    state: state,
                    accent: accent,
                  ),
                  if (detail.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final n in detail.notes)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hhmm(n.notedAt),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: t.ink3,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                n.content,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: t.ink2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.start,
    required this.end,
    required this.state,
    required this.accent,
  });

  final String start;
  final String end;
  final RecordState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final timeStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: t.ink2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Row(
      children: [
        Text(start, style: timeStyle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Icon(LucideIcons.arrowRight, size: 12, color: t.ink4),
        ),
        if (state == RecordState.active) ...[
          const _PulsingDot(),
          const SizedBox(width: 5),
          Text(
            end,
            style: timeStyle.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ] else
          Text(
            end,
            style: timeStyle.copyWith(
              color: state == RecordState.done ? t.ink2 : accent,
            ),
          ),
      ],
    );
  }
}

/// 「正在屙」那个会呼吸的绿点。
///
/// 只有这一个状态配脉冲动画 —— 它是唯一"事情还在发生"的状态。
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: t.live, shape: BoxShape.circle),
      ),
    );
  }
}
