import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../data/note_template_actions.dart';
import '../../data/record_actions.dart';
import '../../domain/record_state.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../state/calendar_view.dart';
import '../../theme/tokens.dart';
import '../widgets/poop_button_icon.dart';
import '../widgets/pooper_picker.dart';
import '../widgets/sheet_shell.dart';
import '../widgets/time_card.dart';
import 'note_composer.dart';
import 'pick_datetime.dart';

/// 补录一条历史记录（视觉稿 ⑧）。
///
/// 和「现在开屙」的区别：
///   - **不动默认屙屎人**，也不碰进行中的记录 —— 只是往过去插一条
///   - 日期可以选（默认是当前选中的那天，通常用户就是翻到那天才发现漏记的）
///   - 结束时间可以留空
/// [day] 为 null 时用当前选中日期。
Future<void> showBackfillSheet(BuildContext context, {DateTime? day}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => BackfillSheet(initialDay: day),
  );
}

class BackfillSheet extends ConsumerStatefulWidget {
  const BackfillSheet({super.key, this.initialDay});

  /// 要补到哪一天。长按日历格进来时会带上那一格。
  final DateTime? initialDay;

  @override
  ConsumerState<BackfillSheet> createState() => _BackfillSheetState();
}

class _BackfillSheetState extends ConsumerState<BackfillSheet> {
  late DateTime _day;
  late DateTime _start;
  DateTime? _end;
  String? _pooperId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 默认落在"用户当前正看着的那一天" —— 他多半是翻到那天发现漏记的。
    // 时间默认 08:00：补录的场景通常是"今天早上那次忘了记"，
    // 用当前时刻反而要改更多。
    final selected = widget.initialDay ??
        ref.read(calendarViewProvider).selectedDate;
    _day = DateTime(selected.year, selected.month, selected.day);
    _start = DateTime(selected.year, selected.month, selected.day, 8);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final poopers = ref.watch(activePoopersProvider).value ?? const <Pooper>[];
    final templates =
        ref.watch(noteTemplatesProvider).value ?? const <NoteTemplate>[];

    // 默认选默认屙屎人（如果用户还没选过）
    if (_pooperId == null && poopers.isNotEmpty) {
      _pooperId = poopers
          .firstWhere(
            (p) => p.isDefault,
            orElse: () => poopers.first,
          )
          .id;
    }

    return SheetShell(
      title: '补录一条',
      subtitle: '补录不会影响默认屙屎人，也不会碰正在进行的记录',
      scrollable: true,
      bottomBar: GestureDetector(
        onTap: _canSave ? _save : null,
        child: Opacity(
          opacity: _canSave ? 1 : 0.4,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [t.brand, t.brandFill],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: t.brandFill.withValues(alpha: t.isDark ? 0.35 : 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PoopButtonIcon.finish(size: 19, onDarkButton: true),
                const SizedBox(width: 8),
                Text(
                  '存 档',
                  style: displayStyle(
                    size: 15.5,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetFieldLabel(text: '记录日期'),
            GestureDetector(
              onTap: _pickDay,
              child: Container(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.lineSoft),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.calendarDays, size: 16, color: t.ink2),
                    const SizedBox(width: 10),
                    Text(
                      '${_day.year}年${_day.month}月${_day.day}日 · '
                      '周${_wd(_day)}',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    const Spacer(),
                    Icon(LucideIcons.chevronDown, size: 15, color: t.ink4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            SheetFieldLabel(
              text: '记录时间',
              trailing: _end == null ? '结束非必填' : '时长 ${_durLabel()}',
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 10,
                  child: TimeCard(
                    label: '开始时刻',
                    value: _hhmm(_start),
                    action: '改时间',
                    icon: LucideIcons.clock,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: _end == null ? t.paperDeep : t.brandSoft,
                          borderRadius: BorderRadius.circular(PoopRadii.pill),
                          border: Border.all(
                            color: _end == null
                                ? t.lineSoft
                                : t.brand.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          _end == null ? '进行中' : _durLabel(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: _end == null ? t.ink3 : t.brandInk,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        LucideIcons.arrowRight,
                        size: 14,
                        color: _end == null ? t.ink4 : t.brandInk,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: TimeCard(
                    label: '结束时刻',
                    value: _end == null ? '未填写' : _hhmm(_end!),
                    action: _end == null ? '补填' : '清除',
                    icon: LucideIcons.flag,
                    empty: _end == null,
                    onTap: _end == null
                        ? () => _pickTime(isStart: false)
                        : () => setState(() => _end = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '快捷时长',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: t.ink3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        for (final mins in [5, 10, 15, 20, 30]) ...[
                          _QuickDurationPill(
                            minutes: mins,
                            isSelected: _end != null &&
                                minutesBetween(_start, _end!) == mins,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                final s = toMinutePrecision(_start);
                                _start = s;
                                _end = s.add(Duration(minutes: mins));
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            const SheetFieldLabel(text: '记录对象'),
            PooperPickerRow(
              selectedId: _pooperId,
              onPick: (p) => setState(() => _pooperId = p.id),
            ),
            const SizedBox(height: 18),

            // ---------------- 便便感受 ----------------
            Row(
              children: [
                const SheetFieldLabel(
                  text: '便便感受',
                  trailing: '点选本次便便状态 · 可多选',
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _promptNewTopic(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.brandSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.plus, size: 12, color: t.brandInk),
                        const SizedBox(width: 3),
                        Text(
                          '自定义感受',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: t.brandInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (templates.isNotEmpty) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  // 已选中的主题置顶排在最前，其余按原顺序排列，保证已选主题不被折叠掩盖
                  final sortedTemplates = [...templates]..sort((a, b) {
                      final aSelected = _selectedTopics.contains(a.content);
                      final bSelected = _selectedTopics.contains(b.content);
                      if (aSelected && !bSelected) return -1;
                      if (!aSelected && bSelected) return 1;
                      return a.sortOrder.compareTo(b.sortOrder);
                    });

                  final hasOverflow = sortedTemplates.length > 7;

                  Widget wrapWidget = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in sortedTemplates)
                        _TopicChip(
                          label: item.content,
                          selected: _selectedTopics.contains(item.content),
                          onTap: () {
                            setState(() {
                              if (_selectedTopics.contains(item.content)) {
                                _selectedTopics.remove(item.content);
                              } else {
                                _selectedTopics.add(item.content);
                              }
                            });
                          },
                        ),
                    ],
                  );

                  if (!hasOverflow) {
                    return wrapWidget;
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            ConstrainedBox(
                              constraints: _tagsExpanded
                                  ? const BoxConstraints()
                                  : const BoxConstraints(maxHeight: 78),
                              child: ClipRect(
                                child: wrapWidget,
                              ),
                            ),
                            // 折叠状态下底部平滑渐隐遮罩（如被底色自然遮盖）
                            if (!_tagsExpanded)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 38,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          t.paper.withValues(alpha: 0.0),
                                          t.paper.withValues(alpha: 0.96),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _tagsExpanded = !_tagsExpanded);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _tagsExpanded ? t.paperDeep : t.brandSoft,
                              borderRadius: BorderRadius.circular(PoopRadii.pill),
                              border: Border.all(
                                color: _tagsExpanded
                                    ? t.lineSoft
                                    : t.brand.withValues(alpha: 0.22),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _tagsExpanded
                                      ? '收起感受'
                                      : '展开全部感受（共 ${sortedTemplates.length} 个）',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _tagsExpanded ? t.ink2 : t.brandInk,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _tagsExpanded
                                      ? LucideIcons.chevronUp
                                      : LucideIcons.chevronDown,
                                  size: 14,
                                  color: _tagsExpanded ? t.ink2 : t.brandInk,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 18),

            const SheetFieldLabel(text: '详细备注说明', trailing: '可选填'),
            // 已添加的备注列表排在上方，保证输入框始终位于最底部
            if (_pendingNotes.isNotEmpty) ...[
              for (final (i, n) in _pendingNotes.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(LucideIcons.stickyNote, size: 13, color: t.ink3),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          n,
                          style: TextStyle(fontSize: 12.5, color: t.ink2),
                        ),
                      ),
                      GestureDetector(
                        key: ValueKey('pendingNoteDelete:$i'),
                        onTap: () => setState(() => _pendingNotes.removeAt(i)),
                        child: Icon(LucideIcons.x, size: 14, color: t.ink4),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
            // 加备注输入框始终位于最底部
            NoteComposer(
              onSubmit: (text) async {
                _pendingNotes.add(text);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 还没落库的备注。补录时记录还不存在，备注没地方挂，所以先攒着。
  final List<String> _pendingNotes = [];

  /// 选中的排便主题
  final Set<String> _selectedTopics = {};
  bool _tagsExpanded = false;

  bool get _canSave => _pooperId != null && !_saving;

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
      helpText: '补到哪一天',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = picked;
      _start = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _start.hour,
        _start.minute,
      );
      if (_end != null) {
        _end = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _end!.hour,
          _end!.minute,
        );
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final at = await pickDateTime(
      context,
      initial: isStart ? _start : (_end ?? _start.add(const Duration(minutes: 10))),
    );
    if (at == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = at;
        // 开始时间挪到结束之后的话，把结束一并推后，别留一个"结束早于开始"
        if (_end != null && _end!.isBefore(at)) {
          _end = at.add(const Duration(minutes: 10));
        }
      } else {
        if (at.isBefore(_start)) {
          // 拒绝：结束不能早于开始。顺手把开始往前挪更符合直觉？
          // 不 —— 那会改掉用户刚设好的值。直接提示。
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  '结束时间不能早于开始（${_hhmm(_start)}）',
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: context.tokens.danger,
              ),
            );
          return;
        }
        _end = at;
      }
    });
  }

  String _durLabel() {
    if (_end == null) return '未填写';
    final m = minutesBetween(_start, _end!);
    return m < 60 ? '$m 分钟' : '${m ~/ 60} 小时 ${m % 60} 分';
  }

  Future<void> _save() async {
    final id = _pooperId;
    if (id == null) return;

    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final cleanStart = toMinutePrecision(_start);
      final cleanEnd = _end == null ? null : toMinutePrecision(_end!);
      final rec = await db.addHistoricalRecord(
        pooperId: id,
        startedAt: cleanStart,
        endedAt: cleanEnd,
        endUnknown: cleanEnd == null,
      );
      // 先写入排便主题（使主题作为核心属性记录）
      for (final topic in _selectedTopics) {
        await db.addNote(rec.id, topic);
        await db.bumpNoteTemplate(topic);
      }
      // 再写入具体的自定义文字备注
      for (final n in _pendingNotes) {
        await db.addNote(rec.id, n);
        await db.bumpNoteTemplate(n);
      }

      ref.invalidate(monthBadgesProvider);
      ref.invalidate(weekBadgesProvider);
      ref.invalidate(dayRecordsProvider);
      ref.invalidate(staleRecordsProvider);
      ref.invalidate(noteTemplatesProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('已补录到 ${_day.month}月${_day.day}日'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _promptNewTopic(BuildContext context, WidgetRef ref) async {
    final t = context.tokens;
    final controller = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: t.lineSoft),
        ),
        title: Text(
          '自定义便便感受',
          style: displayStyle(
            size: 17.5,
            letterSpacing: 0.5,
            color: t.ink,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          style: TextStyle(fontSize: 14.5, color: t.ink),
          decoration: InputDecoration(
            hintText: '比如：很顺畅、拉肚子、干硬',
            hintStyle: TextStyle(fontSize: 13, color: t.ink3),
            filled: true,
            fillColor: t.surface,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.lineSoft),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.lineSoft),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.brandInk, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: t.ink3,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.brandFill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              final val = controller.text.trim();
              Navigator.of(ctx).pop(val.isEmpty ? null : val);
            },
            child: const Text(
              '添加并选用',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (text == null || !mounted) return;
    await ref.read(databaseProvider).createNoteTemplate(text);
    ref.invalidate(noteTemplatesProvider);
    setState(() {
      _selectedTopics.add(text);
    });
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _wd(DateTime d) =>
      const ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1];
}

class _TopicChip extends StatefulWidget {
  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TopicChip> createState() => _TopicChipState();
}

class _TopicChipState extends State<_TopicChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isSelected = widget.selected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [t.brand, t.brandFill],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : t.paperDeep,
            borderRadius: BorderRadius.circular(PoopRadii.pill),
            border: isSelected
                ? null
                : Border.all(color: t.lineSoft, width: 1.0),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: t.brandFill.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(LucideIcons.check, size: 13, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : t.ink,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 补记/修改时间时的一键快捷时长胶囊（+5分、+10分、+15分等）。
class _QuickDurationPill extends StatefulWidget {
  const _QuickDurationPill({
    required this.minutes,
    required this.isSelected,
    required this.onTap,
  });

  final int minutes;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_QuickDurationPill> createState() => _QuickDurationPillState();
}

class _QuickDurationPillState extends State<_QuickDurationPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isSelected = widget.isSelected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: AnimatedContainer(
          duration: PoopMotions.colorDuration,
          curve: PoopMotions.colorCurve,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
          decoration: BoxDecoration(
            color: isSelected ? t.brandSoft : t.paperDeep,
            borderRadius: BorderRadius.circular(PoopRadii.pill),
            border: Border.all(
              color: isSelected
                  ? t.brandInk.withValues(alpha: 0.6)
                  : t.lineSoft,
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Text(
            '+${widget.minutes}分',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? t.brandInk : t.ink2,
            ),
          ),
        ),
      ),
    );
  }
}
