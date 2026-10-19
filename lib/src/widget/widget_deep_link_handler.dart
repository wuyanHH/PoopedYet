import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/record_actions.dart';
import '../providers.dart';
import '../state/calendar_data.dart';
import '../state/calendar_view.dart';
import 'widget_snapshot_service.dart';

/// 桌面小组件请求主界面执行的 UI 动作
enum WidgetUiAction { backfill }

/// 桌面小组件 UI 动作分发通知器
class WidgetActionTriggerNotifier extends Notifier<WidgetUiAction?> {
  @override
  WidgetUiAction? build() => null;

  void trigger(WidgetUiAction action) {
    state = action;
  }

  void clear() {
    state = null;
  }
}

final widgetActionTriggerProvider =
    NotifierProvider<WidgetActionTriggerNotifier, WidgetUiAction?>(
  WidgetActionTriggerNotifier.new,
);

/// 桌面小组件 Deep Link 调度器 Provider
final widgetDeepLinkHandlerProvider = Provider<WidgetDeepLinkHandler>((ref) {
  final handler = WidgetDeepLinkHandler(ref);
  handler.init();
  ref.onDispose(handler.dispose);
  return handler;
});

class WidgetDeepLinkHandler with WidgetsBindingObserver {
  WidgetDeepLinkHandler(this._ref);

  final Ref _ref;
  static const _channel = MethodChannel('com.poopedyet.app/widget');
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_onMethodCall);

    // 回到前台时补一次拉取。
    //
    // 原生侧只在「Dart 已就绪」之后才主动推链接，就绪之前一律排队。
    // 这里的 resume 补拉是第二道保险：某些 ROM 会在 Activity 冷启动的
    // 极早期就把 intent 交过来，那一刻 Flutter 引擎可能还没跑起来。
    WidgetsBinding.instance.addObserver(this);

    // 检查是否有冷启动时排队的 Deep Link
    unawaited(_checkPendingLink());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkPendingLink());
    }
  }

  Future<void> _checkPendingLink() async {
    try {
      final pending = await _channel.invokeMethod<String>('getPendingDeepLink');
      if (pending != null && pending.isNotEmpty) {
        await handleUri(pending);
      }
    } catch (e) {
      debugPrint('[WIDGET-DEEPLINK] 检查排队链接异常: $e');
    }
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final link = call.arguments as String?;
      if (link != null) {
        await handleUri(link);
      }
    }
  }

  Future<void> handleUri(String link) async {
    debugPrint('[WIDGET-DEEPLINK] 收到小组件交互请求: $link');
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'poopedyet') return;

    final db = _ref.read(databaseProvider);

    try {
      if (uri.host == 'action') {
        if (uri.path == '/start') {
          // 一键开屙（支持指定家庭成员）
          final pooperId = uri.queryParameters['pooperId'];
          await db.startPoop(
            pooperId:
                (pooperId != null && pooperId.isNotEmpty) ? pooperId : null,
          );
          _invalidateDataProviders();
          unawaited(WidgetSyncManager.sync(db));
          debugPrint('[WIDGET-DEEPLINK] 一键开屙成功 (pooperId=$pooperId)');
        } else if (uri.path == '/finish') {
          // 一键完成记录
          final recordId = uri.queryParameters['recordId'];
          if (recordId != null && recordId.isNotEmpty) {
            await db.endPoop(recordId);
          } else {
            // 结束所有挂着的进行中记录
            final actives = await (db.select(db.poopRecords)
                  ..where((t) => t.endedAt.isNull() & t.endUnknown.equals(false)))
                .get();
            for (final a in actives) {
              await db.endPoop(a.id);
            }
          }
          _invalidateDataProviders();
          unawaited(WidgetSyncManager.sync(db));
          debugPrint('[WIDGET-DEEPLINK] 一键完成记录成功');
        } else if (uri.path == '/create_manual') {
          // 呼起补录历史便签底表
          _ref
              .read(widgetActionTriggerProvider.notifier)
              .trigger(WidgetUiAction.backfill);
          debugPrint('[WIDGET-DEEPLINK] 触发呼起补录便签底表');
        }
      } else if (uri.host == 'calendar') {
        // 定位日历某天（支持指定日期与默认今天）
        final dateStr = uri.queryParameters['date'];
        if (dateStr != null) {
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final y = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final d = int.tryParse(parts[2]);
            if (y != null && m != null && d != null) {
              final targetDay = DateTime(y, m, d);
              _ref.read(calendarViewProvider.notifier).selectDay(targetDay, syncMonth: true);
              debugPrint('[WIDGET-DEEPLINK] 已定位日历到 $dateStr');
            }
          }
        } else {
          _ref.read(calendarViewProvider.notifier).selectDay(DateTime.now(), syncMonth: true);
          debugPrint('[WIDGET-DEEPLINK] 已定位日历到今天');
        }
      } else if (uri.host == 'main') {
        // 打开主页并切到今天
        _ref.read(calendarViewProvider.notifier).selectDay(DateTime.now(), syncMonth: true);
      }
    } catch (e) {
      debugPrint('[WIDGET-DEEPLINK] 处理小组件动作失败: $e');
    }
  }

  void _invalidateDataProviders() {
    _ref.invalidate(todayProvider);
    _ref.invalidate(monthBadgesProvider);
    _ref.invalidate(weekBadgesProvider);
    _ref.invalidate(dayRecordsProvider);
  }
}
