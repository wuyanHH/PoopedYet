import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

void main() {
  runApp(
    // ProviderScope 必须包在最外层：databaseProvider 的生命周期挂在它上面，
    // 它销毁时数据库连接才会跟着关掉。
    const ProviderScope(child: PoopedYetApp()),
  );
}
