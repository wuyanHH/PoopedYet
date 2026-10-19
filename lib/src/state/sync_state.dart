import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate, TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/sync_merger.dart';
import '../data/sync/sync_service.dart';
import '../providers.dart';
import 'backup_state.dart';
import 'calendar_data.dart';
import 'settings.dart';

/// 双向同步服务。
final syncServiceProvider = Provider<SyncService>((ref) => SyncService());

/// 同步状态（给界面看的那一份）。
class SyncStatus {
  const SyncStatus({
    this.running = false,
    this.lastSyncAt,
    this.lastMessage,
    this.lastSuccess,
    this.lastStats,
  });

  final bool running;
  final DateTime? lastSyncAt;
  final String? lastMessage;

  /// 上次同步是否失败。null = 还没同步过。
  final bool? lastSuccess;

  final SyncMergeStats? lastStats;

  SyncStatus copyWith({
    bool? running,
    DateTime? lastSyncAt,
    String? lastMessage,
    bool? lastSuccess,
    SyncMergeStats? lastStats,
  }) {
    return SyncStatus(
      running: running ?? this.running,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSuccess: lastSuccess ?? this.lastSuccess,
      lastStats: lastStats ?? this.lastStats,
    );
  }
}

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    // 刻意只 **read** 一次快照，不 watch。
    //
    // 同步过程本身会写回 `lastSyncAt`，如果这里 watch 了 webDavConfigProvider，
    // 写状态就会反过来触发本 Provider 重建，把 running 之类的运行时状态冲掉 ——
    // 同一个坑在 autoUpdateCheckProvider 那边已经踩过一次。
    final cfg = ref.read(webDavConfigProvider);
    return SyncStatus(
      lastSyncAt: cfg.lastSyncAt,
      lastMessage: cfg.lastSyncStatus,
    );
  }

  void markRunning() {
    state = state.copyWith(running: true);
  }

  void recordOutcome(SyncOutcome? outcome) {
    if (outcome == null) {
      state = state.copyWith(running: false);
      return;
    }
    state = SyncStatus(
      running: false,
      lastSyncAt: outcome.skipped ? state.lastSyncAt : DateTime.now(),
      lastMessage: outcome.statusLine,
      lastSuccess: outcome.success,
      lastStats: outcome.stats,
    );
  }
}

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);

/// 自动同步协调器：决定"什么时候同步"，不负责"怎么同步"。
///
/// 三条触发路径：
///
/// 1. **冷启动** —— 延迟几秒静默跑一次，保证换设备后第一时间看到对方的数据；
/// 2. **回到前台** —— 带节流，避免用户来回切 App 时反复打服务器；
/// 3. **本地数据变更后防抖** —— 保证"刚记的这条"能自己上云，
///    而不是等用户下次开 App 才想起来。
///
/// 三条路径都汇到同一个 [run]，而 [SyncService] 那边有单例锁兜底，
/// 所以它们在时间上撞车也不会产生两次上传。
class AutoSyncCoordinator with WidgetsBindingObserver {
  AutoSyncCoordinator(this._ref);

  final Ref _ref;

  /// 本地数据变更后多久推送一次。
  ///
  /// 30 秒是有意的折中：用户连着开屙、补录、改备注、写模板，只会同步一次；
  /// 而"刚记完就想在另一台手机看到"，30 秒的等待也完全能接受。
  static const Duration pushDebounce = Duration(seconds: 30);

  /// 回到前台时的最小同步间隔。
  static const Duration resumeMinInterval = Duration(minutes: 3);

  /// 冷启动后延迟多久开始首次同步。
  ///
  /// 刻意排在首屏动画和桌面小组件同步之后 —— 它们抢的是同一块带宽，
  /// 而冷启动那几秒是用户对"卡不卡"最敏感的时刻。
  static const Duration startupDelay = Duration(seconds: 5);

  /// 同步自己写库之后，多久之内忽略表变更事件。
  static const Duration selfWriteGrace = Duration(seconds: 3);

  Timer? _debounce;
  StreamSubscription<Set<TableUpdate>>? _tableSub;
  DateTime? _suppressTableEventsUntil;
  DateTime? _lastRunAt;
  bool _started = false;

  /// 立刻开始监听。重复调用无副作用。
  void start() {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(this);

    Future<void>.delayed(startupDelay, () {
      unawaited(run(reason: '启动'));
    });

    // 用 Drift 的表变更流挂钩子，而不是去每个写入点手动调用一次。
    //
    // 写入点有十几个（开屙、结束、补录、编辑、删除、撤销删除、加备注、
    // 删备注、归档成员、改排序、写模板…），手动挂必然漏掉一两个，
    // 而漏掉的那一个就表现为"某些改动永远同步不上去" —— 这种 bug
    // 还很难复现，因为你得先知道是哪个操作漏了。
    final db = _ref.read(databaseProvider);
    _tableSub = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.poopers,
            db.poopRecords,
            db.poopNotes,
            db.noteTemplates,
          ]),
        )
        .listen((_) {
      if (_isSelfWrite()) return;
      _scheduleDebouncedPush();
    });
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _debounce = null;
    _tableSub?.cancel();
    _tableSub = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final last = _lastRunAt;
    if (last != null &&
        DateTime.now().difference(last) < resumeMinInterval) {
      return;
    }
    unawaited(run(reason: '回到前台'));
  }

  /// 执行一次同步。返回 null 表示"这次压根没跑"（没配置 / 关了 / 已在跑）。
  Future<SyncOutcome?> run({required String reason, bool manual = false}) async {
    final cfg = _ref.read(webDavConfigProvider);
    if (!cfg.isConfigured) return null;
    // 手动点「立即同步」的人必须得到真实结果，所以手动路径无视自动同步开关。
    if (!manual && !cfg.autoSync) return null;

    final service = _ref.read(syncServiceProvider);
    if (service.isRunning) return null;

    _lastRunAt = DateTime.now();
    _ref.read(syncStatusProvider.notifier).markRunning();

    // 同步自己会写库，写库又会触发表变更事件。要在这个时间窗里把它们忽略掉，
    // 否则"同步 → 写库 → 表变更 → 再同步"会变成一个停不下来的自激循环，
    // 表现就是流量悄悄跑光、云端文件被反复重写。
    _suppressTableEventsUntil = DateTime.now().add(selfWriteGrace);

    SyncOutcome? outcome;
    try {
      outcome = await service.syncNow(
        db: _ref.read(databaseProvider),
        prefs: _ref.read(sharedPrefsProvider),
        config: cfg,
      );
    } finally {
      // 写库是异步派发事件的，同步返回后再顺延一个窗口才保险。
      _suppressTableEventsUntil = DateTime.now().add(selfWriteGrace);
      _ref.read(syncStatusProvider.notifier).recordOutcome(outcome);

      if (outcome != null && !outcome.skipped) {
        await _ref.read(webDavConfigProvider.notifier).updateSyncResult(
              success: outcome.success,
              status: outcome.statusLine,
            );
        if (outcome.success) _refreshDataProviders();
      }
    }
    return outcome;
  }

  void _scheduleDebouncedPush() {
    _debounce?.cancel();
    _debounce = Timer(pushDebounce, () {
      unawaited(run(reason: '数据变更'));
    });
  }

  bool _isSelfWrite() {
    final until = _suppressTableEventsUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// 合并结果直接写进了数据库，界面上的缓存得全部作废重取，
  /// 不然用户会看到"同步说成功，但列表还是旧的"。
  void _refreshDataProviders() {
    _ref.invalidate(activePoopersProvider);
    _ref.invalidate(allPoopersProvider);
    _ref.invalidate(noteTemplatesProvider);
    _ref.invalidate(monthBadgesProvider);
    _ref.invalidate(weekBadgesProvider);
    _ref.invalidate(dayRecordsProvider);
    _ref.invalidate(staleRecordsProvider);
    _ref.invalidate(recordDetailProvider);
  }
}

/// 自动同步协调器提供者。
///
/// 被 watch 到才会启动 —— 挂在 `PoopedYetApp.build` 里，
/// 保证整个 App 生命周期内只跑一份。
final autoSyncCoordinatorProvider = Provider<AutoSyncCoordinator>((ref) {
  final coordinator = AutoSyncCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  coordinator.start();
  return coordinator;
});
