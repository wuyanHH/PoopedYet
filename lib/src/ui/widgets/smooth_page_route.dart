import 'package:flutter/material.dart';

/// 具有手帐视差质感的平滑页面路由。
///
/// 相比默认的粗糙切屏，本路由具备：
/// - 320ms 丝滑平移阻尼（easeOutCubic）
/// - 底层页面 25% 视差后退联动，营造纸张层叠纵深感
/// - 优雅退场与流畅手势返回
Route<T> smoothPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final primaryOffset = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ));

      final secondaryOffset = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.25, 0.0),
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ));

      return SlideTransition(
        position: secondaryOffset,
        child: SlideTransition(
          position: primaryOffset,
          child: child,
        ),
      );
    },
  );
}
