import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../calendar/calendar_math.dart';
import '../data/update/auto_update_checker.dart';
import '../data/update/update_prefs.dart';
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
import 'widgets/update_dialog.dart';
import 'widgets/update_download_banner.dart';

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

    // 监听来自桌面小组件的 UI 动作分发（如 4x4 大号组件点击“补录”）
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

    // 启动静默检查更新：延迟几秒、24 小时内最多一次、失败完全无声。
    // 只有真发现新版本才弹窗，同一个版本只打扰一次。
    ref.listen<AsyncValue<AutoUpdateResult>>(autoUpdateCheckProvider, (_, next) {
      final result = next.value;
      if (result == null || !result.hasUpdate) return;

      final release = result.release!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;

        // 首屏已经被别的页面或弹层盖住了，就别硬插一个弹窗打断用户。
        // 这次放过，下次启动（或手动点「检查新版本」）还有机会。
        final route = ModalRoute.of(context);
        if (route != null && !route.isCurrent) return;

        final store = ref.read(updatePrefsProvider.notifier);
        if (ref.read(updatePrefsProvider).notifiedVersion ==
            release.versionName) {
          return;
        }
        store.markNotified(release.versionName);

        UpdateDialog.show(
          context,
          releaseInfo: release,
          deviceAbi: result.deviceAbi ?? 'arm64-v8a',
          skippable: true,
          onSkip: () => store.skipVersion(release.versionName),
        );
      });
    });

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final view = ref.watch(calendarViewProvider);
    final today = ref.watch(todayProvider);
    final isViewingToday = isSameDay(view.selectedDate, today);

    return Scaffold(
      backgroundColor: t.paper,
      body: SafeArea(
        bottom: false,
        child: isLandscape
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左侧日历专栏：纯净日历区，高度完全释放，杜绝被顶栏挤压
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
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
                  // 右侧内容专栏：上方为「屙了么」品牌标题与「历史」「设置」操作栏，下方为选中日期的记录列表
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _AppBar(isLandscape: true),
                        // 应用内更新的后台下载进度条（收起后只剩右上角一颗小圆环）
                        const UpdateDownloadBanner(),
                        Expanded(
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
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AppBar(isLandscape: false),
                  // 应用内更新的后台下载进度条（收起后只剩右上角一颗小圆环）
                  const UpdateDownloadBanner(),
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
                ],
              ),
      ),
      // 右下角悬浮按钮组：「今」（回到今天）仅在非今天时显示于开屙上方，点击回到今天，长按展示提示
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: isViewingToday
                ? const SizedBox.shrink(key: ValueKey('today_hidden'))
                : _TodayButton(
                    key: const ValueKey('today_visible'),
                    onTap: () {
                      final currentToday = ref.read(todayProvider);
                      final nav = ref.read(calendarViewProvider.notifier);
                      nav.selectDay(currentToday);
                      nav.goToMonth(DateTime(currentToday.year, currentToday.month));
                    },
                  ),
          ),
          const SizedBox(height: 10),
          _Fab(
            onTap: () => showCreateRecordSheet(context),
          ),
        ],
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
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      key: _tooltipKey,
      message: widget.tooltip ?? '',
      preferBelow: true,
      verticalOffset: 24,
      waitDuration: const Duration(milliseconds: 150),
      child: Semantics(
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
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _tooltipKey.currentState?.ensureTooltipVisible();
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
      ),
    );
  }
}

/// 「回到今天」微悬浮日历按钮：
/// - 位于「开屙」主按钮正上方，仅在查看非今天日期时呈现；
/// - 采用精致日历装订小卡片造型，中下方呈现温润有型的「今」字；
/// - 点击平滑回到今天，长按 100% 呼出「回到今天」提示气泡。
class _TodayButton extends StatefulWidget {
  const _TodayButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<_TodayButton> createState() => _TodayButtonState();
}

class _TodayButtonState extends State<_TodayButton> {
  bool _pressed = false;
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Tooltip(
      key: _tooltipKey,
      message: '回到今天',
      preferBelow: false,
      verticalOffset: 24,
      waitDuration: const Duration(milliseconds: 150),
      child: Semantics(
        button: true,
        label: '回到今天',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _tooltipKey.currentState?.ensureTooltipVisible();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.90 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 38,
              height: 38,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: t.line.withValues(alpha: 0.85),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : const Color(0x185E422A),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 日历顶部装订条微雕细节
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [t.brand, t.brandFill],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '今',
                        style: displayStyle(
                          size: 16,
                          letterSpacing: 0,
                          color: t.brandInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「开屙」主操作悬浮按钮（简略紧凑形态，内嵌拉屎专属矢量微雕，长按展示说明）。
class _Fab extends StatefulWidget {
  const _Fab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_Fab> createState() => _FabState();
}

class _FabState extends State<_Fab> {
  bool _pressed = false;
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Tooltip(
      key: _tooltipKey,
      message: '开屙 · 开始记录本次如厕',
      preferBelow: false,
      verticalOffset: 28,
      waitDuration: const Duration(milliseconds: 200),
      child: Semantics(
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
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _tooltipKey.currentState?.ensureTooltipVisible();
          },
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
      ),
    );
  }
}
