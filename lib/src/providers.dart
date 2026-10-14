import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'widget/widget_snapshot_service.dart';

/// 应用数据库。全局单例，随 ProviderContainer 一起销毁。
///
/// 构造顺序上这里是**唯一**创建 AppDatabase 的地方 ——
/// 任何地方再 `AppDatabase()` 一次都会开出第二个连接，
/// 而外键的 `PRAGMA foreign_keys = ON` 是 per-connection 的，那样就漏了。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// 启动自检的结果。
class BootReport {
  const BootReport({
    required this.defaultPooperName,
    required this.pooperCount,
    required this.recordCount,
    required this.noteTemplateCount,
    required this.createdFresh,
    required this.foreignKeysOn,
  });

  final String defaultPooperName;
  final int pooperCount;
  final int recordCount;
  final int noteTemplateCount;

  /// 这次启动是不是刚刚才建出「我」（即数据库原本是空的）。
  final bool createdFresh;

  /// **真实连接上**外键约束是否开启。
  ///
  /// SQLite 的 `PRAGMA foreign_keys` 是 **per-connection** 的，默认关闭。
  /// 不开启的话，`poop_records.pooper_id` 上那个 `ON DELETE RESTRICT`
  /// 形同虚设 —— 删人会静默成功，几百条历史记录一起没。
  ///
  /// 单元测试是在内存库上验的；这里要验的是**真机上 drift_flutter 开出来的那条连接**
  /// （它可能跑在后台 isolate 里，行为和内存库不一定一致）。
  final bool foreignKeysOn;
}

/// 启动流程：保证有一个可用的默认屙屎人，然后把现状报出来。
///
/// [ensureDefaultPooper] 的调用点就在这里。它是幂等的，
/// 首启、以及"归档掉最后一个人"之后都会走到同一段逻辑 ——
/// 这正是设计评审里定下的：不能只在首启 if 一下。
final bootReportProvider = FutureProvider<BootReport>((ref) async {
  final db = ref.watch(databaseProvider);

  final before = await db.activePoopers();
  final me = await db.ensureDefaultPooper();

  final poopers = await db.activePoopers();
  final records = await db.select(db.poopRecords).get();
  final templates = await db.select(db.noteTemplates).get();

  // 关键自检：读真实连接上的 PRAGMA，而不是相信 beforeOpen 已经跑过。
  final fkRow = await db.customSelect('PRAGMA foreign_keys').getSingle();
  final fkOn = fkRow.data.values.first == 1;

  final report = BootReport(
    defaultPooperName: me.name,
    pooperCount: poopers.length,
    recordCount: records.length,
    noteTemplateCount: templates.length,
    createdFresh: before.isEmpty,
    foreignKeysOn: fkOn,
  );

  // Flutter 画在 canvas 上，uiautomator 读不到界面文字；
  // 把自检结果同时打进日志，这样 CI / adb 这类没有 GUI 的环境也能核对。
  debugPrint(
    '[BOOT-CHECK] default=${report.defaultPooperName} '
    'poopers=${report.pooperCount} records=${report.recordCount} '
    'templates=${report.noteTemplateCount} '
    'foreign_keys=${report.foreignKeysOn} fresh=${report.createdFresh}',
  );

  unawaited(WidgetSyncManager.sync(db));

  return report;
});
