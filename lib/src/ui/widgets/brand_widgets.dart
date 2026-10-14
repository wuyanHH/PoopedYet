import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/tokens.dart';
import 'poop_button_icon.dart';

/// 屙了么 (PoopedYet) 核心品牌视觉统一管理组件。
///
/// 遵循单一点修改原则（Single Source of Truth）：
///   1. [BrandHeaderBadge]：顶部 Header 品牌门面小图标（与启动页图标 100% 保持一致，纯透明背景，无外框底色）；
///   2. [BrandEmptyStateIllustration]：空白状态占位图，与右下角 FAB 共用同一套「开屙」卷纸时钟图标，
///      依靠【半透明 + 原生小加号角标】优雅区分出“补录/开启”语义；
///   只要在本文件中调整，全 App 首页及所有关联模块 100% 自动同步更新。
class BrandHeaderBadge extends StatelessWidget {
  const BrandHeaderBadge({
    super.key,
    this.size = 34.0,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    // 纯透明背景，与启动页图标完全一致，无任何有色方框、边框或阴影包袱
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/splash_logo_transparent.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// 首页空白状态（Empty State）共用「开屙」卷纸时钟组件。
///
/// 视觉与交互心智设计：
///   - 核心与右下角 FAB 共用同一套 [PoopButtonIcon.start] 卷纸时钟图标；
///   - 采用【半透明 0.72】营造手帐图章质感，避免喧宾夺主；
///   - 右下角内嵌【原生小加号角标（LucideIcons.plus）】，清晰区分出“补录 / 开启新记录”的点击暗示。
class BrandEmptyStateIllustration extends StatelessWidget {
  const BrandEmptyStateIllustration({
    super.key,
    this.size = 76.0,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDark = t.isDark;

    final iconSize = size * 0.58;
    final badgeSize = size * 0.34;

    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. 底盘大圆圈 (温润手帐纸底)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isDark ? t.surface2 : const Color(0xFFFAF8F5),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? t.lineSoft : const Color(0xFFE8E2D9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.22)
                      : const Color(0x145C4033),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            // 2. 居中共用的「开屙」卷纸时钟图标 (半透明手帐印章质感)
            child: Opacity(
              opacity: isDark ? 0.85 : 0.72,
              child: PoopButtonIcon.start(
                size: iconSize,
                onDarkButton: false,
              ),
            ),
          ),

          // 3. 右下角原生小加号角标 (传达“补录/新增”交互语义)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: t.brandFill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? t.surface : Colors.white,
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.brandFill.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.plus,
                size: badgeSize * 0.62,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
