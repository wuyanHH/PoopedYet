import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../domain/history_filter.dart';
import '../../state/calendar_data.dart';
import '../../state/history.dart';
import '../../theme/tokens.dart';
import '../widgets/pooper_avatar.dart';
import '../widgets/settings_widgets.dart';

/// 搜索与筛选（视觉稿 ⑦）。
///
/// **先攒好条件、点「应用」才生效** —— 和记录详情那种"改一下立刻落库"刻意不同。
/// 筛选是纯查询、完全可逆，边打字边刷结果只会让列表一直跳，
/// 用户反而看不清自己在筛什么。
///
/// 例外是顶部历史页那条按人的 chips：那边点一下就生效，
/// 因为"只看阿狗的"是最常用的筛选，值得一步可达。
class HistoryFilterPage extends ConsumerStatefulWidget {
  const HistoryFilterPage({super.key});

  @override
  ConsumerState<HistoryFilterPage> createState() => _HistoryFilterPageState();
}

class _HistoryFilterPageState extends ConsumerState<HistoryFilterPage> {
  late final TextEditingController _kw;
  late Set<String> _pooperIds;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    // 从**当前生效的条件**出发，而不是从空白出发 ——
    // 用户进来多半是想"再改一点"，不是"从头来过"。
    final f = ref.read(historyFilterProvider);
    _kw = TextEditingController(text: f.keyword);
    _pooperIds = {...f.pooperIds};
    _from = f.from;
    _to = f.to;
    _kw.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _kw.removeListener(_onTextChanged);
    _kw.dispose();
    super.dispose();
  }

  /// 攒着的条件（归一化过，保证 from <= to）。
  HistoryFilter get _draft => HistoryFilter(
        pooperIds: _pooperIds,
        keyword: _kw.text,
        from: _from,
        to: _to,
      ).normalized();

  void _reset() => setState(() {
        _kw.clear();
        _pooperIds = {};
        _from = null;
        _to = null;
      });

  void _apply() {
    ref.read(historyFilterProvider.notifier).apply(_draft);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final all = ref.watch(allPoopersProvider).value ?? const <Pooper>[];
    final draft = _draft;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: '搜索与筛选',
      actions: [
        TextButton(
          onPressed: draft.isEmpty ? null : _reset,
          child: Text(
            '重置',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: draft.isEmpty ? t.ink4 : t.ink2,
            ),
          ),
        ),
      ],
      bottomBar: PrimaryButton(
        label: '应 用',
        icon: LucideIcons.check,
        onTap: _apply,
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 24 + bottomInset),
        children: [
          // ---------------- 关键词 ----------------
          const SettingsSectionLabel('关键词'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _kw,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 15, color: t.ink),
              decoration: InputDecoration(
                hintText: '搜便便感受（如很顺畅）、备注或成员',
                hintStyle: TextStyle(fontSize: 13.5, color: t.ink3),
                prefixIcon: Icon(LucideIcons.search, size: 17, color: t.ink3),
                suffixIcon: _kw.text.isEmpty
                    ? null
                    : GestureDetector(
                        onTap: _kw.clear,
                        child: Icon(LucideIcons.x, size: 16, color: t.ink3),
                      ),
                filled: true,
                fillColor: t.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: _border(t.line),
                enabledBorder: _border(t.line),
                focusedBorder: _border(t.brandInk, width: 1.5),
              ),
            ),
          ),

          // ---------------- 时间范围 ----------------
          SettingsSectionLabel(
            '时间范围${_from != null || _to != null ? ' · 含首尾两天' : ''}',
          ),
          SettingsCard(
            children: [
              _DateRow(
                label: '从',
                value: _from,
                onPick: (d) => setState(() => _from = d),
                onClear: () => setState(() => _from = null),
              ),
              _DateRow(
                label: '到',
                value: _to,
                onPick: (d) => setState(() => _to = d),
                onClear: () => setState(() => _to = null),
              ),
            ],
          ),
          _QuickRanges(
            onPick: (from, to) => setState(() {
              _from = from;
              _to = to;
            }),
          ),

          // ---------------- 打卡成员 ----------------
          SettingsSectionLabel(
            '打卡成员${_pooperIds.isEmpty ? ' · 全部' : ' · 已选 ${_pooperIds.length}'}',
          ),
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '还没有添加成员',
                style: TextStyle(fontSize: 12.5, color: t.ink3),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in all)
                    _PooperChip(
                      pooper: p,
                      selected: _pooperIds.contains(p.id),
                      onTap: () => setState(() {
                        if (!_pooperIds.remove(p.id)) _pooperIds.add(p.id);
                      }),
                    ),
                ],
              ),
            ),
          if (_pooperIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '一个都不选 = 不限（看所有人）',
                style: TextStyle(fontSize: 11.5, color: t.ink3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static OutlineInputBorder _border(Color c, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: width),
      );
}

/// 快捷时间范围：今天 / 最近 7 天 / 本周 / 本月。
///
/// 大多数筛选都是这四个之一，点一下比开两次日期选择器快得多。
///
/// 用回调而不是伸手去改父组件的 state —— 那种写法看着省事，
/// 但父子耦合在一起，父组件改个字段名子组件就悄悄坏了。
class _QuickRanges extends StatelessWidget {
  const _QuickRanges({required this.onPick});

  final void Function(DateTime? from, DateTime? to) onPick;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final options = <(String, DateTime?, DateTime?)>[
      ('今天', today, today),
      ('最近 7 天', today.subtract(const Duration(days: 6)), today),
      ('本周', monday, today),
      ('本月', DateTime(today.year, today.month, 1), today),
      ('不限', null, null),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, from, to) in options)
            _QuickRangeChip(
              label: label,
              onTap: () => onPick(from, to),
            ),
        ],
      ),
    );
  }
}

class _QuickRangeChip extends StatefulWidget {
  const _QuickRangeChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickRangeChip> createState() => _QuickRangeChipState();
}

class _QuickRangeChipState extends State<_QuickRangeChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: t.paperDeep,
            borderRadius: BorderRadius.circular(PoopRadii.pill),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SettingsRow(
      leading: LucideIcons.calendarDays,
      title: label,
      subtitle: value == null
          ? '不限'
          : '${value!.year}年${value!.month}月${value!.day}日',
      trailing: value == null
          ? const SettingsChevron()
          : GestureDetector(
              onTap: onClear,
              child: Icon(LucideIcons.x, size: 16, color: t.ink3),
            ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(DateTime.now().year - 10),
          lastDate: DateTime.now(),
          helpText: label == '从' ? '从哪一天起' : '到哪一天止',
          cancelText: '取消',
          confirmText: '确定',
        );
        if (picked != null) onPick(picked);
      },
    );
  }
}

class _PooperChip extends StatefulWidget {
  const _PooperChip({
    required this.pooper,
    required this.selected,
    required this.onTap,
  });

  final Pooper pooper;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PooperChip> createState() => _PooperChipState();
}

class _PooperChipState extends State<_PooperChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: AnimatedContainer(
          duration: PoopMotions.colorDuration,
          curve: PoopMotions.colorCurve,
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            color: widget.selected ? t.brandSoft : t.surface,
            borderRadius: BorderRadius.circular(PoopRadii.pill),
            border: Border.all(
              color: widget.selected ? t.brandInk : t.lineSoft,
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PooperAvatar(
                pooper: widget.pooper,
                size: 24,
                radius: 8,
                iconSize: 13,
                dimmed: widget.pooper.archivedAt != null,
              ),
              const SizedBox(width: 7),
              Text(
                widget.pooper.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                  color: widget.selected ? t.brandInk : t.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
