import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in people)
          _PooperChip(
            pooper: p,
            selected: p.id == selectedId,
            onTap: () => onPick(p),
          ),
      ],
    );
  }
}

class _PooperChip extends StatelessWidget {
  const _PooperChip({
    required this.pooper,
    required this.selected,
    required this.onTap,
  });

  final Pooper pooper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.fromLTRB(7, 6, 13, 6),
        decoration: BoxDecoration(
          color: selected ? t.brandSoft : t.surface,
          borderRadius: BorderRadius.circular(PoopRadii.pill),
          border: Border.all(
            color: selected ? t.brandInk : t.lineSoft,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PooperAvatar(
              pooper: pooper,
              size: 26,
              radius: 9,
              iconSize: 14,
              dimmed: pooper.archivedAt != null,
            ),
            const SizedBox(width: 8),
            Text(
              pooper.name,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? t.brandInk : t.ink2,
              ),
            ),
            if (pooper.isDefault) ...[
              const SizedBox(width: 6),
              Icon(LucideIcons.star, size: 11, color: t.ink4),
            ],
          ],
        ),
      ),
    );
  }
}
