import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../widgets/poop_button_icon.dart';
import '../widgets/settings_widgets.dart';

/// 外观与主题设置页。
///
/// 包含深浅模式切换与 5 款手账色系选择，顶部配备实时响应的预览卡。
class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final settings = ref.watch(settingsProvider);
    final s = ref.read(settingsProvider.notifier);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: '外观与主题',
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + bottomInset),
        children: [
          // 顶部：实时主题预览卡
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _ThemeLivePreviewCard(settings: settings),
          ),

          // ---------------- 深浅模式 ----------------
          const SettingsSectionLabel('深浅模式'),
          SettingsCard(
            children: [
              SettingsRow(
                title: '显示模式',
                subtitle: switch (settings.themeMode) {
                  AppThemeMode.system => '跟随系统自动切换深浅外观',
                  AppThemeMode.light => '保持温暖明亮的手账暖纸质感',
                  AppThemeMode.dark => '暗夜深咖护眼模式，省电舒缓',
                },
                trailing: SettingsSegmented<AppThemeMode>(
                  options: const [
                    ('系统', AppThemeMode.system),
                    ('浅色', AppThemeMode.light),
                    ('深色', AppThemeMode.dark),
                  ],
                  value: settings.themeMode,
                  onChanged: (mode) {
                    HapticFeedback.selectionClick();
                    s.setThemeMode(mode);
                  },
                ),
              ),
            ],
          ),

          // ---------------- 手账色彩方案 ----------------
          const SettingsSectionLabel('手账色彩方案'),
          SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '配色方案',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: t.brandSoft,
                            borderRadius: BorderRadius.circular(PoopRadii.pill),
                          ),
                          child: Text(
                            settings.themeColor.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: t.brandInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '5 种暖调手账色系，自动适配浅色暖纸与暗夜深咖',
                      style: TextStyle(fontSize: 11.5, color: t.ink3),
                    ),
                    const SizedBox(height: 16),
                    _ThemeColorSelector(
                      selected: settings.themeColor,
                      onChanged: (color) {
                        HapticFeedback.selectionClick();
                        s.setThemeColor(color);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SettingsSectionLabel('说明'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '主题色彩将应用于全应用的品牌强调色、日历高亮、图表徽标及状态胶囊。深浅模式下色彩饱和度均经过专业 WCAG AA 对比度校准。',
              style: TextStyle(fontSize: 11.5, color: t.ink3, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部动态实时预览卡
class _ThemeLivePreviewCard extends StatelessWidget {
  const _ThemeLivePreviewCard({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final primary = settings.themeColor.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.lineSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C2D1B0D),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.palette, size: 14, color: t.brandInk),
              const SizedBox(width: 6),
              Text(
                '色彩氛围预览 · ${settings.themeColor.label}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 模拟的手账卡片组件展示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.paperDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.lineSoft),
            ),
            child: Row(
              children: [
                // 模拟便便开屙大按钮（官方统一卷纸+虚线+时钟图标）
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: t.brandFill,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const PoopButtonIcon.start(size: 24, onDarkButton: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '今天屙了么？',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: t.brandSoft,
                              borderRadius: BorderRadius.circular(PoopRadii.pill),
                            ),
                            child: Text(
                              '打卡中',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: t.brandInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '轻触记录一次通畅时刻，保持肠道健康',
                        style: TextStyle(fontSize: 11, color: t.ink3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 主题色彩选择器
class _ThemeColorSelector extends StatelessWidget {
  const _ThemeColorSelector({
    required this.selected,
    required this.onChanged,
  });

  final AppThemeColor selected;
  final ValueChanged<AppThemeColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final item in AppThemeColor.values)
          _ThemeColorItem(
            colorItem: item,
            isSelected: item == selected,
            onTap: () => onChanged(item),
          ),
      ],
    );
  }
}

class _ThemeColorItem extends StatefulWidget {
  const _ThemeColorItem({
    required this.colorItem,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeColor colorItem;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ThemeColorItem> createState() => _ThemeColorItemState();
}

class _ThemeColorItemState extends State<_ThemeColorItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isSel = widget.isSelected;
    final primary = widget.colorItem.primaryColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSel ? primary : Colors.transparent,
                  width: 2.4,
                ),
              ),
              padding: const EdgeInsets.all(2.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: isSel ? 0.45 : 0.2),
                      blurRadius: isSel ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: isSel
                    ? const Icon(
                        LucideIcons.check,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.colorItem.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                color: isSel ? primary : t.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
