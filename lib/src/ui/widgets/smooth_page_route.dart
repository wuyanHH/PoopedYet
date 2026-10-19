import 'package:flutter/material.dart';

/// 二级页面的统一转场入口。
///
/// ## 为什么从「自定义 PageRouteBuilder」改成 MaterialPageRoute
///
/// 之前这里继承 `PageRouteBuilder`，自己画了一套「底页视差 + 当前页缩小收圆角」
/// 的转场，并手写 `WidgetsBindingObserver` 去接 Android 的预测性返回手势。
/// 那套实现有两个绕不过去的问题：
///
/// 1. **它绕过了 `PageTransitionsTheme`。**
///    Flutter 3.24 之后，预测性返回的完整链路（手势开始 / 进度 / commit /
///    cancel，以及底页的 delegated transition）是由
///    `PredictiveBackPageTransitionsBuilder` 统一接管的；而这个 builder 只会
///    被 `MaterialPageRoute.buildTransitions` 调用。自定义 `PageRouteBuilder`
///    虽然也能收到 `handleStartBackGesture`，但拿不到官方的
///    `delegatedTransition`，底页的入场/退场编排也就只能自己猜 ——
///    这正是实机上「拖动时看不到上一页预览」的根本原因。
///    从 Flutter 3.47 起，Android 的默认 builder 已经是
///    `PredictiveBackPageTransitionsBuilder`，用 `MaterialPageRoute`
///    就自动吃到官方实现，不需要再维护一份。
///
/// 2. **它每帧都在做全屏离屏裁剪。**
///    当前页退场时用 `ClipRRect` 收圆角、再叠 `Transform.scale` + 两层
///    `SlideTransition` + 一个 `AnimatedBuilder`。一次转场里整块屏幕要被
///    5 层 RenderObject 依次变换，圆角裁剪每帧重新走一次离屏渲染 ——
///    在 Impeller 下没有光栅缓存，转场本身就注定掉帧。
///
/// 换成 `MaterialPageRoute` 后，转场由官方 builder 提供：
///   - 普通 push / pop：Android 16 风格的 `FadeForwards`
///     （新页从右侧 25% 处淡入滑入、底页向左退 25% 并淡出，
///     方向语义固定，不依赖任何全局状态）；
///   - 预测性返回：当前页缩到 0.9、收 32dp 圆角并跟随手指，底页完整露出，
///     松手才提交、拖回去就回弹。
///
/// ## 实机上看不到返回预览时，按顺序检查
///
/// 1. 系统导航方式必须是**手势导航**。三键导航的返回键没有跟手预览，
///    这是 Android 的系统行为，不是应用能补的。
/// 2. Android 14（API 34）及以上才有逐帧的手势进度回调
///    （`OnBackAnimationCallback`）；Android 13 只有「松手后返回」。
/// 3. 系统 / ROM 必须启用了预测性返回动画。Android 15 起默认开启，
///    部分国产 ROM 会把它移除；Android 13–14 需要用户在开发者选项里手动打开。
/// 4. `AndroidManifest.xml` 的 `<application>` 上必须有
///    `android:enableOnBackInvokedCallback="true"`（本项目已配置）。
///
/// 上述任何一条不满足时，转场会自动回退到 `FadeForwards`，行为依然是
/// 「新页从右进、旧页往左退」的可预期方向，不会出现页面从错误方向滑入。
Route<T> smoothPageRoute<T>(Widget page) => MaterialPageRoute<T>(
  builder: (_) => page,
);
