import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/pooper_icons.dart';
import '../../theme/tokens.dart';

/// 屙屎人头像内存图片稳定缓存池。
///
/// **为什么需要它**：
/// 默认 [MemoryImage] 在 Dart 中仅通过 `Uint8List` 的指针内存地址比对相等性 (`identical`)。
/// 列表滚动触发 item 重建或数据刷新时，若每次传入新生成的列表或者对象引用，
/// 会导致 Flutter 图片管道误判为全新图片，反复触发异步解码并在解码空档期置空图像，
/// 从而引起肉眼可见的头像闪烁。
///
/// 通过此缓存池，只要该成员的图片长度与指纹未变，全局**始终复用同一个 [MemoryImage] 实例**，
/// 彻底根除页面滚动时的头像闪烁，同时省去无谓的重复 CPU/GPU 纹理重解码。
class _CachedAvatarEntry {
  const _CachedAvatarEntry({
    required this.image,
    required this.length,
    required this.fingerprint,
  });

  final MemoryImage image;
  final int length;
  final int fingerprint;

  bool matches(Uint8List blob) {
    if (blob.length != length) return false;
    return _calcFingerprint(blob) == fingerprint;
  }

  static int _calcFingerprint(Uint8List blob) {
    if (blob.isEmpty) return 0;
    final len = blob.length;
    final b0 = blob[0];
    final bMid = blob[len ~/ 2];
    final bEnd = blob[len - 1];
    return Object.hash(len, b0, bMid, bEnd);
  }
}

class _AvatarImageCache {
  static final Map<String, _CachedAvatarEntry> _entries = {};

  static MemoryImage resolve(String pooperId, Uint8List blob) {
    final cached = _entries[pooperId];
    if (cached != null && cached.matches(blob)) {
      return cached.image;
    }
    final image = MemoryImage(blob);
    _entries[pooperId] = _CachedAvatarEntry(
      image: image,
      length: blob.length,
      fingerprint: _CachedAvatarEntry._calcFingerprint(blob),
    );
    return image;
  }
}

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
        child: Image(
          image: _AvatarImageCache.resolve(pooper.id, blob),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          // 库里的是 96px 缩略图，放大时保持平滑抗锯齿
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => _iconOrInitial(scheme, r),
        ),
      );
    } else {
      child = _iconOrInitial(scheme, r);
    }

    if (dimmed) {
      child = Opacity(opacity: 0.45, child: child);
    }

    // 只有列表 / 详情里的大头像才值得单独划一条重绘边界。
    //
    // 日历格里的迷你徽标（14px）一屏就可能出现几十个，每个都包一层
    // RepaintBoundary 就是几十个独立图层——翻月、滚动时合成成本反而更高，
    // 而且这些小图标本身几乎不重绘，边界带不来任何收益。
    if (size < 24) {
      return child;
    }
    return RepaintBoundary(child: child);
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
