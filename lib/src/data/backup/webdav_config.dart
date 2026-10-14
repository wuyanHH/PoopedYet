import 'package:shared_preferences/shared_preferences.dart';

/// 默认 WebDAV 云端备份文件夹名称（纯名称，不带前后斜杠）。
const String kDefaultRemoteFolder = 'pooped_yet';

/// WebDAV 同步配置。
class WebDavConfig {
  const WebDavConfig({
    this.serverUrl = '',
    this.username = '',
    this.password = '',
    this.remotePath = kDefaultRemoteFolder,
    this.allowSelfSignedCert = false,
    this.lastSyncAt,
    this.lastSyncStatus,
  });

  /// 服务器完整 URL，如 https://dav.jianguoyun.com/dav/
  final String serverUrl;

  /// 用户名 / 账号
  final String username;

  /// 密码 / 应用授权码
  final String password;

  /// 云端备份文件夹名称，默认 `pooped_yet`（不含前后斜杠）
  final String remotePath;

  /// 允许自签名或非受信任证书（NAS自建用户常备）
  final bool allowSelfSignedCert;

  /// 上次同步时间
  final DateTime? lastSyncAt;

  /// 上次同步状态说明
  final String? lastSyncStatus;

  bool get isConfigured =>
      serverUrl.trim().isNotEmpty && username.trim().isNotEmpty;

  /// 纯净的文件夹名称（严格去除前后所有的 '/' 斜杠，防止多余展示与误拼）
  String get cleanFolderName {
    var p = remotePath.trim();
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p.isEmpty ? kDefaultRemoteFolder : p;
  }

  WebDavConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? remotePath,
    bool? allowSelfSignedCert,
    DateTime? lastSyncAt,
    String? lastSyncStatus,
  }) {
    return WebDavConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remotePath: remotePath ?? this.remotePath,
      allowSelfSignedCert: allowSelfSignedCert ?? this.allowSelfSignedCert,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
    );
  }

  // ---- SharedPreferences 持久化 ----

  static const _kUrl = 'webdav.serverUrl';
  static const _kUser = 'webdav.username';
  static const _kPass = 'webdav.password';
  static const _kPath = 'webdav.remotePath';
  static const _kCert = 'webdav.allowSelfSignedCert';
  static const _kSyncAt = 'webdav.lastSyncAt';
  static const _kSyncStatus = 'webdav.lastSyncStatus';

  static WebDavConfig load(SharedPreferences prefs) {
    final syncAtStr = prefs.getString(_kSyncAt);
    final rawPath = prefs.getString(_kPath) ?? kDefaultRemoteFolder;

    // 清理可能遗留的历史前后斜杠
    var cleanP = rawPath.trim();
    while (cleanP.startsWith('/')) {
      cleanP = cleanP.substring(1);
    }
    while (cleanP.endsWith('/')) {
      cleanP = cleanP.substring(0, cleanP.length - 1);
    }
    if (cleanP.isEmpty) cleanP = kDefaultRemoteFolder;

    return WebDavConfig(
      serverUrl: prefs.getString(_kUrl) ?? '',
      username: prefs.getString(_kUser) ?? '',
      password: prefs.getString(_kPass) ?? '',
      remotePath: cleanP,
      allowSelfSignedCert: prefs.getBool(_kCert) ?? false,
      lastSyncAt: syncAtStr != null ? DateTime.tryParse(syncAtStr) : null,
      lastSyncStatus: prefs.getString(_kSyncStatus),
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString(_kUrl, serverUrl.trim());
    await prefs.setString(_kUser, username.trim());
    await prefs.setString(_kPass, password);
    await prefs.setString(_kPath, cleanFolderName);
    await prefs.setBool(_kCert, allowSelfSignedCert);
    if (lastSyncAt != null) {
      await prefs.setString(_kSyncAt, lastSyncAt!.toIso8601String());
    }
    if (lastSyncStatus != null) {
      await prefs.setString(_kSyncStatus, lastSyncStatus!);
    }
  }

  Future<void> clear(SharedPreferences prefs) async {
    await prefs.remove(_kUrl);
    await prefs.remove(_kUser);
    await prefs.remove(_kPass);
    await prefs.remove(_kPath);
    await prefs.remove(_kCert);
    await prefs.remove(_kSyncAt);
    await prefs.remove(_kSyncStatus);
  }
}
