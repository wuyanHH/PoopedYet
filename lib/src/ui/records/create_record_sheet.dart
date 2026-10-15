import 'dart:ui';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../calendar/calendar_math.dart';
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
import 'pick_datetime.dart';

/// 弹出新建记录弹窗（已融合现在开屙与补记，底部按钮固定吸底）。
Future<void> showCreateRecordSheet(
  BuildContext context, {
  DateTime? initialDay,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CreateRecordSheet(
      initialDay: initialDay,
    ),
  );
}

/// 新建记录弹窗。
class CreateRecordSheet extends ConsumerStatefulWidget {
  const CreateRecordSheet({
    super.key,
    this.initialDay,
  });

  final DateTime? initialDay;

  @override
  ConsumerState<CreateRecordSheet> createState() => _CreateRecordSheetState();
}

class _CreateRecordSheetState extends ConsumerState<CreateRecordSheet> {
  late DateTime _day;
  late DateTime _start;
  DateTime? _end;
  String? _pooperId;
  bool _saving = false;

  /// 选中的便便感受/模板标签
  final Set<String> _selectedTags = {};
  bool _tagsExpanded = false;

  /// 补充自定义备注输入
  late final TextEditingController _noteCtrl = TextEditingController();

  /// 是否自动结束/收敛上一条未结束的记录
  bool _autoSettlePrevious = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final selected = widget.initialDay ??
        ref.read(calendarViewProvider).selectedDate;
    _day = DateTime(selected.year, selected.month, selected.day);

    if (isSameDay(_day, now)) {
      _start = now;
      _end = null;
    } else {
      // 外部指定补录过去某天，默认设定上午 08:30 起始
      _start = DateTime(_day.year, _day.month, _day.day, 8, 30);
      _end = _start.add(const Duration(minutes: 12));
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  /// 是否判定为“现在实时开屙”场景（今天且未指定结束时间）
  bool get _isLiveNow =>
      isSameDay(_day, DateTime.now()) && _end == null;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final poopers = ref.watch(activePoopersProvider).value ?? const <Pooper>[];
    final templates =
        ref.watch(noteTemplatesProvider).value ?? const <NoteTemplate>[];

    if (_pooperId == null && poopers.isNotEmpty) {
      _pooperId = poopers
          .firstWhere((p) => p.isDefault, orElse: () => poopers.first)
          .id;
    }

    final selectedPooper = poopers.where((p) => p.id == _pooperId).firstOrNull;

    // 检查当前选中的成员是否有尚未结束的记录
    final today = ref.watch(todayProvider);
    final dayRecords = ref.watch(dayRecordsProvider(today)).value ?? [];
    final activeRecordOfPooper = dayRecords.where((d) {
      final r = d.record;
      return r.pooperId == _pooperId && r.endedAt == null && !r.endUnknown;
    }).firstOrNull;

    final isToday = isSameDay(_day, DateTime.now());

    return SheetShell(
      title: '新建屙屎记录',
      subtitle: _isLiveNow
          ? '开启实时计时，打卡完成后右滑卡片即可一键结束'
          : '已指定时间，保存后直接归档',
      scrollable: true,
      // 底部大按钮固定吸底显示，不随内容滚动，兼容小白条
      bottomBar: _SubmitButton(
        saving: _saving,
        label: _isLiveNow ? '立即开始开屙' : '保存打卡记录',
        iconWidget: _isLiveNow
            ? const PoopButtonIcon.start(size: 20, onDarkButton: true)
            : const PoopButtonIcon.finish(size: 19, onDarkButton: true),
        onTap: _submit,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------------- 记录对象 ----------------
            Row(
              children: [
                const SheetFieldLabel(text: '记录对象'),
                const Spacer(),
                if (selectedPooper != null)
                  Text(
                    '当前：${selectedPooper.name}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.brandInk,
                    ),
                  ),
              ],
            ),
            PooperPickerRow(
              selectedId: _pooperId,
              onPick: (p) => setState(() => _pooperId = p.id),
            ),
            const SizedBox(height: 16),

            // 未结束记录友好处理提示栏
            if (activeRecordOfPooper != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.isDark
                      ? const Color(0xFF331F12)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: t.isDark
                        ? const Color(0xFF6E3E1C)
                        : const Color(0xFFFDBA74),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.triangleAlert,
                          size: 16,
                          color: t.isDark
                              ? const Color(0xFFFB923C)
                              : const Color(0xFFEA580C),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${selectedPooper?.name ?? '该成员'} 有一条从 ${_hhmm(activeRecordOfPooper.record.startedAt)} 开始的未结束记录',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: t.isDark
                                  ? const Color(0xFFFDBA74)
                                  : const Color(0xFF9A3412),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() =>
                          _autoSettlePrevious = !_autoSettlePrevious),
                      child: Row(
                        children: [
                          Icon(
                            _autoSettlePrevious
                                ? LucideIcons.circleCheck
                                : LucideIcons.circle,
                            size: 16,
                            color: t.isDark
                                ? const Color(0xFFFB923C)
                                : const Color(0xFFEA580C),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '本次新建时自动结束上一条记录（推荐）',
                              style: TextStyle(
                                fontSize: 12,
                                color: t.isDark
                                    ? const Color(0xFFFDBA74)
                                    : const Color(0xFF9A3412),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ---------------- 统一时间设置 ----------------
            const SheetFieldLabel(text: '记录日期与时间'),
            // 日期行卡片
            GestureDetector(
              onTap: _pickDay,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.lineSoft),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: t.brandSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.calendarDays,
                        size: 16,
                        color: t.brandInk,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_day.year}年${_day.month}月${_day.day}日',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: t.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isToday ? t.brandSoft : t.paperDeep,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isToday ? '今天 · 周${_wd(_day)}' : '周${_wd(_day)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isToday ? t.brandInk : t.ink3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: t.paperDeep,
                        borderRadius: BorderRadius.circular(PoopRadii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '更改',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: t.ink3,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 12,
                            color: t.ink4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 开始时间与结束时间左右卡片
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 10,
                  child: TimeCard(
                    label: '开始时间',
                    value: _hhmm(_start),
                    action: '修改',
                    icon: LucideIcons.clock,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                // 中间状态/时长与流向指示（固定宽度 76px，绝不挤压左右两端卡片，彻底消除宽度抖动）
                SizedBox(
                  width: 76,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: _end == null ? t.liveSoft : t.brandSoft,
                          borderRadius: BorderRadius.circular(PoopRadii.pill),
                          border: Border.all(
                            color: _end == null
                                ? t.live.withValues(alpha: 0.35)
                                : t.brand.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_end == null) ...[
                              Container(
                                width: 4.5,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: t.live,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3.5),
                            ],
                            Flexible(
                              child: Text(
                                _end == null ? '正在屙' : _durLabel(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _end == null ? t.live : t.brandInk,
                                ),
                              ),
                            ),
                          ],
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
                    label: '结束时间',
                    value: _end == null ? '未填写' : _hhmm(_end!),
                    action: '修改',
                    icon: LucideIcons.flag,
                    empty: _end == null,
                    onTap: () => _pickTime(isStart: false),
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
                  // 已选中的标签置顶排在最前，其余按原顺序排列，保证已选标签不被折叠掩盖
                  final sortedTemplates = [...templates]..sort((a, b) {
                      final aSelected = _selectedTags.contains(a.content);
                      final bSelected = _selectedTags.contains(b.content);
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
                          selected: _selectedTags.contains(item.content),
                          onTap: () {
                            setState(() {
                              if (_selectedTags.contains(item.content)) {
                                _selectedTags.remove(item.content);
                              } else {
                                _selectedTags.add(item.content);
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

            // ---------------- 自定义备注说明 ----------------
            const SheetFieldLabel(text: '自定义备注说明', trailing: '可选填'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.lineSoft),
              ),
              child: TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '写点想记录的（比如：今天吃了什么、顺畅度等）...',
                  hintStyle: TextStyle(fontSize: 13, color: t.ink4),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: TextStyle(fontSize: 13.5, color: t.ink),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: '选择记录日期',
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
      initial: isStart
          ? _start
          : (_end ?? _start.add(const Duration(minutes: 10))),
      baseStartTime: isStart ? null : _start,
    );
    if (at == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = at;
        _day = DateTime(at.year, at.month, at.day);
        if (_end != null && _end!.isBefore(at)) {
          _end = at.add(const Duration(minutes: 10));
        }
      } else {
        if (at.isBefore(_start)) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('结束时间不能早于开始（${_hhmm(_start)}）'),
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
    if (_end == null) return '进行中';
    final m = minutesBetween(_start, _end!);
    return m < 60 ? '$m 分钟' : '${m ~/ 60} 小时 ${m % 60} 分';
  }

  Future<void> _submit() async {
    final pooperId = _pooperId;
    if (pooperId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择记录对象')),
      );
      return;
    }

    if (!_isLiveNow && _end != null && _end!.isBefore(_start)) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('结束时间不能早于开始时间（${_hhmm(_start)}）'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.tokens.danger,
          ),
        );
      return;
    }

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);

    try {
      if (_isLiveNow) {
        // 当前实时开屙
        final res = await db.startPoop(
          pooperId: pooperId,
          at: _start,
          autoSettlePrevious: _autoSettlePrevious,
        );

        if (res is StartPoopOk) {
          for (final tag in _selectedTags) {
            await db.addNote(res.record.id, tag);
            await db.bumpNoteTemplate(tag);
          }
          final customNote = _noteCtrl.text.trim();
          if (customNote.isNotEmpty) {
            await db.addNote(res.record.id, customNote);
          }
        } else if (res is StartPoopAlreadyActive) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: const Text('该成员已有未结束的打卡记录，请勾选自动收敛或先结束上一条'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: context.tokens.danger,
              ),
            );
          return;
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: const Text('开始记录失败，请重试'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: context.tokens.danger,
              ),
            );
          return;
        }
      } else {
        // 补记或带结束时间记录：统一按分钟对齐入库
        final cleanStart = toMinutePrecision(_start);
        final cleanEnd = _end == null ? null : toMinutePrecision(_end!);
        final rec = await db.into(db.poopRecords).insertReturning(
          PoopRecordsCompanion.insert(
            pooperId: pooperId,
            startedAt: cleanStart,
            endedAt: drift.Value(cleanEnd),
            endUnknown: drift.Value(cleanEnd == null),
          ),
        );

        for (final tag in _selectedTags) {
          await db.addNote(rec.id, tag);
          await db.bumpNoteTemplate(tag);
        }
        final customNote = _noteCtrl.text.trim();
        if (customNote.isNotEmpty) {
          await db.addNote(rec.id, customNote);
        }
      }

      // 刷新所有相关缓存
      ref.invalidate(monthBadgesProvider);
      ref.invalidate(weekBadgesProvider);
      ref.invalidate(dayRecordsProvider);
      ref.invalidate(staleRecordsProvider);
      ref.invalidate(activePoopersProvider);
      ref.invalidate(noteTemplatesProvider);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isLiveNow ? '已开始记录 · 正在屙' : '打卡记录已保存',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.tokens.danger,
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _promptNewTopic(BuildContext context, WidgetRef ref) async {
    final t = context.tokens;
    final controller = TextEditingController();

    final String? text;
    try {
      text = await showDialog<String>(
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
    } finally {
      controller.dispose();
    }

    if (text == null || !mounted) return;
    await ref.read(databaseProvider).createNoteTemplate(text);
    ref.invalidate(noteTemplatesProvider);
    setState(() {
      _selectedTags.add(text!);
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
            border: Border.all(
              color: isSelected ? Colors.transparent : t.lineSoft,
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: t.brandFill.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : t.ink,
              letterSpacing: 0.2,
            ),
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

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.saving,
    required this.label,
    this.icon,
    this.iconWidget,
    required this.onTap,
  });

  final bool saving;
  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: saving ? null : onTap,
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
        child: saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconWidget != null)
                    iconWidget!
                  else if (icon != null)
                    Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
