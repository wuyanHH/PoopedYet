import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../data/queries.dart';
import '../../data/record_actions.dart';
import '../../data/record_edits.dart';
import '../../domain/record_state.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../theme/tokens.dart';
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

    return SheetShell(
      title: '${r.startedAt.year}年${r.startedAt.month}月${r.startedAt.day}日',
      subtitle: _stateHint(state),
      scrollable: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------------- 谁在屙 ----------------
            const SheetFieldLabel(text: '谁在屙'),
            PooperPickerRow(
              selectedId: r.pooperId,
              // 这条记录可能属于一个已归档的人，得把他放出来，
              // 否则"当前选中"的高亮没地方落。
              includeArchived: true,
              onPick: (p) => _changePooper(context, ref, p),
            ),
            const SizedBox(height: 18),

            // ---------------- 时间 ----------------
            SheetFieldLabel(
              text: '时间',
              trailing: dur == null ? null : '时长 ${formatDuration(dur)}',
            ),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: _TimeCard(
                    label: '开始',
                    value: hhmm(r.startedAt),
                    action: '改日期',
                    onTap: () => _editStart(context, ref),
                  ),
                ),
                Expanded(
                  child: _TimeCard(
                    label: '结束',
                    value: r.endedAt == null ? _endPlaceholder(state) : hhmm(r.endedAt!),
                    action: r.endedAt == null ? '补填' : '清除',
                    empty: r.endedAt == null,
                    onTap: r.endedAt == null
                        ? () => _editEnd(context, ref)
                        : () => _clearEnd(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 进行中的记录给两个明确的出口，而不是让用户猜要怎么"结束"。
            if (state == RecordState.active || state == RecordState.pending)
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: _MiniAction(
                      icon: LucideIcons.check,
                      label: '现在结束',
                      primary: true,
                      onTap: () => _endNow(context, ref),
                    ),
                  ),
                  Expanded(
                    child: _MiniAction(
                      icon: LucideIcons.clock,
                      label: '没记结束时间',
                      onTap: () => _markUnknown(context, ref),
                    ),
                  ),
                ],
              ),
            if (state == RecordState.endUnknown || state == RecordState.done)
              _MiniAction(
                icon: LucideIcons.play,
                label: '重新打开（变回正在屙）',
                onTap: () => _reopen(context, ref),
              ),
            const SizedBox(height: 18),

            // ---------------- 备注 ----------------
            SheetFieldLabel(
              text: '备注',
              trailing: '${detail.notes.length} 条',
            ),
            if (detail.notes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '还没有备注',
                  style: TextStyle(fontSize: 12.5, color: t.ink3),
                ),
              )
            else
              for (final n in detail.notes)
                _NoteRow(
                  note: n,
                  onEdit: () => _editNote(context, ref, n),
                  onDelete: () => _deleteNote(context, ref, n),
                ),
            const SizedBox(height: 10),
            NoteComposer(
              onSubmit: (text) async {
                await ref.read(databaseProvider).addNote(r.id, text);
                // 手打的备注沉淀成模板，下次一句话都不用打。
                await ref.read(databaseProvider).bumpNoteTemplate(text);
                _refresh(ref);
              },
            ),
            const SizedBox(height: 18),

            // ---------------- 底部动作 ----------------
            Row(
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
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: t.brandFill,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '完 成',
                        style: displayStyle(
                          size: 15,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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

  Future<void> _endNow(BuildContext context, WidgetRef ref) async {
    await ref.read(databaseProvider).endPoop(recordId);
    if (!context.mounted) return;
    _refresh(ref);
    _toast(context, '已结束');
  }

  Future<void> _markUnknown(BuildContext context, WidgetRef ref) async {
    await ref.read(databaseProvider).markEndUnknown(recordId);
    if (!context.mounted) return;
    _refresh(ref);
    _toast(context, '记为「未记结束」');
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref) async {
    final res = await ref.read(databaseProvider).reopenRecord(recordId);
    if (!context.mounted) return;
    _handle(context, res, ref);
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
}

/// 单行文字编辑弹窗（改备注用）。空字符串会被拒绝，取消返回 null。
Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String initial,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
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
}

/// 开始 / 结束那两个方卡。
class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.value,
    required this.action,
    required this.onTap,
    this.empty = false,
  });

  final String label;
  final String value;
  final String action;
  final VoidCallback onTap;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: empty ? t.line : t.lineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: t.ink3, letterSpacing: 0.6),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: empty ? t.ink3 : t.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              action,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: t.brandInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一行宽的次要动作按钮。
class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: primary ? t.brandSoft : t.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: primary ? t.brandInk : t.lineSoft),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: primary ? t.brandInk : t.ink2),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: primary ? t.brandInk : t.ink2,
                ),
              ),
            ),
          ],
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
          GestureDetector(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(LucideIcons.pencil, size: 14, color: t.ink4),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(LucideIcons.trash2, size: 14, color: t.ink4),
            ),
          ),
        ],
      ),
    );
  }
}
