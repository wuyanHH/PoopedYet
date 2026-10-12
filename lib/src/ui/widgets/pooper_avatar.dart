import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/pooper_icons.dart';
import '../../theme/tokens.dart';

/// 屙屎人头像。
///
/// 三层兜底，从上到下依次退化：
///   1. 用户上传的照片（[Pooper.avatarBlob]，96px 缩略图，直接存在库里）
///   2. 内置 Lucide 图标（[Pooper.iconKey]）
///   3. 姓名首字 + 由 id 稳定推导的底色
///
/// 颜色不存库、由 [avatarColorFor] 从 id 推导 —— 用户不需要选颜色，
/// 而且换设备恢复数据后颜色还是同一个。
class PooperAvatar extends StatelessWidget {
  const PooperAvatar({
    super.key,
    required this.pooper,
    this.size = 38,
    this.radius,
    this.iconSize,
    this.dimmed = false,
  });

  /// 日历格里的迷你徽标。
  const PooperAvatar.xs(this.pooper, {super.key, this.dimmed = false})
      : size = 14,
        radius = 5,
        iconSize = 9;

  /// 列表、选择器里的常规尺寸。
  const PooperAvatar.md(this.pooper, {super.key, this.dimmed = false})
      : size = 38,
        radius = 13,
        iconSize = 18;

  /// 编辑页顶部的大头像。
  const PooperAvatar.xl(this.pooper, {super.key, this.dimmed = false})
      : size = 84,
        radius = 28,
        iconSize = 40;

  final Pooper pooper;
  final double size;
  final double? radius;
  final double? iconSize;

  /// 已归档的人用低饱和显示。
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scheme = avatarColorFor(pooper.id);
    final r = radius ?? size / 2.6;
    final blob = pooper.avatarBlob;

    Widget child;
    if (blob != null && blob.isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.memory(
          Uint8List.fromList(blob),
          width: size,
          height: size,
          fit: BoxFit.cover,
          // 库里的是 96px 缩略图，放大时别糊成马赛克
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => _iconOrInitial(scheme, r),
        ),
      );
    } else {
      child = _iconOrInitial(scheme, r);
    }

    if (!dimmed) return child;
    return Opacity(opacity: 0.45, child: child);
  }

  Widget _iconOrInitial(AvatarColor scheme, double r) {
    // iconKey 为 null 时说明用户没挑图标，这时用姓名首字 ——
    // 中文单字在极小尺寸下的辨识度比线条图标高得多（日历格里只有 9px）。
    final useInitial = pooper.iconKey == null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.bg,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: const Color(0x145E422A)),
      ),
      alignment: Alignment.center,
      child: useInitial
          ? Text(
              initialOf(pooper.name),
              style: TextStyle(
                color: scheme.fg,
                fontSize: iconSize ?? size * 0.48,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            )
          : Icon(
              pooperIconFor(pooper.iconKey),
              color: scheme.fg,
              size: iconSize ?? size * 0.48,
            ),
    );
  }
}
