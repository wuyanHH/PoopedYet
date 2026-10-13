import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../data/record_actions.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../state/calendar_view.dart';
import '../../theme/tokens.dart';
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetFieldLabel(text: '哪一天'),
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
              text: '时间',
              trailing: _end == null
                  ? '结束非必填'
                  : '时长 ${_durLabel()}',
            ),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: TimeCard(
                    label: '开始',
                    value: _hhmm(_start),
                    action: '改时间',
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                Expanded(
                  child: TimeCard(
                    label: '结束',
                    value: _end == null ? '未填写' : _hhmm(_end!),
                    action: _end == null ? '点点补填' : '清除',
                    empty: _end == null,
                    onTap: _end == null
                        ? () => _pickTime(isStart: false)
                        : () => setState(() => _end = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            const SheetFieldLabel(text: '谁在屙'),
            PooperPickerRow(
              selectedId: _pooperId,
              onPick: (p) => setState(() => _pooperId = p.id),
            ),
            const SizedBox(height: 18),

            const SheetFieldLabel(text: '备注', trailing: '可留空'),
            NoteComposer(
              // 补录时的备注先攒着，点「存档」时和记录一起写 ——
              // 记录还不存在，没地方挂备注。
              onSubmit: (text) async {
                _pendingNotes.add(text);
                setState(() {});
              },
            ),
            if (_pendingNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
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
                        // 有 key 才测得准：SheetShell 的关闭按钮也用同一个图标。
                        key: ValueKey('pendingNoteDelete:$i'),
                        onTap: () => setState(() => _pendingNotes.removeAt(i)),
                        child: Icon(LucideIcons.x, size: 14, color: t.ink4),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 18),

            GestureDetector(
              onTap: _canSave ? _save : null,
              child: Opacity(
                opacity: _canSave ? 1 : 0.4,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: t.brandFill,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.check, size: 17, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        '存 档',
                        style: displayStyle(
                          size: 15,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 还没落库的备注。补录时记录还不存在，备注没地方挂，所以先攒着。
  final List<String> _pendingNotes = [];

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
    final d = _end!.difference(_start);
    final m = d.inMinutes;
    return m < 60 ? '$m 分钟' : '${d.inHours} 小时 ${m - d.inHours * 60} 分';
  }

  Future<void> _save() async {
    final id = _pooperId;
    if (id == null) return;

    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final rec = await db.addHistoricalRecord(
        pooperId: id,
        startedAt: _start,
        endedAt: _end,
        endUnknown: _end == null,
      );
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

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _wd(DateTime d) =>
      const ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1];
}
