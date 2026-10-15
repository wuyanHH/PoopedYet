import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

import 'update_model.dart';

/// GitHub Releases 检查更新服务（零后台静默，纯手动克制触发）
class UpdateService {
  UpdateService({
    this.owner = 'wuyanHH',
    this.repo = 'PoopedYet',
  });

  final String owner;
  final String repo;

  static const _channel = MethodChannel('com.poopedyet.app/widget');

  /// 获取当前本机 CPU 首选指令集架构
  static Future<String> getDeviceAbi() async {
    try {
      final abi = await _channel.invokeMethod<String>('getDeviceAbi');
      if (abi != null && abi.isNotEmpty) {
        return abi.toLowerCase();
      }
    } catch (_) {}
    return 'arm64-v8a'; // 现代安卓机默认保底
  }

  /// 通过原生浏览器唤起下载或打开链接
  static Future<bool> openUrl(String url) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 检查 GitHub Releases 最新版本
  ///
  /// [currentVersion] 本地当前版本（如 "1.0.0" 或 "0.3.3"）
  Future<UpdateReleaseInfo?> checkLatestRelease({
    required String currentVersion,
    String? customOwner,
    String? customRepo,
  }) async {
    final targetOwner = (customOwner != null && customOwner.trim().isNotEmpty)
        ? customOwner.trim()
        : owner;
    final targetRepo = (customRepo != null && customRepo.trim().isNotEmpty)
        ? customRepo.trim()
        : repo;

    final urlStr = 'https://api.github.com/repos/$targetOwner/$targetRepo/releases/latest';

    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(urlStr));
      // GitHub API 要求提供 User-Agent
      request.headers.set('User-Agent', 'PoopedYet-App');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close();
      if (response.statusCode != 200) {
        return null;
      }

      final bodyStr = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> json = jsonDecode(bodyStr);

      final tagName = json['tag_name'] as String? ?? '';
      final versionName = tagName.replaceFirst(RegExp(r'^[vV]'), '');
      final htmlUrl = json['html_url'] as String? ?? '';
      final body = json['body'] as String? ?? '暂无更新描述';
      final publishedAtStr = json['published_at'] as String?;
      final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

      final rawAssets = json['assets'] as List<dynamic>? ?? [];
      final assets = <ReleaseAssetInfo>[];
      for (final a in rawAssets) {
        if (a is Map<String, dynamic>) {
          final asset = ReleaseAssetInfo.fromJson(a);
          if (asset.name.toLowerCase().endsWith('.apk')) {
            assets.add(asset);
          }
        }
      }

      final deviceAbi = await getDeviceAbi();
      final isNewer = UpdateReleaseInfo.compareSemVer(versionName, currentVersion) > 0;

      // 智能架构匹配：
      // 1. 优先找架构完全匹配的 APK（例如 arm64-v8a）
      // 2. 其次找 universal 通用包
      // 3. 再次取第一个 APK
      ReleaseAssetInfo? recommended;
      if (assets.isNotEmpty) {
        recommended = assets.firstWhere(
          (a) => a.archType == deviceAbi,
          orElse: () => assets.firstWhere(
            (a) => a.archType == 'universal',
            orElse: () => assets.first,
          ),
        );
      }

      return UpdateReleaseInfo(
        tagName: tagName,
        versionName: versionName,
        publishedAt: publishedAt,
        changelog: body,
        htmlUrl: htmlUrl,
        assets: assets,
        recommendedAsset: recommended,
        isNewer: isNewer,
      );
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
