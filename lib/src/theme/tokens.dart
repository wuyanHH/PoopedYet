import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    required this.danger,
  });

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

  /// 危险操作。对白 4.93:1。
  final Color danger;

  /// 浅色主题的唯一实例。
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
    danger: Color(0xFFC4453A),
  );

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
    Color? danger,
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
      danger: danger ?? this.danger,
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
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }

  /// 便捷取用：`context.tokens.ink3`
  static PoopTokens of(BuildContext context) =>
      Theme.of(context).extension<PoopTokens>() ?? light;
}

/// 圆角。取自视觉稿 `:root`。
abstract final class PoopRadii {
  static const double card = 20;
  static const double cell = 13;
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
