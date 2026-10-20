import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../../widget/widget_snapshot_service.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/smooth_page_route.dart';
import 'widget_manager_page.dart';

/// 实时灵动胶囊通知设置页。
///
/// 包含实时灵动胶囊总开关（可彻底关闭且零调用原生服务）、
/// 系统通知权限检测与各厂商（vivo 原子岛 / 小米焦点通知 / OPPO 流体云等）深度适配说明。
class WidgetNotificationPage extends ConsumerStatefulWidget {
  const WidgetNotificationPage({super.key});

  @override
  ConsumerState<WidgetNotificationPage> createState() =>
      _WidgetNotificationPageState();
}

class _WidgetNotificationPageState extends ConsumerState<WidgetNotificationPage>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.poopedyet.app/widget');

  bool _notificationEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
    }
  }

  Future<void> _checkNotificationPermission() async {
    try {
      final enabled =
          await _channel.invokeMethod<bool>('isNotificationEnabled') ?? true;
      if (mounted) {
        setState(() => _notificationEnabled = enabled);
      }
    } catch (_) {}
  }

  Future<void> _handleOpenSettings() async {
    try {
      if (!_notificationEnabled) {
        await _channel.invokeMethod('requestNotificationPermission');
      }
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  Future<void> _toggleLiveIsland(bool enabled) async {
    unawaited(HapticFeedback.lightImpact());
    ref.read(settingsProvider.notifier).setLiveIslandEnabled(enabled);

    // 如果关闭，主动向原生发送停用指令，彻底关闭前台服务并移除通知
    if (!enabled) {
      try {
        await _channel.invokeMethod('stopLiveIsland');
      } catch (_) {}
    } else {
      // 如果开启且当前未授权通知，主动唤起权限申请
      if (!_notificationEnabled) {
        try {
          await _channel.invokeMethod('requestNotificationPermission');
        } catch (_) {}
      }
    }

    final db = ref.read(databaseProvider);
    await WidgetSyncManager.sync(db);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = ref.watch(settingsProvider);
    final isLiveEnabled = settings.liveIslandEnabled;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: '通知与实时胶囊',
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + bottomInset),
        children: [
          // ---------------- 1. 开屙实时灵动胶囊总开关 ----------------
          const SettingsSectionLabel('实时灵动胶囊与通知'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.sparkles,
                leadingColor: isLiveEnabled ? t.brandInk : t.ink4,
                leadingBackground:
                    isLiveEnabled ? t.brandSoft : t.paperDeep,
                title: '开屙实时灵动胶囊',
                subtitle: isLiveEnabled
                    ? '开屙时在系统状态栏、锁屏与通知中心呈现实时跳秒与一键完成'
                    : '已彻底关闭 · 开屙时不显示通知，不调用前台服务代码，零后台消耗',
                trailing: SettingsSwitch(
                  value: isLiveEnabled,
                  onChanged: (v) => unawaited(_toggleLiveIsland(v)),
                ),
              ),
              if (isLiveEnabled)
                SettingsRow(
                  leading: LucideIcons.bellRing,
                  leadingColor: _notificationEnabled ? t.brandInk : const Color(0xFFE55D5D),
                  leadingBackground: _notificationEnabled
                      ? t.brandSoft
                      : const Color(0xFFFDE8E8),
                  title: '系统通知权限状态',
                  subtitle: _notificationEnabled
                      ? '已授权 · 支持 vivo 锁屏胶囊、小米焦点通知、OPPO 流体云'
                      : '未允许通知 · 无法在开屙时展示实时跳秒胶囊，点击前往开启',
                  trailing: _notificationEnabled
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: t.brandSoft,
                            borderRadius: BorderRadius.circular(PoopRadii.pill),
                          ),
                          child: Text(
                            '已就绪',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: t.brandInk,
                            ),
                          ),
                        )
                      : InkWell(
                          onTap: _handleOpenSettings,
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: t.brandFill,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              '去开启',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                  onTap: _handleOpenSettings,
                ),
            ],
          ),

          // ---------------- 2. 厂商系统适配原理与常见问题 ----------------
          const SettingsSectionLabel('各系统胶囊与原子岛适配说明'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ManufacturerGuideCard(),
          ),
        ],
      ),
    );
  }
}

/// 厂商系统深度适配指南卡片（折叠式展示）
class _ManufacturerGuideCard extends StatefulWidget {
  @override
  State<_ManufacturerGuideCard> createState() => _ManufacturerGuideCardState();
}

class _ManufacturerGuideCardState extends State<_ManufacturerGuideCard> {
  bool _expanded = true; // 默认展开，让用户一眼看懂

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(LucideIcons.helpCircle, size: 18, color: t.brandInk),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '为什么虚拟机看不到？vivo 原子岛如何呈现？',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '关于 OriginOS 6 原子岛、虚拟机与各厂商机制的专业解答',
                          style: TextStyle(fontSize: 11.5, color: t.ink3),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16,
                    color: t.ink3,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: t.lineSoft),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBrandItem(
                    title: '1. 为什么虚拟机（Android 官方模拟器）没有灵动岛？',
                    content:
                        '• 官方 Android AOSP（即 Google 原生模拟器）在系统层根本没有“挖孔屏灵动岛”的 UI 组件。\n'
                        '• 在原生模拟器上，系统标准实现为「前台服务常驻通知 + 锁屏实时秒表卡片」。开屙时下拉通知栏即可看到实时秒表与「完成打卡」快捷按钮。',
                    tokens: t,
                  ),
                  const SizedBox(height: 14),
                  _buildBrandItem(
                    title: '2. vivo OriginOS 4 / 5 / 6「原子岛」机制说明',
                    content:
                        '• 【厂商限制】vivo 对前置挖孔屏周围的常驻“原子岛胶囊”实行了极严格的官方白名单审查，仅对美团外卖、高德地图、系统自带录音/秒表等合作服务开放挖孔常驻。\n'
                        '• 【本 App 适配方案】深度适配了 vivo 的系统级实时活动通道：开屙时呈现「状态栏实时悬浮横幅」+「锁屏跳秒大胶囊」+「通知面板常驻跳秒」并配备一键完成按钮。\n'
                        '• 【实机关键配置】请点击上方「去开启」或进入系统「设置 → 应用与权限 → 屙了么 → 通知」，务必开启「允许通知」、「悬浮通知」和「锁屏通知」，并将重要度保持为「高」。',
                    tokens: t,
                  ),
                  const SizedBox(height: 14),
                  _buildBrandItem(
                    title: '3. 小米 (HyperOS / MIUI)「焦点通知」',
                    content:
                        '• 小米系统支持挖孔屏与锁屏焦点胶囊，请在「系统设置 → 应用设置 → 屙了么 → 通知管理」中勾选「焦点通知」与「悬浮通知」。',
                    tokens: t,
                  ),
                  const SizedBox(height: 14),
                  _buildBrandItem(
                    title: '4. OPPO / 一加 / realme (ColorOS)「流体云」',
                    content:
                        '• 在系统通知设置中开启「流体云通知」和「横幅通知」，开屙时即可在状态栏左侧显示流动跳秒胶囊。',
                    tokens: t,
                  ),
                  const SizedBox(height: 14),
                  _buildBrandItem(
                    title: '5. 如果在上方关闭开关会发生什么？',
                    content:
                        '• 彻底关闭后，应用在开屙时将直接拦截 liveSession 组装，完全不调用原生前台服务，不发起任何系统通知，零后台开销，完全纯离线。',
                    tokens: t,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBrandItem({
    required String title,
    required String content,
    required PoopTokens tokens,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: tokens.brandInk,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: TextStyle(
            fontSize: 11.5,
            color: tokens.ink2,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}
