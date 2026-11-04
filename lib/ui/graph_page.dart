import 'package:flutter/material.dart';

import '../core/force_layout.dart';
import '../data/app_database.dart';
import '../theme/tokens.dart';
import 'detail_page.dart';

/// 关系图谱页：把随记画成点，把关联画成线。
///
/// 为什么值得单独做一页：列表只回答「有什么」，图谱回答「它们怎么连着」。
/// 后者是这类笔记应用唯一无法被纯文本替代的视角——你能一眼看出哪件事是
/// 枢纽、哪一堆是孤岛。
class GraphPage extends StatefulWidget {
  final AppDatabase db;
  const GraphPage({super.key, required this.db});

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  late Future<GraphSnapshot> _future;
  GraphLayout? _layout;
  int? _selected;

  /// 缩放与平移：图谱节点密度高，固定比例在手机上必然挤成一团
  final _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    _future = widget.db.loadGraph();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.db.loadGraph();
      _layout = null;
      _selected = null;
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('关系图谱'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新布局',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<GraphSnapshot>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data;
          if (data == null || data.isEmpty) {
            return _empty(context, dark);
          }
          // 布局只算一次：FutureBuilder 每次重建都重算 300 次迭代会卡
          final layout = _layout ??= ForceLayout.compute(
            data,
            size: const Size(1600, 1600),
          );
          return Column(
            children: [
              _header(data, dark),
              Expanded(
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: 0.3,
                  maxScale: 3.0,
                  boundaryMargin: const EdgeInsets.all(200),
                  child: SizedBox(
                    width: 1600,
                    height: 1600,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = null),
                      child: Stack(children: [
                        CustomPaint(
                          size: const Size(1600, 1600),
                          painter: _GraphPainter(
                            layout: layout,
                            dark: dark,
                            selected: _selected,
                          ),
                        ),
                        // 节点标签单独用 Widget 画：CustomPainter 里画文字
                        // 要自己算 TextPainter，而且无法做无障碍语义
                        for (final node in layout.nodes)
                          _NodeHitTarget(
                            node: node,
                            selected: _selected == node.thought.id,
                            showLabel: layout.nodes.length <= 40,
                            onTap: () => setState(() => _selected =
                                _selected == node.thought.id
                                    ? null
                                    : node.thought.id),
                            onDoubleTap: () => _open(node.thought),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
              if (_selected != null) _selectionBar(context, layout, dark),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, bool dark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub_outlined,
                size: 44, color: T.inkTertiary.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            const Text('还没有可以连起来的东西',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '在随记详情页点「关联」，把它和另一条随记连起来，\n这里就会长出第一张网。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: dark ? T.darkInkSecondary : T.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(GraphSnapshot data, bool dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: dark ? T.darkCardAlt : T.paperCardAlt,
        border: Border(
          bottom: BorderSide(color: T.inkTertiary.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(children: [
        _stat('${data.nodes.length}', '条随记', T.brandPrimary),
        const SizedBox(width: 18),
        _stat('${data.edgeCount}', '条关联', T.stageDone),
        const SizedBox(width: 18),
        _stat('${data.isolatedCount}', '条未连', T.inkSecondary),
        const Spacer(),
        Text('双指缩放 · 双击进入',
            style: TextStyle(fontSize: 10.5, color: T.inkTertiary)),
      ]),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic, children: [
      Text(value,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: T.inkTertiary)),
    ]);
  }

  Widget _selectionBar(BuildContext context, GraphLayout layout, bool dark) {
    final node = layout.nodes.firstWhere((n) => n.thought.id == _selected,
        orElse: () => layout.nodes.first);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          color: dark ? T.darkCard : T.paperCard,
          border: Border(
            top: BorderSide(color: T.inkTertiary.withValues(alpha: 0.18)),
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                node.thought.title.trim().isEmpty ? '（无标题）' : node.thought.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text('连着 ${node.degree} 条',
                  style: const TextStyle(fontSize: 11, color: T.inkTertiary)),
            ]),
          ),
          TextButton(
            onPressed: () => _open(node.thought),
            child: const Text('打开'),
          ),
        ]),
      ),
    );
  }

  Future<void> _open(Thought t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailPage(db: widget.db, thought: t)),
    );
    if (mounted) _reload();
  }
}

/// 可点区域：比节点圆本身大一圈，手指才点得中
class _NodeHitTarget extends StatelessWidget {
  final GraphNode node;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  const _NodeHitTarget({
    required this.node,
    required this.selected,
    required this.showLabel,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    const box = 44.0;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned(
          left: node.position.dx - box / 2,
          top: node.position.dy - box / 2,
          child: GestureDetector(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            child: SizedBox(width: box, height: box),
          ),
        ),
        // 标签只在节点不多时显示：几十条以上时每个点都挂一段文字，
        // 画面会糊成一片噪点，还不如只留位置关系让人自己缩放去看。
        if (showLabel)
          Positioned(
            left: node.position.dx - 60,
            top: node.position.dy + node.radius + 3,
            width: 120,
            child: IgnorePointer(
              child: Text(
                node.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: selected ? 11.5 : 10.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? T.brandPrimary
                      : (dark ? T.darkInkSecondary : T.inkSecondary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GraphPainter extends CustomPainter {
  final GraphLayout layout;
  final bool dark;
  final int? selected;

  _GraphPainter({required this.layout, required this.dark, this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final n in layout.nodes) n.thought.id: n};
    final edgePaint = Paint()
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final selectedEdge = Paint()
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    // 先画边：让节点盖在线上，视觉上更像「点连着点」
    for (final e in layout.edges) {
      final a = byId[e.fromId];
      final b = byId[e.toId];
      if (a == null || b == null) continue;
      final touches = selected != null &&
          (e.fromId == selected || e.toId == selected);
      final color = switch (e.kind) {
        'depends' => T.stageDone,
        'parent' => T.warning,
        _ => T.brandPrimary,
      };
      edgePaint.color = color.withValues(alpha: touches ? 0.75 : 0.28);
      selectedEdge.color = color.withValues(alpha: 0.9);
      final paint = touches ? selectedEdge : edgePaint;
      canvas.drawLine(a.position, b.position, paint);

      // 箭头：只在选中时画，否则满屏箭头会糊成一片
      if (touches) {
        _arrow(canvas, a.position, b.position, color);
      }
    }

    // 再画节点
    for (final n in layout.nodes) {
      final stage = n.thought.stageId;
      final base = switch (stage) {
        2 => T.stageInProgress,
        3 => T.stageDone,
        _ => T.stageInspiration,
      };
      final isSel = selected == n.thought.id;
      canvas.drawCircle(
        n.position,
        n.radius + (isSel ? 3 : 0),
        Paint()..color = base.withValues(alpha: isSel ? 0.30 : 0.16),
      );
      canvas.drawCircle(
        n.position,
        n.radius,
        Paint()..color = base.withValues(alpha: isSel ? 1 : 0.85),
      );
      if (isSel) {
        canvas.drawCircle(
          n.position,
          n.radius + 3,
          Paint()
            ..color = base
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color) {
    final dir = to - from;
    final len = dir.distance;
    if (len < 1) return;
    final unit = dir / len;
    // 箭头停在圆外沿附近，不要戳进节点里
    final tip = to - unit * 16;
    final normal = Offset(-unit.dy, unit.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - unit.dx * 8 + normal.dx * 4,
          tip.dy - unit.dy * 8 + normal.dy * 4)
      ..lineTo(tip.dx - unit.dx * 8 - normal.dx * 4,
          tip.dy - unit.dy * 8 - normal.dy * 4)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.selected != selected || old.layout != layout || old.dark != dark;
}
