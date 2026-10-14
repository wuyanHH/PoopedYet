import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 快速轻扫的速度阈值（逻辑像素 / 秒）。
const double kSwipeVelocityThreshold = 220;

/// 慢速拖动的位移阈值（逻辑像素）。
const double kSwipeDistanceThreshold = 36;

/// 滑动触发方向。
enum SwipeDirection { prev, next, none }

/// 纯函数：根据位移与初速度计算滑动方向。
///
/// 遵循 Material Design 物理直觉：优先采信快速轻扫的速度，其次采信慢速拖动的位移。
SwipeDirection resolveSwipe({required double totalDx, required double velocity}) {
  final isFast = velocity.abs() >= kSwipeVelocityThreshold;
  final isFar = totalDx.abs() >= kSwipeDistanceThreshold;

  if (isFast) {
    return velocity > 0 ? SwipeDirection.prev : SwipeDirection.next;
  }
  if (isFar) {
    return totalDx > 0 ? SwipeDirection.prev : SwipeDirection.next;
  }
  return SwipeDirection.none;
}

/// 给日历网格加上自然直觉的双向切月/切周手势：
/// - **水平手势（左右滑）**：向左下一月/周，向右上一月/周；
/// - **垂直手势**：遵循手势解耦原则，默认禁用，完全交还外层滚动与底边手柄。
class SwipeToNavigate extends StatefulWidget {
  const SwipeToNavigate({
    super.key,
    required this.child,
    required this.onPrev,
    required this.onNext,
    this.allowVertical = false,
  });

  final Widget child;

  /// 上一个（向右滑或向下滑）。[isVertical] 指示是否为垂直方向手势。
  final void Function({required bool isVertical}) onPrev;

  /// 下一个（向左滑或向上滑）。[isVertical] 指示是否为垂直方向手势。
  final void Function({required bool isVertical}) onNext;

  /// 是否启用垂直上下滑手势（月模式下启用，周模式下仅保留纯水平手势，避免手势竞争）。
  final bool allowVertical;

  @override
  State<SwipeToNavigate> createState() => _SwipeToNavigateState();
}

class _SwipeToNavigateState extends State<SwipeToNavigate> {
  double _dx = 0;
  double _dy = 0;

  @override
  Widget build(BuildContext context) {
    // 关键性能优化：周模式下绝不注册垂直手势识别器，将垂直滚动完全释放给下方的 ListView
    if (!widget.allowVertical) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (_) => _dx = 0,
        onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
        onHorizontalDragEnd: (d) {
          final dir = resolveSwipe(
            totalDx: _dx,
            velocity: d.velocity.pixelsPerSecond.dx,
          );
          if (dir == SwipeDirection.prev) {
            widget.onPrev(isVertical: false);
          } else if (dir == SwipeDirection.next) {
            widget.onNext(isVertical: false);
          }
          _dx = 0;
        },
        onHorizontalDragCancel: () => _dx = 0,
        child: widget.child,
      );
    }

    // 月模式下支持双向手势
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: (_) {
        _dx = 0;
        _dy = 0;
      },
      onPanUpdate: (d) {
        _dx += d.delta.dx;
        _dy += d.delta.dy;
      },
      onPanEnd: (d) {
        final vx = d.velocity.pixelsPerSecond.dx;
        final vy = d.velocity.pixelsPerSecond.dy;

        // 根据位移与初速度综合判断是垂直主意图还是水平主意图
        final isVerticalIntent =
            (_dy.abs() > _dx.abs() * 1.15 || vy.abs() > vx.abs() * 1.15);

        if (isVerticalIntent) {
          // 垂直手势：向上推为下一月，向下拉为上一月
          final isFast = vy.abs() >= kSwipeVelocityThreshold;
          final isFar = _dy.abs() >= kSwipeDistanceThreshold;

          if (isFast || isFar) {
            final isPrev = isFast ? vy > 0 : _dy > 0;
            if (isPrev) {
              widget.onPrev(isVertical: true);
            } else {
              widget.onNext(isVertical: true);
            }
          }
        } else {
          // 水平手势：向左滑为下一月/周，向右滑为上一月/周
          final dir = resolveSwipe(
            totalDx: _dx,
            velocity: vx,
          );
          if (dir == SwipeDirection.prev) {
            widget.onPrev(isVertical: false);
          } else if (dir == SwipeDirection.next) {
            widget.onNext(isVertical: false);
          }
        }

        _dx = 0;
        _dy = 0;
      },
      onPanCancel: () {
        _dx = 0;
        _dy = 0;
      },
      child: widget.child,
    );
  }
}
