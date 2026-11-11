import 'dart:math' as math;

import 'package:flutter/material.dart';

/// v2.4 品牌符号「星雨 · 落瓶」的权威几何（与 tool/gen_visual.py:jar_geometry()
/// 同源）。一图双义：正坠的四芒闪星 = 一次灵感来了；瓶内液面 = 已经攒了多少。
///
/// v2.3 的品牌符号是水滴（灵感的容器）；v2.4 应「更闪 + 积累要有形象寓意」
/// 的方向决策改为开口玻璃瓶 + 琥珀液面 + 四芒闪星。琥珀金专属「灵感/闪」，
/// 品牌蓝专属玻璃壁，绿仍专属「完成」、蓝仍专属「推进中」。

/// v2.3 品牌水滴轮廓（保留：捕获动作的「一滴」意象仍在快拍入口使用）。
///
/// 单位坐标：尖顶 (0,-.44) / 左右腰 (±.33,.10) / 底圆心 (0,.10) 半径 .33。
/// H = min(w/.72, h/.94) 保证下半底始终是**正圆**，不会被容器拉伸成椭圆；
/// 宽高比固定 ≈ 0.759。
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

/// v2.4 品牌开口玻璃瓶轮廓（与 gen_visual.py:jar_outline() 同源）。
///
/// 单位坐标（y 向下为正，原点在瓶中心）：
/// 口半宽 0.26 / 腹半宽 0.34 / 口沿 y=-0.36 / 底 y=+0.30 / 底圆角 0.12 /
/// 口沿外挑 0.07。含口沿的总宽 = 0.82H，总高 = 0.66H。
/// H = min(w/.82, h/.66) 保证比例不被拉伸。
Path brandJarPath(Rect rect) {
  final H = math.min(rect.width / 0.82, rect.height / 0.66);
  final cx = rect.center.dx;
  final cy = rect.center.dy;
  Offset p(double ux, double uy) => Offset(cx + ux * H, cy + uy * H);

  const hm = 0.26, hb = 0.34, top = -0.36, bot = 0.30, cr = 0.12, lip = 0.07;
  return Path()
    // 注意：arcToPoint 只能画 ≤180° 的弧，无法表达「口沿外挑」这种
    // 尖角折返；口沿用两段 lineTo 表达，与生成器 polyline 同构。
    ..moveTo(p(-hm - lip, top).dx, p(-hm - lip, top).dy) // 左口沿外端
    ..lineTo(p(-hm, top).dx, p(-hm, top).dy) // 左口沿内端（尖角折返点）
    ..lineTo(p(-hb, top + 0.10).dx, p(-hb, top + 0.10).dy) // 左肩张开
    ..lineTo(p(-hb, bot - cr).dx, p(-hb, bot - cr).dy) // 左壁直段
    // 左下圆角：圆心 (-hb+cr, bot-cr)。方向坑与水滴同源：y 向下为正，
    // 沿顺时针描边（左壁下行 → 底部 → 右壁上行）四角都是 clockwise:true。
    ..arcToPoint(p(-hb + cr, bot), radius: Radius.circular(cr * H),
        clockwise: true)
    ..lineTo(p(hb - cr, bot).dx, p(hb - cr, bot).dy) // 底部直段
    ..arcToPoint(p(hb, bot - cr), radius: Radius.circular(cr * H),
        clockwise: true)
    ..lineTo(p(hb, top + 0.10).dx, p(hb, top + 0.10).dy) // 右壁直段
    ..lineTo(p(hm, top).dx, p(hm, top).dy) // 右肩收口
    ..lineTo(p(hm + lip, top).dx, p(hm + lip, top).dy) // 右口沿外端
    ..close();
}

/// 瓶内液面：给定瓶 rect 与液位 level ∈ [0,1]（0 空 / 0.5 半满 / 1 满），
/// 返回液面以下的填充路径（贴内壁、含底部圆角，与 gen_visual.py:jar_liquid()
/// 同源）。y 向下为正：level 越大液面越高、ly 越小，故
/// 液面在 [bot-0.07, top+0.05] 内插值，宽按内壁收 0.025。
Path brandJarLiquidPath(Rect rect, double level) {
  final H = math.min(rect.width / 0.82, rect.height / 0.66);
  final cx = rect.center.dx;
  final cy = rect.center.dy;
  Offset p(double ux, double uy) => Offset(cx + ux * H, cy + uy * H);

  const hm = 0.26, hb = 0.34, top = -0.36, bot = 0.30, cr = 0.12;
  const inset = 0.025;
  // 液面 y：level 0 → bot-0.07（近瓶底/空），level 1 → top+0.05（近瓶口/满）
  var ly = (bot - 0.07) + (top + 0.05 - (bot - 0.07)) * level.clamp(0.0, 1.0);
  // 内壁半宽：肩部 (top, top+0.10) 内从口到腹线性张开
  double wallX(double uy) {
    if (uy <= top) return hm;
    final t = math.min(1.0, (uy - top) / 0.10);
    return hm + (hb - hm) * t;
  }

  final hw = wallX(ly) - inset;
  final rr = math.min(cr, hw);
  // 与生成器 jar_liquid 同源：液面不得低于底部圆角起点，否则右壁直段
  // 会从液面向上翻折，得到自交的畸形液体区域（低液位时尤其明显）。
  ly = math.min(ly, bot - rr);
  // 液面下的瓶身轮廓在底部圆角以下还要继续向下弯：左/右壁直段从液面
  // 画到 bot-rr，再用弧段拐进底部。液体顶点序与生成器 jar_liquid 一致：
  // 液面左 → 液面右 → 右壁 → 右下圆角 → 底 → 左下圆角 → 闭合。
  final path = Path()
    ..moveTo(p(-hw, ly).dx, p(-hw, ly).dy) // 液面左
    ..lineTo(p(hw, ly).dx, p(hw, ly).dy) // 液面右
    ..lineTo(p(hw, bot - rr).dx, p(hw, bot - rr).dy) // 右壁直段
    ..arcToPoint(p(hw - rr, bot), radius: Radius.circular(rr * H),
        clockwise: true) // 右下圆角
    ..lineTo(p(-hw + rr, bot).dx, p(-hw + rr, bot).dy) // 底部直段
    ..arcToPoint(p(-hw, bot - rr), radius: Radius.circular(rr * H),
        clockwise: true) // 左下圆角
    ..close();
  return path;
}

/// 首页「记一条」FAB 的水滴形边框（捕获 = 接住一滴灵感）。
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
