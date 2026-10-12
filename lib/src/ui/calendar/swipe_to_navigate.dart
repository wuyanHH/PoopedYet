import 'package:flutter/material.dart';

/// 滑动导航的方向。
enum SwipeDirection {
  /// 没到阈值，不切。
  none,

  /// 向右滑 → 上一个月 / 上一周。
  prev,

  /// 向左滑 → 下一个月 / 下一周。
  next,
}

/// 快速轻扫的速度阈值（逻辑像素 / 秒）。
///
/// 轻扫的**位移很小但意图明确**，只看位移会漏掉它。
const double kSwipeVelocityThreshold = 250;

/// 慢速拖动的位移阈值（逻辑像素）。
///
/// 慢拖的**速度很小但位移明确**，只看速度会漏掉它。
/// 两个阈值都要，是因为这两种手势在参数空间里几乎正交。
const double kSwipeDistanceThreshold = 60;

/// 由位移和速度判定滑动方向。
///
/// 纯函数，单独测 —— 手势的阈值最容易拍脑袋定，定完又不验证。
SwipeDirection resolveSwipe({
  required double totalDx,
  required double velocity,
}) {
  final fastEnough = velocity.abs() >= kSwipeVelocityThreshold;
  final farEnough = totalDx.abs() >= kSwipeDistanceThreshold;

  // 速度够就用速度判方向（轻扫优先，它更接近用户的真实意图）；
  // 否则看位移。两个都不够就是误触，不动。
  if (fastEnough) return velocity > 0 ? SwipeDirection.prev : SwipeDirection.next;
  if (farEnough) return totalDx > 0 ? SwipeDirection.prev : SwipeDirection.next;
  return SwipeDirection.none;
}

/// 给任意子树加上"左右滑动切月/切周"。
///
/// 为什么不用 `PageView`：日历每个月的行数不同（5 或 6 行），
/// PageView 要求所有页等高，只能按最高的 6 行留空间 ——
/// 那样 5 行的月份会白留 61px，而这个 App 的竖向空间本来就很紧。
///
/// 为什么两个阈值都要：见 [resolveSwipe]。
class SwipeToNavigate extends StatefulWidget {
  const SwipeToNavigate({
    super.key,
    required this.child,
    required this.onPrev,
    required this.onNext,
  });

  final Widget child;

  /// 向右滑（上一个）。
  final VoidCallback onPrev;

  /// 向左滑（下一个）。
  final VoidCallback onNext;

  @override
  State<SwipeToNavigate> createState() => _SwipeToNavigateState();
}

class _SwipeToNavigateState extends State<SwipeToNavigate> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // opaque：日历格自己也有 GestureDetector（点选日期），
      // 但横向拖动不会被它们认领，所以事件能到这里。
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
      onHorizontalDragEnd: (d) {
        final dir = resolveSwipe(
          totalDx: _dx,
          velocity: d.primaryVelocity ?? 0,
        );
        _dx = 0;
        switch (dir) {
          case SwipeDirection.prev:
            widget.onPrev();
          case SwipeDirection.next:
            widget.onNext();
          case SwipeDirection.none:
            break;
        }
      },
      child: widget.child,
    );
  }
}
