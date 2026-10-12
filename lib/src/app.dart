import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/tokens.dart';
import 'ui/home_page.dart';

/// 应用根组件。
class PoopedYetApp extends StatelessWidget {
  const PoopedYetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final t = PoopTokens.light;

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

      theme: _buildTheme(t),
      home: const HomePage(),
    );
  }

  ThemeData _buildTheme(PoopTokens t) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: t.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: t.brandFill,
        brightness: Brightness.light,
        surface: t.surface,
      ),
    );

    return base.copyWith(
      // 设计令牌挂上 ThemeExtension，业务代码用 `context.tokens` 取。
      extensions: [t],

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

      // 日历是可交互的，水波纹用焦糖色而不是 Material 默认的紫色。
      splashColor: t.brandSoft,
      highlightColor: t.brandSoft.withValues(alpha: 0.5),

      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
    );
  }
}
