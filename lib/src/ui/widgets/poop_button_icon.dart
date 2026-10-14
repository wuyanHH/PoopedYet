import 'package:flutter/material.dart';

/// 屙了么 (PoopedYet) 核心如厕操作统构按钮图标组件。
///
/// 设计规范（Gemini 方案 A 同构极简设计，基于官方开屙/屙完了矢量规范）：
///   - 共享卷纸立体外轮廓与右侧垂纸，垂纸上带有细腻逼真的【打孔撕纸虚线 - - -】；
///   - 卷纸纸身自带温润燕麦白（#FAF8F5）饱满填充，在任何亮色/暗色/焦糖色背景上均立体可辨；
///   - [PoopButtonIcon.start]：开屙前图标，左侧截面为【落叶黄 #E4B34F】表盘，内嵌焦糖深棕时针分针；
///   - [PoopButtonIcon.finish]：拉完了/完成图标，左侧截面为【鼠尾草绿 #76A08A】，内嵌纯白完成对勾 ✓；
///   - 单一来源原则（Single Source of Truth）：全工程所有开屙与完成相关操作按钮统一引用本组件，一处修改全局生效。
class PoopButtonIcon extends StatelessWidget {
  final bool isFinish;
  final double size;
  final bool onDarkButton;

  /// 「开屙」图标（卷纸 + 虚线 + 落叶黄时钟）
  const PoopButtonIcon.start({
    super.key,
    this.size = 20,
    this.onDarkButton = true,
  }) : isFinish = false;

  /// 「拉完了 / 完成」图标（卷纸 + 虚线 + 鼠尾草绿对勾）
  const PoopButtonIcon.finish({
    super.key,
    this.size = 18,
    this.onDarkButton = true,
  }) : isFinish = true;

  const PoopButtonIcon({
    super.key,
    required this.isFinish,
    this.size = 20,
    this.onDarkButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _UnifiedRollIconPainter(
          isFinish: isFinish,
          onDarkButton: onDarkButton,
        ),
      ),
    );
  }
}

class _UnifiedRollIconPainter extends CustomPainter {
  final bool isFinish;
  final bool onDarkButton;

  const _UnifiedRollIconPainter({
    required this.isFinish,
    required this.onDarkButton,
  });

  // 官方规范颜色 Token
  static const Color colorOatmeal = Color(0xFFFAF8F5);
  static const Color colorCaramel = Color(0xFF5C4033);
  static const Color colorYellow = Color(0xFFE4B34F);
  static const Color colorSageGreen = Color(0xFF76A08A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;

    // 深色按钮（如焦糖棕底）和普通浅色底时的描边色彩策略：
    // 在深色按钮上使用高对比度的深焦糖棕或柔白反差边，确保卷纸层次分明
    final strokeColor = onDarkButton ? colorCaramel : colorCaramel;
    final paperFillColor = colorOatmeal;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paperFillPaint = Paint()
      ..color = paperFillColor
      ..style = PaintingStyle.fill;

    // 1. 绘制共享的卷纸外轮廓与垂纸（开屙 & 拉完了 100% 结构统一）
    final rollBodyPath = Path()
      ..moveTo(8.5 * s, 4.5 * s)
      ..lineTo(16.5 * s, 4.5 * s)
      ..cubicTo(19.0 * s, 4.5 * s, 20.5 * s, 7.0 * s, 20.5 * s, 10.5 * s)
      ..lineTo(20.5 * s, 18.5 * s)
      ..arcToPoint(
        Offset(18.5 * s, 20.5 * s),
        radius: Radius.circular(2.0 * s),
      )
      ..lineTo(15.5 * s, 20.5 * s)
      ..arcToPoint(
        Offset(13.5 * s, 18.5 * s),
        radius: Radius.circular(2.0 * s),
      )
      ..lineTo(13.5 * s, 11.0 * s)
      ..close();

    // 填充燕麦白纸身底色
    canvas.drawPath(rollBodyPath, paperFillPaint);
    // 描边外轮廓
    canvas.drawPath(rollBodyPath, strokePaint);

    // 卷纸筒底侧面横线
    canvas.drawLine(
      Offset(8.5 * s, 16.5 * s),
      Offset(13.5 * s, 16.5 * s),
      strokePaint,
    );

    // 2. 纸巾上的打孔虚线（Tear Line: - - - 三段式精细圆角短虚线）
    final dashPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * s
      ..strokeCap = StrokeCap.round;

    final dashY = 15.2 * s;
    canvas.drawLine(Offset(14.8 * s, dashY), Offset(15.8 * s, dashY), dashPaint);
    canvas.drawLine(Offset(16.6 * s, dashY), Offset(17.6 * s, dashY), dashPaint);
    canvas.drawLine(Offset(18.4 * s, dashY), Offset(19.3 * s, dashY), dashPaint);

    // 3. 绘制左侧卷纸截面（开屙=落叶黄 #E4B34F，拉完了=鼠尾草绿 #76A08A）
    final ovalRect = Rect.fromCenter(
      center: Offset(8.5 * s, 10.5 * s),
      width: 10.4 * s,
      height: 12.0 * s,
    );
    final ovalFillPaint = Paint()
      ..color = isFinish ? colorSageGreen : colorYellow
      ..style = PaintingStyle.fill;

    canvas.drawOval(ovalRect, ovalFillPaint);
    canvas.drawOval(ovalRect, strokePaint);

    // 4. 绘制截面中心符号（开屙=时钟指针，拉完了=完成对勾）
    if (!isFinish) {
      final handPaint = Paint()
        ..color = colorCaramel
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final handPath = Path()
        ..moveTo(8.5 * s, 7.5 * s)
        ..lineTo(8.5 * s, 10.5 * s)
        ..lineTo(10.8 * s, 12.0 * s);
      canvas.drawPath(handPath, handPaint);
    } else {
      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final checkPath = Path()
        ..moveTo(6.3 * s, 10.6 * s)
        ..lineTo(8.0 * s, 12.3 * s)
        ..lineTo(11.0 * s, 8.8 * s);
      canvas.drawPath(checkPath, checkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UnifiedRollIconPainter oldDelegate) =>
      oldDelegate.isFinish != isFinish ||
      oldDelegate.onDarkButton != onDarkButton;
}
