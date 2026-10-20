// CupertinoPageTransitionsBuilder 在 cupertino 包里（material 不导出它）。
// 这里只借用它的转场实现，UI 仍然是 Material。
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/settings.dart';
import 'state/sync_state.dart';
import 'theme/tokens.dart';
import 'ui/splash/splash_screen.dart';

/// 应用根组件。
class PoopedYetApp extends ConsumerWidget {
  const PoopedYetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // 挂上自动同步协调器。watch 一次就够 —— 它在内部注册生命周期监听
    // 与数据表变更监听，整个 App 生命周期只跑一份。
    // 没配置 WebDAV 时它什么都不做，用户不会感知到它的存在。
    ref.watch(autoSyncCoordinatorProvider);

    final lightTokens = PoopTokens.create(
      color: settings.themeColor,
      isDark: false,
    );
    final darkTokens = PoopTokens.create(
      color: settings.themeColor,
      isDark: true,
    );

    // 确定当前的实际亮暗主题，设置沉浸式系统栏与底部导航条
    final isDark = switch (settings.themeMode) {
      AppThemeMode.dark => true,
      AppThemeMode.light => false,
      AppThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    return MaterialApp(
      title: '屙了么',
      debugShowCheckedModeBanner: false,

      // 不配这一段的话，Material 的日期/时间选择器会突然冒出英文界面 ——
      // 补录页要用到 showDatePicker / showTimePicker。
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
      locale: const Locale('zh', 'CN'),

      theme: _buildTheme(lightTokens, Brightness.light),
      darkTheme: _buildTheme(darkTokens, Brightness.dark),
      themeMode: settings.themeMode.toFlutterThemeMode(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme(PoopTokens t, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: t.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: t.brandFill,
        brightness: brightness,
        surface: t.surface,
      ),
    );

    return base.copyWith(
      // 设计令牌挂上 ThemeExtension，业务代码用 `context.tokens` 取。
      extensions: [t],

      // 页面转场统一采用清爽流畅的水平视差滑入滑出过渡（Cupertino 动效规范）：
      // 摒弃带有怪异透明度渐变与缩放抖动的动效，自右向左自然推入下一级页面，
      // 上一级产生柔和视差后退；返回时向右滑出，契合页面层级空间直觉。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),

      textTheme: base.textTheme.apply(
        bodyColor: t.ink,
        displayColor: t.ink,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: t.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.ink,
        elevation: 0,
        centerTitle: false,
      ),

      // 水波纹用主题强调色软底。
      splashColor: t.brandSoft,
      highlightColor: t.brandSoft.withValues(alpha: 0.5),

      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),

      // 全局 SnackBar 规范：与手帐白玉卡片和温润质感完全同源，消除刺眼黑块
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.surface,
        contentTextStyle: TextStyle(
          color: t.ink,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: t.lineSoft.withValues(alpha: t.isDark ? 0.35 : 0.8),
            width: 1.0,
          ),
        ),
        elevation: 6,
      ),
    );
  }
}
