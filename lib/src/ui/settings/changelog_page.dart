import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';
import '../widgets/settings_widgets.dart';

/// 版本更新日志数据项
class ChangelogItem {
  const ChangelogItem({
    required this.version,
    required this.date,
    required this.title,
    required this.highlights,
    this.isMilestone = false,
  });

  final String version;
  final String date;
  final String title;
  final List<String> highlights;
  final bool isMilestone;
}

/// 离线版本历史更新日志
const List<ChangelogItem> kAppChangelogs = [
  ChangelogItem(
    version: '1.1.1',
    date: '2026年10月',
    title: '⬇️ 应用内直下安装 · 预测性返回手势与滚动性能治理',
    highlights: [
      '【应用内直下安装】更新弹窗支持应用内流式下载 APK，实时显示百分比、速度与剩余时间，下载完一键拉起系统安装器；',
      '【静默后台下载】点「后台下载并隐藏」后弹窗关闭、下载继续，通知栏不出现任何下载通知，主页只留一条可收起的迷你进度环；',
      '【断点续传】下载中断或进程被杀后，下次从已下载字节处继续，不必重下整个安装包；',
      '【富文本更新日志】发布说明以手帐风富文本渲染（标题、列表、加粗、代码、链接），顶部给出体积与「新增 / 优化 / 修复」条目计数；',
      '【预测性返回手势】页面转场回归官方 MaterialPageRoute 与 PageTransitionsTheme，Android 14+ 拖动返回时可实时预览上一页；',
      '【滚动流畅度治理】打卡卡片刻意去掉整卡阴影与多余裁剪、日历格改用常驻容器、当日列表去掉外层 AnimatedSwitcher，翻月与滑动更跟手；',
      '【修复】点击「其他架构安装包」连续切换时，旧任务的取消与失败不再覆盖新任务的下载状态。',
    ],
  ),
  ChangelogItem(
    version: '1.1.0',
    date: '2026年10月',
    title: '✨ 桌面小组件 2.0 体系 · 专属成员绑定与自动云同步升级',
    isMilestone: true,
    highlights: [
      '【桌面小组件 2.0 全面进化】新增 34 种成员专属矢量图标头像体系，支持按成员定制专属小组件；',
      '【长按小组件配置向导】新增 WidgetConfigActivity，长按桌面小组件即可即时指派成员与偏好；',
      '【桌面小组件管理专页】设置页新增「桌面小组件」预览与管理面板，包含高清实机渲染效果与添加指南；',
      '【全场景自动云同步】新增轻量后台自动云同步，打卡、编辑、删除后自动静默推送到 WebDAV；',
      '【应用内智能更新与芯片架构识别】深度联动 GitHub Releases，按手机芯片（arm64-v8a 等）精准分发与下载更新；',
      '【手帐转场动画与触觉体验打磨】全链路接入自研 SmoothPageRoute 平滑手帐翻页转场动效。',
    ],
  ),
  ChangelogItem(
    version: '1.0.0',
    date: '2025年03月',
    title: '🎉 正式版里程碑首发 · 身心畅快之作',
    isMilestone: true,
    highlights: [
      '【桌面小组件就绪】小号撕历打卡 (2×2)、中号手帐周历 (4×2)、大号健康工作台 (4×4) 全面就绪，支持桌面一键开屙与完事；',
      '【状态栏胶囊与锁屏秒表】开始排便时常驻系统级秒表，支持各大厂商胶囊识别，锁屏支持一键完成打卡；',
      '【WebDAV 云端同步与恢复】支持坚果云/自建 NAS 备份与分类细粒度还原，新增智能折叠与紧凑排版；',
      '【暗号模式】开启后将便便词汇转化为“深度放空”与“身心减负”，公共场合随心记；',
      '【自研头像裁剪与便签速记】支持自定义成员头像圆形裁剪缩放，便便感受标签智能高频排序；',
      '【首启体验优化】修复首启日历提示条响应式收起 Bug，升级为丝滑平滑收折；',
      '【绝对纯单机隐私承诺】无任何后台恶意识别、无埋点无网络追踪，数据 100% 存在本地。',
    ],
  ),
  ChangelogItem(
    version: '0.3.3',
    date: '2025年03月',
    title: '小组件深度集成与厂商胶囊优化',
    highlights: [
      '深度适配 vivo OriginOS、小米 HyperOS、OPPO 流体云状态栏胶囊；',
      '新增小组件深链路由，桌面点击秒级跳转打卡；',
      '优化节假日排班数据离线打包，节假日角标展示更准确。',
    ],
  ),
  ChangelogItem(
    version: '0.3.0',
    date: '2025年02月',
    title: '暗号模式与多成员手帐周历',
    highlights: [
      '新增多成员管理体系，全家每个人拥有独立便便色彩与头像；',
      '上线经典撕历与周历手帐视图，顺畅连击天数 (Streak) 实时统计；',
      '引入得意黑斜体展示字体，强化复古手帐美学。',
    ],
  ),
  ChangelogItem(
    version: '0.2.0',
    date: '2025年01月',
    title: '本地 JSON 备份与离线分享',
    highlights: [
      '支持全量本地数据导出为通用 JSON 备份文件；',
      '集成系统级安全 FileProvider，支持通过微信、QQ、本地文件管理器分享与导入；',
      '支持补录过去历史时间段的排便记录。',
    ],
  ),
  ChangelogItem(
    version: '0.1.0',
    date: '2024年12月',
    title: '屙了么初代诞生',
    highlights: [
      '“一次点击开屙，轻松记录身心”，确立极简操作交互；',
      '纯本地 SQLite 数据库架构建立，极速秒启，告别臃肿。',
    ],
  ),
];

/// 离线版本历史更新日志页面
class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SettingsScaffold(
      title: '版本更新日志',
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
        itemCount: kAppChangelogs.length,
        itemBuilder: (context, index) {
          final item = kAppChangelogs[index];
          final isFirst = index == 0;
          final isLast = index == kAppChangelogs.length - 1;

          return _TimelineNode(
            item: item,
            isFirst: isFirst,
            isLast: isLast,
          );
        },
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  final ChangelogItem item;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间线轴
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: item.isMilestone ? 14 : 10,
                  height: item.isMilestone ? 14 : 10,
                  decoration: BoxDecoration(
                    color: item.isMilestone ? t.brandFill : t.brandSoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.isMilestone ? Colors.white : t.brandInk,
                      width: 2,
                    ),
                    boxShadow: item.isMilestone
                        ? [
                            BoxShadow(
                              color: t.brandFill.withValues(alpha: 0.35),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: t.lineSoft.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 右侧卡片内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item.isMilestone
                        ? t.brandInk.withValues(alpha: 0.35)
                        : t.lineSoft,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0A2D1B0D),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: item.isMilestone ? t.brandFill : t.paperDeep,
                            borderRadius: BorderRadius.circular(PoopRadii.pill),
                          ),
                          child: Text(
                            'v${item.version}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: item.isMilestone ? Colors.white : t.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.date,
                          style: TextStyle(fontSize: 11.5, color: t.ink3),
                        ),
                        if (item.isMilestone) ...[
                          const Spacer(),
                          Icon(LucideIcons.crown, size: 14, color: t.brandInk),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: displayStyle(
                        size: 14.5,
                        letterSpacing: 0.3,
                        color: item.isMilestone ? t.brandInk : t.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...item.highlights.map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: t.brandInk,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                h,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: t.ink2,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
