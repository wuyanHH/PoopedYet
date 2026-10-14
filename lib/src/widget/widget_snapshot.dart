import 'dart:convert';

/// 桌面小组件轻量数据快照模型。
///
/// 独立于 Drift 数据库实体，设计为扁平、易序列化、原生端极简解析的 JSON 契约。
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.updatedAt,
    required this.isIncognito,
    required this.defaultPooper,
    required this.liveSession,
    required this.todaySummary,
    required this.weekStreakDays,
    required this.weekDays,
    required this.familyMembers,
    this.recentNote,
  });

  factory WidgetSnapshot.fromJson(Map<String, dynamic> json) {
    return WidgetSnapshot(
      updatedAt: json['updatedAt'] as String? ?? '',
      isIncognito: json['isIncognito'] as bool? ?? false,
      defaultPooper: WidgetPooperInfo.fromJson(
        json['defaultPooper'] as Map<String, dynamic>? ?? {},
      ),
      liveSession: WidgetLiveSession.fromJson(
        json['liveSession'] as Map<String, dynamic>? ?? {},
      ),
      todaySummary: WidgetTodaySummary.fromJson(
        json['todaySummary'] as Map<String, dynamic>? ?? {},
      ),
      weekStreakDays: json['weekStreakDays'] as int? ?? 0,
      weekDays: (json['weekDays'] as List<dynamic>? ?? [])
          .map((e) => WidgetWeekDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      familyMembers: (json['familyMembers'] as List<dynamic>? ?? [])
          .map((e) => WidgetFamilyMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentNote: json['recentNote'] != null
          ? WidgetRecentNote.fromJson(
              json['recentNote'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String updatedAt;
  final bool isIncognito;
  final WidgetPooperInfo defaultPooper;
  final WidgetLiveSession liveSession;
  final WidgetTodaySummary todaySummary;
  final int weekStreakDays;
  final List<WidgetWeekDay> weekDays;
  final List<WidgetFamilyMember> familyMembers;
  final WidgetRecentNote? recentNote;

  Map<String, dynamic> toJson() => {
        'updatedAt': updatedAt,
        'isIncognito': isIncognito,
        'defaultPooper': defaultPooper.toJson(),
        'liveSession': liveSession.toJson(),
        'todaySummary': todaySummary.toJson(),
        'weekStreakDays': weekStreakDays,
        'weekDays': weekDays.map((e) => e.toJson()).toList(),
        'familyMembers': familyMembers.map((e) => e.toJson()).toList(),
        'recentNote': recentNote?.toJson(),
      };

  String toJsonString() => jsonEncode(toJson());
}

class WidgetPooperInfo {
  const WidgetPooperInfo({
    required this.id,
    required this.name,
    this.iconKey,
    this.avatarBase64,
    required this.initial,
    required this.colorBg,
    required this.colorFg,
  });

  factory WidgetPooperInfo.fromJson(Map<String, dynamic> json) {
    return WidgetPooperInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '我',
      iconKey: json['iconKey'] as String?,
      avatarBase64: json['avatarBase64'] as String?,
      initial: json['initial'] as String? ?? '我',
      colorBg: json['colorBg'] as String? ?? '#E8E2D9',
      colorFg: json['colorFg'] as String? ?? '#5C4033',
    );
  }

  final String id;
  final String name;
  final String? iconKey;
  final String? avatarBase64;
  final String initial;
  final String colorBg;
  final String colorFg;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'avatarBase64': avatarBase64,
        'initial': initial,
        'colorBg': colorBg,
        'colorFg': colorFg,
      };
}

class WidgetLiveSession {
  const WidgetLiveSession({
    required this.isLive,
    this.recordId,
    this.startedAtMillis,
    this.elapsedMinutes = 0,
  });

  factory WidgetLiveSession.fromJson(Map<String, dynamic> json) {
    return WidgetLiveSession(
      isLive: json['isLive'] as bool? ?? false,
      recordId: json['recordId'] as String?,
      startedAtMillis: json['startedAtMillis'] as int?,
      elapsedMinutes: json['elapsedMinutes'] as int? ?? 0,
    );
  }

  final bool isLive;
  final String? recordId;
  final int? startedAtMillis;
  final int elapsedMinutes;

  Map<String, dynamic> toJson() => {
        'isLive': isLive,
        'recordId': recordId,
        'startedAtMillis': startedAtMillis,
        'elapsedMinutes': elapsedMinutes,
      };
}

class WidgetTodaySummary {
  const WidgetTodaySummary({
    required this.dateStr,
    required this.dayNum,
    required this.weekdayName,
    required this.totalCount,
    this.lastTimeStr,
    this.hoursSinceLast,
    this.lastRemark,
  });

  factory WidgetTodaySummary.fromJson(Map<String, dynamic> json) {
    return WidgetTodaySummary(
      dateStr: json['dateStr'] as String? ?? '',
      dayNum: json['dayNum'] as int? ?? 1,
      weekdayName: json['weekdayName'] as String? ?? '周一',
      totalCount: json['totalCount'] as int? ?? 0,
      lastTimeStr: json['lastTimeStr'] as String?,
      hoursSinceLast: json['hoursSinceLast'] as int?,
      lastRemark: json['lastRemark'] as String?,
    );
  }

  final String dateStr;
  final int dayNum;
  final String weekdayName;
  final int totalCount;
  final String? lastTimeStr;
  final int? hoursSinceLast;
  final String? lastRemark;

  Map<String, dynamic> toJson() => {
        'dateStr': dateStr,
        'dayNum': dayNum,
        'weekdayName': weekdayName,
        'totalCount': totalCount,
        'lastTimeStr': lastTimeStr,
        'hoursSinceLast': hoursSinceLast,
        'lastRemark': lastRemark,
      };
}

class WidgetWeekDay {
  const WidgetWeekDay({
    required this.dateStr,
    required this.dayNum,
    required this.weekday,
    required this.weekdayLabel,
    required this.isToday,
    required this.isHoliday,
    required this.isWorkday,
    required this.count,
    required this.iconKeys,
  });

  factory WidgetWeekDay.fromJson(Map<String, dynamic> json) {
    return WidgetWeekDay(
      dateStr: json['dateStr'] as String? ?? '',
      dayNum: json['dayNum'] as int? ?? 1,
      weekday: json['weekday'] as int? ?? 1,
      weekdayLabel: json['weekdayLabel'] as String? ?? '一',
      isToday: json['isToday'] as bool? ?? false,
      isHoliday: json['isHoliday'] as bool? ?? false,
      isWorkday: json['isWorkday'] as bool? ?? false,
      count: json['count'] as int? ?? 0,
      iconKeys: (json['iconKeys'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  final String dateStr;
  final int dayNum;
  final int weekday;
  final String weekdayLabel;
  final bool isToday;
  final bool isHoliday;
  final bool isWorkday;
  final int count;
  final List<String> iconKeys;

  Map<String, dynamic> toJson() => {
        'dateStr': dateStr,
        'dayNum': dayNum,
        'weekday': weekday,
        'weekdayLabel': weekdayLabel,
        'isToday': isToday,
        'isHoliday': isHoliday,
        'isWorkday': isWorkday,
        'count': count,
        'iconKeys': iconKeys,
      };
}

class WidgetFamilyMember {
  const WidgetFamilyMember({
    required this.id,
    required this.name,
    this.iconKey,
    this.avatarBase64,
    required this.initial,
    required this.colorBg,
    required this.colorFg,
    required this.todayCount,
    required this.lastTimeDesc,
    this.lastTimeStr,
    this.hoursSinceLast,
    this.lastRemark,
  });

  factory WidgetFamilyMember.fromJson(Map<String, dynamic> json) {
    return WidgetFamilyMember(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      iconKey: json['iconKey'] as String?,
      avatarBase64: json['avatarBase64'] as String?,
      initial: json['initial'] as String? ?? '我',
      colorBg: json['colorBg'] as String? ?? '#E8E2D9',
      colorFg: json['colorFg'] as String? ?? '#5C4033',
      todayCount: json['todayCount'] as int? ?? 0,
      lastTimeDesc: json['lastTimeDesc'] as String? ?? '',
      lastTimeStr: json['lastTimeStr'] as String?,
      hoursSinceLast: json['hoursSinceLast'] as int?,
      lastRemark: json['lastRemark'] as String?,
    );
  }

  final String id;
  final String name;
  final String? iconKey;
  final String? avatarBase64;
  final String initial;
  final String colorBg;
  final String colorFg;
  final int todayCount;
  final String lastTimeDesc;
  final String? lastTimeStr;
  final int? hoursSinceLast;
  final String? lastRemark;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'avatarBase64': avatarBase64,
        'initial': initial,
        'colorBg': colorBg,
        'colorFg': colorFg,
        'todayCount': todayCount,
        'lastTimeDesc': lastTimeDesc,
        'lastTimeStr': lastTimeStr,
        'hoursSinceLast': hoursSinceLast,
        'lastRemark': lastRemark,
      };
}

class WidgetRecentNote {
  const WidgetRecentNote({
    required this.pooperName,
    required this.iconKey,
    required this.timeStr,
    required this.durationMinutes,
    required this.text,
  });

  factory WidgetRecentNote.fromJson(Map<String, dynamic> json) {
    return WidgetRecentNote(
      pooperName: json['pooperName'] as String? ?? '我',
      iconKey: json['iconKey'] as String? ?? 'dog',
      timeStr: json['timeStr'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      text: json['text'] as String? ?? '',
    );
  }

  final String pooperName;
  final String iconKey;
  final String timeStr;
  final int durationMinutes;
  final String text;

  Map<String, dynamic> toJson() => {
        'pooperName': pooperName,
        'iconKey': iconKey,
        'timeStr': timeStr,
        'durationMinutes': durationMinutes,
        'text': text,
      };
}
