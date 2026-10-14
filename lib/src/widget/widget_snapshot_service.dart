import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../calendar/calendar_math.dart';
import '../data/database.dart';
import '../data/queries.dart';
import '../domain/record_state.dart';
import '../theme/tokens.dart';
import 'widget_snapshot.dart';

/// 桌面小组件数据快照聚合与跨进程同步服务
class WidgetSnapshotService {
  WidgetSnapshotService(this._db);

  final AppDatabase _db;
  static const _channel = MethodChannel('com.poopedyet.app/widget');
  static const _keyIncognito = 'pref_incognito_mode';

  /// 聚合并生成最新快照
  Future<WidgetSnapshot> buildSnapshot({DateTime? nowOverride}) async {
    final now = nowOverride ?? DateTime.now();
    final todayStart = startOfDay(now);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    // 1. 获取默认成员
    final defaultPooper = await _db.ensureDefaultPooper();
    final activePoopers = await _db.activePoopers();
    final pooperMap = {for (final p in activePoopers) p.id: p};

    // 2. 检查是否有进行中的记录
    final activeRecords = await (_db.select(_db.poopRecords)
          ..where(
            (t) =>
                t.endedAt.isNull() &
                t.endUnknown.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();

    final liveSession = activeRecords.isNotEmpty
        ? WidgetLiveSession(
            isLive: true,
            recordId: activeRecords.first.id,
            startedAtMillis: activeRecords.first.startedAt.millisecondsSinceEpoch,
            elapsedMinutes:
                minutesBetween(activeRecords.first.startedAt, now),
          )
        : const WidgetLiveSession(isLive: false);

    // 3. 获取今日记录统计
    final todayRecords = await (_db.select(_db.poopRecords)
          ..where(
            (t) =>
                t.startedAt.isBiggerOrEqualValue(todayStart) &
                t.startedAt.isSmallerThanValue(tomorrowStart),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();

    // 最新一条记录与最近备注
    String? lastTimeStr;
    int? hoursSinceLast;
    String? lastRemark;

    // 先从今日记录找最近一条，如果今天没有就从历史中找最后一条
    PoopRecord? mostRecent = todayRecords.isNotEmpty ? todayRecords.first : null;
    if (mostRecent == null) {
      final lastAny = await (_db.select(_db.poopRecords)
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(1))
          .get();
      if (lastAny.isNotEmpty) {
        mostRecent = lastAny.first;
      }
    }

    if (mostRecent != null) {
      lastTimeStr = DateFormat('HH:mm').format(mostRecent.startedAt);
      hoursSinceLast = now.difference(mostRecent.startedAt).inHours;

      // 查备注
      final notes = await (_db.select(_db.poopNotes)
            ..where((t) => t.recordId.equals(mostRecent!.id))
            ..orderBy([(t) => OrderingTerm.asc(t.notedAt)]))
          .get();
      if (notes.isNotEmpty) {
        lastRemark = notes.first.content;
      }
    }

    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekdayName = weekdayNames[(now.weekday - 1) % 7];

    final todaySummary = WidgetTodaySummary(
      dateStr: DateFormat('yyyy-MM-dd').format(now),
      dayNum: now.day,
      weekdayName: weekdayName,
      totalCount: todayRecords.length,
      lastTimeStr: lastTimeStr,
      hoursSinceLast: hoursSinceLast,
      lastRemark: lastRemark,
    );

    // 4. 计算本周 7 天排班（周一到周日）
    final weekStart = WeekStart.monday;
    final weekDaysList = weekDaysOf(now, weekStart);
    final weekFrom = startOfDay(weekDaysList.first);
    final weekTo = startOfDay(weekDaysList.last).add(const Duration(days: 1));
    final weekCountsMap = await _db.countsInRange(weekFrom, weekTo);

    // 查本周的节假日情况
    final holidayRows = await (_db.select(_db.holidays)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(DateFormat('yyyy-MM-dd').format(weekFrom)) &
                t.date.isSmallerOrEqualValue(DateFormat('yyyy-MM-dd').format(weekDaysList.last)),
          ))
        .get();
    final holidayMap = {for (final h in holidayRows) h.date: h.isOffDay};

    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final widgetWeekDays = <WidgetWeekDay>[];

    for (var i = 0; i < weekDaysList.length; i++) {
      final day = weekDaysList[i];
      final key = dayKey(day);
      final dayCounts = weekCountsMap[key] ?? {};
      final totalDayCount = dayCounts.values.fold<int>(0, (a, b) => a + b);
      final iconKeys = <String>[];
      for (final pid in dayCounts.keys) {
        final p = pooperMap[pid];
        if (p != null) {
          iconKeys.add(p.iconKey ?? 'dog');
        }
      }

      final dateIso = DateFormat('yyyy-MM-dd').format(day);
      final isOffDay = holidayMap[dateIso];
      final isHoliday = isOffDay == true;
      final isWorkday = isOffDay == false;

      widgetWeekDays.add(
        WidgetWeekDay(
          dateStr: dateIso,
          dayNum: day.day,
          weekday: day.weekday,
          weekdayLabel: weekLabels[i % 7],
          isToday: isSameDay(day, now),
          isHoliday: isHoliday,
          isWorkday: isWorkday,
          count: totalDayCount,
          iconKeys: iconKeys,
        ),
      );
    }

    // 5. 计算连续顺畅天数 (Streak)：单次批量查询 + 内存 Set 比对，彻底杜绝 N+1 循环查库
    final streakYearAgo = todayStart.subtract(const Duration(days: 366));
    final distinctDatesQuery = _db.selectOnly(_db.poopRecords, distinct: true)
      ..addColumns([_db.poopRecords.startedAt])
      ..where(_db.poopRecords.startedAt.isBiggerOrEqualValue(streakYearAgo));
    final dateRows = await distinctDatesQuery.get();
    final activeDateKeys = <String>{
      for (final r in dateRows)
        if (r.read(_db.poopRecords.startedAt) != null)
          dayKey(r.read(_db.poopRecords.startedAt)!)
    };

    var streakDays = 0;
    var checkDay = todayRecords.isNotEmpty ? todayStart : todayStart.subtract(const Duration(days: 1));
    while (streakDays < 365) {
      final k = dayKey(checkDay);
      if (activeDateKeys.contains(k)) {
        streakDays++;
        checkDay = checkDay.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // 6. 聚合所有活跃家庭成员专属状态（供小组件独立绑定与切换）
    final familyMembers = <WidgetFamilyMember>[];
    for (final pooper in activePoopers) {
      final memberTodayRecords =
          todayRecords.where((r) => r.pooperId == pooper.id).toList();
      String lastDesc = '尚未排便';
      String? memberLastTimeStr;
      int? memberHoursSinceLast;
      String? memberLastRemark;

      PoopRecord? memberMostRecent =
          memberTodayRecords.isNotEmpty ? memberTodayRecords.first : null;

      if (memberMostRecent != null) {
        lastDesc =
            '今日 ${memberTodayRecords.length} 次 · ${DateFormat('HH:mm').format(memberMostRecent.startedAt)}';
      } else {
        // 查历史最近一条
        final lastHist = await (_db.select(_db.poopRecords)
              ..where((t) => t.pooperId.equals(pooper.id))
              ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
              ..limit(1))
            .get();
        if (lastHist.isNotEmpty) {
          memberMostRecent = lastHist.first;
          final diffDays = now.difference(memberMostRecent.startedAt).inDays;
          lastDesc = diffDays == 1 ? '昨天' : '${diffDays}天前';
        }
      }

      if (memberMostRecent != null) {
        memberLastTimeStr =
            DateFormat('HH:mm').format(memberMostRecent.startedAt);
        memberHoursSinceLast =
            now.difference(memberMostRecent.startedAt).inHours;

        final mNotes = await (_db.select(_db.poopNotes)
              ..where((t) => t.recordId.equals(memberMostRecent!.id))
              ..orderBy([(t) => OrderingTerm.asc(t.notedAt)]))
            .get();
        if (mNotes.isNotEmpty) {
          memberLastRemark = mNotes.first.content;
        }
      }

      final scheme = avatarColorFor(pooper.id);
      final bgHex = '#${(scheme.bg.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
      final fgHex = '#${(scheme.fg.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
      final avatarB64 = (pooper.avatarBlob != null && pooper.avatarBlob!.isNotEmpty)
          ? base64Encode(pooper.avatarBlob!)
          : null;

      familyMembers.add(
        WidgetFamilyMember(
          id: pooper.id,
          name: pooper.name,
          iconKey: pooper.iconKey,
          avatarBase64: avatarB64,
          initial: initialOf(pooper.name),
          colorBg: bgHex,
          colorFg: fgHex,
          todayCount: memberTodayRecords.length,
          lastTimeDesc: lastDesc,
          lastTimeStr: memberLastTimeStr,
          hoursSinceLast: memberHoursSinceLast,
          lastRemark: memberLastRemark,
        ),
      );
    }

    // 6b. 获取全家最近一条便签速记流水
    WidgetRecentNote? recentNote;
    final latestNotes = await (_db.select(_db.poopNotes)
          ..orderBy([(t) => OrderingTerm.desc(t.notedAt)])
          ..limit(1))
        .get();
    if (latestNotes.isNotEmpty) {
      final note = latestNotes.first;
      final rec = await (_db.select(_db.poopRecords)
            ..where((t) => t.id.equals(note.recordId)))
          .getSingleOrNull();
      if (rec != null) {
        final pooper = pooperMap[rec.pooperId];
        final dur = rec.endedAt != null
            ? rec.endedAt!.difference(rec.startedAt).inMinutes
            : 0;
        recentNote = WidgetRecentNote(
          pooperName: pooper?.name ?? '我',
          iconKey: pooper?.iconKey ?? 'dog',
          timeStr: DateFormat('HH:mm').format(rec.startedAt),
          durationMinutes: dur,
          text: note.content,
        );
      }
    }

    // 7. 读取暗号模式开关
    final prefs = await SharedPreferences.getInstance();
    final isIncognito = prefs.getBool(_keyIncognito) ?? false;

    final defaultScheme = avatarColorFor(defaultPooper.id);
    final defaultBgHex = '#${(defaultScheme.bg.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
    final defaultFgHex = '#${(defaultScheme.fg.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
    final defaultAvatarB64 = (defaultPooper.avatarBlob != null && defaultPooper.avatarBlob!.isNotEmpty)
        ? base64Encode(defaultPooper.avatarBlob!)
        : null;

    return WidgetSnapshot(
      updatedAt: now.toIso8601String(),
      isIncognito: isIncognito,
      defaultPooper: WidgetPooperInfo(
        id: defaultPooper.id,
        name: defaultPooper.name,
        iconKey: defaultPooper.iconKey,
        avatarBase64: defaultAvatarB64,
        initial: initialOf(defaultPooper.name),
        colorBg: defaultBgHex,
        colorFg: defaultFgHex,
      ),
      liveSession: liveSession,
      todaySummary: todaySummary,
      weekStreakDays: streakDays,
      weekDays: widgetWeekDays,
      familyMembers: familyMembers,
      recentNote: recentNote,
    );
  }

  /// 同步快照到系统小组件
  Future<void> sync() async {
    try {
      final snapshot = await buildSnapshot();
      final jsonStr = snapshot.toJsonString();
      await _channel.invokeMethod('updateSnapshot', {
        'snapshotJson': jsonStr,
      });
      debugPrint('[WIDGET-SYNC] 快照同步成功, updatedAt=${snapshot.updatedAt}');
    } catch (e) {
      // 在不支持小组件的平台或模拟器不中断主流程
      debugPrint('[WIDGET-SYNC] 同步异常 (可忽略): $e');
    }
  }
}

/// 全局单例门面，供业务层极简调用
class WidgetSyncManager {
  static WidgetSnapshotService? _service;

  static void initialize(AppDatabase db) {
    _service = WidgetSnapshotService(db);
  }

  static Future<void> sync(AppDatabase db) async {
    _service ??= WidgetSnapshotService(db);
    await _service?.sync();
  }
}
