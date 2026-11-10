import 'package:flutter/material.dart';

import '../../data/app_database.dart';

/// 水滴三态徽章（公共组件）：灵感=空心轮廓 / 推进中=半实心 / 完成=实心。
/// 从 home_page.dart 抽出，供首页 / 详情页等复用。
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
    Widget drop;
    switch (kind) {
      case 'in_progress':
        drop = CustomPaint(
            painter: _HalfDrop(color: color, size: size),
            size: Size(size, size));
        break;
      case 'done':
        drop = Icon(Icons.water_drop, size: size * 0.875, color: color);
        break;
      default:
        drop = CustomPaint(
            painter: _OutlineDrop(color, size), size: Size(size, size));
    }
    return SizedBox(
        width: size, height: size, child: Center(child: drop));
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

class _OutlineDrop extends CustomPainter {
  final Color color;
  final double size;
  const _OutlineDrop(this.color, this.size);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
        _dropPath(size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _dropStroke(this.size)
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _OutlineDrop old) =>
      old.color != color || old.size != size;
}

class _HalfDrop extends CustomPainter {
  final Color color;
  final double size;
  _HalfDrop({required this.color, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _dropPath(size);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _dropStroke(this.size)
          ..color = color);
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2));
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HalfDrop old) =>
      old.color != color || old.size != size;
}

Path _dropPath(Size size) {
  final w = size.width, h = size.height;
  return Path()
    ..moveTo(w / 2, 2)
    ..cubicTo(w / 2, 2, w - 4, h * 0.42, w - 4, h * 0.62)
    ..arcToPoint(Offset(4, h * 0.62),
        radius: Radius.circular((w - 8) / 2), clockwise: false)
    ..cubicTo(4, h * 0.42, w / 2, 2, w / 2, 2)
    ..close();
}

/// 品牌水滴的「图标形态」别名（图标规范①）：
/// 导航栏等处不能直接用 CustomPaint（NavigationDestination.icon 收 IconData），
/// 统一映射到 Material 的 water_drop 轮廓/实心对，保证与 DropBadge 同一语言。
/// （DropBadge 的自绘轮廓比 material 的 water_drop_outlined 更圆润，
/// 二者在导航这类小尺寸下差异不可感知，故用 Material 对作为图标形态。）
abstract final class DropBadgeIcons {
  static const IconData dropOutline = Icons.water_drop_outlined;
  static const IconData dropFilled = Icons.water_drop;
}
