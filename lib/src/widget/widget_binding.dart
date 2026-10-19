import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 桌面上一个已放置的小组件实例的成员绑定。
///
/// 每个实例各自绑定一位屙屎人：同一个「2×2 撕历」放两个，
/// 一个看我、一个看咪咪，互不干扰。
@immutable
class WidgetBinding {
  const WidgetBinding({
    required this.widgetId,
    required this.type,
    required this.typeLabel,
    this.pooperId,
    required this.pooperName,
    required this.isFollowingDefault,
  });

  factory WidgetBinding.fromJson(Map<String, dynamic> json) {
    final rawPooperId = json['pooperId'];
    return WidgetBinding(
      widgetId: (json['widgetId'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'small',
      typeLabel: json['typeLabel'] as String? ?? '桌面小组件',
      pooperId: rawPooperId is String && rawPooperId.isNotEmpty
          ? rawPooperId
          : null,
      pooperName: json['pooperName'] as String? ?? '我',
      isFollowingDefault: json['isFollowingDefault'] as bool? ?? true,
    );
  }

  /// Android 分配给这个小组件实例的 ID。
  final int widgetId;

  /// `small` / `medium` / `large`。
  final String type;

  /// 尺寸的中文说明，如「撕历打卡 (2×2)」。
  final String typeLabel;

  /// 绑定的人；`null` 表示「跟随默认成员」。
  final String? pooperId;

  /// 实际生效的人名（已解析过「跟随默认成员」的回退）。
  final String pooperName;

  final bool isFollowingDefault;
}

/// 与 Android 原生小组件的桥接层。
///
/// 只做两件事：读出桌面上已放置的组件、改写某个组件绑定的人。
/// 真正的渲染始终在原生侧完成 —— 这里不碰布局。
class WidgetBindingService {
  const WidgetBindingService();

  static const _channel = MethodChannel('com.poopedyet.app/widget');

  /// 列出桌面上所有已放置的小组件实例。
  ///
  /// 非 Android 平台或原生侧异常时返回空列表：管理页据此显示引导态，
  /// 而不是把异常抛到 UI 上。
  Future<List<WidgetBinding>> listBindings() async {
    try {
      final raw = await _channel.invokeMethod<String>('listWidgetBindings');
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(WidgetBinding.fromJson)
          .toList(growable: false);
    } catch (e) {
      debugPrint('[WIDGET-BINDING] 读取小组件绑定失败（可忽略）: $e');
      return const [];
    }
  }

  /// 改写某个小组件绑定的屙屎人。
  ///
  /// [pooperId] 传 `null` 表示「跟随默认成员」。原生侧会立刻重绘桌面上
  /// 对应的小组件，不需要重启 App 或重新添加组件。
  Future<bool> setBinding({required int widgetId, String? pooperId}) async {
    try {
      await _channel.invokeMethod('setWidgetPooper', {
        'widgetId': widgetId,
        'pooperId': pooperId,
      });
      return true;
    } catch (e) {
      debugPrint('[WIDGET-BINDING] 写入小组件绑定失败: $e');
      return false;
    }
  }

  /// 请求把某一款小组件钉到桌面（`AppWidgetManager.requestPinAppWidget`）。
  ///
  /// 返回 `false` 表示系统版本低于 Android 8.0，或当前启动器不支持该能力 ——
  /// 两种情况下调用方都应引导用户手动长按桌面添加。
  Future<bool> requestPin(String type) async {
    try {
      final pinned = await _channel.invokeMethod<bool>(
        'requestPinWidget',
        {'type': type},
      );
      return pinned ?? false;
    } catch (e) {
      debugPrint('[WIDGET-BINDING] 请求固定小组件失败: $e');
      return false;
    }
  }

  /// 把所有「绑定到某位成员」的小组件改回「跟随默认成员」。
  ///
  /// **归档或彻底删除一个人之后必须调用。** 小组件是按 `pooperId` 绑定的：
  /// 人没了、绑定还留着的话，那个组件会静默回退成显示默认成员 ——
  /// 用户看到的是「头像莫名换成了别人」，而且在任何选择界面里都找不到原因。
  ///
  /// 返回被清理的组件个数。
  Future<int> clearBindingsFor(String pooperId) async {
    if (pooperId.isEmpty) return 0;

    final bindings = await listBindings();
    var cleared = 0;
    for (final binding in bindings) {
      if (binding.pooperId != pooperId) continue;
      // pooperId 传 null 即写回「跟随默认成员」
      if (await setBinding(widgetId: binding.widgetId)) {
        cleared++;
      }
    }
    return cleared;
  }
}

final widgetBindingServiceProvider = Provider<WidgetBindingService>(
  (ref) => const WidgetBindingService(),
);
