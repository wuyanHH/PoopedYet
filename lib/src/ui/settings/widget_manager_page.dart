import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../providers.dart';
import '../../state/calendar_data.dart';
import '../../theme/tokens.dart';
import '../../widget/widget_binding.dart';
import '../../widget/widget_snapshot_service.dart';
import '../widgets/pooper_avatar.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/sheet_shell.dart';

/// 桌面小组件管理页。
///
/// 解决两件事：
///  1. **可见** —— 桌面上到底放了几个组件、每个在显示谁，这里一眼看全；
///  2. **可改** —— 想换人不必「删掉组件再重新添加」，选中即刻生效。
///
/// 真正渲染小组件的是 Android 原生侧，本页只负责读写绑定关系。
class WidgetManagerPage extends ConsumerStatefulWidget {
  const WidgetManagerPage({super.key});

  @override
  ConsumerState<WidgetManagerPage> createState() => _WidgetManagerPageState();
}

class _WidgetManagerPageState extends ConsumerState<WidgetManagerPage> {
  static const _service = WidgetBindingService();

  /// `null` 表示仍在读取中。
  List<WidgetBinding>? _bindings;

  /// 刷新按钮的旋转圈数：每次点击 +1，交给 AnimatedRotation 做插值。
  /// 之前这个按钮点下去毫无动静，用户根本不知道它到底在更新什么。
  double _refreshTurns = 0;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// 手动刷新 —— 做两件事，缺一不可：
  ///
  ///  1. **重新算一遍快照推给桌面**：在 App 里改了成员、补了记录之后，
  ///     桌面上的组件就该跟着变（平时由写操作自动触发，这里是手动兜底）；
  ///  2. **重读桌面上已放置的组件列表**：用户可能在桌面加了或删了组件。
  ///
  /// 早期只做了第 2 件、而且不给任何反馈，所以看起来「点了没反应」。
  Future<void> _reload() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _refreshTurns += 1;
    });

    try {
      await WidgetSyncManager.sync(ref.read(databaseProvider));
      final list = await _service.listBindings();
      if (!mounted) return;
      setState(() => _bindings = list);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已重新同步到桌面'),
          duration: Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// 活跃成员里挑出「默认成员」：优先 `isDefault`，没有就取第一位。
  Pooper? _defaultPooper(List<Pooper> poopers) {
    if (poopers.isEmpty) return null;
    for (final p in poopers) {
      if (p.isDefault) return p;
    }
    return poopers.first;
  }

  Pooper? _findPooper(List<Pooper> poopers, String? id) {
    if (id == null) return null;
    for (final p in poopers) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bindings = _bindings;

    return SettingsScaffold(
      title: '桌面小组件',
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + bottomInset),
        children: [
          _IntroCard(
            onRefresh: _reload,
            refreshing: _refreshing,
            turns: _refreshTurns,
          ),

          // 三款组件的真实预览图 —— 让用户在 App 里就能比较「哪个更适合我」，
          // 而不是先拖到桌面再删掉重来。
          const SettingsSectionLabel('添加到桌面'),
          for (final preset in _kWidgetPresets)
            _WidgetPreviewCard(
              preset: preset,
              onAdd: () => _requestPin(preset),
            ),

          const SettingsSectionLabel('桌面上的小组件'),
          if (bindings == null)
            const SettingsCard(
              children: [
                SettingsRow(title: '正在读取…', subtitle: '查询桌面上已放置的小组件'),
              ],
            )
          else if (bindings.isEmpty)
            const SettingsCard(
              children: [
                SettingsRow(
                  leading: LucideIcons.layoutGrid,
                  title: '还没有把小组件放到桌面',
                  subtitle: '长按桌面空白处 → 小组件 → 找到「屙了么」，'
                      '选一个尺寸拖出来。添加时会弹出选择屙屎人的浮层，选谁就显示谁。',
                ),
              ],
            )
          else
            SettingsCard(
              children: [
                for (final binding in bindings) _buildBindingRow(context, binding),
              ],
            ),

          const SettingsSectionLabel('说明'),
          SettingsCard(
            children: [
              SettingsRow(
                leading: LucideIcons.mousePointerClick,
                title: '在桌面上就能换人',
                subtitle: '点击小组件上的头像区域，会直接弹出选择浮层，不用打开 App。',
              ),
              SettingsRow(
                leading: LucideIcons.smartphone,
                title: '每个组件各自独立',
                subtitle: '同一个尺寸放多个，可以一个看你、一个看家人，互不影响。',
              ),
              SettingsRow(
                leading: LucideIcons.refreshCw,
                title: '改完立即生效',
                subtitle: '选择后桌面上对应的小组件会马上重画，不需要重启或重新添加。',
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBindingRow(BuildContext context, WidgetBinding binding) {
    final t = context.tokens;
    final poopers = ref.watch(activePoopersProvider).value ?? const <Pooper>[];
    final boundPooper = _findPooper(poopers, binding.pooperId);

    return SettingsRow(
      leading: _iconForType(binding.type),
      title: binding.typeLabel,
      subtitleWidget: Row(
        children: [
          if (boundPooper != null) ...[
            PooperAvatar(pooper: boundPooper, size: 20, radius: 7, iconSize: 11),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              binding.isFollowingDefault
                  ? '跟随默认成员 · ${binding.pooperName}'
                  : '显示 ${binding.pooperName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.35),
            ),
          ),
        ],
      ),
      trailing: const SettingsChevron(),
      onTap: () => _pickPooper(binding),
    );
  }

  IconData _iconForType(String type) => switch (type) {
        'small' => LucideIcons.square,
        'medium' => LucideIcons.rectangleHorizontal,
        _ => LucideIcons.layoutGrid,
      };

  /// 请求把某款小组件钉到桌面。
  Future<void> _requestPin(_WidgetPreset preset) async {
    final pinned = await _service.requestPin(preset.type);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pinned
              ? '已发出添加请求，请在系统弹窗里确认'
              : '当前桌面不支持一键添加，请长按桌面空白处 → 小组件 → 选择「屙了么」',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );

    if (pinned) await _reload();
  }

  /// 弹出成员选择浮层；选中后立刻写回原生并刷新桌面。
  Future<void> _pickPooper(WidgetBinding binding) async {
    final poopers = ref.read(activePoopersProvider).value ?? const <Pooper>[];
    final defaultPooper = _defaultPooper(poopers);

    final picked = await showModalBottomSheet<_PickResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SheetShell(
        title: '谁的小组件',
        subtitle: binding.typeLabel,
        scrollable: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PickTile(
                title: '跟随默认成员',
                subtitle: defaultPooper == null
                    ? '跟随 App 里设置的默认屙屎人'
                    : '当前默认「${defaultPooper.name}」，改默认人选它会一起变',
                pooper: null,
                selected: binding.isFollowingDefault,
                onTap: () => Navigator.of(ctx).pop(const _PickResult(null)),
              ),
              const SizedBox(height: 4),
              for (final pooper in poopers)
                _PickTile(
                  title: pooper.name,
                  subtitle: (pooper.remark?.trim().isNotEmpty ?? false)
                      ? pooper.remark!.trim()
                      : '点选后这个小组件只显示 TA 的数据',
                  pooper: pooper,
                  selected: !binding.isFollowingDefault && binding.pooperId == pooper.id,
                  onTap: () => Navigator.of(ctx).pop(_PickResult(pooper.id)),
                ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;

    final ok = await _service.setBinding(
      widgetId: binding.widgetId,
      pooperId: picked.pooperId,
    );
    if (!mounted) return;

    await _reload();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '已更新：${binding.typeLabel} 现在显示「${picked.displayName(poopers)}」' : '更新失败，请重试',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// 弹层返回值：`pooperId == null` 表示「跟随默认成员」。
///
/// 用一个包装类而不是裸 `String?`，是为了把「用户取消」和
/// 「用户明确选了跟随默认」区分开 —— 后者必须真的写回一次 null。
@immutable
class _PickResult {
  const _PickResult(this.pooperId);

  final String? pooperId;

  String displayName(List<Pooper> poopers) {
    if (pooperId == null) return '跟随默认成员';
    for (final p in poopers) {
      if (p.id == pooperId) return p.name;
    }
    return '已选成员';
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.title,
    required this.subtitle,
    required this.pooper,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Pooper? pooper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? t.brandSoft : t.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? t.brandInk : t.lineSoft,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (pooper != null)
                  PooperAvatar(pooper: pooper!, size: 40, radius: 13, iconSize: 20)
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: t.paperDeep,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Icon(LucideIcons.userRound, size: 20, color: t.ink3),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? t.brandInk : t.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.3),
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(LucideIcons.check, size: 20, color: t.brandInk),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App 内可一键添加的三款小组件。
@immutable
class _WidgetPreset {
  const _WidgetPreset({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.asset,
  });

  /// 与原生 `requestPinWidget` 约定的类型标识。
  final String type;

  final String title;
  final String subtitle;

  /// 预览图。由 `.design/build-widget-previews.py` 生成，
  /// 与原生 `previewImage` 用的是同一张位图，不会出现「预览与实际不符」。
  final String asset;
}

const _kWidgetPresets = <_WidgetPreset>[
  _WidgetPreset(
    type: 'small',
    title: '成员打卡 · 2×2',
    subtitle: '头像 + 今日次数 + 一键开屙',
    asset: 'assets/widget_previews/widget_preview_small.png',
  ),
  _WidgetPreset(
    type: 'medium',
    title: '行动周历 · 4×2',
    subtitle: '距上次多久 + 7 天打卡周历',
    asset: 'assets/widget_previews/widget_preview_medium.png',
  ),
  _WidgetPreset(
    type: 'large',
    title: '家庭看板 · 4×4',
    subtitle: '全员今日状态 + 最新便签',
    asset: 'assets/widget_previews/widget_preview_large.png',
  ),
];

/// 一张「预览图 + 名称 + 添加到桌面」卡片。
class _WidgetPreviewCard extends StatelessWidget {
  const _WidgetPreviewCard({required this.preset, required this.onAdd});

  final _WidgetPreset preset;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(PoopRadii.card),
        border: Border.all(color: t.lineSoft),
      ),
      child: Row(
        children: [
          // 预览图本身画成直角、不透明（启动器会自己裁圆角，透明区在那边
          // 会被渲染成黑色）。App 内这里自己裁一下，保持圆角观感。
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 104,
              height: 76,
              child: Image.asset(preset.asset, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preset.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  preset.subtitle,
                  style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: t.brandFill,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                '添加',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部说明卡：讲清「能做什么」并提供一个手动同步入口。
class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.onRefresh,
    required this.refreshing,
    required this.turns,
  });

  final VoidCallback onRefresh;

  /// 同步进行中：按钮置灰并禁用，避免连点。
  final bool refreshing;

  /// 已旋转的圈数，用来驱动 AnimatedRotation。
  final double turns;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: t.brandSoft,
        borderRadius: BorderRadius.circular(PoopRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: t.brandInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '每个小组件都能独立绑定一位屙屎人：放一个看自己，再放一个看家人。'
              '绑定后，该组件上的今日次数、上次时间、周历打卡都只统计这一位。'
              '右侧按钮可把最新数据重新同步到桌面。',
              style: TextStyle(fontSize: 12, color: t.ink2, height: 1.5),
            ),
          ),
          IconButton(
            tooltip: '把最新数据重新同步到桌面',
            onPressed: refreshing ? null : onRefresh,
            icon: AnimatedRotation(
              turns: turns,
              duration: const Duration(milliseconds: 620),
              curve: Curves.easeInOutCubic,
              child: Icon(
                LucideIcons.refreshCw,
                size: 16,
                color: refreshing ? t.ink3 : t.brandInk,
              ),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
