import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 深浅主题模式选项。
enum AppThemeMode {
  system('跟随系统'),
  light('浅色'),
  dark('深色');

  const AppThemeMode(this.label);

  final String label;

  ThemeMode toFlutterThemeMode() => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}

/// 主题色彩方案。
enum AppThemeColor {
  caramel('经典焦糖', Color(0xFFA85F29)),
  matcha('抹茶森林', Color(0xFF3F7A57)),
  ocean('深海微风', Color(0xFF376C8E)),
  lavender('烟雨丁香', Color(0xFF764E8C)),
  terracotta('落日陶土', Color(0xFFA14333));

  const AppThemeColor(this.label, this.primaryColor);

  final String label;
  final Color primaryColor;
}

/// 设计令牌 —— 与 `.design/ui-reference.html` 的 `:root` **同源**。
///
/// 改这里的任何颜色，必须同时改视觉稿的 `:root`，并且两边都通过对比度自检。
/// 这里的一致性不是靠纪律，是靠 `test/theme/tokens_contrast_test.dart` 强制的。
///
/// ## 焦糖一色三分（最容易搞错的地方）
///
/// 只有一个 `--brand` 到处用的写法，实测有 355 处文本不达 WCAG AA。原因是
/// 「当文字」「当白字底」「当装饰」三种场景的对比度要求根本不同，所以拆成三个：
///
/// | 令牌 | 什么时候用 | 对底色的要求 |
/// |---|---|---|
/// | [brand] | ≥24px 大字、纯装饰填充 | 3:1 |
/// | [brandInk] | 任何焦糖色**文字** | 4.5:1 |
/// | [brandFill] | 焦糖色**底**，上面盖白字 | 白字对它有 4.5:1 |
///
/// **千万不要**把 [brand] 直接拿去写文字或当白字底 —— 那正是被修掉的 bug。
@immutable
class PoopTokens extends ThemeExtension<PoopTokens> {
  const PoopTokens({
    required this.paper,
    required this.paperDeep,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.line,
    required this.lineSoft,
    required this.brand,
    required this.brandInk,
    required this.brandFill,
    required this.brandSoft,
    required this.off,
    required this.offSoft,
    required this.work,
    required this.workSoft,
    required this.live,
    required this.liveSoft,
    required this.pending,
    required this.danger,
    this.isDark = false,
  });

  /// 是否为深色模式。
  final bool isDark;

  // ---- 底 ----
  /// 页面底色，暖米纸。
  final Color paper;

  /// 次级底、分段控件槽、chip 底。
  final Color paperDeep;

  /// 卡片。
  final Color surface;

  /// 周视图格底。
  final Color surface2;

  // ---- 文字 ----
  /// 主文字（深咖，**不用纯黑**）。对 [paper] 13.4:1。
  final Color ink;

  /// 次级文字。对 [paper] 5.98:1。
  final Color ink2;

  /// 三级文字、占位。对 [paper] 5.17:1。
  final Color ink3;

  /// **仅限非文本**：拖拽把手、装饰图标。对白 3.27:1。
  ///
  /// 注意它只对**白底**达标；放在 [brandSoft] 这类浅彩底上会掉到 2.66:1，
  /// 那种场合要用 [ink3]。
  final Color ink4;

  /// 描边、虚线分隔（纯装饰，无对比度要求）。
  final Color line;
  final Color lineSoft;

  // ---- 品牌焦糖（一色三分，见类文档）----
  /// 仅限 ≥24px 大字或纯装饰填充。对纸面 3.11:1。
  final Color brand;

  /// 焦糖色**文字**。对纸面 5.38:1。
  final Color brandInk;

  /// 焦糖色**底**（上面盖白字）。白字对它 4.85:1。
  final Color brandFill;

  /// 主色浅底（计数药丸、图标底）。
  final Color brandSoft;

  // ---- 功能色：法定假日与调休 ----
  /// 休（法定假日）实心角标。白字对它是 6.01:1。
  final Color off;
  final Color offSoft;

  /// 班（调休上班）实心角标。白字对它是 4.61:1。
  final Color work;
  final Color workSoft;

  // ---- 状态 ----
  /// 正在屙。对白 5.08:1。
  final Color live;
  final Color liveSoft;

  /// 「待确认」状态的琥珀色。对白 5.52:1。
  ///
  /// 设计稿原本写的是 `#A9791A`，实测只有 3.86:1，不达 4.5:1，压深了一档。
  final Color pending;

  /// 危险操作。对白 4.93:1。
  final Color danger;

  /// 浅色主题的默认实例（经典焦糖）。
  static const PoopTokens light = PoopTokens(
    paper: Color(0xFFFAF5EC),
    paperDeep: Color(0xFFF2E9DA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFFFCF6),
    ink: Color(0xFF2E2622),
    ink2: Color(0xFF6B5B4E),
    ink3: Color(0xFF756552),
    ink4: Color(0xFF9C8C74),
    line: Color(0xFFE9DDCA),
    lineSoft: Color(0xFFF2E9DA),
    brand: Color(0xFFC8783C),
    brandInk: Color(0xFF9A5219),
    brandFill: Color(0xFFA85F29),
    brandSoft: Color(0xFFF7E5D2),
    off: Color(0xFFB03A2E),
    offSoft: Color(0xFFF8E2DE),
    work: Color(0xFF4A7C8C),
    workSoft: Color(0xFFE0EBEF),
    live: Color(0xFF3F7A57),
    liveSoft: Color(0xFFE1EDE5),
    pending: Color(0xFF8A6114),
    danger: Color(0xFFC4453A),
    isDark: false,
  );

  /// 深色主题的默认实例（暖咖暗夜焦糖）。
  static const PoopTokens dark = PoopTokens(
    paper: Color(0xFF191614),
    paperDeep: Color(0xFF24201C),
    surface: Color(0xFF231E1B),
    surface2: Color(0xFF2E2925),
    ink: Color(0xFFECE4D9),
    ink2: Color(0xFFBFB09F),
    ink3: Color(0xFF968878),
    ink4: Color(0xFF6A5C4F),
    line: Color(0xFF352D26),
    lineSoft: Color(0xFF29221C),
    brand: Color(0xFFDC8C4F),
    brandInk: Color(0xFFF09A55),
    brandFill: Color(0xFFB36730),
    brandSoft: Color(0xFF3D2717),
    off: Color(0xFFDE5547),
    offSoft: Color(0xFF3C1D1A),
    work: Color(0xFF5E9EB3),
    workSoft: Color(0xFF1C2E35),
    live: Color(0xFF4E9A6F),
    liveSoft: Color(0xFF182D20),
    pending: Color(0xFFDCA02C),
    danger: Color(0xFFE3594D),
    isDark: true,
  );

  /// 依据主题色彩方案和明暗度生成设计令牌。
  factory PoopTokens.create({
    required AppThemeColor color,
    required bool isDark,
  }) {
    if (!isDark) {
      // ---- 浅色模式 ----
      return switch (color) {
        AppThemeColor.caramel => light,
        AppThemeColor.matcha => light.copyWith(
            brand: const Color(0xFF4D885B),
            brandInk: const Color(0xFF30623A),
            brandFill: const Color(0xFF3F7A57),
            brandSoft: const Color(0xFFE0ECE3),
            isDark: false,
          ),
        AppThemeColor.ocean => light.copyWith(
            brand: const Color(0xFF4B7E9F),
            brandInk: const Color(0xFF2B5B78),
            brandFill: const Color(0xFF386D8F),
            brandSoft: const Color(0xFFE0EBF2),
            isDark: false,
          ),
        AppThemeColor.lavender => light.copyWith(
            brand: const Color(0xFF8A659E),
            brandInk: const Color(0xFF654079),
            brandFill: const Color(0xFF764E8C),
            brandSoft: const Color(0xFFEFE4F3),
            isDark: false,
          ),
        AppThemeColor.terracotta => light.copyWith(
            brand: const Color(0xFFBD5D4C),
            brandInk: const Color(0xFF8F392A),
            brandFill: const Color(0xFFA14333),
            brandSoft: const Color(0xFFF8E3DF),
            isDark: false,
          ),
      };
    } else {
      // ---- 深色模式 ----
      return switch (color) {
        AppThemeColor.caramel => dark,
        AppThemeColor.matcha => dark.copyWith(
            brand: const Color(0xFF5AA36E),
            brandInk: const Color(0xFF74BD87),
            brandFill: const Color(0xFF3B7752),
            brandSoft: const Color(0xFF183120),
            isDark: true,
          ),
        AppThemeColor.ocean => dark.copyWith(
            brand: const Color(0xFF5898BF),
            brandInk: const Color(0xFF72B1D7),
            brandFill: const Color(0xFF356A8C),
            brandSoft: const Color(0xFF172B38),
            isDark: true,
          ),
        AppThemeColor.lavender => dark.copyWith(
            brand: const Color(0xFFA57EBC),
            brandInk: const Color(0xFFBE97D5),
            brandFill: const Color(0xFF724A88),
            brandSoft: const Color(0xFF2F1D38),
            isDark: true,
          ),
        AppThemeColor.terracotta => dark.copyWith(
            brand: const Color(0xFFD7715F),
            brandInk: const Color(0xFFEB8472),
            brandFill: const Color(0xFF9E3E2E),
            brandSoft: const Color(0xFF3D1B15),
            isDark: true,
          ),
      };
    }
  }

  @override
  PoopTokens copyWith({
    Color? paper,
    Color? paperDeep,
    Color? surface,
    Color? surface2,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? ink4,
    Color? line,
    Color? lineSoft,
    Color? brand,
    Color? brandInk,
    Color? brandFill,
    Color? brandSoft,
    Color? off,
    Color? offSoft,
    Color? work,
    Color? workSoft,
    Color? live,
    Color? liveSoft,
    Color? pending,
    Color? danger,
    bool? isDark,
  }) {
    return PoopTokens(
      paper: paper ?? this.paper,
      paperDeep: paperDeep ?? this.paperDeep,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      ink4: ink4 ?? this.ink4,
      line: line ?? this.line,
      lineSoft: lineSoft ?? this.lineSoft,
      brand: brand ?? this.brand,
      brandInk: brandInk ?? this.brandInk,
      brandFill: brandFill ?? this.brandFill,
      brandSoft: brandSoft ?? this.brandSoft,
      off: off ?? this.off,
      offSoft: offSoft ?? this.offSoft,
      work: work ?? this.work,
      workSoft: workSoft ?? this.workSoft,
      live: live ?? this.live,
      liveSoft: liveSoft ?? this.liveSoft,
      pending: pending ?? this.pending,
      danger: danger ?? this.danger,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  PoopTokens lerp(ThemeExtension<PoopTokens>? other, double t) {
    if (other is! PoopTokens) return this;
    return PoopTokens(
      paper: Color.lerp(paper, other.paper, t)!,
      paperDeep: Color.lerp(paperDeep, other.paperDeep, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      ink4: Color.lerp(ink4, other.ink4, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineSoft: Color.lerp(lineSoft, other.lineSoft, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandInk: Color.lerp(brandInk, other.brandInk, t)!,
      brandFill: Color.lerp(brandFill, other.brandFill, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      off: Color.lerp(off, other.off, t)!,
      offSoft: Color.lerp(offSoft, other.offSoft, t)!,
      work: Color.lerp(work, other.work, t)!,
      workSoft: Color.lerp(workSoft, other.workSoft, t)!,
      live: Color.lerp(live, other.live, t)!,
      liveSoft: Color.lerp(liveSoft, other.liveSoft, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }

  /// 便捷取用：`context.tokens.ink3`
  static PoopTokens of(BuildContext context) =>
      Theme.of(context).extension<PoopTokens>() ?? light;

  /// 随当前主题色动态派生的品牌渐变（用于主按钮、分段胶囊滑块等）。
  LinearGradient get brandGradient => LinearGradient(
        colors: [brand, brandFill],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// 随当前主题色动态派生的品牌投影。
  List<BoxShadow> get brandShadow => [
        BoxShadow(
          color: brandFill.withValues(alpha: isDark ? 0.40 : 0.25),
          blurRadius: 5,
          offset: const Offset(0, 1.5),
        ),
      ];
}

/// 头像的配色对。
///
/// 屙屎人没有存颜色，颜色是**从 id 稳定推导**出来的 —— 见 [avatarColorFor]。
/// 用户不选颜色，所以任意两个人在日历上撞色是可能的；这里挑的是一组
/// 色相拉得比较开的颜色，常用人数（2~4 人）下不会撞。
class AvatarColor {
  const AvatarColor(this.bg, this.fg);

  /// 圆形底色。
  final Color bg;

  /// 图标/首字的前景色。**必须对 [bg] 达到 3:1**（图标是非文本）。
  final Color fg;
}

/// 头像色板。顺序就是取色顺序。
///
/// 每一对都经过 WCAG 非文本 3:1 校验，见 `test/theme/tokens_contrast_test.dart`。
const List<AvatarColor> kAvatarPalette = [
  AvatarColor(Color(0xFFF7E5D2), Color(0xFFB4662F)), // 焦糖
  AvatarColor(Color(0xFFE1EDE5), Color(0xFF3F7A57)), // 苔绿
  AvatarColor(Color(0xFFEFE4F1), Color(0xFF8A5FA8)), // 淡紫
  AvatarColor(Color(0xFFE4EAF0), Color(0xFF4A6B85)), // 雾蓝
  AvatarColor(Color(0xFFF7E3DE), Color(0xFFA85442)), // 陶土
  AvatarColor(Color(0xFFE8EFE0), Color(0xFF5A7A45)), // 橄榄
  AvatarColor(Color(0xFFF2E7DA), Color(0xFF8A5A3C)), // 拿铁
  AvatarColor(Color(0xFFE7E6F4), Color(0xFF5A5A94)), // 灰紫
];

/// 由 id 稳定地取一个头像配色。
///
/// **不能用 `String.hashCode`** —— Dart 的字符串哈希不保证跨进程稳定，
/// 那样每次冷启动同一个人会换颜色，日历看着像随机闪烁。
/// 这里用 FNV-1a，跨平台跨版本都稳定。
AvatarColor avatarColorFor(String id) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < id.length; i++) {
    hash ^= id.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return kAvatarPalette[hash % kAvatarPalette.length];
}

/// 姓名的首字（用于没有图标也没有照片时兜底）。
///
/// 中文取第一个字；英文取首字母大写。
String initialOf(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  return t.characters.first.toUpperCase();
}

/// 便捷扩展：`context.tokens.ink3`。
///
/// 挂在 [BuildContext] 上而不是某个页面文件里 —— 谁 import 了令牌谁就能用。
extension PoopTokensX on BuildContext {
  PoopTokens get tokens => PoopTokens.of(this);
}

/// 展示型字体族（得意黑 / Smiley Sans）。
///
/// **只用于标题类文字**：应用栏标题、月份标题、日期栏、FAB、弹层标题、大数字。
/// 它是个斜体展示字体，字形宽、字重单一 —— 塞进正文会立刻显得廉价。
///
/// 正文**不打包字体**：安卓自带 Noto Sans CJK，中文渲染够好，
/// 为它多背 5~10 MB 不值得。
const String kDisplayFont = 'SmileySans';

/// 展示型文字样式。
///
/// **刻意不接受 fontWeight 参数**：得意黑只有一个字重，
/// 传 `FontWeight.w700` 不会让它变粗，只会让安卓去**合成假粗体** ——
/// 笔画会糊成一团，比不加粗更难看。所有展示型文字都用它自带的字重。
TextStyle displayStyle({
  required double size,
  Color? color,
  double? letterSpacing,
  double height = 1.0,
}) {
  return TextStyle(
    fontFamily: kDisplayFont,
    fontSize: size,
    fontWeight: FontWeight.w400,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// 圆角体系规范。
abstract final class PoopRadii {
  /// 卡片外框圆角：收敛曲率（由20微调为15），骨架利落干练，彻底消除臃肿膨胀感
  static const double card = 15;

  /// 日期单元格圆角：由13微调为9，与外层大卡片形成自然和谐的嵌套比例
  static const double cell = 9;

  static const double sheet = 28;
  static const double pill = 99;
}

/// 阴影。**一律用暖调** `rgba(94,66,42,·)`，绝不用中性灰 ——
/// 灰阴影配米色底会立刻显出"廉价 Material 默认感"。
abstract final class PoopShadows {
  static const List<BoxShadow> s1 = [
    BoxShadow(color: Color(0x0D5E422A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D5E422A), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> s2 = [
    BoxShadow(color: Color(0x125E422A), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x175E422A), blurRadius: 28, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> s3 = [
    BoxShadow(color: Color(0x295E422A), blurRadius: 40, offset: Offset(0, -8)),
  ];
}

/// WCAG 2.1 对比度计算。
///
/// 从 `.design/contrast-check.js` 移植过来 —— 两边必须用同一套口径，
/// 否则设计稿达标了、实现又不达标，自检就白做了。
abstract final class Wcag {
  /// 普通文本的 AA 阈值。
  static const double aaText = 4.5;

  /// 大字（≥24px，或 ≥18.66px 且粗体）与图标的 AA 阈值。
  static const double aaLarge = 3.0;

  /// WCAG 相对亮度。**不要**用 `Color.computeLuminance()` 代替：
  /// 那个走的是 Flutter 自己的线性化路径，为了和 JS 侧逐位对齐，
  /// 这里显式实现 WCAG 定义的那一条。
  static double relativeLuminance(Color c) {
    double channel(double v) {
      final s = v / 255.0;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    // 取 8 位整数值，和 JS 侧 getComputedStyle 拿到的 rgb(r,g,b) 口径一致
    final r = channel((c.r * 255.0).roundToDouble());
    final g = channel((c.g * 255.0).roundToDouble());
    final b = channel((c.b * 255.0).roundToDouble());
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 对比度，1.0 ~ 21.0。参数顺序无关。
  static double ratio(Color a, Color b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }
}

/// 动效与组件样式规范令牌。
///
/// 统一整套应用中的微交互、按压反馈、分段控件滑块过渡、状态切换时钟与曲线，
/// 确保同类组件手感一致、节奏统一。
abstract final class PoopMotions {
  /// 轻量按压缩放反馈时长（按钮、卡片、单元格点击）。
  static const Duration pressDuration = Duration(milliseconds: 120);

  /// 轻量按压曲线。
  static const Curve pressCurve = Curves.easeOutCubic;

  /// 滑块平移与尺寸形变切换时长（Tab、分段控件）。
  static const Duration switchDuration = Duration(milliseconds: 240);

  /// 控件切换缓动曲线。
  static const Curve switchCurve = Curves.easeOutCubic;

  /// 颜色、文字高亮过渡时长（文字颜色、背景渐变、描边）。
  static const Duration colorDuration = Duration(milliseconds: 180);

  /// 颜色过渡缓动曲线。
  static const Curve colorCurve = Curves.easeOutCubic;

  /// 分段控件与高亮滑块统一的焦糖渐变背景。
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFB05F2C), Color(0xFF9A5219)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 焦糖滑块与高亮胶囊统一的柔和焦糖投影。
  static const List<BoxShadow> brandShadow = [
    BoxShadow(
      color: Color(0x38A85F29),
      blurRadius: 5,
      offset: Offset(0, 1.5),
    ),
  ];
}
