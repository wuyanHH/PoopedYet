import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'update_model.dart';

/// 原生通道。与 [UpdateService] 共用同一条 `com.poopedyet.app/widget` 通道 ——
/// 那里已经在处理小组件与深链，没必要为装个包再开一条。
const MethodChannel _channel = MethodChannel('com.poopedyet.app/widget');

/// 应用内下载任务所处的阶段。
enum UpdateDownloadPhase {
  /// 什么都没下。
  idle,

  /// 正在下载（可能是断点续传）。
  downloading,

  /// 已下载完成，等待安装。
  completed,

  /// 失败。[UpdateDownloadState.errorMessage] 里有原因。
  failed,

  /// 用户主动取消。已下载的部分**保留**，下次可以从断点继续。
  canceled,
}

/// 拉起系统安装器的结果。
enum ApkInstallOutcome {
  /// 系统安装界面已拉起。
  launched,

  /// Android 8.0+ 未授予「安装未知应用」，需要引导用户去设置页。
  needsPermission,

  /// 文件不见了（被清理器删掉、或下载没落盘）。
  notFound,

  /// 系统里没有任何 APK 安装器（极罕见，一般是定制 ROM 被裁过）。
  noInstaller,

  /// 其它失败。
  failed,
}

/// 下载任务的完整状态。整个 App 只有一份，挂在 [updateDownloadProvider] 上 ——
/// 弹窗、迷你进度条、设置页读的都是它，所以关闭弹窗并不会打断下载。
@immutable
class UpdateDownloadState {
  const UpdateDownloadState({
    this.phase = UpdateDownloadPhase.idle,
    this.release,
    this.asset,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec = 0,
    this.filePath,
    this.errorMessage,
    this.compact = false,
  });

  final UpdateDownloadPhase phase;

  /// 本次下载对应的发布信息（弹窗据此判断「进度是不是这个版本的」）。
  final UpdateReleaseInfo? release;

  /// 正在下载的具体安装包。
  final ReleaseAssetInfo? asset;

  final int receivedBytes;
  final int totalBytes;

  /// 平滑后的瞬时速度（字节/秒）。
  final double speedBytesPerSec;

  /// 下载完成后的 APK 绝对路径。
  final String? filePath;

  final String? errorMessage;

  /// 迷你进度条是否处于**收起**态（收成一个小圆环，不占横向空间）。
  final bool compact;

  bool get isDownloading => phase == UpdateDownloadPhase.downloading;
  bool get isCompleted => phase == UpdateDownloadPhase.completed;
  bool get isFailed => phase == UpdateDownloadPhase.failed;

  /// 是否值得在界面上露头（下载中、已下载、失败三种都要能看到）。
  bool get isVisible =>
      phase == UpdateDownloadPhase.downloading ||
      phase == UpdateDownloadPhase.completed ||
      phase == UpdateDownloadPhase.failed;

  /// 0.0 ~ 1.0。总大小未知时返回 0（渲染层会退化成不确定进度条）。
  double get progress {
    if (totalBytes <= 0) return 0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  int get percent => (progress * 100).round();

  /// 预计剩余时间；速度未知时为 null。
  Duration? get remaining {
    if (!isDownloading || speedBytesPerSec <= 0 || totalBytes <= 0) return null;
    final left = totalBytes - receivedBytes;
    if (left <= 0) return Duration.zero;
    return Duration(seconds: (left / speedBytesPerSec).round());
  }

  String get formattedReceived =>
      receivedBytes <= 0 ? '0 B' : formatBytes(receivedBytes);

  /// 总大小在拿到响应头之前是未知的，这时显示「大小未知」而不是「0 B」。
  String get formattedTotal =>
      totalBytes <= 0 ? '大小未知' : formatBytes(totalBytes);

  String get formattedSpeed => speedBytesPerSec <= 0
      ? '--'
      : '${formatBytes(speedBytesPerSec.round())}/s';

  String get formattedRemaining {
    final left = remaining;
    if (left == null) return '--';
    if (left.inSeconds < 60) return '${left.inSeconds} 秒';
    return '${left.inMinutes} 分 ${left.inSeconds % 60} 秒';
  }

  UpdateDownloadState copyWith({
    UpdateDownloadPhase? phase,
    UpdateReleaseInfo? release,
    ReleaseAssetInfo? asset,
    int? receivedBytes,
    int? totalBytes,
    double? speedBytesPerSec,
    String? filePath,
    String? errorMessage,
    bool? compact,
    bool clearError = false,
  }) {
    return UpdateDownloadState(
      phase: phase ?? this.phase,
      release: release ?? this.release,
      asset: asset ?? this.asset,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      filePath: filePath ?? this.filePath,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      compact: compact ?? this.compact,
    );
  }
}

/// 应用内 APK 下载器。
///
/// ## 为什么不用系统 DownloadManager
/// 用户要的是「静默后台下载」：关掉弹窗继续下、通知栏不出现任何东西。
/// DownloadManager 的通知可见性在各家 ROM / Android 13+ 上并不完全受应用控制，
/// 而这里用自己的流式下载，**通知栏天然干净**，进度也无需轮询原生即可实时拿到。
///
/// ## 后台边界
/// 下载跑在 Dart isolate 里。App 退到后台只要进程不被系统回收，下载就继续
/// （这正是用户点「隐藏」后期待的行为）。进程被杀的极端情况下，已下载的
/// `*.part` 会留在磁盘上，下次会带 `Range` 头续传，不必从头再来。
class UpdateDownloadController extends Notifier<UpdateDownloadState> {
  HttpClient? _client;
  double _speed = 0;
  int _lastEmitMs = 0;

  /// 任务序号。它的存在是为了解决一个具体竞态：用户连点两个不同架构的包时，
  /// 旧任务的收尾（无论是取消还是失败）**不能**把新任务的状态覆盖掉。
  /// 每次开始/取消都会 ++，旧协程的所有写入都会被 [_emitFor] 丢弃。
  int _taskSeq = 0;

  @override
  UpdateDownloadState build() => const UpdateDownloadState();

  /// 当前平台是否支持「下载完由本应用直接拉起安装器」。
  ///
  /// 只有 Android 有这套机制；桌面端（Windows）继续走浏览器下载的老路。
  static bool get supportsInAppInstall =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 开始（或重新开始）下载一个安装包。
  ///
  /// 已有任务在跑时会被顶掉 —— 用户在「其他架构安装包」里连点两个包是常见操作，
  /// 让他自己去取消第一个不合理。
  Future<void> start({
    required UpdateReleaseInfo release,
    required ReleaseAssetInfo asset,
  }) async {
    if (state.isDownloading) {
      await cancel();
    }
    final taskId = ++_taskSeq;
    _speed = 0;
    _lastEmitMs = 0;

    _emitFor(
      taskId,
      UpdateDownloadState(
        phase: UpdateDownloadPhase.downloading,
        release: release,
        asset: asset,
        totalBytes: asset.sizeBytes,
        compact: state.compact,
      ),
    );

    unawaited(_run(taskId: taskId, asset: asset));
  }

  /// 取消下载。已落盘的字节保留，下次自动续传。
  Future<void> cancel() async {
    if (!state.isDownloading) return;
    final taskId = ++_taskSeq; // 先作废旧任务，再收尾，避免它回写状态
    try {
      _client?.close(force: true);
    } catch (_) {}
    _client = null;
    _emitFor(
      taskId,
      state.copyWith(
        phase: UpdateDownloadPhase.canceled,
        speedBytesPerSec: 0,
        errorMessage: '已取消下载，下次可继续',
      ),
    );
  }

  /// 把迷你进度条收成一个小圆环（页面该干嘛干嘛，下载继续）。
  void collapseBanner() => _emitFor(_taskSeq, state.copyWith(compact: true));

  /// 展开迷你进度条。
  void expandBanner() => _emitFor(_taskSeq, state.copyWith(compact: false));

  /// 彻底忘掉当前任务。磁盘上的半截文件留着，下次下载同一版本仍可续传。
  void reset() {
    if (state.isDownloading) return;
    _emitFor(++_taskSeq, const UpdateDownloadState());
  }

  /// 失败后重试：沿用同一份发布信息与安装包。
  Future<void> retry() async {
    final release = state.release;
    final asset = state.asset;
    if (release == null || asset == null) return;
    await start(release: release, asset: asset);
  }

  /// 拉起系统安装器。
  Future<ApkInstallOutcome> install() async {
    final path = state.filePath;
    if (path == null || path.isEmpty) return ApkInstallOutcome.notFound;

    try {
      final raw = await _channel.invokeMethod<dynamic>(
        'installApk',
        <String, dynamic>{'filePath': path},
      );
      if (raw is Map) {
        if (raw['ok'] == true) return ApkInstallOutcome.launched;
        return switch (raw['code']) {
          'NEED_PERMISSION' => ApkInstallOutcome.needsPermission,
          'NOT_FOUND' => ApkInstallOutcome.notFound,
          'NO_INSTALLER' => ApkInstallOutcome.noInstaller,
          _ => ApkInstallOutcome.failed,
        };
      }
      return ApkInstallOutcome.failed;
    } on MissingPluginException {
      // 旧版本安卓壳、或桌面端：直接当失败，调用方会退回浏览器下载。
      return ApkInstallOutcome.failed;
    } on PlatformException {
      return ApkInstallOutcome.failed;
    }
  }

  /// 跳转到「安装未知应用」授权页，返回是否成功把设置页拉起来。
  Future<bool> openInstallPermissionSettings() async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'openInstallPermissionSettings',
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 磁盘上是否已经躺着上次下到一半的同一个包（用于把文案区分成「下载」与「继续」）。
  Future<int> pendingBytesFor(ReleaseAssetInfo asset) async {
    try {
      final part = await _partFileFor(asset);
      if (await part.exists()) return await part.length();
    } catch (_) {}
    return 0;
  }

  // ---------------- 内部实现 ----------------

  Future<void> _run({
    required int taskId,
    required ReleaseAssetInfo asset,
  }) async {
    // received 声明在 try 外：失败时也要把「已经下了多少」带进状态，
    // 这样进度条不会在报错的瞬间跳回 0。
    var received = 0;
    try {
      final part = await _partFileFor(asset);
      final target = File(
        part.path.substring(0, part.path.length - '.part'.length),
      );

      // 是否从半截文件续传。服务端不支持 Range 时会退回 false。
      var append = false;

      if (!await part.parent.exists()) {
        await part.parent.create(recursive: true);
      }
      // 一次只留一个安装包：旧版本的包留在手机里只是白占十几 MB。
      // 保留当前任务的 .part（要续传）与目标文件（下面还要判断完整性）。
      await _pruneOldArtifacts(part.parent, keep: {part.path, target.path});

      // 目标文件已经完整存在（用户重复点同一个包）：直接算完成，不浪费流量。
      if (await target.exists() && asset.sizeBytes > 0) {
        final existing = await target.length();
        if (existing == asset.sizeBytes) {
          _emitFor(
            taskId,
            state.copyWith(
              phase: UpdateDownloadPhase.completed,
              receivedBytes: existing,
              totalBytes: existing,
              filePath: target.path,
              speedBytesPerSec: 0,
              clearError: true,
            ),
          );
          return;
        }
        await target.delete();
      }

      if (await part.exists()) {
        received = await part.length();
        // 半截文件比目标还大 = 上次下的是另一个包，别拿它续传。
        if (asset.sizeBytes > 0 && received >= asset.sizeBytes) {
          await part.delete();
          received = 0;
        }
        append = received > 0;
      }

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..idleTimeout = const Duration(seconds: 30);
      _client = client;

      final request = await client.getUrl(Uri.parse(asset.downloadUrl));
      request.headers.set('User-Agent', 'PoopedYet-App');
      // 让服务端别做内容压缩：Range 续传和压缩叠在一起会让字节数对不上。
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (append) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$received-');
      }

      final response = await request.close();

      // 服务端不支持 Range 时会老老实实回 200 + 全量内容，这时必须从头写。
      if (append && response.statusCode == HttpStatus.ok) {
        append = false;
        received = 0;
      }
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final total = contentLength > 0
          ? (append ? received + contentLength : contentLength)
          : asset.sizeBytes;
      _emitFor(taskId, state.copyWith(totalBytes: total, clearError: true));

      final sink = part.openWrite(
        mode: append ? FileMode.append : FileMode.write,
      );
      var lastBytes = received;
      var lastAt = DateTime.now();

      try {
        await for (final chunk in response) {
          if (taskId != _taskSeq) break; // 已被取消或被新任务顶掉
          sink.add(chunk);
          received += chunk.length;

          final now = DateTime.now();
          final elapsed = now.difference(lastAt).inMicroseconds;
          if (elapsed > 0) {
            final instant = (received - lastBytes) * 1000000 / elapsed;
            _speed = _speed <= 0 ? instant : _speed * 0.7 + instant * 0.3;
            lastBytes = received;
            lastAt = now;
          }
          // 每 ~120ms 刷一次 UI：再密就是白白重建，再疏进度条会一顿一顿。
          final nowMs = now.millisecondsSinceEpoch;
          if (nowMs - _lastEmitMs >= 120) {
            _lastEmitMs = nowMs;
            _emitFor(
              taskId,
              state.copyWith(
                receivedBytes: received,
                totalBytes: total,
                speedBytesPerSec: _speed,
              ),
            );
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
        client.close(force: true);
        if (identical(_client, client)) _client = null;
      }

      if (taskId != _taskSeq) return; // 收尾的写入交给取消方/新任务

      // 落盘改名：先删掉可能存在的同名旧文件，避免 rename 在某些 ROM 上失败。
      if (await target.exists()) await target.delete();
      await part.rename(target.path);

      _emitFor(
        taskId,
        state.copyWith(
          phase: UpdateDownloadPhase.completed,
          receivedBytes: received,
          totalBytes: received,
          speedBytesPerSec: 0,
          filePath: target.path,
          // 用户可能已经把迷你条收成小圆环去干别的了。
          // 下载完是「该看一眼」的时刻，这里主动展开回来 —— 否则他根本不知道已经下好。
          compact: false,
          clearError: true,
        ),
      );
      debugPrint(
        '[UPDATE-DOWNLOAD] 完成 ${asset.name} (${formatBytes(received)}) → ${target.path}',
      );
    } catch (e) {
      if (taskId != _taskSeq) return;
      _client = null;
      _emitFor(
        taskId,
        state.copyWith(
          phase: UpdateDownloadPhase.failed,
          receivedBytes: received,
          speedBytesPerSec: 0,
          errorMessage: _humanizeError(e),
        ),
      );
      debugPrint('[UPDATE-DOWNLOAD] 失败: $e');
    }
  }

  Future<File> _partFileFor(ReleaseAssetInfo asset) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/updates');
    return File('${dir.path}/${_safeFileName(asset.name)}.part');
  }

  /// 清理上次下载遗留的安装包与半截文件（`keep` 里的除外）。
  Future<void> _pruneOldArtifacts(
    Directory dir, {
    required Set<String> keep,
  }) async {
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (keep.contains(entity.path)) continue;
        final lower = entity.path.toLowerCase();
        if (lower.endsWith('.apk') || lower.endsWith('.part')) {
          await entity.delete();
        }
      }
    } catch (_) {
      // 清理失败不影响下载本身，最多多占一点空间。
    }
  }

  /// 下载文件名里带版本号与架构，但可能夹着空格等字符；
  /// 这里只保留安全的 ASCII，防止路径分隔符之类把文件写到别的目录去。
  String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (cleaned.toLowerCase().endsWith('.apk')) return cleaned;
    return '$cleaned.apk';
  }

  String _humanizeError(Object error) {
    if (error is SocketException) return '网络连接中断，请检查网络后重试';
    if (error is HttpException) return '下载失败：${error.message}';
    if (error is FileSystemException) return '写入文件失败，请清理手机存储后重试';
    return '下载失败，请稍后重试';
  }

  /// 状态写入。
  ///
  /// 两道防线：① 非当前任务的写入直接丢弃；② Provider 在 App 退出时可能已销毁，
  /// 这时安静丢弃即可 —— 下载协程本来就活在 UI 生命周期之外，
  /// 不该因为它把整个 isolate 带崩。
  void _emitFor(int taskId, UpdateDownloadState next) {
    if (taskId != _taskSeq) return;
    try {
      state = next;
    } catch (_) {}
  }
}

/// 全局唯一的下载任务。
final updateDownloadProvider =
    NotifierProvider<UpdateDownloadController, UpdateDownloadState>(
  UpdateDownloadController.new,
);
