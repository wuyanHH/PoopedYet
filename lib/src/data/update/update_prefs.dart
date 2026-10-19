import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/settings.dart' show sharedPrefsProvider;

/// 自动检查更新的偏好与本地状态。
///
/// 为什么不塞进 `Settings`：这几项是「更新模块」自己的运行状态
/// （上次查过什么时候、哪个版本被跳过了），不是用户可感知的界面设置。
/// 混进 `Settings.copyWith` 只会让那个已经很长的参数表再长一截。
class UpdatePrefs {
  const UpdatePrefs({
    this.autoCheck = true,
    this.lastCheckAt,
    this.skippedVersion,
    this.notifiedVersion,
  });

  /// 启动后是否静默检查更新。
  ///
  /// 默认 **true**：检查过程完全无声，只有真发现新版本时才会出现一次弹窗。
  final bool autoCheck;

  /// 上次发起检查的时间（无论成功还是失败）。
  final DateTime? lastCheckAt;

  /// 用户点过「跳过此版本」的版本号，自动检查不再为它弹窗。
  final String? skippedVersion;

  /// 已经弹过窗提醒过的版本号 —— 同一个版本只打扰一次。
  final String? notifiedVersion;

  UpdatePrefs copyWith({
    bool? autoCheck,
    DateTime? lastCheckAt,
    String? skippedVersion,
    String? notifiedVersion,
  }) {
    return UpdatePrefs(
      autoCheck: autoCheck ?? this.autoCheck,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      skippedVersion: skippedVersion ?? this.skippedVersion,
      notifiedVersion: notifiedVersion ?? this.notifiedVersion,
    );
  }
}

const _kAutoCheck = 'update.autoCheck';
const _kLastCheckAt = 'update.lastCheckAt';
const _kSkippedVersion = 'update.skippedVersion';
const _kNotifiedVersion = 'update.notifiedVersion';

/// 更新偏好状态。与 [SettingsNotifier] 一样：同步读、写完内存再落盘。
class UpdatePrefsNotifier extends Notifier<UpdatePrefs> {
  @override
  UpdatePrefs build() {
    final p = ref.watch(sharedPrefsProvider);
    final ts = p.getInt(_kLastCheckAt);
    return UpdatePrefs(
      autoCheck: p.getBool(_kAutoCheck) ?? true,
      lastCheckAt:
          ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null,
      skippedVersion: _orNull(p.getString(_kSkippedVersion)),
      notifiedVersion: _orNull(p.getString(_kNotifiedVersion)),
    );
  }

  static String? _orNull(String? v) => (v == null || v.isEmpty) ? null : v;

  /// 开关自动检查。
  ///
  /// 重新打开时清掉上次检查时间：下次冷启动会立刻查一次，
  /// 而不是让人再等满 24 小时。
  void setAutoCheck(bool value) {
    // copyWith 的可空参数用 `??` 兜底，传 null 表示「保持原值」，
    // 所以清空 lastCheckAt 只能在这里显式构造。
    state = UpdatePrefs(
      autoCheck: value,
      lastCheckAt: value ? null : state.lastCheckAt,
      skippedVersion: state.skippedVersion,
      notifiedVersion: state.notifiedVersion,
    );
    _p.setBool(_kAutoCheck, value);
    if (value) {
      _p.remove(_kLastCheckAt);
    }
  }

  /// 记下本次检查动作发生的时间（不区分成功失败）。
  void markChecked(DateTime at) {
    state = state.copyWith(lastCheckAt: at);
    _p.setInt(_kLastCheckAt, at.millisecondsSinceEpoch);
  }

  /// 用户选择跳过某个版本，之后自动检查不再为它弹窗。
  void skipVersion(String version) {
    state = state.copyWith(skippedVersion: version);
    _p.setString(_kSkippedVersion, version);
  }

  /// 记下已经为某个版本弹过提醒，避免重复打扰。
  void markNotified(String version) {
    state = state.copyWith(notifiedVersion: version);
    _p.setString(_kNotifiedVersion, version);
  }

  SharedPreferences get _p => ref.read(sharedPrefsProvider);
}

final updatePrefsProvider =
    NotifierProvider<UpdatePrefsNotifier, UpdatePrefs>(UpdatePrefsNotifier.new);
