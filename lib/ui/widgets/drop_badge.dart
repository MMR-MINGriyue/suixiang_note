import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import 'drop_shape.dart';

/// 星雨落瓶三态徽章（公共组件）：灵感=空瓶+闪星 / 推进中=半满瓶 / 完成=满瓶。
/// 从 home_page.dart 抽出，供首页 / 详情页等复用。
/// v2.4 起品牌符号从水滴改为「星雨 · 落瓶」（drop_shape.dart brandJarPath）。
class DropBadge extends StatelessWidget {
  final String kind;
  final Color color;
  final double size;

  const DropBadge({
    super.key,
    required this.kind,
    required this.color,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    Widget jar;
    switch (kind) {
      case 'in_progress':
        jar = CustomPaint(
            painter: _HalfJar(color: color, size: size),
            size: Size(size, size));
        break;
      case 'done':
        jar = CustomPaint(
            painter: _FullJar(color: color, size: size),
            size: Size(size, size));
        break;
      default:
        jar = CustomPaint(
            painter: _OutlineJar(color, size), size: Size(size, size));
    }
    return SizedBox(
        width: size, height: size, child: Center(child: jar));
  }
}

/// 从随记行内解析当前 Stage 对象；流数据未就绪时回退灵感态。
/// 抽到这里避免首页/详情页各自维护 fallback 逻辑（架构评审 B2）。
Stage stageOf(List<Stage> stages, Thought thought) {
  try {
    return stages.firstWhere((s) => s.id == thought.stageId);
  } on StateError {
    return Stage(
        id: 1,
        name: '灵感',
        kind: 'inspiration',
        color: '#A8B9E6',
        position: 1.0,
        isSystem: true,
        createdAt: 0);
  }
}

/// 描边随徽章尺寸缩放（比例规范）：14px≈1.8 / 24px≈2.2 / 48px≈2.4，
/// 避免小尺寸描边显粗、大尺寸描边显细。
double _dropStroke(double size) => (size * 0.10).clamp(1.4, 2.4);

/// 瓶体描边（空瓶 / 半满瓶共用）。
void _paintJarOutline(Canvas canvas, Size size, Color color) {
  canvas.drawPath(
      brandJarPath(Offset.zero & size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _dropStroke(size.width)
        ..color = color);
}

/// 空瓶 + 正坠闪星（灵感态）：一颗小四芒星悬在瓶口右上，
/// 「正在闪 = 灵感来了，还没落进瓶子」。
class _OutlineJar extends CustomPainter {
  final Color color;
  final double size;
  const _OutlineJar(this.color, this.size);

  @override
  void paint(Canvas canvas, Size size) {
    _paintJarOutline(canvas, size, color);
    _paintFallingStar(canvas, size, color);
  }

  @override
  bool shouldRepaint(covariant _OutlineJar old) =>
      old.color != color || old.size != size;
}

/// 半满瓶（推进中）：瓶体描边 + 液面以下填充（level 0.5）。
class _HalfJar extends CustomPainter {
  final Color color;
  final double size;
  _HalfJar({required this.color, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
        brandJarLiquidPath(Offset.zero & size, 0.5), Paint()..color = color);
    _paintJarOutline(canvas, size, color);
  }

  @override
  bool shouldRepaint(covariant _HalfJar old) =>
      old.color != color || old.size != size;
}

/// 满瓶（完成）：瓶体描边 + 液体填满（level 1）。
class _FullJar extends CustomPainter {
  final Color color;
  final double size;
  _FullJar({required this.color, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
        brandJarLiquidPath(Offset.zero & size, 1.0), Paint()..color = color);
    _paintJarOutline(canvas, size, color);
  }

  @override
  bool shouldRepaint(covariant _FullJar old) =>
      old.color != color || old.size != size;
}

/// 正坠闪星：瓶口右上的一颗四芒星（8 点多边形，与生成器 star4 同源）。
/// 坠落意象靠位置表达（悬在瓶口上空），小尺寸下不画曳尾（会糊）。
void _paintFallingStar(Canvas canvas, Size size, Color color) {
  final w = size.width, h = size.height;
  final cx = w * 0.74, cy = h * 0.16;
  final R = w * 0.20, ratio = 0.30;
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final r = i.isEven ? R : R * ratio;
    final a = -math.pi / 2 + i * math.pi / 4;
    final x = cx + r * math.cos(a);
    final y = cy + r * math.sin(a);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

/// 品牌符号的「图标形态」别名（图标规范①）：
/// 导航栏等处不能直接用 CustomPaint（NavigationDestination.icon 收 IconData），
/// 统一映射到 Material 图标对。v2.4 水滴→星雨落瓶后：
/// 空瓶语义用 science_outlined、满瓶/选中态用 science
/// （实验瓶是 Material 里最接近开口玻璃瓶的轮廓），替代原 water_drop 对。
/// （DropBadge 的自绘瓶轮廓仍是权威形态；导航这类小尺寸下差异不可感知。）
abstract final class DropBadgeIcons {
  static const IconData dropOutline = Icons.science_outlined;
  static const IconData dropFilled = Icons.science;
}
