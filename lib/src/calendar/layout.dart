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

/// 计数文字基础字号。
const double kBadgeTextBase = 10.0;

/// 格子内边距合计（上下 3 + 2）。
const double _cellPaddingV = 5.0;

/// 日期行与徽标区之间的间距。
const double _dateToBadgeGap = 2.0;

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

/// 一行徽标需要的高度：取"头像固定高度"和"计数文字高度"的较大者。
double badgeRowHeight(double scale) =>
    math.max(kBadgeIconSize, kBadgeTextBase * scale);

/// 日期行的高度：取"日期数字"和"角标药丸（文字 + 上下内边距）"的较大者。
double dateRowHeight(double scale) =>
    math.max(kDateRowBase * scale, kBadgeTextBase * scale + 4);

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
