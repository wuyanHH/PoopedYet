import 'package:flutter/material.dart';

/// 萌系“带笑脸便便君”专属矢量组件（Smiling Poop Icon）。
///
/// 视觉与设计特点：
/// - 经典饱满的三层圆润堆叠黄金螺旋便便造型，顶端俏皮微翘旋涡小尖尖；
/// - 水汪汪的灵动双眼（带白色高光反射点）、甜美微笑弧线唇与粉嫩脸颊；
/// - 支持 [isColor] 全彩立体焦糖金黄渲染（适合空白占位符、大图标展示）；
/// - 支持单色矢量线稿渲染（自适应传入的 [color]，适合 Header 小 Badge）；
/// - 纯原生 Flutter Canvas 贝塞尔曲线与圆弧绘制，无任何外部字体或网络依赖，支持任意尺寸无损缩放。
class CutePoopIcon extends StatelessWidget {
  const CutePoopIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.isColor = false,
  });

  /// 绘制正方形尺寸
  final double size;

  /// 单色模式下的颜色（默认跟随 Theme，若 isColor 为 true 则仅作为基准参考）
  final Color? color;

  /// 是否开启全彩立体萌系质感
  final bool isColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? IconTheme.of(context).color ?? const Color(0xFF9A5219);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _SmilingPoopPainter(
          color: effectiveColor,
          isColor: isColor,
        ),
      ),
    );
  }
}

class _SmilingPoopPainter extends CustomPainter {
  const _SmilingPoopPainter({
    required this.color,
    required this.isColor,
  });

  final Color color;
  final bool isColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    final cx = size.width / 2.0;
    final cy = size.height / 2.0 + 2.0 * scale;

    if (isColor) {
      _paintColorful(canvas, scale, cx, cy);
    } else {
      _paintMonochrome(canvas, scale, cx, cy);
    }
  }

  /// 全彩立体质感渲染
  void _paintColorful(Canvas canvas, double scale, double cx, double cy) {
    // 基础三层色彩
    const cBottom = Color(0xFFCD7319);
    const cMid = Color(0xFFE18C23);
    const cTop = Color(0xFFF5A532);
    const cTip = Color(0xFFFFB43C);
    const cStroke = Color(0xFF8F460A);
    final strokeW = 2.4 * scale;

    final strokePaint = Paint()
      ..color = cStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. 底层
    final bW = 41.0 * scale;
    final bH = 15.5 * scale;
    final bY = cy + 18.0 * scale;
    final bRect = Rect.fromCenter(center: Offset(cx, bY), width: bW * 2, height: bH * 2);
    canvas.drawOval(bRect, Paint()..color = cBottom);
    canvas.drawOval(bRect, strokePaint);

    // 2. 中层
    final mW = 32.0 * scale;
    final mH = 13.5 * scale;
    final mY = cy + 2.5 * scale;
    final mRect = Rect.fromCenter(center: Offset(cx, mY), width: mW * 2, height: mH * 2);
    canvas.drawOval(mRect, Paint()..color = cMid);
    canvas.drawOval(mRect, strokePaint);

    // 3. 顶层
    final tW = 22.0 * scale;
    final tH = 11.5 * scale;
    final tY = cy - 13.0 * scale;
    final tRect = Rect.fromCenter(center: Offset(cx, tY), width: tW * 2, height: tH * 2);
    canvas.drawOval(tRect, Paint()..color = cTop);
    canvas.drawOval(tRect, strokePaint);

    // 4. 顶尖旋转小水滴
    final tipX = cx + 8.0 * scale;
    final tipY = cy - 26.5 * scale;
    final tipR = 6.8 * scale;
    final tipPath = Path()
      ..moveTo(cx - 6.0 * scale, cy - 21.0 * scale)
      ..lineTo(tipX + 4.5 * scale, tipY + 1.0 * scale)
      ..lineTo(cx + 12.0 * scale, cy - 19.0 * scale)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = cTip);

    final tipRect = Rect.fromCircle(center: Offset(tipX, tipY), radius: tipR);
    canvas.drawOval(tipRect, Paint()..color = cTip);
    canvas.drawOval(tipRect, strokePaint);

    // 5. 果冻高光斑
    final hlPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 18.0 * scale, cy - 0.5 * scale), width: 10.0 * scale, height: 6.0 * scale),
      hlPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 12.0 * scale, cy - 15.0 * scale), width: 8.0 * scale, height: 5.5 * scale),
      hlPaint,
    );

    // 6. 萌萌灵动大眼睛（黑豆眼带白高光）
    final eyeY = cy + 2.0 * scale;
    final eyeR = 4.2 * scale;
    final eyePaint = Paint()..color = const Color(0xFF281405);
    final pupilPaint = Paint()..color = Colors.white;

    // 左眼
    canvas.drawCircle(Offset(cx - 13.5 * scale, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(cx - 14.5 * scale, eyeY - 1.2 * scale), 1.5 * scale, pupilPaint);
    // 右眼
    canvas.drawCircle(Offset(cx + 13.5 * scale, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(cx + 12.5 * scale, eyeY - 1.2 * scale), 1.5 * scale, pupilPaint);

    // 7. 甜美微笑嘴巴
    final mouthPath = Path()
      ..moveTo(cx - 5.5 * scale, cy + 4.5 * scale)
      ..quadraticBezierTo(cx, cy + 8.2 * scale, cx + 5.5 * scale, cy + 4.5 * scale);
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = const Color(0xFF321905)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * scale
        ..strokeCap = StrokeCap.round,
    );

    // 8. 害羞粉红腮红
    final blushPaint = Paint()
      ..color = const Color(0xFFFF6E78).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 20.0 * scale, cy + 5.5 * scale), width: 9.0 * scale, height: 5.0 * scale),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 20.0 * scale, cy + 5.5 * scale), width: 9.0 * scale, height: 5.0 * scale),
      blushPaint,
    );
  }

  /// 单色线稿渲染（清晰可辨的笑脸便便轮廓）
  void _paintMonochrome(Canvas canvas, double scale, double cx, double cy) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    // 底层
    final bRect = Rect.fromCenter(
      center: Offset(cx, cy + 18.0 * scale),
      width: 41.0 * scale * 2,
      height: 15.5 * scale * 2,
    );
    canvas.drawOval(bRect, fillPaint);
    canvas.drawOval(bRect, strokePaint);

    // 中层
    final mRect = Rect.fromCenter(
      center: Offset(cx, cy + 2.5 * scale),
      width: 32.0 * scale * 2,
      height: 13.5 * scale * 2,
    );
    canvas.drawOval(mRect, fillPaint);
    canvas.drawOval(mRect, strokePaint);

    // 顶层
    final tRect = Rect.fromCenter(
      center: Offset(cx, cy - 13.0 * scale),
      width: 22.0 * scale * 2,
      height: 11.5 * scale * 2,
    );
    canvas.drawOval(tRect, fillPaint);
    canvas.drawOval(tRect, strokePaint);

    // 顶尖
    final tipX = cx + 8.0 * scale;
    final tipY = cy - 26.5 * scale;
    final tipR = 6.8 * scale;
    final tipRect = Rect.fromCircle(center: Offset(tipX, tipY), radius: tipR);
    canvas.drawOval(tipRect, fillPaint);
    canvas.drawOval(tipRect, strokePaint);

    // 眼睛
    final eyePaint = Paint()..color = color;
    final eyeY = cy + 2.0 * scale;
    canvas.drawCircle(Offset(cx - 13.0 * scale, eyeY), 3.2 * scale, eyePaint);
    canvas.drawCircle(Offset(cx + 13.0 * scale, eyeY), 3.2 * scale, eyePaint);

    // 笑嘴
    final mouthPath = Path()
      ..moveTo(cx - 5.5 * scale, cy + 4.5 * scale)
      ..quadraticBezierTo(cx, cy + 8.0 * scale, cx + 5.5 * scale, cy + 4.5 * scale);
    canvas.drawPath(mouthPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SmilingPoopPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isColor != isColor;
  }
}
