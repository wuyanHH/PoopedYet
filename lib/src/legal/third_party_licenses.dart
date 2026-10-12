import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 得意黑（Smiley Sans）的许可证文本路径。
///
/// ⚠ 放在 `assets/licenses/` 而**不是** `assets/fonts/`：
/// 后者一旦被声明成资源目录，字体会被当作普通资源再打包一遍，白多 2.5 MB。
const String kSmileyLicenseAsset = 'assets/licenses/SmileySans-OFL.txt';

/// 把第三方组件的许可证注册进 Flutter 的许可系统。
///
/// **为什么必须做这件事**：得意黑是 SIL OFL 1.1 授权，
/// 该许可证要求**随分发附上许可证文本**。把文件塞进 assets 只是"随包"，
/// 不等于"呈现给用户"；接进 [LicenseRegistry] 之后，
/// `showLicensePage()`（设置页的「开源许可」）才会真的把它列出来。
///
/// 另外注意 OFL 的 **Reserved Font Name** 条款：
/// 字体名为 `<Smiley>` / `<得意黑>`，**不得改名后再分发**。
/// 我们只是原样使用，没有修改，所以没问题；
/// 但如果将来要裁剪子集或改字形，必须改成一个不冲突的新名字。
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    String text;
    try {
      text = await rootBundle.loadString(kSmileyLicenseAsset);
    } catch (e) {
      // 许可页不该因为一个资源读不到就整页崩掉 —— 但要留下痕迹，
      // 否则"许可证没显示"这件事会静默地一直存在。
      debugPrint('[LICENSE] 读取 $kSmileyLicenseAsset 失败: $e');
      text = '（许可证文本读取失败，文件应位于 $kSmileyLicenseAsset）';
    }
    yield LicenseEntryWithLineBreaks(
      const ['Smiley Sans (得意黑) — atelierAnchor'],
      text,
    );
  });
}
