import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/tokens.dart';

/// 启动自检页。
///
/// **这不是最终界面**，是把基础设施串起来跑通的验证页：
/// Riverpod → Drift → 建库/迁移/索引/种子数据，加上设计令牌的渲染。
/// 真机或模拟器上看到「我」和模板条数，就说明数据层是对的。
///
/// 下一步会把它换成真正的日历主页（视觉稿 ①）。
class BootCheckScreen extends ConsumerWidget {
  const BootCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final report = ref.watch(bootReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('屙了么'),
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: t.ink,
          letterSpacing: 0.5,
        ),
      ),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _ErrorPane(error: e, stack: st),
        data: (r) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Banner(fresh: r.createdFresh),
            const SizedBox(height: 14),
            _Card(
              title: '数据层',
              rows: [
                ('默认屙屎人', r.defaultPooperName),
                ('在册屙屎人', '${r.pooperCount} 人'),
                ('记录总数', '${r.recordCount} 条'),
                ('默认备注模板', '${r.noteTemplateCount} 条'),
                ('外键约束', r.foreignKeysOn ? '已开启 ✓' : '未开启 ✗ 危险'),
              ],
            ),
            const SizedBox(height: 14),
            _Card(
              title: '设计令牌',
              rows: [
                ('纸面 / 卡片', '#FAF5EC / #FFFFFF'),
                ('焦糖三分', 'brand / brandInk / brandFill'),
                ('WCAG 对比度', '全部 AA（60 个测试守着）'),
              ],
            ),
            const SizedBox(height: 18),
            _Swatches(t: t),
            const SizedBox(height: 18),
            Text(
              '这一页只是启动自检。下一步换成日历主页。',
              style: TextStyle(fontSize: 12, color: t.ink3, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.fresh});
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.brandSoft,
        borderRadius: BorderRadius.circular(PoopRadii.card),
      ),
      child: Row(
        children: [
          Icon(
            fresh ? Icons.auto_awesome : Icons.check_circle_outline,
            size: 18,
            color: t.brandInk,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fresh ? '首次启动：已自动创建「我」' : '数据库就绪',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: t.brandInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(PoopRadii.card),
        border: Border.all(color: t.line),
        boxShadow: PoopShadows.s1,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: t.ink3,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(k, style: TextStyle(fontSize: 14, color: t.ink2))),
                  Text(
                    v,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 把关键色块摊出来，肉眼确认渲染没跑偏。
class _Swatches extends StatelessWidget {
  const _Swatches({required this.t});
  final PoopTokens t;

  @override
  Widget build(BuildContext context) {
    final items = <(String, Color, Color)>[
      ('焦糖底/白字', t.brandFill, Colors.white),
      ('焦糖字', t.brandSoft, t.brandInk),
      ('休', t.off, Colors.white),
      ('班', t.work, Colors.white),
      ('正在屙', t.liveSoft, t.live),
      ('危险', t.surface, t.danger),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, bg, fg) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(PoopRadii.pill),
              border: Border.all(color: t.line),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg),
            ),
          ),
      ],
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.error, required this.stack});
  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: t.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                '启动失败',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: t.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            '$error',
            style: TextStyle(fontSize: 13, color: t.ink, height: 1.5),
          ),
          const SizedBox(height: 12),
          SelectableText(
            '$stack',
            style: TextStyle(fontSize: 11, color: t.ink3, height: 1.4),
          ),
        ],
      ),
    );
  }
}
