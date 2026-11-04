import 'dart:math' as math;
import 'dart:ui';

import '../data/app_database.dart';

/// 图谱里一个节点的位置与「重量」。
class GraphNode {
  final Thought thought;
  final Offset position;
  final int degree;

  /// 半径按连接数微调：连得多的略大，一眼能看出「枢纽」。
  /// 但上下限很死（10–18），否则少数节点会把整张图挤成一团。
  double get radius => (10.0 + degree * 1.4).clamp(10.0, 18.0);

  const GraphNode({
    required this.thought,
    required this.position,
    required this.degree,
  });
}

class GraphLayout {
  final List<GraphNode> nodes;
  final List<ThoughtLink> edges;
  final Map<int, Offset> positions;

  const GraphLayout({
    required this.nodes,
    required this.edges,
    required this.positions,
  });

  bool get isEmpty => nodes.isEmpty;
}

/// 力导向布局（Fruchterman–Reingold 变体），纯 Dart，无第三方依赖。
///
/// 三个取舍：
/// 1. **固定种子的初始位置**。若每次打开都随机撒点，同一批数据每次布局都
///    不一样，用户无法靠记忆定位——「上次那条在右下角」这条线索就废了。
///    用节点的 id 做种子，同一批数据每次得到同一张图。
/// 2. **迭代次数固定 300 次、不做收敛判断**。个人规模（<300 节点）下
///    300 次已足够稳定，判收敛反而要多写一堆阈值。
/// 3. **斥力截断**。原始 FR 算法的斥力是 k²/d，两点极近时趋于无穷，
///    实测会出现节点被弹到画布外。这里给 d 设下限，并把每步位移限幅。
class ForceLayout {
  static GraphLayout compute(
    GraphSnapshot snapshot, {
    Size size = const Size(1000, 1000),
    int iterations = 300,
  }) {
    final thoughts = snapshot.nodes;
    if (thoughts.isEmpty) {
      return const GraphLayout(nodes: [], edges: [], positions: {});
    }

    // 度数统计（一个节点连了几条边）
    final degree = <int, int>{};
    for (final e in snapshot.edges) {
      degree[e.fromId] = (degree[e.fromId] ?? 0) + 1;
      degree[e.toId] = (degree[e.toId] ?? 0) + 1;
    }

    final n = thoughts.length;
    final area = size.width * size.height;
    final k = math.sqrt(area / n) * 0.75; // 理想边长

    // 只有一个节点时直接钉在中心：没有别的节点产生斥力，它不该被随机
    // 撒到别处——那样用户看到的是一个飘在角落的孤点，像渲染出了问题。
    if (n == 1) {
      final only = thoughts.first;
      return GraphLayout(
        nodes: [
          GraphNode(
            thought: only,
            position: Offset(size.width / 2, size.height / 2),
            degree: degree[only.id] ?? 0,
          ),
        ],
        edges: const [],
        positions: {only.id: Offset(size.width / 2, size.height / 2)},
      );
    }

    // 初始位置：以 id 为种子撒在圆盘内（半径按索引排开，避免初始重合）
    final rnd = math.Random(thoughts.first.id * 7919 + n);
    final pos = <int, Offset>{};
    final center = Offset(size.width / 2, size.height / 2);
    // 只有在「存在有连接的节点」时，孤点才甩到外圈当背景；
    // 一条边都没有时全放中心区域——否则一张全是散点的图会从边缘开始，
    // 看起来像布局失败。
    final hasCore = degree.isNotEmpty;
    for (var i = 0; i < n; i++) {
      final t = thoughts[i];
      final isCore = degree[t.id] != null;
      if (isCore || !hasCore) {
        final angle = rnd.nextDouble() * math.pi * 2;
        final r = math.sqrt(rnd.nextDouble()) * k * math.sqrt(n) * 0.45;
        pos[t.id] = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      } else {
        final angle = rnd.nextDouble() * math.pi * 2;
        final r = size.width * (0.38 + rnd.nextDouble() * 0.10);
        pos[t.id] = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      }
    }

    final indexById = <int, int>{};
    for (var i = 0; i < n; i++) {
      indexById[thoughts[i].id] = i;
    }

    final disp = List<Offset>.filled(n, Offset.zero);
    final margin = 24.0;

    for (var iter = 0; iter < iterations; iter++) {
      // 温度：随迭代线性降温，末期几乎不动（防抖动的标准做法）
      final temp = (size.width / 12) * (1 - iter / iterations) + 0.8;
      for (var i = 0; i < n; i++) {
        disp[i] = Offset.zero;
      }

      // 斥力：所有节点两两互斥
      for (var i = 0; i < n; i++) {
        final pi = pos[thoughts[i].id]!;
        for (var j = i + 1; j < n; j++) {
          final pj = pos[thoughts[j].id]!;
          var delta = pi - pj;
          var d = delta.distance;
          if (d < 0.01) {
            // 完全重合时给一个确定性的小偏移，否则除零后节点飞走
            delta = Offset((i - j).toDouble() * 0.1 + 0.1, 0.1);
            d = delta.distance;
          }
          final force = (k * k) / math.max(d, 1.0);
          final f = delta / d * force;
          disp[i] = disp[i] + f;
          disp[j] = disp[j] - f;
        }
      }

      // 引力：只拉有边的节点对
      for (final e in snapshot.edges) {
        final i = indexById[e.fromId];
        final j = indexById[e.toId];
        if (i == null || j == null) continue;
        final delta = pos[thoughts[i].id]! - pos[thoughts[j].id]!;
        final d = math.max(delta.distance, 0.01);
        final force = (d * d) / k;
        final f = delta / d * force;
        disp[i] = disp[i] - f;
        disp[j] = disp[j] + f;
      }

      // 位移限幅 + 边界收拢
      for (var i = 0; i < n; i++) {
        final d = disp[i];
        final len = d.distance;
        if (len < 0.0001) continue;
        final step = d / len * math.min(len, temp);
        var next = pos[thoughts[i].id]! + step;
        next = Offset(
          next.dx.clamp(margin, size.width - margin),
          next.dy.clamp(margin, size.height - margin),
        );
        pos[thoughts[i].id] = next;
      }
    }

    final nodes = <GraphNode>[
      for (final t in thoughts)
        GraphNode(
          thought: t,
          position: pos[t.id]!,
          degree: degree[t.id] ?? 0,
        ),
    ];

    return GraphLayout(
      nodes: nodes,
      edges: snapshot.edges,
      positions: pos,
    );
  }
}
