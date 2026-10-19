import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../data/note_template_actions.dart';
import '../../data/queries.dart';
import '../../data/record_actions.dart';
import '../../data/record_edits.dart';
import '../../domain/record_state.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../theme/tokens.dart';
import '../widgets/expand_toggle_button.dart';
import '../widgets/poop_button_icon.dart';
import '../widgets/pooper_picker.dart';
import '../widgets/sheet_shell.dart';
import 'note_composer.dart';
import 'pick_datetime.dart';

/// 记录详情 / 编辑弹层（视觉稿 ⑤）。
///
/// ## 一个和视觉稿不同的决定：改动**立即生效**，没有「保存」
///
/// 视觉稿底部是 `[删除] [保存]`。这里把「保存」换成了「完成」（只关弹层），
/// 因为：
///   1. 改屙屎人可能被 `ux_active_record` 唯一索引拒绝，**必须当场告诉用户**。
///      攒到最后一起保存的话，用户改了三处、点保存、只报一句"失败"，不知道是哪处。
///   2. 立即生效就没有"未保存改动"这个状态，也就不存在退出时丢改动的 bug。
///   3. 备注本来就是一条一条独立提交的（需求里每条备注自带时刻），
///      混一个迟到的"保存"进来反而名不副实。
///
/// 唯一的"攒着再提交"是底部那行备注输入框，它有自己的「添加」按钮。
Future<void> showRecordDetailSheet(
  BuildContext context, {
  required String recordId,
}) {
  // 打开时打一行日志（仅 debug）。理由和 CalendarView 的 [CAL] 一样：
  // Flutter 画在 canvas 上、uiautomator 读不到界面文字，
  // 这是设备端自动化验证"弹层到底开没开"的唯一观察窗口。
  if (kDebugMode) debugPrint('[SHEET] open record=$recordId');

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => RecordDetailSheet(recordId: recordId),
  );
}

class RecordDetailSheet extends ConsumerWidget {
  const RecordDetailSheet({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recordDetailProvider(recordId));
    final d = async.value;

    // ⚠ 这里刻意**不用** `async.when(loading: ...)`。
    //
    // 每次编辑都会 `invalidate` 这个 provider 让它重读；用 `when` 的话
    // 每次改一个字、点一下人，整个弹层都要闪一下转圈 —— 内容还会跳。
    // 正确做法是：**有旧值就一直显示旧值**，只在真正第一次加载时才转圈。
    if (d == null) {
      if (async.isLoading) {
        return const SheetShell(
          title: '记录详情',
          child: SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      // 记录可能已经被别处删了（比如撤销）。这时不该白屏，也不该报错。
      return const SheetShell(
        title: '这条记录已经不在了',
        child: SizedBox(height: 60),
      );
    }

    return _Body(detail: d);
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final RecordDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final r = detail.record;
    final now = DateTime.now();
    final state = recordStateOf(r, now: now);
    final dur = durationOf(r);

    // 快捷标签模板与已有备注的分类匹配
    final templates =
        ref.watch(noteTemplatesProvider).value ?? const <NoteTemplate>[];
    final templateSet = templates.map((tpl) => tpl.content).toSet();
    final existingTagNotes = {
      for (final n in detail.notes.where((n) => templateSet.contains(n.content)))
        n.content: n,
    };
    final customNotes =
        detail.notes.where((n) => !templateSet.contains(n.content)).toList();

    // 这条记录此刻是否还"挂着"（进行中 / 超过阈值待确认）。
    //
    // 注意**不能**用 `r.endedAt == null` 来判断：`endUnknown`（用户明确表示
    // 没记结束时间）同样没有 endedAt，但它不是进行中 —— 给一条三天前的
    // 「未记结束」记录补一个"现在结束"，只会把时长算得更离谱。
    final isOngoing =
        state == RecordState.active || state == RecordState.pending;

    return SheetShell(
      title: '${r.startedAt.year}年${r.startedAt.month}月${r.startedAt.day}日',
      subtitle: _stateHint(state),
      scrollable: true,
      maxHeightFactor: 0.92,
      bottomBar: Row(
        spacing: 10,
        children: [
          Expanded(
            child: SheetGhostButton(
              icon: LucideIcons.trash2,
              label: '删除',
              danger: true,
              onTap: () => _deleteRecord(context, ref),
            ),
          ),
          Expanded(
            flex: 2,
            child: _DetailDoneButton(
              // 还在进行中时，这颗按钮必须**真的把记录结束掉**。
              //
              // 它以前无论什么状态都只 `pop()` 关掉弹层 —— 用户打开一条
              // 正在屙的记录、点了底部那个醒目的「完 成」，记录却依然挂在
              // 进行中，看起来就是「点了没反应」。已结束的记录才保留
              // 「完成 = 关掉弹层」这个编辑收尾的语义。
              label: isOngoing ? '完成打卡' : '完 成',
              onTap: () => isOngoing
                  ? _endNow(context, ref)
                  : Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------------- 记录对象 ----------------
            const SheetFieldLabel(text: '记录对象'),
            PooperPickerRow(
              selectedId: r.pooperId,
              // 这条记录可能属于一个已归档的人，得把他放出来，
              // 否则"当前选中"的高亮没地方落。
              includeArchived: true,
              onPick: (p) => _changePooper(context, ref, p),
            ),
            const SizedBox(height: 14),

            // ---------------- 时间 ----------------
            const SheetFieldLabel(text: '时间'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _TimeCard(
                    label: '开始时间',
                    value: hhmm(r.startedAt),
                    action: '修改',
                    icon: LucideIcons.clock,
                    onTap: () => _editStart(context, ref),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: t.paperDeep,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.lineSoft),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.arrowRight,
                      size: 14,
                      color: t.brandInk,
                    ),
                  ),
                ),
                Expanded(
                  child: _TimeCard(
                    label: '结束时间',
                    value: r.endedAt == null
                        ? _endPlaceholder(state)
                        : hhmm(r.endedAt!),
                    action: '修改',
                    icon: LucideIcons.flag,
                    empty: r.endedAt == null,
                    onTap: () => _editEnd(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 时长与状态全宽展示栏：100% 容纳任何长文本，彻底消除截断
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
              decoration: BoxDecoration(
                color: dur == null
                    ? (state == RecordState.active ? t.liveSoft : t.paperDeep)
                    : t.brandSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: dur == null
                      ? (state == RecordState.active
                          ? t.live.withValues(alpha: 0.35)
                          : t.lineSoft)
                      : t.brand.withValues(alpha: 0.25),
                  width: 0.9,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (dur == null && state == RecordState.active) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: t.live,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '正在屙 · 已屙 ${formatDuration(Duration(minutes: minutesBetween(r.startedAt, now)))}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: t.live,
                      ),
                    ),
                  ] else if (dur != null) ...[
                    Icon(LucideIcons.timer, size: 14, color: t.brandInk),
                    const SizedBox(width: 6),
                    Text(
                      '如厕时长：${formatDuration(dur)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: t.brandInk,
                      ),
                    ),
                  ] else ...[
                    Icon(LucideIcons.info, size: 13, color: t.ink3),
                    const SizedBox(width: 6),
                    Text(
                      '未记结束时间 · 时长不详',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.ink3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ---------------- 便便感受 ----------------
            Row(
              children: [
                const SheetFieldLabel(
                  text: '便便感受',
                  trailing: '点选添加便便感受 · 点击取消',
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _promptNewTopicForDetail(context, ref, r.id),
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
              _DetailTopicGrid(
                templates: templates,
                existingTagNotes: existingTagNotes,
                onToggleTag: (item) async {
                  HapticFeedback.selectionClick();
                  final existing = existingTagNotes[item.content];
                  if (existing != null) {
                    // 已有该主题，再次点击卸下
                    await ref.read(databaseProvider).deleteNote(existing.id);
                  } else {
                    // 点击立即为记录打上该主题
                    await ref.read(databaseProvider).addNote(r.id, item.content);
                    await ref.read(databaseProvider).bumpNoteTemplate(item.content);
                  }
                  _refresh(ref);
                },
              ),
            ],
            const SizedBox(height: 14),

            // ---------------- 详细文字备注 ----------------
            SheetFieldLabel(
              text: '详细文字备注',
              trailing: customNotes.isEmpty ? '可选填' : '${customNotes.length} 条',
            ),
            // 已添加的备注列表排在上方
            if (customNotes.isNotEmpty) ...[
              for (final n in customNotes)
                _NoteRow(
                  note: n,
                  onEdit: () => _editNote(context, ref, n),
                  onDelete: () => _deleteNote(context, ref, n),
                ),
              const SizedBox(height: 10),
            ],
            // 加备注输入框始终位于最底部，并在提交后自动平滑滚动对齐到底部
            Builder(
              builder: (composerCtx) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NoteComposer(
                      onSubmit: (text) async {
                        await ref.read(databaseProvider).addNote(r.id, text);
                        _refresh(ref);
                        // 提交后下一帧自动平滑滚动到底部，保证最新添加的备注和输入框始终可见
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (composerCtx.mounted) {
                            Scrollable.ensureVisible(
                              composerCtx,
                              alignment: 1.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        });
                      },
                    ),
                    // 底部避让间距充足留白，保证滚动到底部时「添加备注」整个按钮完整舒展，绝不被吸底栏紧贴或遮挡
                    const SizedBox(height: 52),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _stateHint(RecordState s) => switch (s) {
        RecordState.active => '正在屙',
        RecordState.pending => '这条已经挂了很久，确认一下',
        RecordState.endUnknown => '没记结束时间，时长不详',
        RecordState.done => '已完成',
      };

  static String _endPlaceholder(RecordState s) =>
      s == RecordState.endUnknown ? '未记结束' : '未结束';

  // ==========================================================================
  //  各处的写入。每一个都走同一条路：写库 → invalidate → 报错就弹 SnackBar。
  // ==========================================================================

  /// 写完之后把所有受影响的缓存打掉。
  ///
  /// 这里必须同时刷**详情自己**和日历那边的缓存 ——
  /// 只刷一边的话，弹层里改完关掉，日历上的徽标还是旧的。
  void _refresh(WidgetRef ref) {
    ref.invalidate(recordDetailProvider(recordId));
    ref.invalidate(monthBadgesProvider);
    ref.invalidate(weekBadgesProvider);
    ref.invalidate(dayRecordsProvider);
    ref.invalidate(staleRecordsProvider);
    ref.invalidate(noteTemplatesProvider);
    ref.invalidate(allPoopersProvider);
  }

  String get recordId => detail.record.id;

  void _toast(BuildContext context, String msg, {bool error = false}) {
    final t = context.tokens;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? t.danger : null,
        ),
      );
  }

  /// 编辑结果统一处理：失败的话把原因说人话。
  bool _handle(BuildContext context, RecordEditResult res, WidgetRef ref) {
    switch (res) {
      case EditOk():
        _refresh(ref);
        return true;
      case EditEndBeforeStart():
        _toast(context, '结束时间不能早于开始时间', error: true);
        return false;
      case EditPooperAlreadyActive(:final existing):
        _toast(
          context,
          '已经有一条进行中的记录了（${hhmm(existing.startedAt)} 开始），先结束它',
          error: true,
        );
        return false;
    }
  }

  Future<void> _changePooper(
    BuildContext context,
    WidgetRef ref,
    Pooper p,
  ) async {
    if (p.id == detail.record.pooperId) return;
    final res = await ref.read(databaseProvider).changePooper(recordId, p.id);
    if (!context.mounted) return;
    if (_handle(context, res, ref)) _toast(context, '改到 ${p.name} 了');
  }

  Future<void> _editStart(BuildContext context, WidgetRef ref) async {
    final at = await pickDateTime(context, initial: detail.record.startedAt);
    if (at == null || !context.mounted) return;
    final res = await ref.read(databaseProvider).updateStartedAt(recordId, at);
    if (!context.mounted) return;
    _handle(context, res, ref);
  }

  Future<void> _editEnd(BuildContext context, WidgetRef ref) async {
    final at = await pickDateTime(
      context,
      initial: detail.record.endedAt ?? DateTime.now(),
      baseStartTime: detail.record.startedAt,
      onClear: detail.record.endedAt != null
          ? () => _clearEnd(context, ref)
          : null,
    );
    if (at == null || !context.mounted) return;
    final res = await ref.read(databaseProvider).updateEndedAt(recordId, at);
    if (!context.mounted) return;
    _handle(context, res, ref);
  }

  Future<void> _clearEnd(BuildContext context, WidgetRef ref) async {
    final res = await ref.read(databaseProvider).reopenRecord(recordId);
    if (!context.mounted) return;
    if (_handle(context, res, ref)) _toast(context, '已清除结束时间，变回正在屙');
  }

  Future<void> _promptNewTopicForDetail(
    BuildContext context,
    WidgetRef ref,
    String recordId,
  ) async {
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

    if (text == null || !context.mounted) return;
    await ref.read(databaseProvider).createNoteTemplate(text);
    await ref.read(databaseProvider).addNote(recordId, text);
    ref.invalidate(noteTemplatesProvider);
    _refresh(ref);
  }

  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    PoopNote n,
  ) async {
    final text = await _promptText(
      context,
      title: '改备注',
      initial: n.content,
    );
    if (text == null) return;
    final ok = await ref.read(databaseProvider).updateNote(n.id, text);
    if (!context.mounted) return;
    if (!ok) {
      _toast(context, '备注不能为空', error: true);
      return;
    }
    _refresh(ref);
  }

  Future<void> _deleteNote(
    BuildContext context,
    WidgetRef ref,
    PoopNote n,
  ) async {
    await ref.read(databaseProvider).deleteNote(n.id);
    if (!context.mounted) return;
    _refresh(ref);
  }

  Future<void> _deleteRecord(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('备注会一起删掉，不能撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await ref.read(databaseProvider).deleteRecord(recordId);
    _refresh(ref);
    if (context.mounted) Navigator.of(context).pop();
  }

  /// 把这条进行中的记录就地结束掉 —— 底部「完成打卡」按钮的真正动作。
  ///
  /// 结束时间取"现在"，与记录卡左滑完成的语义完全一致（同一个 `endPoop`）。
  /// 先弹提示再关弹层：关掉之后 `context` 就失效了，提示会丢。
  Future<void> _endNow(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final endedAt = DateTime.now();

    try {
      await ref.read(databaseProvider).endPoop(recordId, at: endedAt);
    } catch (e) {
      if (context.mounted) {
        _toast(context, '结束失败：$e', error: true);
      }
      return;
    }

    _refresh(ref);
    if (context.mounted) {
      _toast(context, '已记录 ${hhmm(endedAt)} 为结束时间');
    }
    if (navigator.mounted) navigator.pop();
  }
}

/// 单行文字编辑弹窗（改备注用）。空字符串会被拒绝，取消返回 null。
Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String initial,
}) async {
  final controller = TextEditingController(text: initial);
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          minLines: 2,
          maxLength: 200,
          decoration: const InputDecoration(hintText: '写点什么…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final t = controller.text.trim();
              Navigator.of(ctx).pop(t.isEmpty ? null : t);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// 精致手帐质感的「开始 / 结束」时间卡片。
class _TimeCard extends StatefulWidget {
  const _TimeCard({
    required this.label,
    required this.value,
    this.action = '修改',
    required this.onTap,
    this.empty = false,
    this.icon = LucideIcons.clock,
  });

  final String label;
  final String value;
  final String action;
  final VoidCallback onTap;
  final bool empty;
  final IconData icon;

  @override
  State<_TimeCard> createState() => _TimeCardState();
}

class _TimeCardState extends State<_TimeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDone = !widget.empty;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.empty ? t.line : t.lineSoft,
              width: widget.empty ? 1.2 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A2D1B0D),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部行：图标（颜色始终统一为品牌焦糖色，绝对对称） + 标签 + 右侧操作小胶囊
              Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 13,
                    color: t.brandInk,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.ink3,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  // 右侧动作胶囊（统一显示「修改」，整洁纯粹）
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: t.paperDeep,
                      borderRadius: BorderRadius.circular(PoopRadii.pill),
                    ),
                    child: Text(
                      widget.action,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: t.ink3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 主时间文字区域（采用固定 32px 高度锁定，彻底杜绝有无结束时间引起的卡片高度跳动！）
              SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: isDone
                      ? Text(
                          widget.value,
                          style: displayStyle(
                            size: 23,
                            letterSpacing: 0.5,
                            color: t.ink,
                          ),
                        )
                      : Text(
                          widget.value,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: t.ink3,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一条备注：时刻 + 内容 + 改/删。
class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final PoopNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              hhmm(note.notedAt),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: t.ink3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              note.content,
              style: TextStyle(fontSize: 13, height: 1.45, color: t.ink2),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: '修改这条备注',
            preferBelow: false,
            verticalOffset: 16,
            waitDuration: const Duration(milliseconds: 200),
            triggerMode: TooltipTriggerMode.longPress,
            child: GestureDetector(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(LucideIcons.pencil, size: 14, color: t.ink4),
              ),
            ),
          ),
          Tooltip(
            message: '删除这条备注',
            preferBelow: false,
            verticalOffset: 16,
            waitDuration: const Duration(milliseconds: 200),
            triggerMode: TooltipTriggerMode.longPress,
            child: GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(LucideIcons.trash2, size: 14, color: t.ink4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDoneButton extends StatefulWidget {
  const _DetailDoneButton({required this.onTap, this.label = '完 成'});

  final VoidCallback onTap;

  /// 按钮文案。进行中的记录是「完成打卡」（真的结束），否则是「完 成」（收尾关弹层）。
  final String label;

  @override
  State<_DetailDoneButton> createState() => _DetailDoneButtonState();
}

class _DetailDoneButtonState extends State<_DetailDoneButton> {
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
        scale: _pressed ? 0.96 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: t.brandGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: t.brandShadow,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PoopButtonIcon.finish(size: 19, onDarkButton: true),
              const SizedBox(width: 8),
              Text(
                widget.label,
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
    );
  }
}

/// 详情与修改弹窗中的排便主题胶囊（与新建页保持 100% 视觉语言一致）。
class _DetailTopicChip extends StatefulWidget {
  const _DetailTopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DetailTopicChip> createState() => _DetailTopicChipState();
}

class _DetailTopicChipState extends State<_DetailTopicChip> {
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
      onTap: widget.onTap,
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

/// 支持已选置顶、默认紧凑折叠（最多 8 项）与平滑展开收起的排便主题网格。
class _DetailTopicGrid extends StatefulWidget {
  const _DetailTopicGrid({
    required this.templates,
    required this.existingTagNotes,
    required this.onToggleTag,
  });

  final List<NoteTemplate> templates;
  final Map<String, PoopNote> existingTagNotes;
  final Future<void> Function(NoteTemplate item) onToggleTag;

  @override
  State<_DetailTopicGrid> createState() => _DetailTopicGridState();
}

class _DetailTopicGridState extends State<_DetailTopicGrid> {
  bool _expanded = false;
  static const int kDefaultVisibleCount = 8;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // 排序策略：已选中的标签置顶排在前面，其余按原顺序排列，保证已选标签不被折叠掩盖
    final sortedTemplates = [...widget.templates]..sort((a, b) {
        final aSelected = widget.existingTagNotes.containsKey(a.content);
        final bSelected = widget.existingTagNotes.containsKey(b.content);
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
          _DetailTopicChip(
            label: item.content,
            selected: widget.existingTagNotes.containsKey(item.content),
            onTap: () => widget.onToggleTag(item),
          ),
      ],
    );

    if (!hasOverflow) {
      return wrapWidget;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              ConstrainedBox(
                constraints: _expanded
                    ? const BoxConstraints()
                    : const BoxConstraints(maxHeight: 78),
                child: Padding(
                  padding: EdgeInsets.only(right: !_expanded ? 28 : 0),
                  child: ClipRect(
                    child: wrapWidget,
                  ),
                ),
              ),
              // 折叠状态下底部平滑渐隐遮罩并在右下角展示微悬浮圆形展开按钮
              if (!_expanded) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 36,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            t.paper.withValues(alpha: 0.0),
                            t.paper.withValues(alpha: 0.82),
                            t.paper,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: ExpandToggleButton(
                    isExpanded: false,
                    onToggle: () {
                      HapticFeedback.selectionClick();
                      setState(() => _expanded = true);
                    },
                    size: 22,
                    semanticLabel: '展开全部感受',
                  ),
                ),
              ],
            ],
          ),
        ),
        // 展开状态下在底部右侧呈现微悬浮圆形收起按钮
        if (_expanded) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: ExpandToggleButton(
              isExpanded: true,
              onToggle: () {
                HapticFeedback.selectionClick();
                setState(() => _expanded = false);
              },
              size: 22,
              semanticLabel: '收起感受',
            ),
          ),
        ],
      ],
    );
  }
}
