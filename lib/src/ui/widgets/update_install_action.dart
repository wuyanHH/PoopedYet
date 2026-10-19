import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/update/apk_downloader.dart';
import '../../theme/tokens.dart';

/// 拉起系统安装器，并把「安装不了」的四种原因分别翻译成人话。
///
/// 单独抽出来是因为更新弹窗和迷你下载条都要用同一套行为 ——
/// 复制两份的话，总有一天会出现「弹窗里会引导授权、进度条里只会报错」的分叉。
Future<void> installDownloadedApk(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(updateDownloadProvider.notifier);
  final outcome = await controller.install();
  if (!context.mounted) return;

  switch (outcome) {
    case ApkInstallOutcome.launched:
      // 系统安装界面已经盖上来，这里什么都不用做。
      break;

    case ApkInstallOutcome.needsPermission:
      final go = await _promptUnknownSources(context);
      if (go == true) {
        await controller.openInstallPermissionSettings();
      }

    case ApkInstallOutcome.notFound:
      _toast(context, '安装包已不存在，请重新下载');
      controller.reset();

    case ApkInstallOutcome.noInstaller:
      _toast(context, '系统里没有找到安装器，无法自动安装');

    case ApkInstallOutcome.failed:
      _toast(context, '无法拉起安装界面，请在文件管理器里手动打开安装包');
  }
}

/// 「安装未知应用」授权引导。
///
/// Android 8.0 起这是一道用户必须亲自点头的门，应用只能把设置页推到他面前。
/// 文案里点明是哪个开关，免得用户在设置里翻半天。
Future<bool?> _promptUnknownSources(BuildContext context) {
  final t = context.tokens;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: t.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: t.lineSoft.withValues(alpha: 0.8)),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: t.brandSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.shieldCheck, size: 18, color: t.brandInk),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    '还差一步授权',
                    style: displayStyle(size: 16, letterSpacing: 0.4, color: t.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '系统要求先允许「屙了么」安装应用。点击下方按钮进入设置，'
              '打开「允许来自此来源的应用」后返回即可继续安装。',
              style: TextStyle(fontSize: 12.5, color: t.ink2, height: 1.6),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: TextButton.styleFrom(foregroundColor: t.ink3),
                    child: const Text('稍后'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: t.brandFill,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PoopRadii.pill),
                      ),
                    ),
                    child: const Text('去授权'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void _toast(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
    );
}
