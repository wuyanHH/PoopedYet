import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 具有手帐视差质感的平滑页面路由，并接入 Android 的预测性返回手势。
///
/// 相比默认的粗糙切屏，本路由具备：
/// - 320ms 丝滑平移阻尼（easeOutCubic）
/// - 底层页面 25% 视差后退 + 轻微缩放，营造纸张层叠纵深感
/// - 当前页在退场时轻微缩小并收圆角，像一张被抽走的卡片
/// - **跟手方向跟随手势起始边缘**（左右各自滑向自己那一侧）
/// - 优雅退场与流畅手势返回
///
/// ## 预测性返回（Android 14 及以上）
///
/// 手指从屏幕边缘往里拖时，系统会通过
/// [WidgetsBindingObserver.handleStartBackGesture] 把「手势进度」广播给
/// 所有观察者。接收侧 Flutter **已经实现好了** ——
/// [TransitionRoute.handleStartBackGesture] 会直接把路由自己的
/// `_controller.value` 设成手势进度。所以下面这组 `SlideTransition`
/// 天然就是预览动画：往右拖，当前页跟着手指往右滑出、底下的页面带着
/// 25% 视差从左侧露出来；松手才真正返回，中途拖回去就弹回原位。
///
/// **方向必须跟着边缘走。** 手势导航允许从左、右两侧边缘发起返回：
/// 从左边缘右滑，页面应该向右滑出；从右边缘左滑，页面就该向左滑出。
/// 若固定朝一个方向滑，从另一侧返回时页面会「顶着手指跑」，
/// 手感立刻变得又假又糙。方向取自 [PredictiveBackEvent.swipeEdge]，
/// 通过 [_activeSwipeEdge] 在「正在滑出的当前页」和「正在恢复的底页」
/// 之间对齐 —— 同一时刻只可能有一个返回手势，所以模块级共享是安全的。
///
/// 另外：`PageRouteBuilder.transitionsBuilder` 回调拿不到路由对象，
/// 因此这里改为继承 [PageRouteBuilder] 并重写 [buildTransitions]。
Route<T> smoothPageRoute<T>(Widget page) => _SmoothPageRoute<T>(page: page);

/// 最近一次返回手势的起始边缘。默认按「从左边缘」处理，
/// 这样程序化导航（点返回箭头、push / pop）的手感与原来完全一致。
final ValueNotifier<SwipeEdge> _activeSwipeEdge =
    ValueNotifier<SwipeEdge>(SwipeEdge.left);

/// 退场时页面最多缩小多少（占比）。
const double _kExitScale = 0.045;

/// 退场时页面最多收多少圆角（dp）。
const double _kExitRadius = 22;

/// 底页被覆盖时后退多远（屏幕宽度的占比）。
const double _kParallax = 0.25;

/// 底页被覆盖时最多缩小多少（占比）。
const double _kCoverScale = 0.06;

class _SmoothPageRoute<T> extends PageRouteBuilder<T> {
  _SmoothPageRoute({required Widget page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
        );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 预测性返回的**整个生命周期**都走线性。
    //
    // 一来，系统给的 progress 就是手指的归一化位移，再叠一层缓动会让页面
    // 跑到手指前面。二来（更要命），这里必须「全程同一条曲线」：手势拖到
    // 一半时 animation.value 是 0.5、页面正好滑出屏幕一半，一旦 commit 后
    // 换成 easeInCubic，同一个 0.5 会被映射到别的位置，页面会当场跳一下。
    //
    // popGestureInProgress 恰好覆盖「手指拖动 + 松手后的收尾」这两段
    // （navigator 的 userGestureInProgress 要等退出动画结束才解除），
    // 所以它天然就是这个开关，不必另外维护标志位。
    //
    // 程序化导航（点返回箭头、push / pop）保留原来的缓动。
    final following = popGestureInProgress;
    final primaryCurve = following
        ? Curves.linear
        : (animation.status == AnimationStatus.reverse
              ? Curves.easeInCubic
              : Curves.easeOutCubic);
    final secondaryCurve = following
        ? Curves.linear
        : (secondaryAnimation.status == AnimationStatus.reverse
              ? Curves.easeInCubic
              : Curves.easeOutCubic);

    return _PredictiveBackRelay(
      route: this,
      child: ValueListenableBuilder<SwipeEdge>(
        valueListenable: _activeSwipeEdge,
        builder: (context, edge, _) {
          // 从左边缘右滑 → 页面向右退场（+1）；从右边缘左滑 → 向左（-1）。
          final dir = edge == SwipeEdge.right ? -1.0 : 1.0;

          return SlideTransition(
            // 底页：被覆盖时朝当前页的**来向**退让，形成视差纵深。
            position: secondaryAnimation.drive(
              Tween<Offset>(
                begin: Offset.zero,
                end: Offset(-_kParallax * dir, 0.0),
              ).chain(CurveTween(curve: secondaryCurve)),
            ),
            child: ScaleTransition(
              scale: secondaryAnimation.drive(
                Tween<double>(begin: 1.0, end: 1 - _kCoverScale)
                    .chain(CurveTween(curve: secondaryCurve)),
              ),
              child: SlideTransition(
                position: animation.drive(
                  Tween<Offset>(
                    begin: Offset(dir, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: primaryCurve)),
                ),
                // 退场时轻收一点：缩放 + 圆角，让页面像一张被抽走的卡片，
                // 而不是一块硬邦邦的矩形直接滑出屏幕。
                child: _ExitDecoration(
                  animation: animation,
                  curve: primaryCurve,
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 退场装饰：越接近「已滑出」，页面越小、圆角越大。
///
/// 就位状态（进度 0）时**不加任何包装**，避免常驻一次离屏裁剪。
class _ExitDecoration extends StatelessWidget {
  const _ExitDecoration({
    required this.animation,
    required this.curve,
    required this.child,
  });

  final Animation<double> animation;
  final Curve curve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, inner) {
        // 就位时 animation.value == 1，退场时趋近 0。
        //
        // ⚠ 这里**不能**加 `animation.isAnimating` 之类的判断：
        //   跟手拖动时 controller 是被 `setValue` 直接赋值的，
        //   `isAnimating` 恒为 false —— 加了那一句，最需要灵动的跟手阶段
        //   反而会退化成一块硬矩形平移。
        final exit = (1 - curve.transform(animation.value)).clamp(0.0, 1.0);
        if (exit <= 0.001) {
          return inner!;
        }
        return Transform.scale(
          scale: 1 - _kExitScale * exit,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kExitRadius * exit),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}

/// 把 Android 的预测性返回手势转交给本路由。
///
/// 它不绘制任何东西，只负责注册 [WidgetsBindingObserver] 并转发事件。
/// 其中「松手提交」这一步是自己实现的 —— 为了绕开 Flutter 内部一个会让
/// 页面闪回原位的写法，详见 [handleCommitBackGesture] 里的注释。
class _PredictiveBackRelay extends StatefulWidget {
  const _PredictiveBackRelay({required this.route, required this.child});

  final ModalRoute<dynamic> route;
  final Widget child;

  @override
  State<_PredictiveBackRelay> createState() => _PredictiveBackRelayState();
}

class _PredictiveBackRelayState extends State<_PredictiveBackRelay>
    with WidgetsBindingObserver {
  /// 松手提交后，是否还在等退出动画跑完，以便补上 `didStopUserGesture()`。
  bool _awaitingGestureEnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.route.animation?.addStatusListener(_onRouteAnimationStatus);
  }

  @override
  void dispose() {
    widget.route.animation?.removeStatusListener(_onRouteAnimationStatus);
    // 兜底：正常路径下退出动画会先跑完、由上面的监听器收尾；万一这条路由是
    // 被别处直接摘掉的，也别把 navigator 的 userGestureInProgress 留在 true。
    _endUserGesture();
    // 路由都没了，这次手势自然结束，方向一并复位。
    _activeSwipeEdge.value = SwipeEdge.left;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status.isDismissed) {
      _endUserGesture();
    }
    if (status.isCompleted) {
      // 页面回到就位状态 —— 可能是提交后的收尾，也可能是中途取消的回弹。
      // 两种情况下这次手势都结束了，方向可以复位，
      // 免得下一次程序化导航（点返回箭头）用错方向。
      _activeSwipeEdge.value = SwipeEdge.left;
    }
  }

  void _endUserGesture() {
    if (!_awaitingGestureEnd) {
      return;
    }
    _awaitingGestureEnd = false;
    widget.route.navigator?.didStopUserGesture();
  }

  /// 只有「正显示在最上层、且确实可以被弹掉」的路由才接管手势。
  ///
  /// 首页（`isFirst`）、正在做转场的路由、被 `PopScope` 拦下的路由，
  /// 它们的 `popGestureEnabled` 都是 false —— 此时返回 false，
  /// 手势就落回系统默认行为，和没开预测性返回时一模一样。
  bool get _handlesGesture =>
      widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    // 实体 / 三键导航的返回键事件不是手势，不该被「跟手预览」接管。
    if (backEvent.isButtonEvent || !_handlesGesture) {
      return false;
    }
    // 记下手势从哪一侧发起：页面滑出方向、底页视差方向都跟着它走。
    _activeSwipeEdge.value = backEvent.swipeEdge;
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCancelBackGesture() => widget.route.handleCancelBackGesture();

  @override
  void handleCommitBackGesture() {
    final navigator = widget.route.navigator;
    if (navigator == null) {
      return;
    }

    // 手势还没松手就又发生了别的导航（比如途中 push 了新页面）：别再 pop 了，
    // 但收尾不能漏 —— 与 Flutter 自己 _handleDragEnd 里的 `if (isCurrent)` 一致。
    if (!widget.route.isCurrent) {
      navigator.didStopUserGesture();
      return;
    }

    // 这里刻意**不调用** widget.route.handleCommitBackGesture()。
    //
    // TransitionRoute._handleDragEnd 在 `navigator.pop()` 之后还会补一句
    // `_controller.reverse(from: upperBound)`。可 pop 本身（didPop 里的
    // `_controller.reverse()`）已经让退出动画从**手指停下的位置**开始跑了，
    // 那一句会把 controller 硬拽回 1.0 —— 用户看到的就是「松手瞬间整页闪回
    // 原位、再从头完整滑出一次」，跟手感全毁。
    //
    // Flutter 自带的预测性返回转场不受影响，是因为它不直接用 route 的
    // animation 驱动位置，而是在 commit 时把当前位移存进 _lastDrag 再另起一段
    // 补间。我们这套 SlideTransition 是直接吃 animation 的，所以必须绕开那句。
    navigator.pop();

    // 收尾。官方会把 userGestureInProgress 一直保持到退出动画结束才解除
    // （AndroidBackGesturePageTransitionsBuilder 依赖它），这里照做 ——
    // 我们的跟手曲线判断同样依赖它，而且必须覆盖到动画结束为止。
    if (widget.route.animation?.status.isDismissed ?? true) {
      navigator.didStopUserGesture();
    } else {
      _awaitingGestureEnd = true;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
