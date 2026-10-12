import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import 'database.dart';

/// 打包的节假日数据来源。
///
/// 数据来自国务院办公厅公告，经 [NateScarlet/holiday-cn](https://github.com/NateScarlet/holiday-cn)
/// 整理成 JSON。三态：休（`isOffDay = true`）/ 班（`isOffDay = false`）/ 无记录。
///
/// **注意 `isOffDay = false` 的那批恰恰是周末补班** —— 它们才是"班"角标。
const String kHolidayAssetDir = 'assets/holidays/';

/// 数据里覆盖的年份（用来在设置页显示"内置数据版本"）。
///
/// 只是展示值；真正加载哪些文件是从 AssetManifest 里扫的，
/// 所以**加了新文件不用改这里**（改了也只是显示得准一点）。
const List<int> kBundledHolidayYears = [
  2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026,
];

/// 从打包资源灌入 `holidays` 表。
///
/// 幂等，可以每次启动都调 —— 总共 300 多行，upsert 一次是毫秒级。
/// 做成"每次启动重灌"而不是"只在首启灌"，是为了将来能靠发版更新数据：
/// 用户装了新版本，表里自然就是新数据，不用写迁移。
Future<int> loadHolidaysFromAssets(AppDatabase db) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where((p) =>
          p.startsWith(kHolidayAssetDir) && p.endsWith('.json'))
      .toList()
    ..sort();

  if (paths.isEmpty) return 0;

  final rows = <HolidaysCompanion>[];
  for (final path in paths) {
    final raw = await rootBundle.loadString(path);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) continue;

    final days = decoded['days'];
    if (days is! List) continue;

    for (final d in days) {
      if (d is! Map) continue;
      final date = d['date'];
      final off = d['isOffDay'];
      if (date is! String || off is! bool) continue;

      rows.add(
        HolidaysCompanion.insert(
          date: date,
          name: Value(d['name'] as String?),
          isOffDay: off,
        ),
      );
    }
  }

  if (rows.isEmpty) return 0;

  await db.batch((b) {
    b.insertAllOnConflictUpdate(db.holidays, rows);
  });
  return rows.length;
}
