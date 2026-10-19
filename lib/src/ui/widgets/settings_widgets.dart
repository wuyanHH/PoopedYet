import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';

/// 设置类的页面外壳：应用栏 + 可滚动内容 + 分组标题。
///
/// 设置页、屙屎人管理、默认备注管理都用它 ——
/// 各写一份的话，返回箭头的位置、标题字号、页面底色迟早各不相同。
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.bottomBar,
  });

  final String title;
  final Widget child;

  /// 应用栏右侧的动作（新增、排序等）。
  final List<Widget> actions;

  /// 固定在底部的操作条（筛选页的「应用」就挂在这里）。
  ///
  /// 用 `bottomNavigationBar` 而不是 Stack 叠一层：
  /// 叠的话内容会滚到底条下面，得给列表补底部内边距，很容易忘。
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: t.paper,
      bottomNavigationBar: bottomBar == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: t.paper,
                border: Border(
                  top: BorderSide(color: t.lineSoft, width: 1.0),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    viewInsetsBottom > 0
                        ? 10.0
                        : (bottomInset > 0 ? 8.0 : 12.0),
                  ),
                  child: bottomBar,
                ),
              ),
            ),
      body: SafeArea(
        // 让滚动内容在全面屏下自然铺满至底部，避免在手势小白条处形成生硬的截断缝隙
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 12, 4),
              child: Row(
                children: [
                  _BackButton(),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: t.ink,
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// 主操作按钮（「应用」「存档」这类）。
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;

  /// null = 禁用（降透明度）。
  final VoidCallback? onTap;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: t.brandGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: enabled ? t.brandShadow : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 17, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: displayStyle(
                    size: 15,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: '返回上一页',
      preferBelow: true,
      verticalOffset: 24,
      waitDuration: const Duration(milliseconds: 200),
      triggerMode: TooltipTriggerMode.longPress,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(LucideIcons.chevronLeft, size: 20, color: t.ink2),
        ),
      ),
    );
  }
}

/// 分组标题（「屙屎人」「日历」「数据」…）。
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: t.ink3,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// 设置项卡片：把若干个 [SettingsRow] 装进一张白卡。
///
/// ## 这张卡为什么画得这么"素"
///
/// 它原来是「外层 `Container` 挂一圈 `blurRadius: 4` 的投影 + 内层 `Material`
/// 用 `shape` 配 `clipBehavior: Clip.antiAlias` 裁圆角」。单看一张卡没问题，
/// 但设置页一屏里就叠着 1~2 张**整卡大小**的卡，而这两笔开销都跟面积成正比：
///
/// - `BoxShadow` 的模糊要走一次离屏渲染，尺寸是整张卡片（设置页那张
///   「日历与列表」有 7 行、五百多像素高，一屏几乎就是一整张）；
/// - `Material` 一旦给了 `shape`，绘制就会退化成 `PhysicalShape`，
///   裁剪用的是 `ShapeBorderClipper` 生成的通用 `Path`，引擎认不出
///   它其实是个圆角矩形，也就走不了快速路径。
///
/// 在 release 的 Impeller 后端下这两笔钱**每帧都要重付**（它的图片层不做
/// 光栅缓存），于是设置页上下滚动就一顿一顿的。现在改成：
///
/// - 卡片层次交给 `Border.all` 的 1px 描边承担。深色模式取深一档的 [t.line]，
///   补上原先那层 20% 黑阴影的分离度；浅色模式的阴影本来就只有 3% alpha，
///   去掉之后肉眼基本无感；
/// - 圆角裁剪下沉到 `ClipRRect`（走 clipRRect 快速路径），并且**套在
///   `Material` 外面** —— InkWell 的水波纹是由 `Material` 的墨水层绘制的，
///   套在里面就裁不到它了，这也是 [SettingsRow] 里那些 `InkWell`
///   依然被裁在圆角内的原因。
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cardRadius = BorderRadius.circular(PoopRadii.card);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: cardRadius,
        border: Border.all(color: t.isDark ? t.line : t.lineSoft),
      ),
      child: ClipRRect(
        borderRadius: cardRadius,
        child: Material(
          color: t.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: t.lineSoft,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 一行设置项。
///
/// [leading] 是左边的色块图标；[trailing] 放开关、箭头或一段值文本。
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.leading,
    this.leadingColor,
    this.leadingBackground,
    this.trailing,
    this.onTap,
    this.borderRadius,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final IconData? leading;
  final Color? leadingColor;
  final Color? leadingBackground;
  final Widget? trailing;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  /// 危险操作（删除、清空）用红字。
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final titleColor = danger ? t.danger : t.ink;
    final effectiveBackground = leadingBackground ??
        (danger ? t.danger.withValues(alpha: 0.12) : t.brandSoft);
    final effectiveColor = leadingColor ?? (danger ? t.danger : t.brandInk);

    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(
        children: [
          if (leading != null) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: effectiveBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(leading, size: 16, color: effectiveColor),
            ),
            const SizedBox(width: 12),
          ],
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
                    color: titleColor,
                  ),
                ),
                if (subtitleWidget != null) ...[
                  const SizedBox(height: 5),
                  subtitleWidget!,
                ] else if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: t.ink3,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: row,
    );
  }
}

/// 右侧的箭头。
class SettingsChevron extends StatelessWidget {
  const SettingsChevron({super.key});

  @override
  Widget build(BuildContext context) => Icon(
        LucideIcons.chevronRight,
        size: 17,
        color: context.tokens.ink4,
      );
}

/// 右侧的一段值文本。
class SettingsValue extends StatelessWidget {
  const SettingsValue(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.tokens.ink3,
        ),
      );
}

/// 开关样式统一在这里，免得每处各写一个颜色不对的 Switch。
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: t.brandFill,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: t.line,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// 一排分段选项（每周起始日、日历字号、统计范围）。
///
/// 视觉与交互规范统一：
/// - 采用统一的 [PoopMotions] 动效令牌（滑块平移 240ms easeOutCubic、文字过渡 180ms easeOutCubic）
/// - 底层为平滑物理平移的焦糖渐变滑块与柔和暖调阴影，消除突兀生硬的生切感
/// - 支持按压微缩放手感反馈，与全应用标杆控件对齐
class SettingsSegmented<T> extends StatelessWidget {
  const SettingsSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  /// 显示文案 -> 值。
  final List<(String, T)> options;
  final T value;
  final ValueChanged<T> onChanged;

  static const double _itemHeight = 26.0;
  static const double _padding = 2.5;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = options.length;
    final selectedIndex = options.indexWhere((e) => e.$2 == value);
    final validIndex = selectedIndex >= 0 ? selectedIndex : 0;

    // 根据最长字符长度调整每个 tab 的固定宽度，确保排版整洁且不抖动
    final maxChars = options.fold<int>(
      0,
      (max, e) => e.$1.length > max ? e.$1.length : max,
    );
    final itemWidth = maxChars >= 2 ? 44.0 : 36.0;
    final alignmentX = n <= 1 ? 0.0 : -1.0 + (2.0 * validIndex / (n - 1));

    return Container(
      width: itemWidth * n + _padding * 2,
      height: _itemHeight + _padding * 2,
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: t.paperDeep,
        borderRadius: BorderRadius.circular(PoopRadii.pill),
      ),
      child: Stack(
        children: [
          // 统一的平移胶囊滑块
          AnimatedAlign(
            duration: PoopMotions.switchDuration,
            curve: PoopMotions.switchCurve,
            alignment: Alignment(alignmentX, 0),
            child: Container(
              width: itemWidth,
              height: _itemHeight,
              decoration: BoxDecoration(
                gradient: t.brandGradient,
                borderRadius: BorderRadius.circular(PoopRadii.pill),
                boxShadow: t.brandShadow,
              ),
            ),
          ),
          // 上层点击与文字层
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < n; i++)
                _SettingsSegmentedItem(
                  label: options[i].$1,
                  selected: i == validIndex,
                  width: itemWidth,
                  height: _itemHeight,
                  onTap: () => onChanged(options[i].$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSegmentedItem extends StatefulWidget {
  const _SettingsSegmentedItem({
    required this.label,
    required this.selected,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  State<_SettingsSegmentedItem> createState() => _SettingsSegmentedItemState();
}

class _SettingsSegmentedItemState extends State<_SettingsSegmentedItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: PoopMotions.colorDuration,
              curve: PoopMotions.colorCurve,
              style: TextStyle(
                fontSize: 12,
                fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w700,
                letterSpacing: 0.5,
                color: widget.selected ? Colors.white : t.ink3,
              ),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}
