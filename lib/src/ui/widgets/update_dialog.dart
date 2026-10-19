import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/update/update_model.dart';
import '../../data/update/update_service.dart';
import '../../theme/tokens.dart';

/// 深浅色完美兼容的检查更新弹窗
///
/// 自动检查触发时传 [skippable]（并在 [onSkip] 里落库），
/// 用户就能明确告诉应用「这个版本别再来烦我」。
class UpdateDialog extends StatefulWidget {
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
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _showAllAssets = false;

  void _download(String url) {
    Navigator.of(context).pop();
    UpdateService.openUrl(url);
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

    return AlertDialog(
      backgroundColor: t.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: t.lineSoft.withValues(alpha: 0.8)),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部标题与图标
            Row(
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
                        style: displayStyle(
                          size: 18,
                          letterSpacing: 0.5,
                          color: t.ink,
                        ),
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
            ),
            const SizedBox(height: 14),

            // 架构推荐胶囊指示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: t.paperDeep,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.cpu, size: 13, color: t.brandInk),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '本机 CPU 架构: ${widget.deviceAbi} · 已智能匹配最佳性能安装包',
                      style: TextStyle(
                        fontSize: 11,
                        color: t.ink2,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 更新日志内容区
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.paperDeep,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.lineSoft.withValues(alpha: 0.5)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  r.changelog.trim().isEmpty ? '日常性能优化与体验改进' : r.changelog,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: t.ink,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 折叠展示其他架构安装包
            if (otherAssets.isNotEmpty) ...[
              GestureDetector(
                onTap: () => setState(() => _showAllAssets = !_showAllAssets),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showAllAssets ? '收起其他架构安装包' : '查看其他架构安装包 (${otherAssets.length})',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: t.brandInk,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showAllAssets ? LucideIcons.chevronUp : LucideIcons.chevronDown,
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
                        InkWell(
                          onTap: () => _download(asset.downloadUrl),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${asset.archType} (${asset.formattedSize})',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: t.ink,
                                    ),
                                  ),
                                ),
                                Icon(LucideIcons.download, size: 13, color: t.brandInk),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 14),

            // 操作按钮
            Row(
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
                      final url = recommended?.downloadUrl ?? r.htmlUrl;
                      _download(url);
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
                      recommended != null
                          ? '立即下载 (${recommended.archType})'
                          : '前往发布页',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
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
}
