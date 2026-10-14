import 'package:flutter/material.dart';
import 'poop_button_icon.dart';

/// 专为「开屙与完成」打造的统构操作图标（向后兼容代理）。
///
/// 核心绘制逻辑已全面统一收敛至 [PoopButtonIcon]：
/// - 开屙状态：[PoopButtonIcon.start]（落叶黄时钟卷纸）
/// - 完成状态：[PoopButtonIcon.finish]（鼠尾草绿对勾卷纸）
/// 本文件保持历史兼容性，单点修改统一由 [PoopButtonIcon] 驱动。
enum PoopIconStyle {
  /// 统一卷纸（开屙状态）
  roll,

  /// 统一卷纸（完成状态）
  finish,

  /// 便便螺旋（兼容保留）
  swirl,

  /// 水滴（兼容保留）
  droplet,
}

/// 全局统一「开屙」图标组件（直接代理 PoopButtonIcon.start）。
class StartPoopIcon extends StatelessWidget {
  const StartPoopIcon({
    super.key,
    this.size = 20.0,
    this.color = Colors.white,
    this.onDarkButton = true,
  });

  final double size;
  final Color color;
  final bool onDarkButton;

  @override
  Widget build(BuildContext context) {
    return PoopButtonIcon.start(
      size: size,
      onDarkButton: onDarkButton,
    );
  }
}

/// 全局统一「完成」图标组件（直接代理 PoopButtonIcon.finish）。
class FinishPoopIcon extends StatelessWidget {
  const FinishPoopIcon({
    super.key,
    this.size = 18.0,
    this.color = Colors.white,
    this.onDarkButton = true,
  });

  final double size;
  final Color color;
  final bool onDarkButton;

  @override
  Widget build(BuildContext context) {
    return PoopButtonIcon.finish(
      size: size,
      onDarkButton: onDarkButton,
    );
  }
}

/// 历史兼容类
class PoopActionIcon extends StatelessWidget {
  const PoopActionIcon({
    super.key,
    this.size = 20.0,
    this.color = Colors.white,
    this.style = PoopIconStyle.roll,
    this.onDarkButton = true,
  });

  final double size;
  final Color color;
  final PoopIconStyle style;
  final bool onDarkButton;

  @override
  Widget build(BuildContext context) {
    final isFinish = style == PoopIconStyle.finish;
    return PoopButtonIcon(
      isFinish: isFinish,
      size: size,
      onDarkButton: onDarkButton,
    );
  }
}
