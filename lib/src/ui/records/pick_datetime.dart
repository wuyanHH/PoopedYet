import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';
import '../widgets/sheet_shell.dart';

/// 弹出符合暖奶油手账焦糖美学的高颜值一体化时间选择器。
///
/// 彻底告别 Material 官方粗糙丑陋的二次连环弹窗（先弹日历方块、再弹时钟表盘）：
///   - 底部抽屉一站式时分双滚轮（带机械齿轮触感反馈）
///   - 实时等宽大数字时分看板与日期徽标
///   - 预设快捷微调胶囊（当前时刻、±5分钟、整点）
///   - 单次确认保存，零多余弹窗步骤
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CustomDateTimePickerSheet(
      initial: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _CustomDateTimePickerSheet extends StatefulWidget {
  const _CustomDateTimePickerSheet({
    required this.initial,
    this.firstDate,
    this.lastDate,
  });

  final DateTime initial;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<_CustomDateTimePickerSheet> createState() =>
      _CustomDateTimePickerSheetState();
}

class _CustomDateTimePickerSheetState
    extends State<_CustomDateTimePickerSheet> {
  late DateTime _selectedDay;
  late int _selectedHour;
  late int _selectedMinute;

  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  static const double _itemExtent = 40.0;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      widget.initial.year,
      widget.initial.month,
      widget.initial.day,
    );
    _selectedHour = widget.initial.hour;
    _selectedMinute = widget.initial.minute;

    _hourController =
        FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _scrollToTime(int hour, int minute) {
    setState(() {
      _selectedHour = hour.clamp(0, 23);
      _selectedMinute = minute.clamp(0, 59);
    });
    if (_hourController.hasClients) {
      _hourController.animateToItem(
        _selectedHour,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
    if (_minuteController.hasClients) {
      _minuteController.animateToItem(
        _selectedMinute,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
    HapticFeedback.selectionClick();
  }

  void _adjustMinutes(int delta) {
    var dt = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      _selectedHour,
      _selectedMinute,
    ).add(Duration(minutes: delta));
    _scrollToTime(dt.hour, dt.minute);
  }

  Future<void> _changeDate() async {
    final now = DateTime.now();
    final first = widget.firstDate ?? DateTime(now.year - 5);
    final last = widget.lastDate ?? DateTime(now.year + 2, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: first,
      lastDate: last,
      helpText: '选择记录所属日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDay = DateTime(picked.year, picked.month, picked.day);
      });
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hourStr = _selectedHour.toString().padLeft(2, '0');
    final minStr = _selectedMinute.toString().padLeft(2, '0');

    return SheetShell(
      title: '调整记录时间',
      subtitle: '时分双滚轮精密微调，一次确认保存',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------------- 1. 顶部日期徽标与快捷改日期 ----------------
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _changeDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: t.paperDeep,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.lineSoft),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: t.brandSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.calendarDays,
                        size: 15,
                        color: t.brandInk,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_selectedDay.year}年${_selectedDay.month}月${_selectedDay.day}日 · 周${_wd(_selectedDay)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(PoopRadii.pill),
                        border: Border.all(color: t.lineSoft),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '换日期',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: t.ink2,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(LucideIcons.chevronRight, size: 12, color: t.ink3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------------- 2. 居中时分大看板看板 ----------------
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: t.brand.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : const Color(0x102D1B0D),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _TimeDigitCard(digit: hourStr, unit: '时'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: t.brandInk,
                        height: 1.0,
                      ),
                    ),
                  ),
                  _TimeDigitCard(digit: minStr, unit: '分'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ---------------- 3. 双滚轮精密旋转区域 ----------------
            SizedBox(
              height: 136,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 滚轮正中焦糖高光选中条
                  Container(
                    height: _itemExtent,
                    decoration: BoxDecoration(
                      color: t.brandSoft.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: t.brandInk.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                  ),

                  // 上下自然渐变遮罩虚化
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              t.paper.withValues(alpha: 0.85),
                              t.paper.withValues(alpha: 0.0),
                              t.paper.withValues(alpha: 0.0),
                              t.paper.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.28, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 双滚轮
                  Row(
                    children: [
                      // 小时滚轮 (00 ~ 23)
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: _hourController,
                          itemExtent: _itemExtent,
                          perspective: 0.003,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (idx) {
                            setState(() => _selectedHour = idx);
                            HapticFeedback.selectionClick();
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 24,
                            builder: (context, i) {
                              final isSelected = i == _selectedHour;
                              return Center(
                                child: Text(
                                  i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: isSelected ? 21 : 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isSelected ? t.brandInk : t.ink3,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: t.lineSoft,
                      ),
                      // 分钟滚轮 (00 ~ 59)
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: _minuteController,
                          itemExtent: _itemExtent,
                          perspective: 0.003,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (idx) {
                            setState(() => _selectedMinute = idx);
                            HapticFeedback.selectionClick();
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 60,
                            builder: (context, i) {
                              final isSelected = i == _selectedMinute;
                              return Center(
                                child: Text(
                                  i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: isSelected ? 21 : 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isSelected ? t.brandInk : t.ink3,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---------------- 4. 快捷微调药丸胶囊 ----------------
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _PresetChip(
                  label: '设为现在',
                  icon: LucideIcons.rotateCcw,
                  onTap: () {
                    final now = DateTime.now();
                    _scrollToTime(now.hour, now.minute);
                  },
                ),
                _PresetChip(
                  label: '-5分钟',
                  onTap: () => _adjustMinutes(-5),
                ),
                _PresetChip(
                  label: '+5分钟',
                  onTap: () => _adjustMinutes(5),
                ),
                _PresetChip(
                  label: '整点',
                  onTap: () => _scrollToTime(_selectedHour, 0),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ---------------- 5. 一键确认保存 ----------------
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final result = DateTime(
                  _selectedDay.year,
                  _selectedDay.month,
                  _selectedDay.day,
                  _selectedHour,
                  _selectedMinute,
                );
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop(result);
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: PoopMotions.brandGradient,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: PoopMotions.brandShadow,
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.check, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      '确 认 时 间',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _wd(DateTime d) =>
      const ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1];
}

class _TimeDigitCard extends StatelessWidget {
  const _TimeDigitCard({required this.digit, required this.unit});

  final String digit;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          digit,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: t.ink,
            height: 1.0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: t.ink3,
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatefulWidget {
  const _PresetChip({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_PresetChip> createState() => _PresetChipState();
}

class _PresetChipState extends State<_PresetChip> {
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
          decoration: BoxDecoration(
            color: t.paperDeep,
            borderRadius: BorderRadius.circular(PoopRadii.pill),
            border: Border.all(color: t.lineSoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 12, color: t.brandInk),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: t.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
