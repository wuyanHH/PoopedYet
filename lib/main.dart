import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/legal/third_party_licenses.dart';
import 'src/state/settings.dart';

Future<void> main() async {
  // SharedPreferences 的初始化是异步的。在这里 await 一次并通过 override 注入，
  // 业务代码里就能**同步**读设置 —— 否则每个用到设置的 widget 都得处理 loading 态，
  // 而设置项（每周起始日、字号）是日历布局的直接输入，不能等。
  WidgetsFlutterBinding.ensureInitialized();

  // 把得意黑的 OFL 许可证注册进 Flutter 的许可系统，
  // 设置页的「开源许可」才能列出来（OFL 要求随分发附上）。
  registerThirdPartyLicenses();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    // ProviderScope 必须包在最外层：databaseProvider 的生命周期挂在它上面，
    // ProviderScope 销毁时数据库连接才会跟着关掉。
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const PoopedYetApp(),
    ),
  );
}
