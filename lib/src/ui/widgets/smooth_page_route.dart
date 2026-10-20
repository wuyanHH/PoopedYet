import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 二级页面的统一转场入口。
///
/// 统一采用 [CupertinoPageRoute]，提供清爽流畅的水平平滑推入/滑出视差过渡，
/// 消除透明度闪烁与缩放渐变，完全契合页面层级空间衔接。
Route<T> smoothPageRoute<T>(Widget page) => CupertinoPageRoute<T>(
  builder: (_) => page,
);
