import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 内置图标头像的目录。
///
/// **全部用 Lucide 矢量图标，禁止 emoji** —— emoji 在不同设备上长得不一样，
/// 而且渲染出来带一层廉价感，和"便签手帐"的方向不搭。
///
/// 存进数据库的是 [PooperIcon.key]（字符串，如 `dog`），不是 IconData ——
/// IconData 的码点是字体内部编号，换图标库版本就会变，存进去等于存了个随机数。
/// 取不到 key 时回落到 `user`，所以删掉某个图标也不会让老数据崩。
class PooperIcon {
  const PooperIcon(this.key, this.icon);

  final String key;
  final IconData icon;
}

/// 可选图标，顺序就是选择器里的显示顺序。
///
/// 前半是动物（贴合"屙屎人"的玩梗气质），后半是物件与人物。
const List<PooperIcon> kPooperIcons = [
  PooperIcon('dog', LucideIcons.dog),
  PooperIcon('cat', LucideIcons.cat),
  PooperIcon('rabbit', LucideIcons.rabbit),
  PooperIcon('bird', LucideIcons.bird),
  PooperIcon('turtle', LucideIcons.turtle),
  PooperIcon('fish', LucideIcons.fish),
  PooperIcon('snail', LucideIcons.snail),
  PooperIcon('squirrel', LucideIcons.squirrel),
  PooperIcon('bug', LucideIcons.bug),
  PooperIcon('ghost', LucideIcons.ghost),
  PooperIcon('star', LucideIcons.star),
  PooperIcon('heart', LucideIcons.heart),
  PooperIcon('crown', LucideIcons.crown),
  PooperIcon('rocket', LucideIcons.rocket),
  PooperIcon('leaf', LucideIcons.leaf),
  PooperIcon('flame', LucideIcons.flame),
  PooperIcon('droplet', LucideIcons.droplet),
  PooperIcon('zap', LucideIcons.zap),
  PooperIcon('coffee', LucideIcons.coffee),
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
  PooperIcon('user', LucideIcons.user),
  PooperIcon('users', LucideIcons.users),
  PooperIcon('smartphone', LucideIcons.smartphone),
  PooperIcon('sun', LucideIcons.sun),
  PooperIcon('moon', LucideIcons.moon),
  PooperIcon('palette', LucideIcons.palette),
];

/// key -> IconData。
final Map<String, IconData> _byKey = {
  for (final e in kPooperIcons) e.key: e.icon,
};

/// 兜底图标：没有选图标、或者 key 已经不存在时用。
const IconData kFallbackPooperIcon = LucideIcons.user;

/// 按 key 取图标；取不到就回落，**不抛异常**。
///
/// 回落而不是报错，是因为 key 存在数据库里 —— 万一将来改图标库删掉了某个图标，
/// 老用户的头像应该退化成默认图标，而不是让日历整页崩掉。
IconData pooperIconFor(String? key) {
  if (key == null) return kFallbackPooperIcon;
  return _byKey[key] ?? kFallbackPooperIcon;
}

/// key 是否是我们认识的图标。
bool isKnownPooperIcon(String? key) => key != null && _byKey.containsKey(key);
