import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/update/apk_downloader.dart';
import '../../theme/tokens.dart';
import 'update_install_action.dart';

/// 应用内更新的「迷你下载条」。
///
/// 用户点「后台下载并隐藏」之后，更新弹窗关掉、下载继续跑，界面就靠这一条
/// 显示进度。它有两个形态：
/// - **展开**：一条卡片，显示百分比、速度、剩余时间，可取消、可安装；
/// - **收起**：缩成右上角一个小圆环（下载中显示进度，完成显示勾），点击再展开。
///
/// 之所以能收起来：用户要的是「下载归下载，别占我地方」。
/// 但彻底不给入口也不行 —— 得留一个随时能找回来的点。
class UpdateDownloadBanner extends ConsumerWidget {
  const UpdateDownloadBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(updateDownloadProvider);
    final controller = ref.read(updateDownloadProvider.notifier);

    final child = !state.isVisible
        ? const SizedBox.shrink()
        : state.compact
            ? Align(
                alignment: Alignment.centerRight,
                child: _CompactOrb(
                  tokens: t,
                  state: state,
                  onTap: controller.expandBanner,
                ),
              )
            : _ExpandedCard(
                tokens: t,
                state: state,
                controller: controller,
                ref: ref,
              );

    return AnimatedSize(
      duration: PoopMotions.switchDuration,
      curve: PoopMotions.switchCurve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: PoopMotions.colorDuration,
        switchInCurve: PoopMotions.colorCurve,
        child: KeyedSubtree(
          key: ValueKey('${state.isVisible}-${state.compact}-${state.phase}'),
          child: child,
        ),
      ),
    );
  }
}

/// 展开态卡片。
class _ExpandedCard extends StatelessWidget {
  const _ExpandedCard({
    required this.tokens,
    required this.state,
    required this.controller,
    required this.ref,
  });

  final PoopTokens tokens;
  final UpdateDownloadState state;
  final UpdateDownloadController controller;

  /// 安装动作要读 provider，所以这里必须带着 ref 传下来 ——
  /// 不能靠 `ProviderScope.containerOf` 硬转，那个返回的是 ProviderContainer。
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final version = state.release?.versionName ?? '';

    final (IconData icon, Color iconColor, String title) = switch (state.phase) {
      UpdateDownloadPhase.completed => (
          LucideIcons.circleCheck,
          t.live,
          'v$version 已下载完成',
        ),
      UpdateDownloadPhase.failed => (
          LucideIcons.triangleAlert,
          t.off,
          'v$version 下载失败',
        ),
      _ => (
          LucideIcons.cloudDownload,
          t.brandInk,
          '正在下载 v$version',
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.lineSoft.withValues(alpha: 0.9)),
          boxShadow: PoopShadows.s1,
        ),
        padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: iconColor),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                ),
                if (state.isDownloading)
                  Text(
                    '${state.percent}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: t.brandInk,
                    ),
                  ),
                const SizedBox(width: 2),
                _MiniIconButton(
                  icon: LucideIcons.chevronUp,
                  tooltip: '收起',
                  onTap: controller.collapseBanner,
                ),
              ],
            ),
            const SizedBox(height: 7),
            if (state.isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(PoopRadii.pill),
                child: LinearProgressIndicator(
                  value: state.totalBytes > 0 ? state.progress : null,
                  minHeight: 4,
                  backgroundColor: t.paperDeep,
                  valueColor: AlwaysStoppedAnimation<Color>(t.brandFill),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${state.formattedReceived} / ${state.formattedTotal}'
                      ' · ${state.formattedSpeed}'
                      ' · 剩余 ${state.formattedRemaining}',
                      style: TextStyle(fontSize: 10.5, color: t.ink3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _MiniTextButton(
                    label: '取消',
                    onTap: controller.cancel,
                  ),
                ],
              ),
            ] else if (state.isCompleted) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '安装包已就绪（${state.formattedTotal}），点击安装即可升级',
                      style: TextStyle(fontSize: 11, color: t.ink2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _MiniTextButton(
                    label: '忽略',
                    onTap: controller.reset,
                  ),
                  const SizedBox(width: 6),
                  _MiniFilledButton(
                    label: '立即安装',
                    onTap: () => installDownloadedApk(context, ref),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      state.errorMessage ?? '下载失败，请稍后重试',
                      style: TextStyle(fontSize: 11, color: t.ink2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _MiniTextButton(
                    label: '忽略',
                    onTap: controller.reset,
                  ),
                  const SizedBox(width: 6),
                  _MiniFilledButton(
                    label: '重试',
                    onTap: () => controller.retry(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 收起态：一颗带进度的小圆环。
class _CompactOrb extends StatelessWidget {
  const _CompactOrb({
    required this.tokens,
    required this.state,
    required this.onTap,
  });

  final PoopTokens tokens;
  final UpdateDownloadState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final done = state.isCompleted;
    final failed = state.isFailed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Tooltip(
        message: done ? '安装包已下载，点击查看' : '正在后台下载，点击查看',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.surface,
                border: Border.all(
                  color: done
                      ? t.live.withValues(alpha: 0.5)
                      : t.brandFill.withValues(alpha: 0.35),
                ),
                boxShadow: PoopShadows.s1,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (state.isDownloading)
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        value: state.totalBytes > 0 ? state.progress : null,
                        strokeWidth: 3,
                        backgroundColor: t.paperDeep,
                        valueColor: AlwaysStoppedAnimation<Color>(t.brandFill),
                      ),
                    ),
                  Icon(
                    done
                        ? LucideIcons.circleCheck
                        : failed
                            ? LucideIcons.triangleAlert
                            : LucideIcons.cloudDownload,
                    size: 18,
                    color: done
                        ? t.live
                        : failed
                            ? t.off
                            : t.brandInk,
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

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 15, color: t.ink3),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _MiniTextButton extends StatelessWidget {
  const _MiniTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PoopRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: t.ink3,
          ),
        ),
      ),
    );
  }
}

class _MiniFilledButton extends StatelessWidget {
  const _MiniFilledButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PoopRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: t.brandFill,
          borderRadius: BorderRadius.circular(PoopRadii.pill),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
