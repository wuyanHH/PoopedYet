/// 字节数的人话格式化。
///
/// 放在模型层是刻意的：安装包体积（`ReleaseAssetInfo.formattedSize`）与
/// 下载进度（`UpdateDownloadState`）必须用同一套口径，
/// 否则弹窗上会同时出现「17.2 MB」和「17.20 MB」两种写法。
String formatBytes(int bytes) {
  if (bytes <= 0) return '大小未知';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// 对应 GitHub Releases Assets 安装包模型
class ReleaseAssetInfo {
  const ReleaseAssetInfo({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.archType,
  });

  final String name;
  final String downloadUrl;
  final int sizeBytes;
  final String archType; // 'arm64-v8a', 'armeabi-v7a', 'universal', 'x86_64', 'other'

  String get formattedSize => formatBytes(sizeBytes);

  static String detectArch(String filename) {
    final lower = filename.toLowerCase();
    if (lower.contains('arm64-v8a') || lower.contains('arm64')) {
      return 'arm64-v8a';
    } else if (lower.contains('armeabi-v7a') || lower.contains('armv7') || lower.contains('arm32')) {
      return 'armeabi-v7a';
    } else if (lower.contains('x86_64')) {
      return 'x86_64';
    } else if (lower.contains('universal')) {
      return 'universal';
    }
    return 'other';
  }

  factory ReleaseAssetInfo.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final url = json['browser_download_url'] as String? ?? '';
    final size = json['size'] as int? ?? 0;
    return ReleaseAssetInfo(
      name: name,
      downloadUrl: url,
      sizeBytes: size,
      archType: detectArch(name),
    );
  }
}

/// GitHub 最新 Release 信息模型
class UpdateReleaseInfo {
  const UpdateReleaseInfo({
    required this.tagName,
    required this.versionName,
    required this.publishedAt,
    required this.changelog,
    required this.htmlUrl,
    required this.assets,
    required this.recommendedAsset,
    required this.isNewer,
  });

  final String tagName;
  final String versionName;
  final DateTime? publishedAt;
  final String changelog;
  final String htmlUrl;
  final List<ReleaseAssetInfo> assets;
  final ReleaseAssetInfo? recommendedAsset;
  final bool isNewer;

  /// 语义化版本号比较：v1 > v2 返回 >0，v1 == v2 返回 0，v1 < v2 返回 <0
  static int compareSemVer(String v1, String v2) {
    final clean1 = v1.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final clean2 = v2.trim().replaceFirst(RegExp(r'^[vV]'), '');

    final p1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final p2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    for (var i = 0; i < maxLen; i++) {
      final num1 = i < p1.length ? p1[i] : 0;
      final num2 = i < p2.length ? p2[i] : 0;
      if (num1 != num2) {
        return num1.compareTo(num2);
      }
    }
    return 0;
  }
}
