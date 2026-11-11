import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixiang_note/ui/widgets/drop_shape.dart';

/// 品牌水滴几何守卫。
///
/// v1 的「记一条」FAB 用四段 cubicTo 把 60×60 撑满，得到 1:1 的扁蛋形
/// （底部宽扁椭圆），v2.3 重塑启动图标时漏改了它，用户看到「变形水滴」
/// （m07447）。v2.3.1 把几何抽到 brandDropPath()，这里把「尖顶 + 正圆底 +
/// 宽高比 0.759」钉死，防止以后有人又把形状拉回 1:1。
void main() {
  double ratio(Rect rect) {
    final b = brandDropPath(rect).getBounds();
    return b.width / b.height;
  }

  test('方形 rect 下宽高比 ≈ 0.759，不是 v1 的 1.0 扁蛋形', () {
    final r = ratio(const Rect.fromLTWH(0, 0, 60, 60));
    expect(r, closeTo(0.759, 0.01),
        reason: '品牌水滴必须是收腰的水滴（0.66H / 0.87H ≈ 0.759），'
            '1.0 说明退回了撑满容器的扁蛋形');
    expect(r, lessThan(0.85));
  });

  test('不同尺寸/长宽比下比例恒定：H 自适应，正圆底不会被拉伸', () {
    const rects = [
      Rect.fromLTWH(0, 0, 60, 60), // FAB 实际尺寸
      Rect.fromLTWH(0, 0, 100, 100),
      Rect.fromLTWH(0, 0, 120, 60), // 很宽
      Rect.fromLTWH(0, 0, 60, 120), // 很高
      Rect.fromLTWH(13, 27, 48, 90), // 带偏移
    ];
    for (final rect in rects) {
      expect(ratio(rect), closeTo(0.759, 0.01),
          reason: 'rect=$rect 时水滴被拉伸了——H 应由 min(w/.72,h/.94) 决定');
    }
  });

  test('宽高等于 0.66H / 0.87H，且形状居中不越界', () {
    const rect = Rect.fromLTWH(0, 0, 60, 60);
    final b = brandDropPath(rect).getBounds();
    // H = min(60/.72, 60/.94) = 60/.94
    final H = 60 / 0.94;
    expect(b.width, closeTo(0.66 * H, 0.5));
    expect(b.height, closeTo(0.87 * H, 0.5));
    expect(b.center.dx, closeTo(rect.center.dx, 0.5));
    expect(b.center.dy, closeTo(rect.center.dy, 0.5));
    // 尖顶朝上、底朝下：整体留在 rect 内（生成器留的安全余量）
    expect(b.top, greaterThanOrEqualTo(rect.top - 0.5));
    expect(b.bottom, lessThanOrEqualTo(rect.bottom + 0.5));
  });

  test('DropShapeBorder 的 outer/inner path 与 brandDropPath 一致', () {
    const rect = Rect.fromLTWH(0, 0, 60, 60);
    const border = DropShapeBorder();
    final expected = brandDropPath(rect).getBounds();
    for (final p in [
      border.getOuterPath(rect),
      border.getInnerPath(rect),
    ]) {
      final b = p.getBounds();
      expect(b.width, closeTo(expected.width, 0.01));
      expect(b.height, closeTo(expected.height, 0.01));
    }
  });

  // ---- v2.4 星雨落瓶（brandJarPath / brandJarLiquidPath）守卫 ----

  double jarRatio(Rect rect) {
    final b = brandJarPath(rect).getBounds();
    return b.width / b.height;
  }

  test('瓶体宽高比恒定（瓶腹主导，与生成器一致），不被容器拉伸', () {
    // 注：getBounds 只覆盖线段本体。瓶体最宽处是瓶腹 0.68H（口沿 0.66H
    // 略窄于腹），最高 0.66H；实测比例 = 0.68/0.66 ≈ 1.031。
    const rects = [
      Rect.fromLTWH(0, 0, 60, 60),
      Rect.fromLTWH(0, 0, 100, 100),
      Rect.fromLTWH(0, 0, 120, 60),
      Rect.fromLTWH(0, 0, 60, 120),
      Rect.fromLTWH(13, 27, 48, 90),
    ];
    for (final rect in rects) {
      expect(jarRatio(rect), closeTo(0.68 / 0.66, 0.02),
          reason: 'rect=$rect 时瓶体被拉伸了——H 应由 min(w/.82,h/.66) 决定');
    }
  });

  test('瓶体形状居中且留在 rect 内', () {
    const rect = Rect.fromLTWH(0, 0, 60, 60);
    final b = brandJarPath(rect).getBounds();
    final H = 60 / 0.82; // = min(60/.82, 60/.66)，宽度主导
    expect(b.center.dx, closeTo(rect.center.dx, 0.5));
    // 瓶几何本身不关于 y=0 对称（口沿 -0.36 / 底 +0.30，中心 -0.03），
    // 故 bbox 中心比 rect 中心上移 0.03H（≈2.2px），仍属居中。
    expect(b.center.dy, closeTo(rect.center.dy - 0.03 * H, 0.5));
    expect(b.top, greaterThanOrEqualTo(rect.top - 0.5));
    expect(b.bottom, lessThanOrEqualTo(rect.bottom + 0.5));
    expect(b.left, greaterThanOrEqualTo(rect.left - 0.5));
    expect(b.right, lessThanOrEqualTo(rect.right + 0.5));
  });

  test('液体液位越高 bbox 越高（0 空 / 0.5 半 / 1 满，单调增）', () {
    const rect = Rect.fromLTWH(0, 0, 60, 60);
    final jar = brandJarPath(rect).getBounds();
    final empty = brandJarLiquidPath(rect, 0.0).getBounds();
    final half = brandJarLiquidPath(rect, 0.5).getBounds();
    final full = brandJarLiquidPath(rect, 1.0).getBounds();
    // level ∈ [0,1]：0 液面在瓶底附近（浅 / 空）、1 液面在瓶口附近（满）。
    // y 向下为正，ly 从 bot-0.07 插值到 top+0.05；液面越高填充区域越高，
    // 故 bbox 高度必须严格单调增。这条断言正是 v2.4 首版 level 语义倒置
    // （-1 空 / 1 满 与插值方向相反，done 态画成空瓶）的回归守卫。
    expect(half.height, greaterThan(empty.height));
    expect(full.height, greaterThan(half.height));
    // 液体不越出瓶体（液体只填充瓶身，瓶口段留空）
    expect(full.top, greaterThanOrEqualTo(jar.top - 0.5));
    expect(full.bottom, lessThanOrEqualTo(jar.bottom + 0.5));
    expect(full.left, greaterThanOrEqualTo(jar.left - 0.5));
    expect(full.right, lessThanOrEqualTo(jar.right + 0.5));
  });
}
