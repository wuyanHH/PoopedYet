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
    final activeTokens = isDark ? darkTokens : lightTokens;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: activeTokens.paper,
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

      // 页面转场统一走 Flutter 官方这套，别在页面里各自造轮子。
      //
      // Android 用 PredictiveBackPageTransitionsBuilder：它是唯一能接住
      // 系统「预测性返回」逐帧进度的实现（拖入时缩小当前页、露出底页），
      // 系统不支持时自动回退到 FadeForwards。fallbackColor 必须给纸张色 ——
      // 默认的 ColorScheme.surface 在深色主题下转场会闪一块偏亮的底。
      //
      // iOS 不在这里显式配置：PageTransitionsTheme 找不到 iOS 的 key 时
      // 会自动回落到 Cupertino 的横向推入 + 边缘返回，正好是想要的平台
      // 直觉。（本项目只发 Android；桌面平台统一用 FadeForwards。）
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(
            fallbackColor: t.paper,
          ),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(
            backgroundColor: t.paper,
          ),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(
            backgroundColor: t.paper,
          ),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(
            backgroundColor: t.paper,
          ),
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
