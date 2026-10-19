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
    this.weeklySummary = const WidgetWeeklySummary(totalCount: 0, activeDays: 0),
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
      weeklySummary: json['weeklySummary'] != null
          ? WidgetWeeklySummary.fromJson(
              json['weeklySummary'] as Map<String, dynamic>,
            )
          : const WidgetWeeklySummary(totalCount: 0, activeDays: 0),
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

  /// 本周小结，4×4 底部那块的主信息。
  final WidgetWeeklySummary weeklySummary;

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
        'weeklySummary': weeklySummary.toJson(),
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
    this.pooperId,
    this.pooperName,
  });

  factory WidgetLiveSession.fromJson(Map<String, dynamic> json) {
    return WidgetLiveSession(
      isLive: json['isLive'] as bool? ?? false,
      recordId: json['recordId'] as String?,
      startedAtMillis: json['startedAtMillis'] as int?,
      elapsedMinutes: json['elapsedMinutes'] as int? ?? 0,
      pooperId: json['pooperId'] as String?,
      pooperName: json['pooperName'] as String?,
    );
  }

  final bool isLive;
  final String? recordId;
  final int? startedAtMillis;
  final int elapsedMinutes;

  /// 正在屙的是谁。
  ///
  /// 这个字段不是装饰：家里两个人可能同时开着计时，锁屏通知与灵动胶囊
  /// 必须显示**实际那个人**的名字，而不是默认成员的名字。
  final String? pooperId;
  final String? pooperName;

  Map<String, dynamic> toJson() => {
        'isLive': isLive,
        'recordId': recordId,
        'startedAtMillis': startedAtMillis,
        'elapsedMinutes': elapsedMinutes,
        'pooperId': pooperId,
        'pooperName': pooperName,
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
    this.pooperCounts = const {},
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
      pooperCounts: (json['pooperCounts'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
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

  /// 当天每位成员的打卡次数，键为 `pooperId`。
  ///
  /// 为什么不能只用 [count]：小组件可以绑定到具体某一位成员，
  /// 这时周历该点亮的是**TA 自己**的打卡。用全家汇总的话，
  /// 「我的组件」会一直显示别人的记录，成员一多就完全失真。
  final Map<String, int> pooperCounts;

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
        'pooperCounts': pooperCounts,
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
    this.isArchived = false,
    this.isLive = false,
    this.liveRecordId,
    this.liveStartedAtMillis,
    this.streakDays = 0,
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
      isArchived: json['isArchived'] as bool? ?? false,
      isLive: json['isLive'] as bool? ?? false,
      liveRecordId: json['liveRecordId'] as String?,
      liveStartedAtMillis: json['liveStartedAtMillis'] as int?,
      streakDays: json['streakDays'] as int? ?? 0,
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

  /// 是否已归档。
  ///
  /// 归档成员**仍然留在快照里**：小组件是按 `pooperId` 绑定的，
  /// 绑的人被归档之后组件还是得把 TA 的头像和名字画对，
  /// 而不是静默变成默认成员。选择界面则据此把归档的人挡在外面（或置灰）。
  final bool isArchived;

  /// 这位成员此刻是不是正在屙。
  ///
  /// 每个组件只该关心**自己绑定的那个人**：全家只要有一个人在屙就把所有
  /// 组件的按钮都变成「完成」，是说不通的 —— 点下去会结束别人的计时。
  final bool isLive;
  final String? liveRecordId;
  final int? liveStartedAtMillis;

  /// 这位成员自己的「连续顺畅」天数。
  ///
  /// 顶层那个 `weekStreakDays` 是**全家**的（任意一人有记录就算这天有），
  /// 拿它渲染某个成员的卡片会虚高 —— 一个人连着记、另一个人从没记过，
  /// 两个人的组件却都显示同一个数字。
  final int streakDays;

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
        'isArchived': isArchived,
        'isLive': isLive,
        'liveRecordId': liveRecordId,
        'liveStartedAtMillis': liveStartedAtMillis,
        'streakDays': streakDays,
      };
}

/// 本周（周一到今天）的全家小结。
///
/// 4×4 原来那块「最新便签速记」拿了 `weight=1`，在真机上占近四成高度，
/// 而便签是低频内容 —— 绝大多数时候那整块是「暂无近期便签速记」的空白，
/// 还只读、点不动，纯粹在浪费版面。
///
/// 换成这份小结之后：空白变成了有信息量的数字，便签仍然保留，
/// 只是退成一行、有才显示。
class WidgetWeeklySummary {
  const WidgetWeeklySummary({
    required this.totalCount,
    required this.activeDays,
    this.mostActiveName,
    this.mostActiveCount = 0,
  });

  factory WidgetWeeklySummary.fromJson(Map<String, dynamic> json) {
    return WidgetWeeklySummary(
      totalCount: json['totalCount'] as int? ?? 0,
      activeDays: json['activeDays'] as int? ?? 0,
      mostActiveName: json['mostActiveName'] as String?,
      mostActiveCount: json['mostActiveCount'] as int? ?? 0,
    );
  }

  /// 本周全家合计次数。
  final int totalCount;

  /// 本周有记录的天数（今天还没记就不算）。
  final int activeDays;

  /// 本周最勤的那位；一个人都没记录时为 null。
  final String? mostActiveName;
  final int mostActiveCount;

  Map<String, dynamic> toJson() => {
        'totalCount': totalCount,
        'activeDays': activeDays,
        'mostActiveName': mostActiveName,
        'mostActiveCount': mostActiveCount,
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
