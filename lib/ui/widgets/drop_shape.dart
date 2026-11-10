import 'dart:math' as math;

import 'package:flutter/material.dart';

/// v2.3 品牌水滴的权威轮廓几何（与 tool/gen_visual.py:drop_outline() 同源）。
///
/// 单位坐标：尖顶 (0,-.44) / 左右腰 (±.33,.10) / 底圆心 (0,.10) 半径 .33。
/// H = min(w/.72, h/.94) 保证下半底始终是**正圆**，不会被容器拉伸成椭圆；
/// 宽高比固定 ≈ 0.759。
///
/// 背景：首页「记一条」FAB 在 v1 用四段 cubicTo 把 60×60 撑成 1:1 的扁蛋形，
/// 底部是宽扁椭圆而不是圆。v2.3 重塑启动图标时漏改了这个页面内私有控件，
/// 于是应用里出现一枚和品牌符号不同构的「变形水滴」。v2.3.1 把几何抽到此处，
/// 让 FAB 与生成器共用同一套坐标，并由 test/drop_shape_test.dart 守住宽高比。
Path brandDropPath(Rect rect) {
  final H = math.min(rect.width / 0.72, rect.height / 0.94);
  final cx = rect.center.dx;
  final cy = rect.center.dy;
  Offset p(double ux, double uy) => Offset(cx + ux * H, cy + uy * H);

  final top = p(0, -0.44);
  final rWaist = p(0.33, 0.10);
  final lWaist = p(-0.33, 0.10);
  return Path()
    // 尖顶 → 右腰：生成器 R 曲线的控制点
    ..moveTo(top.dx, top.dy)
    ..cubicTo(p(0.015, -0.20).dx, p(0.015, -0.20).dy,
        p(0.33, -0.02).dx, p(0.33, -0.02).dy, rWaist.dx, rWaist.dy)
    // 右腰 → 左腰：正圆下半弧。radius = 半弦长 → 恰为半圆。
    // 方向坑：本函数 y 向下为正，从右腰到左腰必须 clockwise:true 才走下半圆；
    // clockwise:false 会走上半圆，得到「尖顶 + 上鼓包」的倒怪形状——v2.3.1
    // 的 drop_shape_test.dart 实测 bbox 高只有 0.54H（而非 0.87H）才抓到它。
    ..arcToPoint(lWaist, radius: Radius.circular(0.33 * H), clockwise: true)
    // 左腰 → 尖顶：生成器 L 曲线反向
    ..cubicTo(p(-0.33, -0.02).dx, p(-0.33, -0.02).dy,
        p(-0.015, -0.20).dx, p(-0.015, -0.20).dy, top.dx, top.dy)
    ..close();
}

/// 首页「记一条」FAB 的水滴形边框（也可供其它品牌按钮复用）。
class DropShapeBorder extends OutlinedBorder {
  const DropShapeBorder();

  @override
  OutlinedBorder copyWith({BorderSide? side}) => const DropShapeBorder();

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      brandDropPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => const DropShapeBorder();
}
