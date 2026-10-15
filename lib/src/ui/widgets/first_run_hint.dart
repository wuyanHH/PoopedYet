import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../state/calendar_data.dart';
import '../../state/calendar_view.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../settings/pooper_list_page.dart';
import 'smooth_page_route.dart';

/// 首启的一次性提示条（视觉稿 ⑳）。
///
/// 首启**不弹引导页** —— 这个 App 的核心动作是"一次点击开屙"，
/// 在它前面竖一道"先填名字选头像"的墙，是用最贵的位置解决最便宜的问题。
/// 「屙屎人」这个特色用一条可关掉的提示条交代就够了。
///
/// 显示条件（三个都满足）：
///   1. 用户没关过它
///   2. 正好只有一个在册屙屎人
///   3. 这个人一条记录都没有
///
/// 第 2、3 条合起来就是"刚装好还没开始用"。一旦记录过、或加过人，
/// 提示条自己就消失了，不需要额外的状态。
class FirstRunHint extends ConsumerStatefulWidget {
  const FirstRunHint({super.key});

  @override
  ConsumerState<FirstRunHint> createState() => _FirstRunHintState();
}

class _FirstRunHintState extends ConsumerState<FirstRunHint> {
  bool _dismissed = false;

  void _dismiss(SharedPreferences prefs) {
    if (_dismissed) return;
    setState(() => _dismissed = true);
    prefs.setBool(kFirstRunHintDismissed, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final prefs = ref.watch(sharedPrefsProvider);
    if (_dismissed || (prefs.getBool(kFirstRunHintDismissed) ?? false)) {
      return const SizedBox.shrink();
    }

    final poopers = ref.watch(activePoopersProvider).value;
    if (poopers == null || poopers.length != 1) return const SizedBox.shrink();

    // 这个人在册但还没有任何记录 → 说明还在"刚装好"阶段
    // 使用统一的 todayProvider 归一化当月月份，避免毫秒级全新 key 导致 Provider 重复查询
    final today = ref.watch(todayProvider);
    final records = ref.watch(monthBadgesProvider(normalizeMonth(today))).value;
    // 只查当月不够严谨，但首启提示条只关心"最近有没有开始用"，
    // 而且当月没记录时用户看到提示也是合适的。
    final hasAnyInMonth = records != null && records.isNotEmpty;
    if (hasAnyInMonth) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      child: _dismissed
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
                decoration: BoxDecoration(
                  color: t.brandSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x2E9A5219)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: t.brandFill,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(LucideIcons.users, size: 15, color: Colors.white),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '已自动创建「${poopers.first.name}」',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: t.brandInk,
                              height: 1.35,
                            ),
                          ),
                          Text(
                            '家里还有别人要记？可以加多个屙屎人',
                            style: TextStyle(fontSize: 11, color: t.ink2, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        // 点击「去添加」后标记提示已读，并顺畅导航至屙屎人管理列表页
                        _dismiss(prefs);
                        Navigator.of(context).push(
                          smoothPageRoute(const PooperListPage()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: t.brandFill,
                          borderRadius: BorderRadius.circular(PoopRadii.pill),
                        ),
                        child: const Text(
                          '去添加',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // ✕ 优化触控热区与即时响应反馈，杜绝点不中的问题
                    IconButton(
                      onPressed: () => _dismiss(prefs),
                      icon: Icon(LucideIcons.x, size: 16, color: t.ink3),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      splashRadius: 18,
                      tooltip: '关闭提示',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
