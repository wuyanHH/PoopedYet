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
    version: '1.1.5',
    date: '2026年10月',
    title: '关于页新增开源主页入口 · 自动检查间隔缩短至 6 小时',
    highlights: [
      '【开源项目主页入口】「关于屙了么」的协议与致谢区新增 GitHub 仓库主页入口：点击唤起浏览器直达项目主页，浏览器不可用时自动复制链接兜底；长按任意位置可直接复制仓库地址。',
      '【自动检查更勤快】启动静默检查更新的节流间隔由 24 小时缩短为 6 小时——发版节奏加快后，新版本能更快送达，仍保持无更新时全程无声、不打扰；设置页副标题同步更新。',
    ],
  ),
  ChangelogItem(
    version: '1.1.4',
    date: '2026年10月',
    title: '灵动胶囊全新表盘图标 · 更新检查重试与包体瘦身',
    highlights: [
      '【灵动胶囊大图标焕新】通知大图标改为动态绘制的「落叶黄表盘卷纸时钟」圆形徽章，与主页、开屙按钮及桌面小组件的视觉规范同源，告别老旧的闹钟便便图标；状态栏小图标同步重绘。',
      '【不再亮起桌面角标】通知渠道升级为 v6，关闭桌面图标小红点与未读数字角标——进行中的如厕计时是前台服务，不是未读消息；同时关闭通知灯光，仅保留静默计时；旧渠道 v3 / v4 / v5 一并清理。',
      '【修复】断网或请求超时时，启动自动检查不再把「检查时间」提前落盘。原先失败也算「查过了」，二十四小时节流会吞掉网络恢复后的第一次检查；现在只有成功拿到线上版本信息才落盘，恢复联网后下次启动即可重新检查。',
      '【更新检查自动重试】检查更新的网络请求在超时后自动重试一次（连接超时放宽到 12 秒），弱网环境下首次冷启动的检查成功率明显提高。',
      '【修复】物理删除成员后不再出现「全家没有默认人」的空档：删除事务内补上兜底闭环，若删掉的是唯一默认人或最后一名成员，会自动提拔或补建「我」，日历打卡立即可用。',
      '【修复】补录历史记录后，桌面小组件与锁屏灵动胶囊立即同步刷新，与打卡、编辑、删除行为保持同一推流闭环。',
      '【安装包瘦身约 2.37MB】五张设计过程草稿与重复大图（品牌规范底稿、9:16 启动底图等）从打包资源目录迁出归档，安装包体积直接下降；工程内未被引用的历史兼容组件一并移除。',
    ],
  ),
  ChangelogItem(
    version: '1.1.3',
    date: '2026年10月',
    title: '设置页拆分四个专页 · 日历字号溢出修复与胶囊过渡打磨',
    highlights: [
      '【设置页拆分成四个专页】原先一整页的长列表按用途拆开：「外观与主题」负责深浅模式与五套手账色系，「日历与打卡视图」负责默认视图、每周起始日、排序、格内字号与角标，「通知与实时胶囊」负责实时胶囊开关与厂商适配说明，「关于屙了么」负责版本、更新与开源许可。找设置项不用再一路往下滚。',
      '【实时胶囊可单独关闭】新增「开屙实时灵动胶囊」总开关，默认开启。关闭后开屙不再展示前台通知，也不再启动前台服务；原生侧补充 stopLiveIsland 通道方法，运行中可立即收掉胶囊。',
      '【修复】系统字号放大到 1.3× 时，日历格底部溢出 1 像素（真机上表现为格子下方一条黄黑警戒条）。格高预算漏算了徽标行实际的 15px 行高与日期数字外层 1px 内边距，两处补齐后 1.3× 下仍有余量。',
      '【修复】左右滑动切换月份时偶发的布局时序异常。日历卡的高度动画原先用零时长，会走 AnimationController 的同步通知分支，在布局过程中把自身标脏；改为 1ms 后走 ticker 分支，值的变化发生在帧回调里。',
      '【便便感受胶囊】选中与取消改为整套联动过渡：底色、描边、阴影与文字颜色同时淡入淡出，不再出现「胶囊变色了但文字还在跳」；点击时也不再引起位置重排。',
      '【页面转场】回归官方 MaterialPageRoute 与 PageTransitionsTheme：Android 使用 PredictiveBackPageTransitionsBuilder，iOS 使用原生 Cupertino 滑入，桌面使用 FadeForwards，方向关系在各平台都符合直觉。',
      '【沉浸式边到边】接入 edgeToEdge 与透明系统导航栏，关闭导航栏对比度强制，内容延伸到状态栏与手势条之后，不再出现一条硬边色带。',
      '【记录详情】已完成的记录，底部主按钮由「完成」降为次要样式的「关闭」。它本来就只是关掉弹层，不该以焦糖渐变大按钮的姿态冒充一个可执行的动作；只有进行中的记录才保留「完成打卡」。',
      '【防社死暗号入口迁移】暗号模式开关并入「桌面小组件」管理页，切换后立即重推小组件快照，桌面文案即时生效。',
      '【厂商胶囊兼容】通知渠道升级为 v5 并显式清理 v3 / v4 残留，避免旧渠道被系统静音降级的设置带过来；补齐 vivo 原子岛、小米焦点通知与 ColorOS 流体云的识别字段。',
    ],
  ),
  ChangelogItem(
    version: '1.1.2',
    date: '2026年10月',
    title: '桌面小组件交互全面修复 · 换人浮层重做与冷启动稳定性',
    highlights: [
      '【换人不再打开 App】点小组件成员区改为在独立任务里弹出浮层，不再把整个应用拽到前台，关掉浮层即回到桌面；',
      '【换人浮层重做】遮罩改为随窗口淡入、卡片自下而上滑入，去掉系统 Dialog 那套没有过渡的变暗与老旧缩放动画；',
      '【换人浮层不再卡顿】成员头像改为后台解码 + 内存缓存，列表高度在测量阶段一次算好，消除弹出时先铺满再缩回的抖动；',
      '【修复】记录详情里点底部「完成」只关闭弹层、并没有真正结束记录的问题，进行中的记录现在会真的写入结束时间；',
      '【修复】锁屏胶囊 / 通知栏的「完成打卡」在应用冷启动时被丢弃的问题，改为主界面就绪后再交付待处理动作；',
      '【修复】应用进程未在后台时，点小组件「现在开屙 / 完成打卡」毫无反应的问题，后台引擎初始化回归主线程并保活到动作落库；',
      '【修复】换人浮层点卡片空白处会误把浮层关掉的问题，并补齐成员行的按压反馈。',
    ],
  ),
  ChangelogItem(
    version: '1.1.1',
    date: '2026年10月',
    title: '应用内直下安装 · 预测性返回手势与滚动性能治理',
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
    title: '桌面小组件 2.0 体系 · 专属成员绑定与自动云同步',
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
    title: '正式版里程碑首发 · 身心畅快之作',
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
