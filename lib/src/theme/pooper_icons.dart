import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 内置图标头像的定义。
class PooperIcon {
  const PooperIcon(this.key, this.icon, {this.label = ''});

  final String key;
  final IconData icon;
  final String label;
}

/// 精选推荐的高频实用头像列表（彻底移除无厘头的公文包、飞机、正方形、便利贴等奇怪图标）。
///
/// 聚焦于：家庭成员、常见萌宠以及温馨日常符号。
const List<PooperIcon> kCuratedPooperIcons = [
  // ---- 角色与家庭 ----
  PooperIcon('user', LucideIcons.user, label: '我/个人'),
  PooperIcon('users', LucideIcons.users, label: '家庭/情侣'),
  PooperIcon('heart', LucideIcons.heart, label: '爱心/宝贝'),
  PooperIcon('crown', LucideIcons.crown, label: '皇冠/主子'),

  // ---- 萌宠与动物 ----
  PooperIcon('dog', LucideIcons.dog, label: '小狗'),
  PooperIcon('cat', LucideIcons.cat, label: '小猫'),
  PooperIcon('rabbit', LucideIcons.rabbit, label: '小兔'),
  PooperIcon('bird', LucideIcons.bird, label: '小鸟'),
  PooperIcon('fish', LucideIcons.fish, label: '小鱼'),

  // ---- 治愈与生活符号 ----
  PooperIcon('sun', LucideIcons.sun, label: '太阳/活力'),
  PooperIcon('moon', LucideIcons.moon, label: '月亮/晚安'),
  PooperIcon('star', LucideIcons.star, label: '星星/闪耀'),
  PooperIcon('coffee', LucideIcons.coffee, label: '咖啡/打工'),
  PooperIcon('flame', LucideIcons.flame, label: '火苗/热情'),
  PooperIcon('leaf', LucideIcons.leaf, label: '绿叶/清新'),
];

/// 历史全部图标字典（仅用于向后兼容，确保老用户若曾存过旧 key 仍能正确渲染，不会报错或崩溃）。
const List<PooperIcon> _kAllLegacyIcons = [
  ...kCuratedPooperIcons,
  PooperIcon('turtle', LucideIcons.turtle),
  PooperIcon('snail', LucideIcons.snail),
  PooperIcon('squirrel', LucideIcons.squirrel),
  PooperIcon('bug', LucideIcons.bug),
  PooperIcon('ghost', LucideIcons.ghost),
  PooperIcon('rocket', LucideIcons.rocket),
  PooperIcon('droplet', LucideIcons.droplet),
  PooperIcon('zap', LucideIcons.zap),
  PooperIcon('milk', LucideIcons.milk),
  PooperIcon('pizza', LucideIcons.pizza),
  PooperIcon('utensils', LucideIcons.utensils),
  PooperIcon('partyPopper', LucideIcons.partyPopper),
  PooperIcon('briefcase', LucideIcons.briefcase),
  PooperIcon('graduationCap', LucideIcons.graduationCap),
  PooperIcon('plane', LucideIcons.plane),
  PooperIcon('home', LucideIcons.home),
  PooperIcon('mapPin', LucideIcons.mapPin),
  PooperIcon('stickyNote', LucideIcons.stickyNote),
  PooperIcon('play', LucideIcons.play),
  PooperIcon('square', LucideIcons.square),
  PooperIcon('wind', LucideIcons.wind),
  PooperIcon('bed', LucideIcons.bed),
  PooperIcon('bath', LucideIcons.bath),
  PooperIcon('smartphone', LucideIcons.smartphone),
  PooperIcon('palette', LucideIcons.palette),
];

/// 暴露给外部选择器的精选图标列表
const List<PooperIcon> kPooperIcons = kCuratedPooperIcons;

/// key -> IconData。
final Map<String, IconData> _byKey = {
  for (final e in _kAllLegacyIcons) e.key: e.icon,
};

/// 兜底图标：没有选图标、或者 key 已经不存在时用。
const IconData kFallbackPooperIcon = LucideIcons.user;

/// 按 key 取图标；取不到就回落，不抛异常。
IconData pooperIconFor(String? key) {
  if (key == null) return kFallbackPooperIcon;
  return _byKey[key] ?? kFallbackPooperIcon;
}

/// key 是否是我们认识的图标。
bool isKnownPooperIcon(String? key) => key != null && _byKey.containsKey(key);
