import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// 屙了么 (PoopedYet)「正在屙」动态状态胶囊（方案 1A：旋转卷纸秒表 + 单向无限流淌三段式打孔分割虚线）。
///
/// 视觉与自适应特性：
///   - 解决不同容器底色（Header 暖纸色 vs 卡片纯白色 vs 暗色模式）下的背景融入问题；
///   - 自带鼠尾草绿（#76A08A）温润呼吸渐变与柔和脉冲边框；
///   - 卷纸左侧时钟截面 360° 顺时针秒针平滑旋转；
///   - 纸面裁剪区内 2 组三段式打孔虚线 (- - -) 单向无限向下平滑流淌；
///   - 消除卷纸内部竖线穿模瑕疵，纯 Flutter Canvas 原生渲染，零外部插件依赖。
class OngoingPoopBadge extends StatefulWidget {
  final String label;
  final String? durationText;
  final VoidCallback? onTap;
  final double iconSize;
  final bool compact;

  const OngoingPoopBadge({
    super.key,
    this.label = '正在屙',
    this.durationText,
    this.onTap,
    this.iconSize = 20.0,
    this.compact = false,
  });

  @override
  State<OngoingPoopBadge> createState() => _OngoingPoopBadgeState();
}

class _OngoingPoopBadgeState extends State<OngoingPoopBadge>
    with SingleTickerProviderStateMixin {
  // 官方规范颜色 Token
  static const Color primaryCaramel = Color(0xFF5C4033);
  static const Color accentSage = Color(0xFF76A08A);
  static const Color darkSageText = Color(0xFF355846);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDark = t.isDark;

    // 根据亮暗主题自适应文字与容器底色
    final textColor = isDark ? t.live : darkSageText;
    final liveBaseColor = isDark ? t.live : accentSage;

    final horizontalPadding = widget.compact ? 8.0 : 10.0;
    final verticalPadding = widget.compact ? 3.0 : 5.0;
    final fontSize = widget.compact ? 11.0 : 12.0;

    // 静态内容（文字 + 布局）不随呼吸动画变化，作为 AnimatedBuilder 的
    // child 复用。这样 60fps 的呼吸/卷纸动画每帧只需要重建外层的背景装饰
    // 和那枚 CustomPaint，而不是整行文字重新布局。
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. 动态卷纸秒表 + 单向流淌打孔虚线 Icon
        SizedBox(
          width: widget.iconSize,
          height: widget.iconSize,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _Scheme1AUnrollingPainter(
                progress: _controller.value,
                isDark: isDark,
                caramelColor: isDark ? t.ink : primaryCaramel,
                paperFillColor:
                    isDark ? t.surface : Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
        ),
        SizedBox(width: widget.compact ? 4 : 6),

        // 2. 状态文字「正在屙」
        Text(
          widget.label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: textColor,
            height: 1.1,
          ),
        ),

        // 3. 可选动态时长（例如 "03:24"）
        if (widget.durationText != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '·',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: textColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          Text(
            widget.durationText!,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: isDark ? t.ink : primaryCaramel,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1.1,
            ),
          ),
        ],
      ],
    );

    return RepaintBoundary(
      // 这颗胶囊是常驻 60fps 的动画源。自己不划一条重绘边界的话，
      // 首页顶栏（以及它所在的整棵子树）每一帧都会被拖着重绘。
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          child: content,
          builder: (context, child) {
            final breath =
                0.5 + 0.5 * math.sin(_controller.value * 2 * math.pi);

            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              decoration: BoxDecoration(
                // 背景自适应：既保证鼠尾草绿呼吸，又杜绝不同底色下的生硬色差
                color: isDark
                    ? t.liveSoft.withValues(alpha: 0.20 + 0.12 * breath)
                    : liveBaseColor.withValues(alpha: 0.12 + 0.08 * breath),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark
                      ? t.live.withValues(alpha: 0.35 + 0.25 * breath)
                      : liveBaseColor.withValues(alpha: 0.35 + 0.30 * breath),
                  width: 1.2,
                ),
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _Scheme1AUnrollingPainter extends CustomPainter {
  final double progress; // 0.0 ~ 1.0 单向无限循环
  final bool isDark;
  final Color caramelColor;
  final Color paperFillColor;

  const _Scheme1AUnrollingPainter({
    required this.progress,
    required this.isDark,
    required this.caramelColor,
    required this.paperFillColor,
  });

  static const Color accentYellow = Color(0xFFE4B34F);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;

    final strokePaint = Paint()
      ..color = caramelColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. 卷纸筒与垂纸一体式外轮廓（彻底消除内部穿模竖线）
    final rollPath = Path()
      ..moveTo(8.5 * s, 4.5 * s)
      ..lineTo(16.5 * s, 4.5 * s)
      ..cubicTo(19.0 * s, 4.5 * s, 20.5 * s, 7.0 * s, 20.5 * s, 10.5 * s)
      ..lineTo(20.5 * s, 19.1 * s)
      ..arcToPoint(
        Offset(19.0 * s, 20.6 * s),
        radius: Radius.circular(1.5 * s),
      )
      ..lineTo(15.0 * s, 20.6 * s)
      ..arcToPoint(
        Offset(13.5 * s, 19.1 * s),
        radius: Radius.circular(1.5 * s),
      )
      ..lineTo(13.5 * s, 16.5 * s)
      ..lineTo(8.5 * s, 16.5 * s);

    // 填充底色自适应：使用容器协调的洁白纯纸色，杜绝色块割裂
    canvas.drawPath(rollPath, Paint()..color = paperFillColor);

    // 2. 纸面裁剪区内 2 组三段式打孔分割虚线 (- - -) 单向无限向下平滑流淌
    canvas.save();
    canvas.clipPath(rollPath);

    const double topStart = 5.2;
    const double travelRange = 15.2;
    for (int i = 0; i < 2; i++) {
      final localT = (progress + i * 0.5) % 1.0;
      final y = (topStart + localT * travelRange) * s;
      final edgeFade = math.sin(localT * math.pi).clamp(0.0, 1.0);

      final dashPaint = Paint()
        ..color = caramelColor.withValues(alpha: 0.62 * edgeFade)
        ..strokeWidth = 1.4 * s
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(14.6 * s, y), Offset(15.6 * s, y), dashPaint);
      canvas.drawLine(Offset(16.7 * s, y), Offset(17.7 * s, y), dashPaint);
      canvas.drawLine(Offset(18.8 * s, y), Offset(19.6 * s, y), dashPaint);
    }
    canvas.restore();

    // 3. 外轮廓描边 + 垂纸内侧防穿模短折角 (16.5 -> 14.3)
    canvas.drawPath(rollPath, strokePaint);
    canvas.drawLine(
      Offset(13.5 * s, 16.5 * s),
      Offset(13.5 * s, 14.3 * s),
      strokePaint,
    );

    // 4. 左侧落叶黄表盘截面 + 360° 顺时针秒针平滑旋转
    final ovalRect = Rect.fromCenter(
      center: Offset(8.5 * s, 10.5 * s),
      width: 10.4 * s,
      height: 12.0 * s,
    );
    canvas.drawOval(ovalRect, Paint()..color = accentYellow);
    canvas.drawOval(ovalRect, strokePaint);

    final angle = progress * 2 * math.pi - math.pi / 2;
    final center = Offset(8.5 * s, 10.5 * s);
    final handEnd = Offset(
      center.dx + math.cos(angle) * 3.3 * s,
      center.dy + math.sin(angle) * 3.7 * s,
    );
    canvas.drawLine(center, handEnd, strokePaint);
    canvas.drawCircle(center, 1.0 * s, Paint()..color = caramelColor);
  }

  @override
  bool shouldRepaint(covariant _Scheme1AUnrollingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isDark != isDark ||
      oldDelegate.caramelColor != caramelColor ||
      oldDelegate.paperFillColor != paperFillColor;
}
