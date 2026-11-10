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
}
