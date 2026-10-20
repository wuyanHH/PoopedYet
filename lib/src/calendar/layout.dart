/// 日历格的尺寸计算。
///
/// 纯函数、不依赖 Flutter，方便直接测。
///
/// ## 为什么需要它
///
/// 设计定的格高是固定的 58px。日期 14.5px、角标 10px、头像 14px、计数 10px ——
/// 按这个算，**58px 在字号放大到约 1.35 倍以内都是够的**：
///
/// | 有效字号 | 日期行 | 徽标行 | 需要高度 | 58px 够吗 |
/// |---|---|---|---|---|
/// | 1.0× | 14.5 | 14.0 | 51.5 | ✅ |
/// | 1.3× | 18.85 | 14.0 | 55.9 | ✅ |
/// | 1.5× | 21.75 | 15.0 | 60.8 | ❌ 差 3px |
/// | 2.0× | 29.0 | 20.0 | 78.0 | ❌ 差 20px |
///
/// 注意 1.3 倍时**徽标行还是 14px** —— 头像本身是固定的 14px 图标，
/// 文字涨到 13px 还没超过它。所以真正涨的只有日期行。
/// 这也正是"上限 1.3"这个决定站得住的原因。
///
/// [cellHeightFor] 在需要时把格子撑高，所以**放大字号不会挤爆格子**；
/// 但因为上限卡在 1.5 倍，实际最多撑到约 61px，几乎不会发生。
library;

import 'dart:math' as math;

/// 日期行基础高度（字号 1.0× 时）。
const double kDateRowBase = 14.5;

/// 徽标行基础高度 —— 由头像图标高度决定，不随字号线性变化。
const double kBadgeIconSize = 14.0;

/// 一行徽标的**实际行高**。
///
/// 它比图标本身（[kBadgeIconSize]）高 1px：DayCell 里每个徽标行都是
/// `SizedBox(height: 15)`，那 1px 是容器上下留的呼吸位。
///
/// ⚠ 早先这里直接拿 `kBadgeIconSize` 当行高，每个徽标行少算 1px、
///   两行就是 2px；再叠上日期行漏算的那 1px，字号一到 1.3× 就把
///   58px 的格子挤爆（真机上表现为格子底部一条黄黑警戒条）。
const double kBadgeRowHeight = 15.0;

/// 日期数字上方那层 `Padding(top: 1)`。
const double _dateTopInset = 1.0;

/// 计数文字基础字号。
const double kBadgeTextBase = 10.0;

/// 格子内边距合计（上下 3 + 2）。
const double _cellPaddingV = 5.0;

/// 日期行与徽标区之间的间距。
///
/// ⚠ 从 2 收到 1，是为了把 1.3× 字号下的内容真正压回 58px 以内。
///   把行高与内边距算准之后，1.3× 仍需 57.85px —— 只差 0.15px 的余量太脆，
///   任何一个字体版本变化都可能再溢出；收掉这 1px 后余量变成 1.15px。
const double _dateToBadgeGap = 1.0;

/// 徽标行之间的间距。
const double _badgeGap = 2.0;

/// 设计基准格高。
const double kBaseCellHeight = 58.0;

/// 系统字号在日历格内的**上限**。
///
/// 安卓字体档位是 `1.0 / 1.15 / 1.3 / 1.5 / 2.0`，取 1.3 是因为
/// **它正好是「大」这一档** —— 常用需求全覆盖，只有「特大 / 最大」被截住。
/// 不截的话 2.0× 时 6 行要吃掉约 483px，记录列表基本就没了。
const double kMaxSystemScale = 1.3;

/// 叠加用户手选的「日历字号」之后，总倍率的上限。
///
/// 1.3 × 1.15 = 1.495，刚好压在 1.5 以内。
const double kMaxTotalScale = 1.5;

/// 算出日历格里实际生效的字号倍率。
///
/// [userScale] 是用户在设置里手选的档位（0.9 / 1.0 / 1.15）。
/// 用户的手选是**明确表达**，所以在系统上限之上再乘一次。
double effectiveCalendarScale(double systemScale, double userScale) {
  final sys = systemScale.isFinite && systemScale > 0 ? systemScale : 1.0;
  final usr = userScale.isFinite && userScale > 0 ? userScale : 1.0;
  final capped = math.min(sys, kMaxSystemScale) * usr;
  return math.min(capped, kMaxTotalScale);
}

/// 一行徽标需要的高度。
///
/// 恒为 [kBadgeRowHeight]：DayCell 里每行都写死 `SizedBox(height: 15)`，
/// 内部再用 `FittedBox(scaleDown)` 把内容压进去 —— 所以文字放大时被压的是
/// 内容，行高不变。字号小到 10×scale 也超不过 15，取 max 只是兜底。
double badgeRowHeight(double scale) =>
    math.max(kBadgeRowHeight, kBadgeTextBase * scale);

/// 日期行的高度：取"日期数字"和"角标药丸（文字 + 上下内边距）"的较大者。
///
/// `+_dateTopInset` 对应 DayCell 里日期数字外层那圈 `Padding(top: 1)`，
/// 漏掉它会让算出来的格高比实际需要的少 1px。
double dateRowHeight(double scale) => math.max(
      kDateRowBase * scale + _dateTopInset,
      kBadgeTextBase * scale + 4,
    );

/// 格子至少要多高，内容才不会被压扁。
///
/// 注意返回值可能**小于** [kBaseCellHeight] —— 字号调小时不需要把格子也缩掉，
/// 所以 [cellHeightFor] 会取和基准值的较大者。
double minCellHeightFor(double scale, {int badgeRows = 2}) {
  final rows = badgeRows <= 0 ? 0 : badgeRows;
  final badges = rows == 0
      ? 0.0
      : rows * badgeRowHeight(scale) + (rows - 1) * _badgeGap;
  return _cellPaddingV + dateRowHeight(scale) + _dateToBadgeGap + badges;
}

/// 算出一格最终的高度。
///
/// 正常情况下就是 58；只有字号放大到把内容挤爆时才撑高。
double cellHeightFor(double scale, {int badgeRows = 2}) {
  return math.max(kBaseCellHeight, minCellHeightFor(scale, badgeRows: badgeRows));
}
