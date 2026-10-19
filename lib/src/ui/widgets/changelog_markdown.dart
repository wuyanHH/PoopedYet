import 'package:flutter/material.dart';

import '../../data/update/changelog_parser.dart';
import '../../theme/tokens.dart';

/// 更新日志的富文本渲染。
///
/// 输入是 [ChangelogBlock] 序列（由 `parseChangelogBlocks` 从 GitHub Release
/// 正文解析而来），这里只负责把它们画成手帐风格的排版：
/// 标题带焦糖竖条、列表用小圆点/勾选框、引用带侧边线、代码块用等宽字体。
///
/// **不引第三方 Markdown 包**的原因见 `changelog_parser.dart` 顶部注释。
class ChangelogMarkdown extends StatelessWidget {
  const ChangelogMarkdown({
    super.key,
    required this.blocks,
    this.onOpenLink,
    this.baseFontSize = 12.5,
  });

  final List<ChangelogBlock> blocks;

  /// 点击链接时回调（一般是唤起浏览器）。
  final ValueChanged<String>? onOpenLink;

  final double baseFontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (blocks.isEmpty) {
      return Text(
        '日常性能优化与体验改进',
        style: TextStyle(fontSize: baseFontSize, color: t.ink2, height: 1.6),
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) {
        final gap = _gapBefore(blocks[i], blocks[i - 1]);
        if (gap > 0) children.add(SizedBox(height: gap));
      }
      children.add(_buildBlock(context, t, blocks[i]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// 块与块之间的呼吸感。列表项之间收紧、段落与标题之间放开 ——
  /// 一视同仁的大间距会让十几条更新读起来像一盘散沙。
  double _gapBefore(ChangelogBlock current, ChangelogBlock previous) {
    if (current.kind == ChangelogBlockKind.heading) {
      return previous.kind == ChangelogBlockKind.heading ? 8 : 12;
    }
    if (previous.kind == ChangelogBlockKind.heading) return 6;
    if (current.kind == ChangelogBlockKind.bullet ||
        current.kind == ChangelogBlockKind.ordered) {
      return 5;
    }
    if (current.kind == ChangelogBlockKind.divider) return 10;
    if (previous.kind == ChangelogBlockKind.divider) return 10;
    return 8;
  }

  Widget _buildBlock(BuildContext context, PoopTokens t, ChangelogBlock block) {
    switch (block.kind) {
      case ChangelogBlockKind.heading:
        final isTop = block.level <= 2;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(top: isTop ? 3.5 : 3, right: 7),
              width: 3,
              height: isTop ? 13 : 11,
              decoration: BoxDecoration(
                color: t.brand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: _rich(
                t,
                block.text,
                _base(t, size: isTop ? 13 : 12.5).copyWith(
                  fontWeight: FontWeight.w800,
                  color: t.ink,
                  height: 1.35,
                ),
              ),
            ),
          ],
        );

      case ChangelogBlockKind.bullet:
        return Padding(
          padding: EdgeInsets.only(left: block.level * 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bulletMarker(t, block),
              const SizedBox(width: 7),
              Expanded(child: _rich(t, block.text, _base(t))),
            ],
          ),
        );

      case ChangelogBlockKind.ordered:
        return Padding(
          padding: EdgeInsets.only(left: block.level * 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 16,
                child: Text(
                  '${block.index ?? 1}.',
                  style: _base(t, size: baseFontSize - 0.5).copyWith(
                    fontWeight: FontWeight.w800,
                    color: t.brandInk,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(child: _rich(t, block.text, _base(t))),
            ],
          ),
        );

      case ChangelogBlockKind.quote:
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 2, 0, 2),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: t.brand.withValues(alpha: 0.55), width: 2.5),
            ),
          ),
          child: _rich(
            t,
            block.text,
            _base(t).copyWith(color: t.ink3, fontStyle: FontStyle.italic),
          ),
        );

      case ChangelogBlockKind.divider:
        return Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 2),
          color: t.lineSoft,
        );

      case ChangelogBlockKind.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: t.paperDeep,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.lineSoft.withValues(alpha: 0.7)),
          ),
          child: Text(
            block.text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: baseFontSize - 1,
              height: 1.5,
              color: t.ink2,
            ),
          ),
        );

      case ChangelogBlockKind.paragraph:
        return _rich(t, block.text, _base(t));
    }
  }

  /// 列表符号：普通条目是小圆点，任务列表条目是勾选框。
  Widget _bulletMarker(PoopTokens t, ChangelogBlock block) {
    if (block.checkbox == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(Icons.check_rounded, size: 12, color: t.brandInk),
      );
    }
    if (block.checkbox == false) {
      return Container(
        margin: const EdgeInsets.only(top: 4.5),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: t.ink4, width: 1.2),
        ),
      );
    }
    return Container(
      margin: EdgeInsets.only(top: block.level > 0 ? 5.5 : 5, right: 1),
      width: block.level > 0 ? 3.5 : 4.5,
      height: block.level > 0 ? 3.5 : 4.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: block.level > 0 ? t.ink4 : t.brand,
      ),
    );
  }

  TextStyle _base(
    PoopTokens t, {
    double? size,
    double height = 1.62,
  }) {
    return TextStyle(
      fontSize: size ?? baseFontSize,
      color: t.ink2,
      height: height,
    );
  }

  /// 把一行文本按行内语法渲染成 [Text.rich]。
  Widget _rich(PoopTokens t, String source, TextStyle base) {
    final spans = parseInlineSpans(source);
    return Text.rich(
      TextSpan(
        children: [
          for (final span in spans) _toInlineSpan(t, span, base),
        ],
      ),
      style: base,
    );
  }

  InlineSpan _toInlineSpan(PoopTokens t, ChangelogSpan span, TextStyle base) {
    // 链接用 WidgetSpan + GestureDetector：这样不必管理 TapGestureRecognizer
    // 的生命周期（TextSpan.recognizer 是每次 build 都要新建并手动 dispose 的坑）。
    final link = span.link;
    if (link != null && link.isNotEmpty) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => onOpenLink?.call(link),
          behavior: HitTestBehavior.opaque,
          child: Text(
            span.text.isEmpty ? link : span.text,
            style: base.copyWith(
              color: t.brandInk,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: t.brandInk.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    var style = base;
    if (span.bold) {
      style = style.copyWith(fontWeight: FontWeight.w700, color: t.ink);
    }
    if (span.italic) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    if (span.strike) {
      style = style.copyWith(decoration: TextDecoration.lineThrough);
    }
    if (span.code) {
      style = style.copyWith(
        fontFamily: 'monospace',
        fontSize: (base.fontSize ?? baseFontSize) - 0.5,
        color: t.brandInk,
        backgroundColor: t.paperDeep,
      );
    }
    return TextSpan(text: span.text, style: style);
  }
}

/// 「新增 4 · 优化 3 · 修复 1」分类摘要胶囊。
///
/// 更新正文动辄十几条，用户先想知道的是「这次值得升吗」——
/// 分类计数就是回答这个问题的第一眼信息。
class ChangelogAspectChips extends StatelessWidget {
  const ChangelogAspectChips({super.key, required this.summary});

  final ChangelogSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;

    final chips = <Widget>[];
    for (final aspect in ChangelogAspect.values) {
      final count = summary.countOf(aspect);
      if (count <= 0) continue;
      final color = switch (aspect) {
        ChangelogAspect.feature => t.live,
        ChangelogAspect.improve => t.work,
        ChangelogAspect.fix => t.pending,
      };
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: t.isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(PoopRadii.pill),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 5),
              Text(
                '${aspect.label} $count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: t.ink2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}
