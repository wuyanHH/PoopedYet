import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/record_actions.dart';
import '../dev/demo_seeder.dart';
import '../providers.dart';
import '../state/calendar_data.dart';
import '../theme/tokens.dart';
import 'calendar/calendar_card.dart';
import 'records/day_section.dart';
import 'records/record_detail_sheet.dart';
import 'widgets/first_run_hint.dart';

/// 日历主页（视觉稿 ①）。
///
/// 三块：应用栏 → 日历卡 → 日期栏 + 当天记录，右下角一个 FAB。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    // 启动流程：建默认屙屎人 + 收敛超时记录。
    // watch 一下就够了，结果不参与渲染；失败也不该白屏。
    ref.watch(bootstrapProvider);

    return Scaffold(
      backgroundColor: t.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AppBar(),
            const FirstRunHint(),
            const SizedBox(height: 4),
            const CalendarCard(),
            Expanded(
              child: DaySection(
                onTapRecord: (id) =>
                    showRecordDetailSheet(context, recordId: id),
              ),
            ),
          ],
        ),
      ),
      // FAB 记的永远是"现在"，和选中哪天无关 ——
      // 它是"现在开屙"，不是"给这天补一条"。补录走历史页。
      floatingActionButton: _Fab(onTap: () => _startPoop(context, ref)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// 一键开屙。
  ///
  /// **不弹层、不询问**，直接落库 —— 这是这个 App 的手感关键。
  /// 补充细节（改人、补结束时间、写备注）走编辑页。
  Future<void> _startPoop(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final result = await db.startPoop();

    if (!context.mounted) return;

    switch (result) {
      case StartPoopOk(:final record):
        _refresh(ref);

        final people = await db.activePoopers();
        final who = people.where((p) => p.id == record.pooperId).firstOrNull;
        if (!context.mounted) return;

        // 「一键」的代价是没有退路，所以必须给撤销。
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('${who?.name ?? '记录'} 已开始 · 正在屙'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: '撤销',
                onPressed: () async {
                  await db.deleteRecord(record.id);
                  _refresh(ref);
                },
              ),
            ),
          );

      case StartPoopAlreadyActive(:final existing):
        // 这里必须说人话。数据库那边是 UNIQUE 约束报错，但用户不该看到那个。
        final people = await db.activePoopers();
        final who = people.where((p) => p.id == existing.pooperId).firstOrNull;
        final mins = DateTime.now().difference(existing.startedAt).inMinutes;

        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${who?.name ?? '有人'} 从 ${_hhmm(existing.startedAt)} 开始还在屙'
                '（已 $mins 分钟），先结束它',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );

      case StartPoopNoPooper():
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('还没有屙屎人，先去设置里加一个'),
              behavior: SnackBarBehavior.floating,
            ),
          );
    }
  }

  /// 落库之后把受影响的缓存全打掉。
  ///
  /// 日历徽标按月缓存、记录列表按天缓存，加了记录两边都要刷新；
  /// 直接 invalidate 整个 family 最省心（几十条数据重建一次是毫秒级）。
  void _refresh(WidgetRef ref) {
    ref.invalidate(monthBadgesProvider);
    ref.invalidate(weekBadgesProvider);
    ref.invalidate(dayRecordsProvider);
    ref.invalidate(staleRecordsProvider);
    ref.invalidate(activePoopersProvider);
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _AppBar extends ConsumerWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Row(
        children: [
          GestureDetector(
            // 长按标题开开发菜单 —— 不占界面，普通用户也碰不到。
            onLongPress: kDebugMode ? () => _devMenu(context, ref) : null,
            child: Text(
              '屙了么',
              style: displayStyle(size: 21, letterSpacing: 1, color: t.ink),
            ),
          ),
          const Spacer(),
          _IconButton(icon: LucideIcons.search, onTap: () {}),
          _IconButton(icon: LucideIcons.settings, onTap: () {}),
        ],
      ),
    );
  }

  Future<void> _devMenu(BuildContext context, WidgetRef ref) async {
    final t = ref.read(_tokensProbe);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: t.paper,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PoopRadii.sheet),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '开发菜单（仅 debug 构建）',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '演示数据会清空现有记录与屙屎人，用来验证日历的三种角标与四种记录状态。',
                style: TextStyle(fontSize: 12, color: t.ink3, height: 1.5),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: t.brandFill),
                onPressed: () async {
                  Navigator.of(sheetCtx).pop();
                  final db = ref.read(databaseProvider);
                  await DemoSeeder(db).run();
                  _devRefresh(ref);
                },
                child: const Text('生成演示数据'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _devRefresh(WidgetRef ref) {
    ref.invalidate(monthBadgesProvider);
    ref.invalidate(weekBadgesProvider);
    ref.invalidate(dayRecordsProvider);
    ref.invalidate(activePoopersProvider);
    ref.invalidate(staleRecordsProvider);
  }
}

/// 拿令牌但不依赖 BuildContext（弹层里用）。
final _tokensProbe = Provider((ref) => PoopTokens.light);

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 17, color: t.ink2),
      ),
    );
  }
}

/// 「现在开屙」。
class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          // 渐变浅端必须够深：白字对 #B05F2C 是 4.65:1。
          // 原来的 #D98B4C 只有 2.71:1，连大字阈值都不到。
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB05F2C), Color(0xFF9A5219)],
          ),
          borderRadius: BorderRadius.circular(PoopRadii.pill),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59A85F29),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.plus, size: 17, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              '现在开屙',
              style: displayStyle(
                size: 15,
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
