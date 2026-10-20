import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../widget/widget_snapshot_service.dart';
import 'tables.dart';

part 'database.g.dart';

/// 应用数据库。
///
/// 纯本地 SQLite，不联网、不上传。
@DriftDatabase(tables: [Poopers, PoopRecords, PoopNotes, NoteTemplates, Holidays])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'pooped_yet'));

  /// 给测试用的构造：传内存数据库，不落盘。
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();

      // ---- 下面这些索引 Drift 的注解表达不了，手写 SQL ----

      // 1) 全局最多一个默认屙屎人。
      //
      // 只有普通布尔字段的话，可能同时存在两个默认，或者一个都没有
      // （默认那个被归档了）。部分唯一索引让非法状态根本写不进去。
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS ux_default_pooper '
        'ON poopers(is_default) WHERE is_default = 1',
      );

      // 2) 一个人同时只能有一条"正在进行中"的记录。
      //
      // ⚠ 条件里必须带 `end_unknown = 0`。
      //   漏掉它的话，「未记结束」的记录（ended_at 为 NULL 但用户已明确表示没记）
      //   会被当成进行中，于是这个人再也开不了新记录 —— 忘点一次结束就永久卡死。
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS ux_active_record '
        'ON poop_records(pooper_id) WHERE ended_at IS NULL AND end_unknown = 0',
      );

      // 3) 日历按月聚合、历史按时间倒序，都靠这个。
      //    注意排序用 started_at 而不是 created_at ——
      //    补录一条上个月的记录时，created_at 是今天，但它应该出现在上个月。
      await customStatement(
        'CREATE INDEX IF NOT EXISTS ix_records_started ON poop_records(started_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS ix_records_pooper_started '
        'ON poop_records(pooper_id, started_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS ix_notes_record ON poop_notes(record_id, noted_at)',
      );

      await _seedDefaults();
    },
    beforeOpen: (details) async {
      // 外键约束在 SQLite 里默认是关的，必须每次连接都打开。
      // 不打开的话上面那个 KeyAction.restrict 形同虚设 —— 删人会静默成功。
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// 首次建库时灌入默认备注。
  ///
  /// 需求：「可以设置一些默认备注（比如拉肚子之类），也要支持手动增添」。
  Future<void> _seedDefaults() async {
    const seeds = <String>[
      '拉肚子',
      '很顺畅',
      '有点干',
      '带薪摸鱼',
      '玩手机',
      '吃了火龙果',
      '昨晚吃辣了',
    ];
    await batch((b) {
      for (var i = 0; i < seeds.length; i++) {
        b.insert(
          noteTemplates,
          NoteTemplatesCompanion.insert(
            content: seeds[i],
            sortOrder: Value(i),
          ),
        );
      }
    });
  }

  // ==========================================================================
  //  屙屎人的生命周期
  // ==========================================================================

  /// 保证始终至少有一个可用的默认屙屎人。
  ///
  /// **必须在这两个时机都调用**：
  ///   1. 首次启动（数据库是空的）
  ///   2. 归档 / 删除之后（**归档掉最后一个人也会回到"一个都没有"**）
  ///
  /// 所以千万不要把它写成只在首启跑的 `if (isFirstRun)` ——
  /// 那样就漏掉了第二条路径。这是设计评审里发现的一个真实缺口。
  Future<Pooper> ensureDefaultPooper() async {
    final alive = await activePoopers();

    if (alive.isEmpty) {
      // 静默建档。不弹引导页 —— 这个 App 的核心动作是"一次点击开屙"，
      // 在它前面竖一道"先填名字选头像"的墙，是用最贵的位置解决最便宜的问题。
      // 提示"还能加人"交给主页那条可关闭的提示条。
      return into(poopers).insertReturning(
        PoopersCompanion.insert(name: '我', isDefault: const Value(true)),
      );
    }

    final hasDefault = alive.any((p) => p.isDefault);
    if (!hasDefault) {
      // 默认那个人被归档了。把剩下最早创建（sortOrder 最小）的提上来。
      // 不转移的话唯一索引放行、但没有任何人是默认，FAB 就不知道该记给谁。
      final next = alive.first;
      await (update(poopers)..where((t) => t.id.equals(next.id)))
          .write(const PoopersCompanion(isDefault: Value(true)));
      return next.copyWith(isDefault: true);
    }

    return alive.firstWhere((p) => p.isDefault);
  }

  /// 未归档的屙屎人，按 sortOrder 再按 createdAt 排序。
  Future<List<Pooper>> activePoopers() {
    return (select(poopers)
          ..where((t) => t.archivedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .get();
  }

  /// 归档一个人（**不是删除**）。历史记录原样保留，日历与统计仍然计入。
  ///
  /// 如果归档的是默认人，会自动把默认转移给别人；一个都不剩时
  /// `isDefault` 全为 null，下次 [ensureDefaultPooper] 会补一个。
  Future<void> archivePooper(String id) async {
    await transaction(() async {
      await (update(poopers)..where((t) => t.id.equals(id)))
          .write(PoopersCompanion(archivedAt: Value(DateTime.now())));

      final wasDefault = await (select(poopers)..where((t) => t.id.equals(id)))
          .getSingleOrNull()
          .then((p) => p?.isDefault ?? false);
      if (!wasDefault) return;

      // 先把默认清掉再选下一个 —— 否则会短暂违反唯一索引
      await (update(poopers)..where((t) => t.id.equals(id)))
          .write(const PoopersCompanion(isDefault: Value(false)));

      final alive = await activePoopers();
      if (alive.isNotEmpty) {
        await (update(poopers)..where((t) => t.id.equals(alive.first.id)))
            .write(const PoopersCompanion(isDefault: Value(true)));
      }
    });

    // 桌面小组件读的是跨进程快照，不主动同步的话它会一直拿着旧成员表 ——
    // 表现就是「人都归档了，小组件里还选得到他」。
    unawaited(WidgetSyncManager.sync(this));
  }

  /// 取消归档。
  Future<void> unarchivePooper(String id) async {
    await (update(poopers)..where((t) => t.id.equals(id)))
        .write(const PoopersCompanion(archivedAt: Value(null)));
    unawaited(WidgetSyncManager.sync(this));
  }

  /// 某个屙屎人名下一共有多少条记录。
  ///
  /// 彻底删除前用来明确告知「将删除 N 条记录」——
  /// 不报数字的确认框等于没确认。
  Future<int> countRecordsOf(String pooperId) async {
    final row = await (selectOnly(poopRecords)
          ..addColumns([poopRecords.id.count()])
          ..where(poopRecords.pooperId.equals(pooperId)))
        .getSingle();
    return row.read(poopRecords.id.count()) ?? 0;
  }

  /// **危险操作**：彻底删除一个人，连同他的全部记录。
  ///
  /// 返回被删掉的记录条数，让 UI 能明确告知"将删除 N 条记录"。
  /// 因为外键是 `restrict`，必须按顺序删：备注 → 记录 → 人。
  Future<int> purgePooper(String id) async {
    final deleted = await transaction(() async {
      final recordIds = await (selectOnly(poopRecords)
            ..addColumns([poopRecords.id])
            ..where(poopRecords.pooperId.equals(id)))
          .map((r) => r.read(poopRecords.id)!)
          .get();

      if (recordIds.isNotEmpty) {
        await (delete(poopNotes)
              ..where((t) => t.recordId.isIn(recordIds)))
            .go();
      }
      final removed = await (delete(poopRecords)
            ..where((t) => t.pooperId.equals(id)))
          .go();
      await (delete(poopers)..where((t) => t.id.equals(id))).go();

      // 保证始终至少有一个可用的默认屙屎人（若删除了唯一的默认人或最后一个人，自动提拔或补齐兜底人「我」）
      await ensureDefaultPooper();

      return removed;
    });

    unawaited(WidgetSyncManager.sync(this));
    return deleted;
  }

  /// 设置默认屙屎人。先清空再设置，避免短暂违反唯一索引。
  Future<void> setDefaultPooper(String id) async {
    await transaction(() async {
      await update(poopers).write(const PoopersCompanion(isDefault: Value(false)));
      await (update(poopers)..where((t) => t.id.equals(id)))
          .write(const PoopersCompanion(isDefault: Value(true)));
    });

    // 「跟随默认成员」的小组件全靠这份默认值，不同步的话换了默认人
    // 桌面上那些组件还显示着旧的人（头像自然也不对）。
    unawaited(WidgetSyncManager.sync(this));
  }
}
