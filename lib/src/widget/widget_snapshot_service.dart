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

    // 1. 获取成员：一次取全表，活跃的在前、归档的在后。
    //
    // 为什么连归档的也要带上：小组件是按 pooperId 绑定的，绑的人被归档之后
    // 那个组件仍然要把 TA 的头像和名字画对。只给活跃成员的话，原生侧查不到
    // 就会静默回退成默认成员 —— 用户看到的就是「头像莫名变成了另一个人」。
    final defaultPooper = await _db.ensureDefaultPooper();
    final allPoopers = await (_db.select(_db.poopers)
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .get();
    final pooperMap = {for (final p in allPoopers) p.id: p};

    // 1. 读取基础配置与开关（暗号模式、实时灵动胶囊开关）
    final prefs = await SharedPreferences.getInstance();
    final isIncognito = prefs.getBool(_keyIncognito) ?? false;
    final isLiveIslandEnabled = prefs.getBool('settings.liveIslandEnabled') ?? true;

    // 2. 检查进行中的记录 —— **按人分开**。
    //
    // 每个人同时最多挂一条（由 ux_active_record 唯一索引保证），
    // 而每个小组件只该看自己绑定那位的状态：家里有人开屙就把所有组件的
    // 按钮都变成「完成」，点下去会结束别人的计时。
    final activeRecords = await (_db.select(_db.poopRecords)
          ..where(
            (t) =>
                t.endedAt.isNull() &
                t.endUnknown.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();

    final liveByPooper = <String, PoopRecord>{};
    for (final record in activeRecords) {
      // 已按 started_at 倒序，首次出现的即该成员最新的那条
      liveByPooper.putIfAbsent(record.pooperId, () => record);
    }

    // 顶层 liveSession 仍然保留「全家最新的一条」，供锁屏胶囊 / 前台服务使用；
    // 如果用户在设置中关闭了灵动岛/实时胶囊，直接置为 isLive: false，
    // 彻底阻断原生前台服务的启动，并让已运行的服务立刻停止！
    final anyLive = (activeRecords.isNotEmpty && isLiveIslandEnabled) ? activeRecords.first : null;
    final liveSession = anyLive != null
        ? WidgetLiveSession(
            isLive: true,
            recordId: anyLive.id,
            startedAtMillis: anyLive.startedAt.millisecondsSinceEpoch,
            elapsedMinutes: minutesBetween(anyLive.startedAt, now),
            pooperId: anyLive.pooperId,
            pooperName: pooperMap[anyLive.pooperId]?.name,
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
          pooperCounts: dayCounts,
        ),
      );
    }

    // 4.5 本周小结。
    //
    // 直接复用上面算好的 widgetWeekDays，不再多查一次库。
    // 4×4 底部原来那块「最新便签速记」拿了 weight=1、占近四成高度，
    // 却常年显示空白；换成这份小结之后，同样的位置有了真实信息量。
    final weeklyTotal = widgetWeekDays.fold<int>(0, (sum, d) => sum + d.count);
    final weeklyActiveDays = widgetWeekDays.where((d) => d.count > 0).length;

    final weeklyCountByPooper = <String, int>{};
    for (final day in widgetWeekDays) {
      day.pooperCounts.forEach((pooperId, count) {
        weeklyCountByPooper[pooperId] =
            (weeklyCountByPooper[pooperId] ?? 0) + count;
      });
    }
    String? weeklyTopName;
    var weeklyTopCount = 0;
    weeklyCountByPooper.forEach((pooperId, count) {
      if (count > weeklyTopCount) {
        weeklyTopCount = count;
        weeklyTopName = pooperMap[pooperId]?.name;
      }
    });
    final weeklySummary = WidgetWeeklySummary(
      totalCount: weeklyTotal,
      activeDays: weeklyActiveDays,
      mostActiveName: weeklyTopName,
      mostActiveCount: weeklyTopCount,
    );

    // 5. 连续顺畅天数（Streak）：一次批量查询 + 内存 Set 比对，杜绝 N+1 循环查库。
    //
    // 这里同时算出「全家」与「每位成员各自」两套打卡日期集合：单人卡片上的
    // 「连续顺畅 N 天」必须是 TA 自己的，用全家口径会虚高 —— 一个人天天记、
    // 另一个人从没记过，两个人的组件却显示同一个数字。
    final streakYearAgo = todayStart.subtract(const Duration(days: 366));
    final distinctDatesQuery = _db.selectOnly(_db.poopRecords, distinct: true)
      ..addColumns([_db.poopRecords.startedAt, _db.poopRecords.pooperId])
      ..where(_db.poopRecords.startedAt.isBiggerOrEqualValue(streakYearAgo));
    final dateRows = await distinctDatesQuery.get();

    final allActiveDateKeys = <String>{};
    final activeDateKeysByPooper = <String, Set<String>>{};
    for (final row in dateRows) {
      final startedAt = row.read(_db.poopRecords.startedAt);
      final pooperId = row.read(_db.poopRecords.pooperId);
      if (startedAt == null || pooperId == null) continue;
      final key = dayKey(startedAt);
      allActiveDateKeys.add(key);
      activeDateKeysByPooper.putIfAbsent(pooperId, () => <String>{}).add(key);
    }

    final streakDays = computeStreak(
      allActiveDateKeys,
      todayHasRecord: todayRecords.isNotEmpty,
      todayStart: todayStart,
    );

    // 6. 聚合所有家庭成员状态（含已归档 —— 归档的人仍可能被某个小组件绑着）
    final familyMembers = <WidgetFamilyMember>[];
    for (final pooper in allPoopers) {
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
          // 按**自然日**算差，不是按时长整除：
          // 昨晚 23:50 到今天 00:10 只隔 20 分钟，时长整除会得到 0 天，
          // 于是显示成「0天前」；按自然日则是「昨天」。
          final diffDays =
              todayStart.difference(startOfDay(memberMostRecent.startedAt)).inDays;
          lastDesc = switch (diffDays) {
            <= 0 => '今天',
            1 => '昨天',
            _ => '$diffDays天前',
          };
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
      final memberLive = liveByPooper[pooper.id];

      familyMembers.add(
        WidgetFamilyMember(
          id: pooper.id,
          name: pooper.name,
          iconKey: pooper.iconKey,
          avatarBase64: encodeAvatarBase64(pooper.id, pooper.avatarBlob),
          initial: initialOf(pooper.name),
          colorBg: bgHex,
          colorFg: fgHex,
          todayCount: memberTodayRecords.length,
          lastTimeDesc: lastDesc,
          lastTimeStr: memberLastTimeStr,
          hoursSinceLast: memberHoursSinceLast,
          lastRemark: memberLastRemark,
          isArchived: pooper.archivedAt != null,
          isLive: memberLive != null,
          liveRecordId: memberLive?.id,
          liveStartedAtMillis: memberLive?.startedAt.millisecondsSinceEpoch,
          streakDays: computeStreak(
            activeDateKeysByPooper[pooper.id] ?? const <String>{},
            todayHasRecord: memberTodayRecords.isNotEmpty,
            todayStart: todayStart,
          ),
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

    final defaultScheme = avatarColorFor(defaultPooper.id);
    final defaultBgHex = '#${(defaultScheme.bg.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
    final defaultFgHex = '#${(defaultScheme.fg.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';

    return WidgetSnapshot(
      updatedAt: now.toIso8601String(),
      isIncognito: isIncognito,
      defaultPooper: WidgetPooperInfo(
        id: defaultPooper.id,
        name: defaultPooper.name,
        iconKey: defaultPooper.iconKey,
        avatarBase64: encodeAvatarBase64(defaultPooper.id, defaultPooper.avatarBlob),
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
      weeklySummary: weeklySummary,
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

/// 头像 base64 的内存缓存。
///
/// 每次开屙、结束、补录都会重建一次快照，而头像 blob 动辄十几 KB ——
/// 每次都重新 `base64Encode` 一遍纯属浪费 CPU（一晚上能白编几百次），
/// 还会让快照 JSON 频繁产生无意义的新字符串。
///
/// 这里用「长度 + 首中尾字节」做指纹，内容没变就复用上一次的结果。
/// 指纹口径与 `pooper_avatar.dart` 里的图片缓存保持一致。
final Map<String, _AvatarBase64Entry> _avatarBase64Cache = {};

/// 从「有记录的日期集合」倒推连续天数。
///
/// [todayHasRecord] 为 false 时从**昨天**开始数：今天还没记并不代表断签，
/// 一天都没过完就判人归零，用户一打开 App 会以为自己断了。
int computeStreak(
  Set<String> activeDateKeys, {
  required bool todayHasRecord,
  required DateTime todayStart,
}) {
  if (activeDateKeys.isEmpty) return 0;

  var days = 0;
  var cursor = todayHasRecord ? todayStart : todayStart.subtract(const Duration(days: 1));
  while (days < 365) {
    if (!activeDateKeys.contains(dayKey(cursor))) break;
    days++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return days;
}

class _AvatarBase64Entry {
  const _AvatarBase64Entry(this.fingerprint, this.encoded);

  final int fingerprint;
  final String encoded;
}

/// 把头像 blob 编码成 base64；没有头像时返回 null。
String? encodeAvatarBase64(String pooperId, List<int>? blob) {
  if (blob == null || blob.isEmpty) return null;

  final fingerprint = Object.hash(
    blob.length,
    blob[0],
    blob[blob.length ~/ 2],
    blob[blob.length - 1],
  );
  final cached = _avatarBase64Cache[pooperId];
  if (cached != null && cached.fingerprint == fingerprint) {
    return cached.encoded;
  }

  final encoded = base64Encode(blob);
  _avatarBase64Cache[pooperId] = _AvatarBase64Entry(fingerprint, encoded);
  return encoded;
}
