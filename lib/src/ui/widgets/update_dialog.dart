import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/update/apk_downloader.dart';
import '../../data/update/changelog_parser.dart';
import '../../data/update/update_model.dart';
import '../../data/update/update_service.dart';
import '../../theme/tokens.dart';
import 'changelog_markdown.dart';
import 'update_install_action.dart';

/// 检查更新弹窗。
///
/// 自动检查触发时传 [skippable]（并在 [onSkip] 里落库），
/// 用户就能明确告诉应用「这个版本别再来烦我」。
///
/// ## 下载为什么是应用内的
/// 以前点「立即下载」是把 APK 地址丢给浏览器，用户要自己找回来、自己装。
/// 现在改成在应用内流式下载（见 `apk_downloader.dart`），
/// 进度实时可见、可随时收进后台、下完一键安装。
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({
    super.key,
    required this.releaseInfo,
    required this.deviceAbi,
    this.skippable = false,
    this.onSkip,
  });

  final UpdateReleaseInfo releaseInfo;
  final String deviceAbi;

  /// 是否展示「跳过此版本」。
  final bool skippable;

  /// 点「跳过此版本」时的回调（调用方负责落盘）。
  final VoidCallback? onSkip;

  static Future<void> show(
    BuildContext context, {
    required UpdateReleaseInfo releaseInfo,
    required String deviceAbi,
    bool skippable = false,
    VoidCallback? onSkip,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UpdateDialog(
        releaseInfo: releaseInfo,
        deviceAbi: deviceAbi,
        skippable: skippable,
        onSkip: onSkip,
      ),
    );
  }

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _showAllAssets = false;

  /// 正文只解析一次就够 —— Release 内容在弹窗生命周期里不会变。
  late final List<ChangelogBlock> _blocks;
  late final ChangelogSummary _summary;

  @override
  void initState() {
    super.initState();
    _blocks = parseChangelogBlocks(widget.releaseInfo.changelog);
    _summary = summarizeChangelog(_blocks);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = widget.releaseInfo;
    final dateStr = r.publishedAt != null
        ? DateFormat('yyyy年MM月dd日').format(r.publishedAt!)
        : '最新发布';

    final recommended = r.recommendedAsset;
    final otherAssets = r.assets.where((a) => a != recommended).toList();

    // 正文区高度跟着屏幕走：小屏手机不至于把按钮顶出屏幕，大屏也不会空一大块。
    // 注意 clamp 的返回类型是 num，必须显式转回 double 才能喂给 BoxConstraints。
    final maxLogHeight =
        (MediaQuery.of(context).size.height * 0.30).clamp(110.0, 260.0).toDouble();

    return AlertDialog(
      backgroundColor: t.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: t.lineSoft.withValues(alpha: 0.8)),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(t, r, dateStr),
            const SizedBox(height: 13),
            _summaryCard(t, r, recommended),
            const SizedBox(height: 11),

            // ---- 更新日志富文本区 ----
            Container(
              constraints: BoxConstraints(maxHeight: maxLogHeight),
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: t.paperDeep,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.lineSoft.withValues(alpha: 0.5)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ChangelogMarkdown(
                  blocks: _blocks,
                  onOpenLink: (url) => UpdateService.openUrl(url),
                ),
              ),
            ),
            if (_blocks.length > 7) ...[
              const SizedBox(height: 5),
              Center(
                child: Text(
                  '上下滑动查看完整更新内容',
                  style: TextStyle(fontSize: 10, color: t.ink4),
                ),
              ),
            ],

            // ---- 下载 / 安装状态区 + 主操作 ----
            //
            // 单独包一个 Consumer：下载中进度每 120ms 刷一次，若不隔离，
            // 上面那一整段富文本更新日志会跟着重新解析、重新排版，白白掉帧。
            Consumer(
              builder: (context, downloadRef, _) {
                final download = downloadRef.watch(updateDownloadProvider);
                final controller =
                    downloadRef.read(updateDownloadProvider.notifier);

                // 进度是不是**这个版本**的？用户可能正在下别的版本，
                // 那种情况下这个弹窗要老老实实显示自己的按钮，不能张冠李戴。
                final belongsHere =
                    download.release?.versionName == r.versionName;
                final downloading = belongsHere && download.isDownloading;
                final completed = belongsHere &&
                    download.isCompleted &&
                    (download.filePath ?? '').isNotEmpty;
                final failed = belongsHere && download.isFailed;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (downloading) ...[
                      const SizedBox(height: 12),
                      _progressPanel(t, download),
                    ] else if (completed) ...[
                      const SizedBox(height: 12),
                      _completedPanel(t, download),
                    ] else if (failed) ...[
                      const SizedBox(height: 12),
                      _failedPanel(t, download),
                    ],

                    // ---- 其他架构安装包 ----
                    if (otherAssets.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _otherAssetsSection(t, otherAssets, downloading),
                    ],

                    const SizedBox(height: 14),
                    _actions(
                      t,
                      r,
                      recommended,
                      downloading: downloading,
                      completed: completed,
                      failed: failed,
                      controller: controller,
                    ),
                  ],
                );
              },
            ),

            // 可选出口：跳过这个版本，别再自动提醒。
            // 手动检查时也提供 —— 用户看过一眼决定暂不升级，
            // 那就该有一个「别再拿它烦我」的明确选项。
            if (widget.skippable) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () {
                    widget.onSkip?.call();
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: t.ink4,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: Text(
                    '跳过此版本 v${r.versionName}，不再自动提醒',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------- 各个区块 ----------------

  Widget _header(PoopTokens t, UpdateReleaseInfo r, String dateStr) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: t.brandSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(LucideIcons.sparkles, size: 20, color: t.brandInk),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '发现新版本',
                style: displayStyle(size: 18, letterSpacing: 0.5, color: t.ink),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: t.brandFill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'v${r.versionName}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 11, color: t.ink3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 摘要卡：架构 / 体积 / 分类计数一次说清，用户不必读完整篇正文。
  Widget _summaryCard(
    PoopTokens t,
    UpdateReleaseInfo r,
    ReleaseAssetInfo? recommended,
  ) {
    final subtitle = recommended != null
        ? '${recommended.formattedSize} · ${r.assets.length} 个架构可选'
        : '本平台暂未提供安装包，可前往发布页查看';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: t.paperDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.lineSoft.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.cpu, size: 13, color: t.brandInk),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  recommended != null
                      ? '本机 ${widget.deviceAbi} · 已智能匹配最佳安装包'
                      : '本机 ${widget.deviceAbi}',
                  style: TextStyle(
                    fontSize: 11,
                    color: t.ink2,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 19),
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 10.5, color: t.ink3, height: 1.4),
            ),
          ),
          if (!_summary.isEmpty) ...[
            const SizedBox(height: 8),
            ChangelogAspectChips(summary: _summary),
          ],
        ],
      ),
    );
  }

  Widget _progressPanel(PoopTokens t, UpdateDownloadState download) {
    final controller = ref.read(updateDownloadProvider.notifier);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: t.brandSoft.withValues(alpha: t.isDark ? 0.55 : 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.cloudDownload, size: 14, color: t.brandInk),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '正在下载 ${download.asset?.archType ?? ''} 安装包',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
              ),
              Text(
                '${download.percent}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: t.brandInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(PoopRadii.pill),
            child: LinearProgressIndicator(
              value: download.totalBytes > 0 ? download.progress : null,
              minHeight: 5,
              backgroundColor: t.paper.withValues(alpha: t.isDark ? 0.4 : 0.7),
              valueColor: AlwaysStoppedAnimation<Color>(t.brandFill),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${download.formattedReceived} / ${download.formattedTotal}',
                style: TextStyle(fontSize: 10.5, color: t.ink3),
              ),
              const Spacer(),
              Text(
                '${download.formattedSpeed} · 剩余 ${download.formattedRemaining}',
                style: TextStyle(fontSize: 10.5, color: t.ink3),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => controller.cancel(),
              style: TextButton.styleFrom(
                foregroundColor: t.ink3,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text('取消下载', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completedPanel(PoopTokens t, UpdateDownloadState download) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: t.liveSoft.withValues(alpha: t.isDark ? 0.55 : 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleCheck, size: 15, color: t.live),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '安装包已下载完成（${download.formattedTotal}），点击下方按钮安装',
              style: TextStyle(fontSize: 11.5, color: t.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _failedPanel(PoopTokens t, UpdateDownloadState download) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: t.offSoft.withValues(alpha: t.isDark ? 0.5 : 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, size: 15, color: t.off),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              download.errorMessage ?? '下载失败，请稍后重试',
              style: TextStyle(fontSize: 11.5, color: t.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otherAssetsSection(
    PoopTokens t,
    List<ReleaseAssetInfo> otherAssets,
    bool busy,
  ) {
    final r = widget.releaseInfo;
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showAllAssets = !_showAllAssets),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showAllAssets
                      ? '收起其他架构安装包'
                      : '查看其他架构安装包 (${otherAssets.length})',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: t.brandInk,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showAllAssets
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  size: 13,
                  color: t.brandInk,
                ),
              ],
            ),
          ),
        ),
        if (_showAllAssets)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.paperDeep,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (final asset in otherAssets)
                  _assetRow(t, asset, r, busy),
              ],
            ),
          ),
      ],
    );
  }

  Widget _assetRow(
    PoopTokens t,
    ReleaseAssetInfo asset,
    UpdateReleaseInfo release,
    bool busy,
  ) {
    final download = ref.read(updateDownloadProvider);
    final isCurrent = download.asset?.name == asset.name &&
        (download.isDownloading || download.isCompleted);
    final inApp = UpdateDownloadController.supportsInAppInstall;

    return InkWell(
      onTap: busy
          ? null
          : () {
              if (inApp) {
                ref.read(updateDownloadProvider.notifier).start(
                      release: release,
                      asset: asset,
                    );
              } else {
                UpdateService.openUrl(asset.downloadUrl);
                Navigator.of(context).pop();
              }
            },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${asset.archType} (${asset.formattedSize})',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isCurrent ? t.brandInk : t.ink,
                ),
              ),
            ),
            Icon(
              inApp ? LucideIcons.download : LucideIcons.externalLink,
              size: 13,
              color: t.brandInk,
            ),
          ],
        ),
      ),
    );
  }

  /// 底部主操作区。
  Widget _actions(
    PoopTokens t,
    UpdateReleaseInfo r,
    ReleaseAssetInfo? recommended, {
    required bool downloading,
    required bool completed,
    required bool failed,
    required UpdateDownloadController controller,
  }) {
    final inApp = UpdateDownloadController.supportsInAppInstall;
    final canDownloadInApp = inApp && recommended != null;

    if (downloading) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: TextButton(
              onPressed: () => controller.cancel(),
              style: TextButton.styleFrom(
                foregroundColor: t.ink3,
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: FilledButton.icon(
              onPressed: () {
                // 关掉弹窗、把进度收进顶部迷你条：下载继续，用户可以回去干别的。
                controller.expandBanner();
                Navigator.of(context).pop();
              },
              icon: const Icon(LucideIcons.minimize2, size: 15),
              label: const Text('后台下载并隐藏'),
              style: FilledButton.styleFrom(
                backgroundColor: t.brandFill,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PoopRadii.pill),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (completed) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: TextButton(
              onPressed: () {
                if (recommended != null) {
                  controller.start(release: r, asset: recommended);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: t.ink3,
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text('重新下载'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: FilledButton.icon(
              onPressed: () => installDownloadedApk(context, ref),
              icon: const Icon(LucideIcons.packagePlus, size: 15),
              label: const Text('已下载，点击安装'),
              style: FilledButton.styleFrom(
                backgroundColor: t.brandFill,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PoopRadii.pill),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 未开始 / 已取消 / 失败：主按钮是下载（或重试），没法应用内下载时退回发布页。
    final String primaryLabel;
    if (canDownloadInApp) {
      if (failed) {
        primaryLabel = '重试下载';
      } else if (recommended != null) {
        // 体积已经在摘要卡里了，按钮上只留架构 —— 否则小屏按钮文字会挤爆。
        primaryLabel = '立即下载 · ${recommended.archType}';
      } else {
        primaryLabel = '立即下载';
      }
    } else {
      primaryLabel = '前往发布页';
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: t.ink3,
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            child: const Text('稍后再说'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: FilledButton(
            onPressed: () {
              // `recommended != null` 必须在这里再判一次：Dart 不会因为
              // canDownloadInApp 这个组合布尔量就把 recommended 提升为非空。
              if (canDownloadInApp && recommended != null) {
                controller.start(release: r, asset: recommended);
              } else {
                UpdateService.openUrl(r.htmlUrl);
                Navigator.of(context).pop();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: t.brandFill,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PoopRadii.pill),
              ),
            ),
            child: Text(
              primaryLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
