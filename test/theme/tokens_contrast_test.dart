import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pooped_yet/src/theme/tokens.dart';

/// 设计令牌的对比度护栏。
///
/// 这套色板的初版有 **355 处文本 + 50 处图标** 不达 WCAG AA，而肉眼看完全正常。
/// 暖色调尤其容易骗人：米色底 + 中灰文字看着"柔和高级"，实测只有 2.76:1。
///
/// 所以"改颜色要重新验对比度"这件事不能靠纪律，要靠这个测试。
/// 视觉稿那边有等价的 `.design/contrast-check.js`，两边口径必须一致 ——
/// 见 [Wcag] 的文档注释。
void main() {
  const t = PoopTokens.light;

  /// 断言 [fg] 放在 [bg] 上达到 AA。
  void expectAA(
    Color fg,
    Color bg, {
    required String what,
    double min = Wcag.aaText,
    Color? bg2,
  }) {
    final r = Wcag.ratio(fg, bg);
    expect(
      r,
      greaterThanOrEqualTo(min),
      reason: '$what：对 ${_hex(bg)} 只有 ${r.toStringAsFixed(2)}:1，需要 $min',
    );
    if (bg2 != null) {
      final r2 = Wcag.ratio(fg, bg2);
      expect(
        r2,
        greaterThanOrEqualTo(min),
        reason: '$what：对 ${_hex(bg2)} 只有 ${r2.toStringAsFixed(2)}:1，需要 $min',
      );
    }
  }

  group('文字色 · 普通正文（需 4.5:1）', () {
    test('主文字 / 次级文字 / 三级文字 在三种底上都达标', () {
      for (final bg in {'纸面': t.paper, '白卡': t.surface, '次级底': t.paperDeep}.entries) {
        expectAA(t.ink, bg.value, what: '主文字对${bg.key}');
        expectAA(t.ink2, bg.value, what: '次级文字对${bg.key}');
        expectAA(t.ink3, bg.value, what: '三级文字对${bg.key}');
      }
    });

    test('焦糖色文字用 brandInk，不用 brand', () {
      for (final bg in {'纸面': t.paper, '白卡': t.surface, '主色浅底': t.brandSoft}.entries) {
        expectAA(t.brandInk, bg.value, what: 'brandInk 对${bg.key}');
      }
    });

    test('白字放在 brandFill / off / work / live 上都达标', () {
      expectAA(Colors.white, t.brandFill, what: '白字对 brandFill');
      expectAA(Colors.white, t.off, what: '白字对「休」');
      expectAA(Colors.white, t.work, what: '白字对「班」');
      expectAA(Colors.white, t.live, what: '白字对「正在屙」');
      expectAA(Colors.white, t.danger, what: '白字对 danger');
    });

    test('状态色当文字用也达标', () {
      expectAA(t.live, t.surface, what: '正在屙对白卡');
      expectAA(t.live, t.paper, what: '正在屙对纸面');
      expectAA(t.danger, t.surface, what: 'danger 对白卡');
      expectAA(t.danger, t.paper, what: 'danger 对纸面');
    });
  });

  group('非文本 · 图标与描边（需 3.0:1）', () {
    test('ink4 只对白底达标', () {
      expectAA(t.ink4, t.surface, what: 'ink4 对白卡', min: Wcag.aaLarge);
    });

    test('今天日期的描边色（brand）对纸面达标', () {
      expectAA(t.brand, t.paper, what: 'brand 对纸面', min: Wcag.aaLarge);
      expectAA(t.brand, t.surface, what: 'brand 对白卡', min: Wcag.aaLarge);
    });
  });

  group('回归护栏：这些组合必须**不达标**，否则说明有人改回去了', () {
    test('旧 ink-3 (#A2937F) 对纸面不足 4.5:1 —— 这就是它被换掉的原因', () {
      const oldInk3 = Color(0xFFA2937F);
      expect(Wcag.ratio(oldInk3, t.paper), lessThan(Wcag.aaText));
      expect(Wcag.ratio(oldInk3, t.surface), lessThan(Wcag.aaText));
      expect(Wcag.ratio(oldInk3, t.paperDeep), lessThan(Wcag.aaText));
    });

    test('brand 直接当文字用不足 4.5:1 —— 所以必须用 brandInk', () {
      expect(Wcag.ratio(t.brand, t.paper), lessThan(Wcag.aaText));
      expect(Wcag.ratio(t.brand, t.surface), lessThan(Wcag.aaText));
    });

    test('白字放在 brand（而不是 brandFill）上不足 4.5:1', () {
      expect(Wcag.ratio(Colors.white, t.brand), lessThan(Wcag.aaText));
    });

    test('旧的主按钮渐变浅端 (#D98B4C) 上的白字只有 2.71:1', () {
      const oldGradientLight = Color(0xFFD98B4C);
      final r = Wcag.ratio(Colors.white, oldGradientLight);
      expect(r, lessThan(Wcag.aaLarge)); // 连大字阈值都不到
      expect(r, closeTo(2.71, 0.05));
    });

    test('ink-4 放在主色浅底上不达标 —— 这是它曾被误用的地方', () {
      // .firsthint 的 ✕ 按钮曾用 ink4 放在 brandSoft 上，实测 2.66:1
      final r = Wcag.ratio(t.ink4, t.brandSoft);
      expect(r, lessThan(Wcag.aaLarge));
      expect(r, closeTo(2.66, 0.05));
      // 改用 ink3 后达标，顺带确认它确实达标
      expectAA(t.ink3, t.brandSoft, what: 'ink3 对主色浅底', min: Wcag.aaLarge);
    });
  });

  group('Wcag 工具自身', () {
    test('黑白对比度是 21:1', () {
      expect(Wcag.ratio(Colors.white, Colors.black), closeTo(21.0, 0.01));
    });

    test('同色对比度是 1:1', () {
      expect(Wcag.ratio(t.ink, t.ink), closeTo(1.0, 0.001));
    });

    test('参数顺序不影响结果', () {
      expect(
        Wcag.ratio(t.ink, t.paper),
        closeTo(Wcag.ratio(t.paper, t.ink), 1e-12),
      );
    });

    test('相对亮度落在 0~1', () {
      for (final c in [t.paper, t.ink, t.brand, t.brandFill, t.paperDeep]) {
        final l = Wcag.relativeLuminance(c);
        expect(l, inInclusiveRange(0.0, 1.0));
      }
    });

    test('与 JS 侧 contrast-check.js 的已知数值一致', () {
      // 这几个数字是从 .design/contrast-check.js 的实测输出里抄来的，
      // 用来保证 Dart 和 JS 两侧算法没有悄悄分叉。
      expect(Wcag.ratio(t.ink3, t.paper), closeTo(5.17, 0.02));
      expect(Wcag.ratio(t.brandInk, t.paper), closeTo(5.38, 0.02));
      expect(Wcag.ratio(Colors.white, t.brandFill), closeTo(4.85, 0.02));
      expect(Wcag.ratio(Colors.white, t.off), closeTo(6.01, 0.02));
      expect(Wcag.ratio(Colors.white, t.work), closeTo(4.61, 0.02));
      expect(Wcag.ratio(t.live, t.surface), closeTo(5.08, 0.02));
    });
  });

  group('ThemeExtension 契约', () {
    test('copyWith 只改指定字段', () {
      final changed = t.copyWith(ink: const Color(0xFF000000));
      expect(changed.ink, const Color(0xFF000000));
      expect(changed.paper, t.paper);
      expect(changed.brandInk, t.brandInk);
    });

    test('lerp 在 t=0 / t=1 时等于两端', () {
      final other = t.copyWith(ink: const Color(0xFFFFFFFF));
      expect(t.lerp(other, 0).ink, t.ink);
      expect(t.lerp(other, 1).ink, other.ink);
    });

    test('lerp 遇到别的类型时返回自身', () {
      expect(t.lerp(null, 0.5).ink, t.ink);
    });
  });
}

String _hex(Color c) =>
    '#${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}';
