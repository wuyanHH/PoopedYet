import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/database.dart';
import '../../data/queries.dart';
import '../../domain/record_state.dart';
import '../../state/calendar_data.dart';
import '../../theme/tokens.dart';
import '../widgets/expand_toggle_button.dart';
import '../widgets/ongoing_poop_badge.dart';
import '../widgets/poop_button_icon.dart';
import '../widgets/pooper_avatar.dart';

/// 一条记录的卡片。
///
/// 视觉与手势全面重构升级：
///   - 抛弃生硬且在圆角处穿帮露底的 Dismissible，自研无缝贴合的物理阻尼弹簧抽屉卡片
///   - 彻底解决圆角与滑动背景之间的三角形空白瑕疵
///   - 左右滑动作语义清晰解耦：
///     * 向左滑 👈：核心生命周期流转（无结束时间 ➔ 结束打卡并记为当前时间；已有结束时间 ➔ 删除记录）
///     * 向右滑 👉：内容补充（添加便签备注 / 补充打卡细节，绝不再混淆为标记完成）
///   - 自带自然渐进阻尼与弹性复位动效
class RecordCard extends ConsumerStatefulWidget {
  const RecordCard({
    super.key,
    required this.detail,
    required this.now,
    this.onTap,
    this.onQuickEnd,
    this.onDelete,
    this.onAddNote,
  });

  final RecordDetail detail;
  final DateTime now;
  final VoidCallback? onTap;

  /// 左滑快捷结束打卡（仅在无结束时间时触发）
  final Future<void> Function()? onQuickEnd;

  /// 左滑快捷删除（仅在已有结束时间时触发）
  final Future<void> Function()? onDelete;

  /// 右滑快捷添加备注/补充细节
  final VoidCallback? onAddNote;

  @override
  ConsumerState<RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends ConsumerState<RecordCard>
    with TickerProviderStateMixin {
  bool _pressed = false;
  bool _notesExpanded = false;
  bool _isDeleting = false;
  bool _isCompleting = false;
  bool _hasTriggeredHaptic = false;

  // 水平阻尼拖拽与弹簧复位
  double _dragOffset = 0.0;
  late final AnimationController _springController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Animation<double>? _springAnimation;

  // 丝滑删除动效控制器：向左滑出淡出 + 高度折叠闭合
  late final AnimationController _deleteController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _deleteSlideAnimation;
  late final Animation<double> _deleteOpacityAnimation;
  late final Animation<double> _deleteSizeAnimation;

  /// 触发动作的水平位移阈值（85px 配合充足的滑动空间，手感明确自然）
  static const double kTriggerThreshold = 85.0;

  /// 最大允许拖拽的位移（由原来的 120 扩大到 220，让后方的操作信息有充分空间展示）
  static const double kMaxDragDistance = 220.0;

  @override
  void initState() {
    super.initState();
    // 飞出动画：从当前拖拽位置迅速加速滑出屏幕
    _deleteSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _deleteController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInCubic),
      ),
    );
    // 淡出动画：随飞出同时渐隐
    _deleteOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _deleteController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    // 尺寸收缩折叠动画：高度平滑过渡到 0，下方卡片丝滑上移
    _deleteSizeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _deleteController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeInOutCubic),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant RecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 关键双重防护：如果绑定的记录 ID 改变了，说明 Flutter 框架在某种列表刷新场景下复用了该 State，
    // 必须立即将所有动画与删除状态彻底重置为初始状态，绝不能携带任何历史残留的删除状态！
    if (oldWidget.detail.record.id != widget.detail.record.id) {
      _isDeleting = false;
      _isCompleting = false;
      _dragOffset = 0.0;
      _springController.reset();
      _deleteController.reset();
    }
  }

  @override
  void dispose() {
    _springController.dispose();
    _deleteController.dispose();
    super.dispose();
  }

  void _resetPosition({bool spring = true}) {
    if (!spring || _dragOffset == 0.0) {
      setState(() {
        _dragOffset = 0.0;
        _isCompleting = false;
      });
      return;
    }
    _springAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragOffset = _springAnimation!.value;
        });
      });
    _springController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    });
  }

  /// 执行带有极致丝滑物理动画的删除
  Future<void> _executeDelete() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);

    // 播放滑出飞走 + 高度无缝折叠收起动画
    try {
      await _deleteController.forward();
    } catch (_) {}

    // 动画收起完毕后，再触发真正的数据库删除与数据流刷新，实现 0 跳跃 0 抽搐的自然过渡
    if (widget.onDelete != null) {
      await widget.onDelete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = widget.detail.record;
    final state = recordStateOf(r, now: widget.now);
    final hasEnded = r.endedAt != null;

    final Color accent = switch (state) {
      RecordState.active => t.live,
      RecordState.pending => t.pending,
      RecordState.endUnknown => t.ink3,
      RecordState.done => t.ink3,
    };

    final isLive = state == RecordState.active;

    // 精准区分“便便感受标签”与“用户自定义文字备注”
    final templates =
        ref.watch(noteTemplatesProvider).value ?? const <NoteTemplate>[];
    final templateContentSet =
        templates.map((tpl) => tpl.content.trim()).toSet();

    // 属于便便感受标签的词条（匹配预设感受模板）
    final topicNotes = widget.detail.notes
        .where((n) => templateContentSet.contains(n.content.trim()))
        .toList();

    // 真正属于用户的自定义文字备注（无论字数多短，统统作为真实备注保留展示，绝不误吞！）
    final customDetailNotes = widget.detail.notes
        .where((n) => !templateContentSet.contains(n.content.trim()))
        .toList();

    final cardRadius = BorderRadius.circular(18);

    // 上层主内容视图
    final cardContent = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: isLive
                ? (t.isDark ? const Color(0xFF1C2720) : const Color(0xFFF6FAF7))
                : (state == RecordState.pending
                    ? (t.isDark ? const Color(0xFF282218) : const Color(0xFFFDFBF7))
                    : t.surface),
            borderRadius: cardRadius,
            border: Border.all(
              color: isLive
                  ? t.live.withValues(alpha: 0.38)
                  : (state == RecordState.pending
                      ? t.pending.withValues(alpha: 0.35)
                      : t.line),
              width: (isLive || state == RecordState.pending) ? 1.3 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 头部：头像 + 名字 + 排便主题徽标 + 状态徽标与时长
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    PooperAvatar.md(
                      widget.detail.pooper,
                      dimmed: widget.detail.pooper.archivedAt != null,
                    ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.detail.pooper.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        color: t.ink,
                                      ),
                                    ),
                                  ),
                                  // 排便主题徽标（一眼看清本次排便性质）
                                  if (topicNotes.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    for (final topic in topicNotes.take(2)) ...[
                                      Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: t.brandSoft,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: t.brand.withValues(alpha: 0.25),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          topic.content,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: t.brandInk,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                  if (widget.detail.pooper.archivedAt != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.paperDeep,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '已归档',
                                        style: TextStyle(fontSize: 10, color: t.ink4),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              // 起止时间主行
                              _TimeRow(
                                start: hhmm(r.startedAt),
                                end: endLabel(r, now: widget.now),
                                state: state,
                                accent: accent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 右侧状态与时长药丸（正在屙接入全新的方案 1A 动态胶囊）
                        if (isLive)
                          OngoingPoopBadge(
                            label: '正在屙',
                            durationText: durationLabel(r, now: widget.now),
                            iconSize: 16,
                            onTap: widget.onTap,
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              color: state == RecordState.done
                                  ? t.brandSoft
                                  : (state == RecordState.pending
                                      ? t.pending.withValues(alpha: 0.12)
                                      : t.paperDeep),
                              borderRadius: BorderRadius.circular(PoopRadii.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  state == RecordState.done
                                      ? LucideIcons.clock
                                      : (state == RecordState.pending
                                          ? LucideIcons.triangleAlert
                                          : LucideIcons.helpCircle),
                                  size: 11,
                                  color: state == RecordState.done ? t.brandInk : accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  durationLabel(r, now: widget.now),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: state == RecordState.done ? t.brandInk : accent,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    // 详细文字备注小气泡（仅在有除主题之外的详细文字时展示）
                    if (customDetailNotes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _NotesBubble(
                        notes: customDetailNotes,
                        expanded: _notesExpanded,
                        onToggleExpand: () =>
                            setState(() => _notesExpanded = !_notesExpanded),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );

    return AnimatedBuilder(
      animation: _deleteController,
      builder: (context, child) {
        // 如果处于删除动效中，卡片沿原方向迅速加速滑出屏幕
        final effectiveOffset = _isDeleting
            ? _dragOffset -
                (_deleteSlideAnimation.value *
                    (MediaQuery.sizeOf(context).width + 120))
            : _dragOffset;

        return SizeTransition(
          sizeFactor: _deleteSizeAnimation,
          axisAlignment: 0.0,
          child: FadeTransition(
            opacity: _deleteOpacityAnimation,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: cardRadius,
                border: Border.all(
                  color: t.lineSoft.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isLive
                        ? (t.isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : const Color(0x1A2E7D32))
                        : (t.isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : const Color(0x102D1B0D)),
                    blurRadius: isLive ? 14 : 10,
                    spreadRadius: -2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: cardRadius,
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    if (_isDeleting) return;
                    _hasTriggeredHaptic = false;
                    if (_springController.isAnimating) {
                      _springController.stop();
                    }
                  },
                  onHorizontalDragUpdate: (d) {
                    if (_isDeleting) return;
                    setState(() {
                      // 优化渐进阻尼手感：在 90px 内保持敏捷跟手，超过 90px 阻尼增大，最大可滑动 220px 彻底露出所有信息
                      final abs = _dragOffset.abs();
                      final factor = abs < 90.0
                          ? 0.85
                          : (0.85 - ((abs - 90.0) / 240.0)).clamp(0.35, 0.85);
                      _dragOffset = (_dragOffset + d.delta.dx * factor)
                          .clamp(-kMaxDragDistance, kMaxDragDistance);

                      // 越过触发阈值瞬间触发微触觉反馈，回退时轻微提示，赋予物理操作确认感
                      final isOver = _dragOffset.abs() >= kTriggerThreshold;
                      if (isOver && !_hasTriggeredHaptic) {
                        _hasTriggeredHaptic = true;
                        HapticFeedback.mediumImpact();
                      } else if (!isOver && _hasTriggeredHaptic) {
                        _hasTriggeredHaptic = false;
                        HapticFeedback.selectionClick();
                      }
                    });
                  },
                  onHorizontalDragEnd: (d) async {
                    if (_isDeleting) return;
                    _hasTriggeredHaptic = false;
                    final vx = d.velocity.pixelsPerSecond.dx;
                    // 严格同向性约束：位移方向必须与速度方向保持一致，彻底杜绝右滑回弹时因反向速度误触发左滑删除
                    final isLeftSwipe =
                        _dragOffset < 0 && (_dragOffset < -kTriggerThreshold || vx < -360);
                    final isRightSwipe =
                        _dragOffset > 0 && (_dragOffset > kTriggerThreshold || vx > 360);

                    if (isLeftSwipe) {
                      if (!hasEnded) {
                        // 未结束 ➔ 结束打卡：立即标记完成状态，保证弹簧回弹期间底板保持翡翠绿与已完成状态，绝不闪变红色删除
                        HapticFeedback.lightImpact();
                        setState(() => _isCompleting = true);
                        _resetPosition(spring: true);
                        if (widget.onQuickEnd != null) {
                          await widget.onQuickEnd!();
                        } else {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  '已记录当前时间（${hhmm(DateTime.now())}）为结束时间',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                        }
                      } else {
                        // 已结束 ➔ 触发丝滑删除物理动效
                        HapticFeedback.mediumImpact();
                        await _executeDelete();
                      }
                    } else if (isRightSwipe) {
                      // 向右滑 👉：内容补充操作（添加便签备注）
                      HapticFeedback.lightImpact();
                      _resetPosition(spring: true);
                      if (widget.onAddNote != null) {
                        widget.onAddNote!();
                      } else if (widget.onTap != null) {
                        widget.onTap!();
                      }
                    } else {
                      _resetPosition(spring: true);
                    }
                  },
                  onHorizontalDragCancel: () {
                    if (!_isDeleting) {
                      _hasTriggeredHaptic = false;
                      _resetPosition(spring: true);
                    }
                  },
                  child: Stack(
                    children: [
                      // 底层动作背景层：展示丰富的操作反馈与提示，文字与图标层次分明
                      Positioned.fill(
                        child: _SeamlessSwipeBackground(
                          dragOffset: effectiveOffset,
                          isTriggerReady: effectiveOffset.abs() >= kTriggerThreshold,
                          hasEnded: hasEnded,
                          isCompleting: _isCompleting,
                          endedAt: r.endedAt,
                          now: widget.now,
                        ),
                      ),

                      // 上层主内容卡片：随阻尼位移平移
                      Transform.translate(
                        offset: Offset(effectiveOffset, 0),
                        child: cardContent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 无缝贴合圆角的滑动动作底板组件。
///
/// 彻底根除圆角处的空白缝隙，左右滑动作语义清晰明确：
///   - 左滑（`dragOffset < 0`）：未完成显示翡翠绿“完成打卡”；已完成显示酒红“删除记录”；
///   - 右滑（`dragOffset > 0`）：显示温暖焦糖便签色“添加便签”。
///
/// 视口自适应优化（彻底解决信息被上层卡片截断的问题）：
///   将文字与图标内容严格约束在当前【露出的可视视口（宽度为 absOffset）】内，
///   并在小位移、标准位移与大位移下分级展示精炼文案，杜绝文字被遮挡。
class _SeamlessSwipeBackground extends StatelessWidget {
  const _SeamlessSwipeBackground({
    super.key,
    required this.dragOffset,
    required this.isTriggerReady,
    required this.hasEnded,
    this.isCompleting = false,
    required this.endedAt,
    required this.now,
  });

  final double dragOffset;
  final bool isTriggerReady;
  final bool hasEnded;
  final bool isCompleting;
  final DateTime? endedAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (dragOffset == 0.0) {
      return const SizedBox.shrink();
    }

    final absOffset = dragOffset.abs();
    final isLeftDragging = dragOffset < 0;
    final showFinish = !hasEnded || isCompleting;

    // 渐变背景色配置
    final LinearGradient gradient;
    if (isLeftDragging) {
      gradient = showFinish
          ? LinearGradient(
              colors: isTriggerReady
                  ? const [Color(0xFF2E7D32), Color(0xFF1B5E20)]
                  : const [Color(0xFF388E3C), Color(0xFF256F2A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            )
          : LinearGradient(
              colors: isTriggerReady
                  ? const [Color(0xFFC62828), Color(0xFF8F1D1D)]
                  : const [Color(0xFFD32F2F), Color(0xFFA92222)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            );
    } else {
      gradient = LinearGradient(
        colors: isTriggerReady
            ? const [Color(0xFFBA5F26), Color(0xFF9E4E1C)]
            : const [Color(0xFFC46D35), Color(0xFFA65824)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    }

    // 动作信息配置
    final IconData icon;
    final String shortTitle;
    final String readyTitle;
    final String subtitle;

    if (isLeftDragging) {
      if (showFinish) {
        icon = LucideIcons.checkCheck;
        shortTitle = isCompleting ? '已完成' : '左滑完成';
        readyTitle = isCompleting ? '已完成' : '松手完成';
        subtitle = isCompleting ? '打卡记录已完成' : '记录 ${hhmm(now)} 结束';
      } else {
        icon = LucideIcons.trash2;
        shortTitle = '左滑删除';
        readyTitle = '松手删除';
        subtitle = '可随时撤销恢复';
      }
    } else {
      icon = LucideIcons.stickyNote;
      shortTitle = '右滑便签';
      readyTitle = '松手便签';
      subtitle = '打开编辑详情';
    }

    // 标题文本：根据是否达到触发阈值动态呈现最明确的交互暗示
    final displayTitle = isTriggerReady ? readyTitle : shortTitle;

    // 内容透明度随位移平滑淡入（从 16px 起步淡入，50px 即可完全清晰可见）
    final contentOpacity = ((absOffset - 16.0) / 34.0).clamp(0.0, 1.0);

    return Stack(
      children: [
        // 1. 满铺渐变背景，保证卡片移开时底色无缝且饱满
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(gradient: gradient),
          ),
        ),

        // 2. 自适应防截断视口：
        //    通过赋予内部至少 150px 的安全排版空间，彻底根除文字被挤压截断成省略号的顽疾！
        //    上层卡片滑开多少像素，就平滑露出多少像素，信息层次清晰自然。
        Positioned(
          top: 0,
          bottom: 0,
          left: isLeftDragging ? null : 0,
          right: isLeftDragging ? 0 : null,
          width: math.max(absOffset, 150.0),
          child: ClipRect(
            child: Opacity(
              opacity: contentOpacity,
              child: Align(
                alignment: isLeftDragging ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!isLeftDragging) ...[
                        _ActionIconBadge(
                          icon: icon,
                          isTriggerReady: isTriggerReady,
                          isFinishIcon: false,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: isLeftDragging
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isTriggerReady
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              fontSize: 13.0,
                              letterSpacing: 0.2,
                            ),
                          ),
                          // 只要滑动超过 70px，即可自然清晰展现副标题，不再设置 145px 的过高门槛
                          if (absOffset >= 70.0) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(
                                  alpha: isTriggerReady ? 0.95 : 0.8,
                                ),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isLeftDragging) ...[
                        const SizedBox(width: 8),
                        _ActionIconBadge(
                          icon: icon,
                          isTriggerReady: isTriggerReady,
                          isFinishIcon: !hasEnded,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 滑动动作图标小徽章，支持微缩与弹性放大
class _ActionIconBadge extends StatelessWidget {
  const _ActionIconBadge({
    required this.icon,
    required this.isTriggerReady,
    required this.isFinishIcon,
    this.compact = false,
  });

  final IconData icon;
  final bool isTriggerReady;
  final bool isFinishIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 34.0;
    final iconSize = compact ? 16.0 : 18.0;

    return AnimatedScale(
      scale: isTriggerReady ? 1.08 : 0.95,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isTriggerReady
              ? Colors.white.withValues(alpha: 0.32)
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(compact ? 9 : 11),
          border: Border.all(
            color: isTriggerReady
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.3),
            width: 1.1,
          ),
          boxShadow: isTriggerReady
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: isFinishIcon
            ? PoopButtonIcon.finish(size: iconSize, onDarkButton: true)
            : Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.start,
    required this.end,
    required this.state,
    required this.accent,
  });

  final String start;
  final String end;
  final RecordState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final timeStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: t.ink2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (state == RecordState.active) {
      // 正在屙时仅保留干脆利落的开始时间，彻底消除“进行中”等冗余字样
      return Text(start, style: timeStyle);
    }

    return Row(
      children: [
        Text(start, style: timeStyle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Icon(LucideIcons.arrowRight, size: 12, color: t.ink4),
        ),
        Text(
          end,
          style: timeStyle.copyWith(
            color: state == RecordState.done ? t.ink2 : accent,
          ),
        ),
      ],
    );
  }
}

/// 备注展示气泡：
///   - 高度与行数精准判定：只有当总行数或总高度真正超标时才触发折叠，少量短文本绝对不折叠不遮挡；
///   - 内部采用 SingleChildScrollView 隔离 Column 高度约束，彻底根绝 BOTTOM OVERFLOWED 斑马纹溢出警告条；
///   - 右下角统一采用精致微悬浮圆形展开/收起按钮（180°顺滑旋转 chevron）。
class _NotesBubble extends StatelessWidget {
  const _NotesBubble({
    required this.notes,
    required this.expanded,
    required this.onToggleExpand,
  });

  final List<PoopNote> notes;
  final bool expanded;
  final VoidCallback onToggleExpand;

  /// 折叠状态下的舒适视觉高度上限（约相当于 3~4 行标准文本高度）
  static const double kCollapsedMaxHeight = 84.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // 精确估算行数：
    // 每条备注至少占 1 行；若内容字符过长（按中文每行约 18~20 字折算）累加行数。
    var totalEstimatedLines = 0;
    for (final n in notes) {
      final len = n.content.length;
      totalEstimatedLines += (len <= 18) ? 1 : (1 + (len - 18 + 17) ~/ 18);
    }
    // 只有当总行数超过 3 行或者总条数大于 3 时，才真正需要折叠！
    final hasOverflow = totalEstimatedLines > 3 || notes.length > 3;

    // 正文列表：正文独占 100% 全宽，杜绝横向挤压
    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (idx, n) in notes.indexed) ...[
          if (idx > 0) const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hhmm(n.notedAt),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: t.ink3,
                    fontFeatures: const [
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  n.content,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: t.ink2,
                  ),
                ),
              ),
            ],
          ),
        ],
        // 展开状态下在底部右侧呈现微悬浮圆形收起按钮
        if (hasOverflow && expanded) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: ExpandToggleButton(
              isExpanded: true,
              onToggle: onToggleExpand,
              size: 22,
              semanticLabel: '收起备注',
            ),
          ),
        ],
      ],
    );

    final shouldClip = hasOverflow && !expanded;

    return AnimatedSize(
      duration: PoopMotions.colorDuration,
      curve: PoopMotions.colorCurve,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: t.paperDeep.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            // 1. 内容主体层：
            //    仅在超出且折叠时约束最大高度并裁切；展开状态下解除硬性约束
            Padding(
              padding: EdgeInsets.fromLTRB(
                10,
                8,
                shouldClip ? 28 : 10, // 折叠时右侧预留按钮避让间距
                8,
              ),
              child: shouldClip
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: kCollapsedMaxHeight,
                      ),
                      child: ClipRect(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: contentColumn,
                        ),
                      ),
                    )
                  : contentColumn,
            ),

            // 2. 超出且处于折叠状态时，呈现柔和底部渐变淡出并在右下角展示圆形展开按钮
            if (shouldClip) ...[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 32,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(10),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          t.paperDeep.withValues(alpha: 0.0),
                          t.paperDeep.withValues(alpha: 0.75),
                          t.paperDeep,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 5,
                child: ExpandToggleButton(
                  isExpanded: false,
                  onToggle: onToggleExpand,
                  size: 22,
                  semanticLabel: '展开全部备注',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 「正在屙」那个会呼吸的绿点。
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 0.88,
    end: 1.15,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  late final Animation<double> _opacityAnimation = Tween<double>(
    begin: 0.45,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          width: 7.5,
          height: 7.5,
          decoration: BoxDecoration(
            color: t.live,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: t.live.withValues(alpha: 0.35),
                blurRadius: 3.5,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
