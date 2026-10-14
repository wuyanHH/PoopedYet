import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/calendar_data.dart';
import '../../theme/tokens.dart';
import 'pooper_avatar.dart';

/// 一排可点的屙屎人。
///
/// 「记一次」和「记录详情」都要用，所以抽出来 ——
/// 两处各写一遍的话，选中态的样式迟早会不一样。
class PooperPickerRow extends ConsumerWidget {
  const PooperPickerRow({
    super.key,
    required this.selectedId,
    required this.onPick,
    this.includeArchived = false,
  });

  /// 当前选中的人。null 表示还没选。
  final String? selectedId;

  final ValueChanged<Pooper> onPick;

  /// 是否把已归档的人也算进来。
  ///
  /// 记录详情里要算：这条记录可能本来就属于一个已归档的人，
  /// 不放出来的话那个"当前选中"的高亮就没地方落。
  final bool includeArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allPoopersProvider).value ?? const <Pooper>[];
    final people = includeArchived
        ? all
        : all.where((p) => p.archivedAt == null).toList();

    if (people.isEmpty) {
      return Text(
        '还没有屙屎人',
        style: TextStyle(fontSize: 13, color: context.tokens.ink3),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < people.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _PooperChip(
              pooper: people[i],
              selected: people[i].id == selectedId,
              onTap: () => onPick(people[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _PooperChip extends StatefulWidget {
  const _PooperChip({
    required this.pooper,
    required this.selected,
    required this.onTap,
  });

  final Pooper pooper;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PooperChip> createState() => _PooperChipState();
}

class _PooperChipState extends State<_PooperChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: PoopMotions.pressDuration,
        curve: PoopMotions.pressCurve,
        child: AnimatedContainer(
          duration: PoopMotions.colorDuration,
          curve: PoopMotions.colorCurve,
          padding: const EdgeInsets.fromLTRB(7, 6, 13, 6),
          decoration: BoxDecoration(
            color: widget.selected ? t.brandSoft : t.surface,
            borderRadius: BorderRadius.circular(PoopRadii.pill),
            border: Border.all(
              color: widget.selected ? t.brandInk : t.lineSoft,
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PooperAvatar(
                pooper: widget.pooper,
                size: 26,
                radius: 9,
                iconSize: 14,
                dimmed: widget.pooper.archivedAt != null,
              ),
              const SizedBox(width: 8),
              Text(
                widget.pooper.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                  color: widget.selected ? t.brandInk : t.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
