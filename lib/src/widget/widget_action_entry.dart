import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/database.dart';
import '../data/record_actions.dart';
import 'widget_snapshot_service.dart';

/// 桌面小组件动作的**无界面执行入口**。
///
/// 点小组件上的「现在开屙 / 完成打卡」不该把用户拽进 App —— 原生侧会临时拉起
/// 一个没有 UI 的 `FlutterEngine` 执行这个入口（见 `WidgetActionRunner.kt`），
/// 这里复用主 App 完全相同的数据访问代码（drift + 业务方法），写完把新快照
/// 推回原生，然后自己收工。
///
/// ## 为什么不在 Kotlin 里直接写 SQLite
///
/// 那样确实更省事，但要复刻一整套业务契约：drift 的 DateTime 编码、
/// `ux_active_record` 唯一索引（一个人只能挂一条进行中记录）、
/// 外键约束、以及各种边界（重复开屙、记录已被别处结束……）。
/// 在原生复刻一份，迟早会在某次 schema 变更后**悄悄写坏用户数据**。
/// 让 Dart 去写，规则永远只有一份。
///
/// ## ⚠ 这个函数本身不能直接当 entrypoint 用
///
/// Flutter 的 `DartEntrypoint` **只在根库（`main.dart`）的顶层作用域**按名字
/// 解析函数，放在别的库里会直接报 `Could not resolve main entrypoint function`。
/// 所以真正的入口是 `main.dart` 里那个同名的转发函数，它再调到这里。
void runWidgetActionEntrypoint() {
  WidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.poopedyet.app/widget_action');

  Future<void> run() async {
    Map<dynamic, dynamic>? args;
    try {
      args = await channel.invokeMethod<Map<dynamic, dynamic>>('getPendingAction');
    } catch (e) {
      debugPrint('[WIDGET-ACTION] 取待执行动作失败: $e');
    }

    if (args != null) {
      try {
        await _performAction(args);
      } catch (e) {
        debugPrint('[WIDGET-ACTION] 执行失败: $e');
      }
    }

    // 无论成功失败都要回报，否则原生侧那个临时引擎会一直挂着。
    try {
      await channel.invokeMethod<void>('finished');
    } catch (_) {
      // 引擎可能已经被销毁，忽略
    }
  }

  unawaited(run());
}

/// 真正落地：开一条新记录，或结束一条进行中的记录。
Future<void> _performAction(Map<dynamic, dynamic> args) async {
  final db = AppDatabase();
  try {
    switch (args['action']) {
      case 'start':
        final pooperId = (args['pooperId'] as String?)?.trim();
        await db.startPoop(
          pooperId: (pooperId == null || pooperId.isEmpty) ? null : pooperId,
        );
      case 'finish':
        final recordId = (args['recordId'] as String?)?.trim();
        if (recordId == null || recordId.isEmpty) return;
        await db.endPoop(recordId);
      default:
        return;
    }

    // 写完立刻把新快照推回原生，桌面上的组件马上就能看到结果 ——
    // 不然用户会觉得「点了没反应」。
    await WidgetSyncManager.sync(db);
  } finally {
    await db.close();
  }
}
