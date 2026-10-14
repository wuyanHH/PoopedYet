import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup/backup_service.dart';
import '../data/backup/webdav_client.dart';
import '../data/backup/webdav_config.dart';
import 'settings.dart';

/// 备份服务提供者。
final backupServiceProvider = Provider<BackupService>((ref) {
  return const BackupService();
});

/// WebDAV 配置状态提供者。
final webDavConfigProvider =
    NotifierProvider<WebDavConfigNotifier, WebDavConfig>(
  WebDavConfigNotifier.new,
);

class WebDavConfigNotifier extends Notifier<WebDavConfig> {
  @override
  WebDavConfig build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return WebDavConfig.load(prefs);
  }

  Future<void> updateConfig(WebDavConfig newConfig) async {
    final prefs = ref.read(sharedPrefsProvider);
    await newConfig.save(prefs);
    state = newConfig;
  }

  Future<void> updateSyncResult({
    required bool success,
    required String status,
  }) async {
    final updated = state.copyWith(
      lastSyncAt: DateTime.now(),
      lastSyncStatus: status,
    );
    await updateConfig(updated);
  }

  Future<void> clearConfig() async {
    final prefs = ref.read(sharedPrefsProvider);
    await state.clear(prefs);
    state = const WebDavConfig();
  }
}

/// WebDAV 客户端提供者。
final webDavClientProvider = Provider<WebDavClient>((ref) {
  final config = ref.watch(webDavConfigProvider);
  return WebDavClient(config: config);
});
