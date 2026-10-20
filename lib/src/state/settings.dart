import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../calendar/calendar_math.dart';
import '../theme/tokens.dart';
import 'calendar_view.dart';

/// `SharedPreferences` 实例。**必须在 `main()` 里用 override 注入** ——
/// 它的初始化是异步的，而在 build 里 await 会让每一帧都可能 rebuild。
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPrefsProvider 必须在 main() 里 overrideWithValue 注入',
  ),
);

/// 日历字号档位。
///
/// 日历格固定 58px，系统字体放到 2.0× 时 6 行月份要吃掉约 477px，
/// 而可用高度只有约 553px —— 记录列表会被挤没。所以日历格内的字号有上限，
/// 再给一个独立档位让需要大字的人不必受系统档位摆布。
///
/// 见 `docs/design-system.md` §9e。
enum CalendarTextSize {
  small(0.9),
  medium(1.0),
  large(1.15);

  const CalendarTextSize(this.scale);

  final double scale;
}

/// 系统字号在日历格内的允许上限。
///
/// 安卓字体档位是 1.0 / 1.15 / 1.3 / 1.5 / 2.0，**1.3 正好是「大」这一档**，
/// 常用需求全覆盖，只有「特大 / 最大」会被截住。
const double kCalendarMaxSystemScale = 1.3;

/// 记录列表排序方式。
enum RecordSortOrder {
  /// 倒序：时间晚（最新）的排在最前（默认）。
  desc,

  /// 正序：时间早（最早）的排在最前。
  asc;
}

/// 用户设置。
class Settings {
  const Settings({
    this.weekStart = WeekStart.monday,
    this.showBadges = true,
    this.showHolidayTags = true,
    this.weekendBrandColor = true,
    this.hideArchivedPoopers = false,
    this.calendarTextSize = CalendarTextSize.medium,
    this.themeMode = AppThemeMode.system,
    this.themeColor = AppThemeColor.caramel,
    this.defaultCalendarMode = CalendarMode.month,
    this.recordSortOrder = RecordSortOrder.desc,
    this.liveIslandEnabled = true,
  });

  /// 每周起始日。日历网格的偏移量直接依赖它。
  final WeekStart weekStart;

  /// 日期格里显示头像与次数（关掉只显示当天总数）。
  final bool showBadges;

  /// 显示休 / 班角标。
  final bool showHolidayTags;

  /// 周末数字用焦糖色。
  final bool weekendBrandColor;

  /// 日历徽标与统计里隐藏已归档的屙屎人。
  ///
  /// 默认 **false**：归档的人历史仍在，默认隐藏会让日历数字莫名变小，
  /// 用户会以为数据丢了。
  final bool hideArchivedPoopers;

  final CalendarTextSize calendarTextSize;

  /// 深浅色主题模式（跟随系统 / 浅色 / 深色）。
  final AppThemeMode themeMode;

  /// 主题色彩方案（经典焦糖 / 抹茶森林 / 深海微风 / 烟雨丁香 / 落日陶土）。
  final AppThemeColor themeColor;

  /// 默认展示视图（打开软件时默认以月历或周历展示）。
  final CalendarMode defaultCalendarMode;

  /// 记录列表的排序规则（时间倒序 / 时间正序，默认时间倒序）。
  final RecordSortOrder recordSortOrder;

  /// 实时灵动胶囊 / vivo 原子岛 / 状态栏与锁屏前台跳秒通知。
  /// 关闭后，开屙时不展示前台通知，不调用前台服务。
  final bool liveIslandEnabled;

  Settings copyWith({
    WeekStart? weekStart,
    bool? showBadges,
    bool? showHolidayTags,
    bool? weekendBrandColor,
    bool? hideArchivedPoopers,
    CalendarTextSize? calendarTextSize,
    AppThemeMode? themeMode,
    AppThemeColor? themeColor,
    CalendarMode? defaultCalendarMode,
    RecordSortOrder? recordSortOrder,
    bool? liveIslandEnabled,
  }) {
    return Settings(
      weekStart: weekStart ?? this.weekStart,
      showBadges: showBadges ?? this.showBadges,
      showHolidayTags: showHolidayTags ?? this.showHolidayTags,
      weekendBrandColor: weekendBrandColor ?? this.weekendBrandColor,
      hideArchivedPoopers: hideArchivedPoopers ?? this.hideArchivedPoopers,
      calendarTextSize: calendarTextSize ?? this.calendarTextSize,
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      defaultCalendarMode: defaultCalendarMode ?? this.defaultCalendarMode,
      recordSortOrder: recordSortOrder ?? this.recordSortOrder,
      liveIslandEnabled: liveIslandEnabled ?? this.liveIslandEnabled,
    );
  }
}

const _kWeekStart = 'settings.weekStart';
const _kShowBadges = 'settings.showBadges';
const _kShowHolidayTags = 'settings.showHolidayTags';
const _kWeekendBrand = 'settings.weekendBrandColor';
const _kHideArchived = 'settings.hideArchivedPoopers';
const _kCalTextSize = 'settings.calendarTextSize';
const _kThemeMode = 'settings.themeMode';
const _kThemeColor = 'settings.themeColor';
const _kDefaultCalMode = 'settings.defaultCalendarMode';
const _kRecordSortOrder = 'settings.recordSortOrder';
const _kLiveIslandEnabled = 'settings.liveIslandEnabled';

/// 首启的「已自动创建『我』」提示条是否已被关掉。
/// 关过就永不再出现。
const String kFirstRunHintDismissed = 'firstRun.hintDismissed';

/// 设置的状态。
///
/// 同步读取：所有值在 [build] 时从已经加载好的 [SharedPreferences] 里取，
/// 写入时同步更新内存状态再落盘（不 await 落盘，UI 不该等磁盘）。
class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() {
    final p = ref.watch(sharedPrefsProvider);
    final ws = p.getString(_kWeekStart);
    final ts = p.getString(_kCalTextSize);
    final tm = p.getString(_kThemeMode);
    final tc = p.getString(_kThemeColor);
    final dcm = p.getString(_kDefaultCalMode);
    final rso = p.getString(_kRecordSortOrder);

    return Settings(
      weekStart: WeekStart.values.firstWhere(
        (e) => e.name == ws,
        orElse: () => WeekStart.monday,
      ),
      showBadges: p.getBool(_kShowBadges) ?? true,
      showHolidayTags: p.getBool(_kShowHolidayTags) ?? true,
      weekendBrandColor: p.getBool(_kWeekendBrand) ?? true,
      hideArchivedPoopers: p.getBool(_kHideArchived) ?? false,
      calendarTextSize: CalendarTextSize.values.firstWhere(
        (e) => e.name == ts,
        orElse: () => CalendarTextSize.medium,
      ),
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == tm,
        orElse: () => AppThemeMode.system,
      ),
      themeColor: AppThemeColor.values.firstWhere(
        (e) => e.name == tc,
        orElse: () => AppThemeColor.caramel,
      ),
      defaultCalendarMode: CalendarMode.values.firstWhere(
        (e) => e.name == dcm,
        orElse: () => CalendarMode.month,
      ),
      recordSortOrder: RecordSortOrder.values.firstWhere(
        (e) => e.name == rso,
        orElse: () => RecordSortOrder.desc,
      ),
      liveIslandEnabled: p.getBool(_kLiveIslandEnabled) ?? true,
    );
  }

  SharedPreferences get _p => ref.read(sharedPrefsProvider);

  void setRecordSortOrder(RecordSortOrder v) {
    state = state.copyWith(recordSortOrder: v);
    _p.setString(_kRecordSortOrder, v.name);
  }

  void setDefaultCalendarMode(CalendarMode v) {
    state = state.copyWith(defaultCalendarMode: v);
    _p.setString(_kDefaultCalMode, v.name);
  }

  void setWeekStart(WeekStart v) {
    state = state.copyWith(weekStart: v);
    _p.setString(_kWeekStart, v.name);
  }

  void setShowBadges(bool v) {
    state = state.copyWith(showBadges: v);
    _p.setBool(_kShowBadges, v);
  }

  void setShowHolidayTags(bool v) {
    state = state.copyWith(showHolidayTags: v);
    _p.setBool(_kShowHolidayTags, v);
  }

  void setWeekendBrandColor(bool v) {
    state = state.copyWith(weekendBrandColor: v);
    _p.setBool(_kWeekendBrand, v);
  }

  void setHideArchivedPoopers(bool v) {
    state = state.copyWith(hideArchivedPoopers: v);
    _p.setBool(_kHideArchived, v);
  }

  void setCalendarTextSize(CalendarTextSize v) {
    state = state.copyWith(calendarTextSize: v);
    _p.setString(_kCalTextSize, v.name);
  }

  void setThemeMode(AppThemeMode v) {
    state = state.copyWith(themeMode: v);
    _p.setString(_kThemeMode, v.name);
  }

  void setThemeColor(AppThemeColor v) {
    state = state.copyWith(themeColor: v);
    _p.setString(_kThemeColor, v.name);
  }

  void setLiveIslandEnabled(bool v) {
    state = state.copyWith(liveIslandEnabled: v);
    _p.setBool(_kLiveIslandEnabled, v);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
