import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../dev/demo_seeder.dart';
import '../providers.dart';
import '../state/calendar_data.dart';
import '../state/calendar_view.dart';
import '../theme/tokens.dart';
import '../widget/widget_deep_link_handler.dart';
import 'calendar/calendar_card.dart';
import 'history/history_page.dart';
import 'records/backfill_sheet.dart';
import 'records/create_record_sheet.dart';
import 'records/day_section.dart';
import 'records/record_detail_sheet.dart';
import 'settings/settings_page.dart';
import 'widgets/brand_widgets.dart';
import 'widgets/first_run_hint.dart';
import 'widgets/ongoing_poop_badge.dart';
import 'widgets/poop_button_icon.dart';
import 'widgets/smooth_page_route.dart';

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

    // 挂载桌面小组件 Deep Link 调度器（一键开屙/完成记录/定位日历）
    ref.watch(widgetDeepLinkHandlerProvider);

    // 监听来自桌面小组件的 UI 动作分发（如 4x4 大号组件点击“📝 补录”）
    ref.listen<WidgetUiAction?>(widgetActionTriggerProvider, (prev, next) {
      if (next == WidgetUiAction.backfill) {
        ref.read(widgetActionTriggerProvider.notifier).clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            showBackfillSheet(context);
          }
        });
      }
    });

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      backgroundColor: t.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppBar(isLandscape: isLandscape),
            if (!isLandscape) ...[
              const FirstRunHint(),
              const SizedBox(height: 4),
              const RepaintBoundary(child: CalendarCard()),
              Expanded(
                child: RepaintBoundary(
                  child: DaySection(
                    onTapRecord: (id) =>
                        showRecordDetailSheet(context, recordId: id),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 左侧日历栏：支持平滑滚动，避免任何低高度横屏设备发生溢出
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            FirstRunHint(),
                            SizedBox(height: 2),
                            RepaintBoundary(child: CalendarCard()),
                          ],
                        ),
                      ),
                    ),
                    // 中间细微垂直分隔线，增强分栏质感
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: t.lineSoft.withValues(alpha: 0.6),
                    ),
                    // 右侧记录列表栏：独立滚动展示选中日期的所有记录
                    Expanded(
                      flex: 5,
                      child: RepaintBoundary(
                        child: DaySection(
                          onTapRecord: (id) =>
                              showRecordDetailSheet(context, recordId: id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      // FAB 点击弹出新建开屙记录弹窗
      floatingActionButton: _Fab(
        onTap: () => showCreateRecordSheet(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _AppBar extends ConsumerWidget {
  const _AppBar({this.isLandscape = false});

  final bool isLandscape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    // 监听当日打卡记录，智能感知是否有正在进行的打卡。
    // 使用规范化零点的 todayProvider，避免使用 DateTime.now() 产生毫秒级全新 key 导致 Provider 重建与重复查询
    final today = ref.watch(todayProvider);
    final dayRecords =
        ref.watch(dayRecordsProvider(today)).value ?? const [];
    final hasActive =
        dayRecords.any((d) => d.record.endedAt == null && !d.record.endUnknown);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        isLandscape ? 4 : 8,
        14,
        isLandscape ? 4 : 6,
      ),
      child: Row(
        children: [
          // 品牌标题与状态展示
          GestureDetector(
            // 长按标题开开发菜单 —— 不占界面，普通用户也碰不到。
            onLongPress: kDebugMode
                ? () {
                    HapticFeedback.heavyImpact();
                    _devMenu(context, ref);
                  }
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 品牌统一门面 Logo Badge（遵循单一来源，引用纯矢量可爱便便图标）
                const BrandHeaderBadge(size: 36),
                const SizedBox(width: 9),
                Text(
                  '屙了么',
                  style: displayStyle(size: 21, letterSpacing: 0.8, color: t.ink),
                ),
                // 仅在有进行中记录时展示全新的动态状态胶囊（方案 1A：旋转卷纸秒表 + 虚线流淌）
                if (hasActive) ...[
                  const SizedBox(width: 8),
                  const OngoingPoopBadge(
                    compact: true,
                    iconSize: 15,
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          // 右侧微质感物理按压反馈按钮组
          _AppBarAction(
            icon: LucideIcons.history,
            tooltip: '历史记录',
            onTap: () => Navigator.of(context).push(
              smoothPageRoute(const HistoryPage()),
            ),
          ),
          const SizedBox(width: 7),
          _AppBarAction(
            icon: LucideIcons.settings,
            tooltip: '设置',
            onTap: () => Navigator.of(context).push(
              smoothPageRoute(const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _devMenu(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final t = sheetCtx.tokens;
        final bottomInset = MediaQuery.paddingOf(sheetCtx).bottom;
        return Container(
          decoration: BoxDecoration(
            color: t.paper,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PoopRadii.sheet),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            bottomInset > 0 ? bottomInset + 14 : 20,
          ),
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
        );
      },
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

class _AppBarAction extends StatefulWidget {
  const _AppBarAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_AppBarAction> createState() => _AppBarActionState();
}

class _AppBarActionState extends State<_AppBarAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: widget.tooltip,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: PoopMotions.pressDuration,
          curve: PoopMotions.pressCurve,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: t.lineSoft, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: t.isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : const Color(0x0A2D1B0D),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 17, color: t.ink2),
          ),
        ),
      ),
    );
  }
}

/// 「开屙」主操作悬浮按钮（简略紧凑形态，告别通用 '+' 号，内嵌拉屎专属矢量微雕）。
class _Fab extends StatefulWidget {
  const _Fab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_Fab> createState() => _FabState();
}

class _FabState extends State<_Fab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      label: '开屙',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.brand, t.brandFill],
              ),
              borderRadius: BorderRadius.circular(PoopRadii.pill),
              boxShadow: [
                BoxShadow(
                  color: t.brandFill.withValues(alpha: t.isDark ? 0.40 : 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PoopButtonIcon.start(
                  size: 20,
                  onDarkButton: true,
                ),
                const SizedBox(width: 6),
                Text(
                  '开屙',
                  style: displayStyle(
                    size: 14,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
