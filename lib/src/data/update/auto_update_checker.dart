import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_version.dart';
import 'update_model.dart';
import 'update_prefs.dart';
import 'update_service.dart';

/// 一次检查更新的结论。
enum AutoUpdateStatus {
  /// 用户关掉了自动检查（手动点「检查新版本」不会走到这里）。
  disabled,

  /// 距上次检查还不到 [AutoUpdateChecker.interval]，本次按兵不动。
  throttled,

  /// 已是最新正式版。
  upToDate,

  /// 有新版本，但用户之前选过「跳过此版本」。
  skipped,

  /// 网络或接口失败。自动路径下完全无声。
  failed,

  /// 发现可用新版本。
  available,
}

/// 一次检查的结果。
class AutoUpdateResult {
  const AutoUpdateResult({
    required this.status,
    this.release,
    this.deviceAbi,
  });

  final AutoUpdateStatus status;

  /// [AutoUpdateStatus.available] 时的发布信息。
  final UpdateReleaseInfo? release;

  /// 本机 CPU 架构，用于在弹窗里标出推荐的安装包。
  final String? deviceAbi;

  bool get hasUpdate =>
      status == AutoUpdateStatus.available && release != null;
}

/// 检查更新的统一入口：自动路径与手动路径共用同一段逻辑。
abstract final class AutoUpdateChecker {
  /// 两次自动检查之间的最小间隔。
  static const Duration interval = Duration(hours: 24);

  /// 间隔的人话描述，设置页副标题直接引用它，避免文案与代码走偏。
  static const String intervalLabel = '24 小时内最多检查一次';

  /// 启动静默检查在首屏渲染后延后多久再发请求。
  static const Duration startupDelay = Duration(seconds: 3);

  /// 执行一次检查。
  ///
  /// [manual] 为 true 表示用户在设置页主动点了「检查新版本」：
  /// 此时无视节流、无视开关、也无视「跳过此版本」——
  /// 主动来问的人必须得到真实答案。
  static Future<AutoUpdateResult> run({
    required UpdatePrefs prefs,
    required UpdatePrefsNotifier store,
    String currentVersion = kAppVersion,
    bool manual = false,
  }) async {
    if (!manual) {
      if (!prefs.autoCheck) {
        return const AutoUpdateResult(status: AutoUpdateStatus.disabled);
      }
      final last = prefs.lastCheckAt;
      if (last != null && DateTime.now().difference(last) < interval) {
        return const AutoUpdateResult(status: AutoUpdateStatus.throttled);
      }
    }

    try {
      final info = await UpdateService().checkLatestRelease(
        currentVersion: currentVersion,
      );
      if (info == null) {
        // 请求失败（网络超时/断网）时不记录成功节流，以便用户网络恢复后在下次启动时能够重新检查
        return const AutoUpdateResult(status: AutoUpdateStatus.failed);
      }

      // 成功获得线上版本信息后，才正式落盘本次检查时间
      store.markChecked(DateTime.now());

      if (!info.isNewer) {
        return const AutoUpdateResult(status: AutoUpdateStatus.upToDate);
      }
      if (!manual && prefs.skippedVersion == info.versionName) {
        return const AutoUpdateResult(status: AutoUpdateStatus.skipped);
      }

      final abi = await UpdateService.getDeviceAbi();
      debugPrint(
        '[UPDATE-CHECK] manual=$manual latest=v${info.versionName} abi=$abi',
      );
      return AutoUpdateResult(
        status: AutoUpdateStatus.available,
        release: info,
        deviceAbi: abi,
      );
    } catch (e) {
      debugPrint('[UPDATE-CHECK] 检查失败: $e');
      return const AutoUpdateResult(status: AutoUpdateStatus.failed);
    }
  }
}

/// 启动时的静默检查。
///
/// **刻意不 watch [updatePrefsProvider]**：检查过程本身会写入
/// 「上次检查时间」，如果这里 watch 了，写状态就会反过来触发自己重建，
/// 变成一圈停不下来的自激循环。所以一次性 read 快照，之后各自安好。
///
/// 失败、被节流、已是最新 —— 这些都在 UI 上保持完全无声，
/// 只有 [AutoUpdateStatus.available] 才值得打扰用户。
final autoUpdateCheckProvider = FutureProvider<AutoUpdateResult>((ref) async {
  final prefs = ref.read(updatePrefsProvider);
  final store = ref.read(updatePrefsProvider.notifier);

  // 首屏与启动动画先跑完，别和桌面小组件同步抢带宽。
  await Future<void>.delayed(AutoUpdateChecker.startupDelay);

  return AutoUpdateChecker.run(prefs: prefs, store: store);
});
