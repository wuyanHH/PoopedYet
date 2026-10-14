import 'dart:convert';
import 'dart:io';

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
const List<int> kBundledHolidayYears = [
  2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026,
];

/// CDN 与 GitHub API 地址模板
const String kHolidayCdnUrlPattern =
    'https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/{year}.json';
const String kHolidayRawUrlPattern =
    'https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/{year}.json';

/// 从 JSON 字符串解析节假日行。
List<HolidaysCompanion> parseHolidayJson(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return const [];

  final days = decoded['days'];
  if (days is! List) return const [];

  final rows = <HolidaysCompanion>[];
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
  return rows;
}

/// 从打包资源灌入 `holidays` 表。
///
/// 幂等，可以每次启动都调 —— 总共 300 多行，upsert 一次是毫秒级。
Future<int> loadHolidaysFromAssets(AppDatabase db) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where((p) => p.startsWith(kHolidayAssetDir) && p.endsWith('.json'))
      .toList()
    ..sort();

  if (paths.isEmpty) return 0;

  final rows = <HolidaysCompanion>[];
  for (final path in paths) {
    final raw = await rootBundle.loadString(path);
    rows.addAll(parseHolidayJson(raw));
  }

  if (rows.isEmpty) return 0;

  await db.batch((b) {
    b.insertAllOnConflictUpdate(db.holidays, rows);
  });
  return rows.length;
}

/// 在线同步 API 结果。
class HolidaySyncResult {
  const HolidaySyncResult({
    required this.success,
    required this.insertedCount,
    required this.syncedYears,
    this.errorMessage,
  });

  final bool success;
  final int insertedCount;
  final List<int> syncedYears;
  final String? errorMessage;
}

/// 查询数据库中已包含的节假日年份列表与总条数。
Future<({List<int> years, int totalCount})> getHolidayDatabaseStats(
  AppDatabase db,
) async {
  final all = await db.select(db.holidays).get();
  if (all.isEmpty) return (years: const <int>[], totalCount: 0);

  final yearSet = <int>{};
  for (final h in all) {
    if (h.date.length >= 4) {
      final y = int.tryParse(h.date.substring(0, 4));
      if (y != null) yearSet.add(y);
    }
  }

  final sorted = yearSet.toList()..sort();
  return (years: sorted, totalCount: all.length);
}

/// 从开源 API 在线拉取并更新法定节假日与调休数据。
///
/// 默认拉取前后各 1 年（如当前 2025，则拉取 2024、2025、2026、2027）。
Future<HolidaySyncResult> syncHolidaysFromApi(
  AppDatabase db, {
  List<int>? targetYears,
  String? customCdnPattern,
}) async {
  final nowYear = DateTime.now().year;
  final years = targetYears ?? [nowYear - 1, nowYear, nowYear + 1, nowYear + 2];

  final rows = <HolidaysCompanion>[];
  final successfulYears = <int>[];

  for (final y in years) {
    // 优先尝试 CDN 加速源，若失败则回退至 GitHub 原生 Raw 源
    final cdnUrl = (customCdnPattern ?? kHolidayCdnUrlPattern).replaceAll('{year}', '$y');
    final rawUrl = kHolidayRawUrlPattern.replaceAll('{year}', '$y');

    var content = await _httpGet(cdnUrl);
    if (content == null || content.isEmpty) {
      content = await _httpGet(rawUrl);
    }

    if (content != null && content.isNotEmpty) {
      try {
        final parsed = parseHolidayJson(content);
        if (parsed.isNotEmpty) {
          rows.addAll(parsed);
          successfulYears.add(y);
        }
      } catch (_) {
        // 容错单个年份 JSON 异常
      }
    }
  }

  if (rows.isEmpty) {
    return HolidaySyncResult(
      success: false,
      insertedCount: 0,
      syncedYears: const [],
      errorMessage: '网络连接超时或未能获取到最新节假日数据',
    );
  }

  await db.batch((b) {
    b.insertAllOnConflictUpdate(db.holidays, rows);
  });

  return HolidaySyncResult(
    success: true,
    insertedCount: rows.length,
    syncedYears: successfulYears,
  );
}

Future<String?> _httpGet(String url) async {
  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    return await response.transform(utf8.decoder).join();
  } catch (_) {
    return null;
  } finally {
    client?.close();
  }
}
