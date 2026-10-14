import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../state/calendar_data.dart';
import '../../theme/tokens.dart';
import '../home_page.dart';

/// 记录进程内是否已经完成过首启流程（防止热恢复时重复走全套启动动画）
bool _hasAppEverStarted = false;

/// 屙了么 (PoopedYet) 官方方案 A 定稿启动屏（Splash Screen）。
///
/// 视觉与业务规范特性（Strict Gemini Brand Spec）：
///   - 温暖燕麦白背景（#FAF8F5）；
///   - 核心插画采用官方 65% 安全区高精手绘「卷纸时钟 + 萌萌便便君」（assets/images/splash_logo_safezone.png）；
///   - 品牌大字：「屙了么」（42px，得意黑 Smiley Sans，焦糖深棕 #5C4033）+「PoopedYet」（22px）；
///   - 品牌正式标语：「“日理万机，屙了有记”」+「Every Poop, Accounted For.」；
///   - 底部单行随机幽默提示语轮播（按业务规范严禁展示版本号）；
///   - 异步完成数据库与状态装载后，无缝平滑淡入主界面。
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashTip {
  const _SplashTip({required this.icon, required this.text});
  final IconData icon;
  final String text;
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  static const List<_SplashTip> _randomTips = [
    _SplashTip(
      icon: LucideIcons.timer,
      text: '提示：蹲坑不要超过十分钟，谨防腿麻和痔疮...',
    ),
    _SplashTip(
      icon: LucideIcons.droplets,
      text: '提示：多喝温水多吃蔬菜，愿你每次都顺畅如风...',
    ),
    _SplashTip(
      icon: LucideIcons.sparkles,
      text: 'Poop Happens. Log It. 每一坨都值得被记录...',
    ),
    _SplashTip(
      icon: LucideIcons.clock,
      text: '提示：带薪拉屎虽好，注意不要刷手机忘记时间...',
    ),
  ];

  late final _SplashTip _currentTip;
  late final AnimationController _enterController;
  late final AnimationController _floatController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _floatAnimation;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _currentTip = _randomTips[Random().nextInt(_randomTips.length)];

    // 设置状态栏与底部手势条透明/燕麦白沉浸式
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFFAF8F5),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // 1. 入场缩放与淡入动画控制器 (850ms)
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOut),
      ),
    );

    // 2. 轻盈微浮呼吸控制器 (2400ms 循环)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _floatAnimation = Tween<double>(begin: -3.5, end: 3.5).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    _enterController.forward().then((_) {
      if (mounted) {
        _floatController.repeat(reverse: true);
      }
    });

    _checkBootstrapAndNavigate();
  }

  @override
  void dispose() {
    _enterController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _checkBootstrapAndNavigate() async {
    // 保证入场动画舒发展现完毕后，平滑淡入主界面
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1100)),
      ref.read(bootstrapProvider.future),
    ]);

    if (!mounted || _navigated) return;
    _navigated = true;
    _hasAppEverStarted = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const HomePage(),
        transitionsBuilder: (_, animation, __, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          return SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: fade,
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDark = t.isDark;

    // 官方规范颜色 Token
    const bgOatmeal = Color(0xFFFAF8F5);
    const primaryCaramel = Color(0xFF5C4033);
    const textSecondary = Color(0xFF8A827D);
    const textDisabled = Color(0xFFB5ADA7);

    final effectiveBg = isDark ? t.paper : bgOatmeal;
    final effectivePrimary = isDark ? t.ink : primaryCaramel;

    return Scaffold(
      backgroundColor: effectiveBg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_enterController, _floatController]),
          builder: (context, _) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // 1. 核心主角插画：官方纯透明底高精插画（卷纸时钟 + 焦糖便便君 + 鼠尾草绿星光）
                    Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Image.asset(
                          'assets/images/splash_logo_transparent.png',
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. 品牌大标题：「屙了么」
                    Text(
                      '屙了么',
                      style: displayStyle(
                        size: 42,
                        letterSpacing: 3.0,
                        color: effectivePrimary,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // 英文品名：PoopedYet
                    Text(
                      'PoopedYet',
                      style: displayStyle(
                        size: 22,
                        letterSpacing: 0.8,
                        color: effectivePrimary,
                      ),
                    ),

                    const Spacer(flex: 2),

                    // 3. 官方正式标语：日理万机，屙了有记
                    Text(
                      '“日理万机，屙了有记”',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: effectivePrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Every Poop, Accounted For.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                        color: textSecondary,
                      ),
                    ),

                    const Spacer(flex: 3),

                    // 4. 底部单行随机幽默提示语轮播（使用组件库 Lucide 矢量图标，杜绝 Emoji 杂色与平台渲染差异）
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _currentTip.icon,
                            size: 13.5,
                            color: (isDark ? t.ink4 : textDisabled).withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _currentTip.text,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? t.ink4 : textDisabled,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
