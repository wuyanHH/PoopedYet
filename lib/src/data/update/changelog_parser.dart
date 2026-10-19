import 'package:flutter/foundation.dart';

/// GitHub Release 正文的**轻量 Markdown 解析**。
///
/// 为什么自己写而不是引 `flutter_markdown`：
/// 1. Release 正文实际只会用到极少几个语法（标题、列表、加粗、行内代码、链接、分割线）；
/// 2. 本项目对依赖一向吝啬，多一个包就多一份升级与体积成本；
/// 3. 渲染层要按手帐设计令牌重排（圆点、缩进、行距），第三方主题反而要覆写一遍。
///
/// 解析结果分两级：[ChangelogBlock] 表示块级结构，块内的行内语法再交给
/// [parseInlineSpans] 拆成 [ChangelogSpan]。渲染层只管照着画。
enum ChangelogBlockKind {
  /// `# 标题` ~ `###### 标题`
  heading,

  /// `- 条目`
  bullet,

  /// `1. 条目`
  ordered,

  /// 普通段落（连续多行合并为一段，内部用 `\n` 保留原始换行）
  paragraph,

  /// `> 引用`
  quote,

  /// `---` 分割线
  divider,

  /// ``` 围栏代码块
  code,
}

/// 一个块级元素。
@immutable
class ChangelogBlock {
  const ChangelogBlock({
    required this.kind,
    this.text = '',
    this.level = 0,
    this.index,
    this.checkbox,
  });

  final ChangelogBlockKind kind;

  /// 块内文本（不含 Markdown 标记本身）。
  final String text;

  /// [ChangelogBlockKind.heading] 时是 1~6 的标题层级；
  /// 列表时是缩进深度（0 起），用于画层级缩进。
  final int level;

  /// [ChangelogBlockKind.ordered] 的序号。
  final int? index;

  /// 任务列表状态：`true` 已完成、`false` 未完成、`null` 不是任务列表。
  final bool? checkbox;

  /// 这一块是否算「一条更新条目」（用于统计新增/优化/修复）。
  bool get isEntry =>
      kind == ChangelogBlockKind.bullet ||
      kind == ChangelogBlockKind.ordered ||
      kind == ChangelogBlockKind.paragraph;
}

/// 行内样式切片。
@immutable
class ChangelogSpan {
  const ChangelogSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.code = false,
    this.link,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool strike;
  final bool code;

  /// 链接地址；非空时该切片可点击。
  final String? link;
}

/// 更新条目的归类，用于弹窗顶部的摘要胶囊。
enum ChangelogAspect {
  feature('新增'),
  improve('优化'),
  fix('修复');

  const ChangelogAspect(this.label);

  final String label;
}

/// 各类条目的数量。
@immutable
class ChangelogSummary {
  const ChangelogSummary({
    this.feature = 0,
    this.improve = 0,
    this.fix = 0,
  });

  final int feature;
  final int improve;
  final int fix;

  int get total => feature + improve + fix;

  bool get isEmpty => total == 0;

  int countOf(ChangelogAspect aspect) => switch (aspect) {
        ChangelogAspect.feature => feature,
        ChangelogAspect.improve => improve,
        ChangelogAspect.fix => fix,
      };
}

/// 把 Release 正文解析成块序列。
List<ChangelogBlock> parseChangelogBlocks(String source) {
  final blocks = <ChangelogBlock>[];
  final lines = _stripHtmlNoise(source).split('\n');

  // 段落缓冲：连续的普通行要合并成一段，遇到空行或其它语法块才落盘。
  final paragraph = StringBuffer();
  var inCodeFence = false;
  final codeBuffer = StringBuffer();

  void flushParagraph() {
    final text = paragraph.toString().trim();
    paragraph.clear();
    if (text.isEmpty) return;
    blocks.add(ChangelogBlock(kind: ChangelogBlockKind.paragraph, text: text));
  }

  for (final rawLine in lines) {
    final line = rawLine.replaceAll('\r', '');
    final trimmed = line.trim();

    // 围栏代码块内部不做任何语法解释，原样收着。
    if (trimmed.startsWith('```')) {
      if (inCodeFence) {
        blocks.add(
          ChangelogBlock(
            kind: ChangelogBlockKind.code,
            text: codeBuffer.toString().trimRight(),
          ),
        );
        codeBuffer.clear();
      } else {
        flushParagraph();
      }
      inCodeFence = !inCodeFence;
      continue;
    }
    if (inCodeFence) {
      codeBuffer.writeln(line);
      continue;
    }

    if (trimmed.isEmpty) {
      flushParagraph();
      continue;
    }

    // 分割线：---、***、___（三个及以上）
    if (RegExp(r'^([-*_])\s*(\1\s*){2,}$').hasMatch(trimmed)) {
      flushParagraph();
      blocks.add(const ChangelogBlock(kind: ChangelogBlockKind.divider));
      continue;
    }

    // 标题
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      blocks.add(
        ChangelogBlock(
          kind: ChangelogBlockKind.heading,
          level: heading.group(1)!.length,
          text: heading.group(2)!.trim(),
        ),
      );
      continue;
    }

    // 引用
    if (trimmed.startsWith('>')) {
      flushParagraph();
      blocks.add(
        ChangelogBlock(
          kind: ChangelogBlockKind.quote,
          text: trimmed.replaceFirst(RegExp(r'^>\s?'), '').trim(),
        ),
      );
      continue;
    }

    // 列表：先算缩进层级（每 2 个空格 / 1 个 Tab 记一层），最多 3 层。
    final indentMatch = RegExp(r'^[ \t]*').firstMatch(line)!;
    final indent = _indentDepth(indentMatch.group(0)!);

    final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      flushParagraph();
      final content = bullet.group(1)!.trim();
      final check = RegExp(r'^\[([ xX])\]\s*(.*)$').firstMatch(content);
      if (check != null) {
        blocks.add(
          ChangelogBlock(
            kind: ChangelogBlockKind.bullet,
            level: indent,
            text: check.group(2)!.trim(),
            checkbox: check.group(1)!.toLowerCase() == 'x',
          ),
        );
      } else {
        blocks.add(
          ChangelogBlock(
            kind: ChangelogBlockKind.bullet,
            level: indent,
            text: content,
          ),
        );
      }
      continue;
    }

    final ordered = RegExp(r'^(\d{1,3})[.)]\s+(.*)$').firstMatch(trimmed);
    if (ordered != null) {
      flushParagraph();
      blocks.add(
        ChangelogBlock(
          kind: ChangelogBlockKind.ordered,
          level: indent,
          index: int.tryParse(ordered.group(1)!),
          text: ordered.group(2)!.trim(),
        ),
      );
      continue;
    }

    // 普通段落行
    if (paragraph.isNotEmpty) paragraph.write('\n');
    paragraph.write(trimmed);
  }

  flushParagraph();
  if (inCodeFence && codeBuffer.isNotEmpty) {
    blocks.add(
      ChangelogBlock(
        kind: ChangelogBlockKind.code,
        text: codeBuffer.toString().trimRight(),
      ),
    );
  }

  return blocks;
}

/// 解析一行内的行内语法。
///
/// 支持 `**粗体**`、`*斜体*`、`~~删除线~~`、`` `代码` ``、`[文字](链接)` 与裸链接。
/// 不支持的语法一律当纯文本 —— 宁可少渲染，也不能把用户的原文吃掉。
List<ChangelogSpan> parseInlineSpans(String input) {
  final spans = <ChangelogSpan>[];
  final buffer = StringBuffer();
  var i = 0;

  void flush({bool bold = false, bool italic = false, bool strike = false, bool code = false, String? link}) {
    if (buffer.isEmpty) return;
    spans.add(
      ChangelogSpan(
        buffer.toString(),
        bold: bold,
        italic: italic,
        strike: strike,
        code: code,
        link: link,
      ),
    );
    buffer.clear();
  }

  while (i < input.length) {
    final ch = input[i];

    // `代码`
    if (ch == '`') {
      final end = input.indexOf('`', i + 1);
      if (end > i + 1) {
        flush();
        spans.add(ChangelogSpan(input.substring(i + 1, end), code: true));
        i = end + 1;
        continue;
      }
    }

    // [文字](链接)
    if (ch == '[') {
      final labelEnd = input.indexOf(']', i + 1);
      if (labelEnd > i + 1 && labelEnd + 1 < input.length && input[labelEnd + 1] == '(') {
        final urlEnd = input.indexOf(')', labelEnd + 2);
        if (urlEnd > labelEnd + 2) {
          flush();
          final label = input.substring(i + 1, labelEnd);
          final url = input.substring(labelEnd + 2, urlEnd);
          spans.add(ChangelogSpan(label, link: url, bold: true));
          i = urlEnd + 1;
          continue;
        }
      }
    }

    // **粗体**
    if (ch == '*' && _startsWith(input, i, '**')) {
      final end = input.indexOf('**', i + 2);
      if (end > i + 2) {
        flush();
        buffer.write(input.substring(i + 2, end));
        flush(bold: true);
        i = end + 2;
        continue;
      }
    }

    // ~~删除线~~
    if (ch == '~' && _startsWith(input, i, '~~')) {
      final end = input.indexOf('~~', i + 2);
      if (end > i + 2) {
        flush();
        buffer.write(input.substring(i + 2, end));
        flush(strike: true);
        i = end + 2;
        continue;
      }
    }

    // *斜体* / _斜体_（不处理成对星号里的空格，避免误伤 2*3 这类文本）
    if ((ch == '*' || ch == '_') && !_startsWith(input, i, '**')) {
      final end = input.indexOf(ch, i + 1);
      if (end > i + 1 && !input.substring(i + 1, end).contains('\n')) {
        flush();
        buffer.write(input.substring(i + 1, end));
        flush(italic: true);
        i = end + 1;
        continue;
      }
    }

    // 裸链接
    if (ch == 'h' && _startsWith(input, i, 'http')) {
      final match = RegExp(r'^https?://[^\s)>\]]+').firstMatch(input.substring(i));
      if (match != null) {
        flush();
        final url = match.group(0)!;
        spans.add(ChangelogSpan(url, link: url));
        i += url.length;
        continue;
      }
    }

    buffer.write(ch);
    i++;
  }

  flush();
  return spans;
}

/// 统计正文里「新增 / 优化 / 修复」各有多少条。
///
/// 归类顺序是**修复 → 新增 → 优化**：「优化体验并修复闪退」这种句子，
/// 用户真正在意的是它修了东西，归到修复比归到优化更贴近直觉。
ChangelogSummary summarizeChangelog(List<ChangelogBlock> blocks) {
  var feature = 0;
  var improve = 0;
  var fix = 0;

  for (final block in blocks) {
    if (!block.isEntry) continue;
    switch (classifyChangelogEntry(block.text)) {
      case ChangelogAspect.feature:
        feature++;
      case ChangelogAspect.improve:
        improve++;
      case ChangelogAspect.fix:
        fix++;
      case null:
        break;
    }
  }

  return ChangelogSummary(feature: feature, improve: improve, fix: fix);
}

/// 判定单条更新内容属于哪一类，判定不出来时返回 null。
ChangelogAspect? classifyChangelogEntry(String raw) {
  final text = raw.trim().toLowerCase();
  if (text.isEmpty) return null;

  // 1. emoji 前缀最可靠 —— 发版人写 emoji 就是为了标类别。
  const emojiMap = <ChangelogAspect, List<String>>{
    ChangelogAspect.fix: ['🐛', '🩹', '🚑', '🔧'],
    ChangelogAspect.feature: ['✨', '🎉', '🚀', '🆕', '📦', '🌟'],
    ChangelogAspect.improve: ['⚡', '🎨', '💄', '♻️', '🔥', '🧹', '📝'],
  };
  for (final entry in emojiMap.entries) {
    for (final emoji in entry.value) {
      if (text.contains(emoji)) return entry.key;
    }
  }

  // 2. 关键词。顺序即优先级，见方法文档。
  const keywords = <ChangelogAspect, List<String>>{
    ChangelogAspect.fix: [
      '修复', '修正', '修好', '修掉', '解决', '闪退', '崩溃', '异常', '报错',
      'bug', 'fix', 'hotfix', 'crash',
    ],
    ChangelogAspect.feature: [
      '新增', '新添', '增加', '添加', '支持', '上线', '引入', '全新', '推出',
      '开放', 'feature', 'add ', 'new ', 'support',
    ],
    ChangelogAspect.improve: [
      '优化', '改进', '提升', '打磨', '调整', '增强', '重构', '精简', '性能',
      '体验', '交互', '排版', '视觉', 'improve', 'optimi', 'enhance', 'polish',
      'refactor', 'ui ', 'ux ',
    ],
  };
  for (final entry in keywords.entries) {
    for (final keyword in entry.value) {
      if (text.contains(keyword)) return entry.key;
    }
  }

  return null;
}

// ---------------- 内部工具 ----------------

bool _startsWith(String source, int index, String pattern) {
  if (index + pattern.length > source.length) return false;
  return source.startsWith(pattern, index);
}

int _indentDepth(String leading) {
  var spaces = 0;
  for (final unit in leading.codeUnits) {
    spaces += unit == 0x09 ? 4 : 1;
  }
  final depth = spaces ~/ 2;
  return depth > 3 ? 3 : depth;
}

/// 剔掉 HTML 注释、`<img>`、`<details>` 这类在纯文本渲染里只会变成噪音的片段。
String _stripHtmlNoise(String source) {
  var text = source.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  // 整行就是一个 HTML 标签的（图片、换行符、details 开合）直接删掉
  text = text.replaceAll(RegExp(r'^\s*</?[a-zA-Z][^>]*>\s*$', multiLine: true), '');
  // "Full Changelog: <url>" 这类对比链接是 GitHub 自动生成的，对用户没信息量
  text = text.replaceAll(
    RegExp(r'^\s*\*{0,2}Full Changelog\*{0,2}:.*$', multiLine: true, caseSensitive: false),
    '',
  );
  return text;
}
