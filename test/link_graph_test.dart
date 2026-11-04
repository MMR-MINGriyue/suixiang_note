import 'dart:io';
import 'dart:ui';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:suixiang_note/core/force_layout.dart';
import 'package:suixiang_note/data/app_database.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String root;
  _FakePathProvider(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

/// 关联（thought_links）+ 图谱布局测试。
///
/// 关联是这个应用里唯一的「图」结构，数据层一旦允许出现自环、重复边或
/// 指向已删随记的边，图谱就会画出莫名其妙的线；这些都在这里锁住。
void main() {
  late Directory tmp;
  late AppDatabase db;
  var created = false;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('suixiang_link_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDownAll(() async {
    if (created) await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> freshDb() async {
    if (created) await db.close();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    created = true;
    await db.select(db.stages).get(); // 触发 beforeOpen 建索引与三态种子
  }

  Future<int> seed(String content) =>
      db.saveDraft(content: content);

  setUp(freshDb);

  group('关联读写', () {
    test('建立关联后双向都能查到', () async {
      final a = await seed('想法 A');
      final b = await seed('想法 B');
      expect(await db.linkThoughts(a, b), isTrue);

      final fromA = await db.watchLinksOf(a).first;
      final fromB = await db.watchLinksOf(b).first;
      expect(fromA.length, 1);
      expect(fromB.length, 1);
      expect(fromA.first.other.id, b);
      expect(fromB.first.other.id, a);
    });

    test('方向被正确记录：outgoing 为 true 的是「我指向对方」', () async {
      final a = await seed('起因');
      final b = await seed('结果');
      await db.linkThoughts(a, b, kind: 'depends');

      final fromA = await db.watchLinksOf(a).first;
      final fromB = await db.watchLinksOf(b).first;
      expect(fromA.first.outgoing, isTrue);
      expect(fromB.first.outgoing, isFalse);
    });

    test('关系类型的显示文案随方向变化', () async {
      final a = await seed('A');
      final b = await seed('B');
      await db.linkThoughts(a, b, kind: 'depends');
      expect((await db.watchLinksOf(a).first).first.kindLabel, '依赖');
      expect((await db.watchLinksOf(b).first).first.kindLabel, '被依赖');
    });

    test('不能关联自己', () async {
      final a = await seed('自己');
      expect(await db.linkThoughts(a, a), isFalse);
      expect(await db.watchLinksOf(a).first, isEmpty);
    });

    test('对端在回收站里时不显示（避免点进去是空白）', () async {
      final a = await seed('A');
      final b = await seed('B');
      await db.linkThoughts(a, b);
      await db.softDelete(b);
      expect(await db.watchLinksOf(a).first, isEmpty);
    });

    test('重复建立同一条关联不会产生两条（UNIQUE 兜底）', () async {
      final a = await seed('A');
      final b = await seed('B');
      await db.linkThoughts(a, b);
      await db.linkThoughts(a, b); // 第二次应被 insertOrIgnore 吞掉
      final list = await db.watchLinksOf(a).first;
      expect(list.length, 1);
    });

    test('同类但反向算两条不同的关联', () async {
      final a = await seed('A');
      final b = await seed('B');
      await db.linkThoughts(a, b);
      await db.linkThoughts(b, a);
      expect((await db.watchLinksOf(a).first).length, 2);
    });

    test('取消关联是软删，列表里立刻消失但数据还在', () async {
      final a = await seed('A');
      final b = await seed('B');
      await db.linkThoughts(a, b);
      final link = (await db.watchLinksOf(a).first).first;
      await db.unlinkThought(link.link.id);
      expect(await db.watchLinksOf(a).first, isEmpty);

      // 软删：行还在，只是 deletedAt 非空
      final rows = await db.select(db.thoughtLinks).get();
      expect(rows.length, 1);
      expect(rows.first.deletedAt, isNotNull);
    });
  });

  group('图谱快照', () {
    test('空库返回空快照', () async {
      final g = await db.loadGraph();
      expect(g.isEmpty, isTrue);
      expect(g.edgeCount, 0);
    });

    test('节点含全部未删未归档随记', () async {
      await seed('A');
      await seed('B');
      final c = await seed('C');
      await db.softDelete(c);
      final g = await db.loadGraph();
      expect(g.nodes.length, 2);
    });

    test('归档的随记不进图谱（归档=不关心了）', () async {
      final a = await seed('A');
      await seed('B');
      await db.setArchived(a, true);
      final g = await db.loadGraph();
      expect(g.nodes.length, 1);
      expect(g.nodes.first.title, 'B');
    });

    test('两端都在图里时边被保留', () async {
      final a = await seed('A');
      final b = await seed('B');
      await db.linkThoughts(a, b);
      final g = await db.loadGraph();
      expect(g.edgeCount, 1);
    });

    test('一端已删的边被丢掉（否则画出指向空处的线）', () async {
      final a = await seed('A');
      final b = await seed('B');
      await db.linkThoughts(a, b);
      await db.softDelete(b);
      final g = await db.loadGraph();
      expect(g.edgeCount, 0);
    });

    test('isolatedCount 如实统计孤点', () async {
      final a = await seed('A');
      final b = await seed('B');
      await seed('C');
      await seed('D');
      await db.linkThoughts(a, b);
      final g = await db.loadGraph();
      expect(g.nodes.length, 4);
      expect(g.isolatedCount, 2);
    });

    test('maxNodes 限制节点数（防止一次布局几千个点卡死）', () async {
      for (var i = 0; i < 8; i++) {
        await seed('第 $i 条');
      }
      final g = await db.loadGraph(maxNodes: 5);
      expect(g.nodes.length, 5);
    });
  });

  group('力导向布局', () {
    test('空快照返回空布局，不崩', () {
      final layout = ForceLayout.compute(
        GraphSnapshot(nodes: const [], edges: const []),
      );
      expect(layout.isEmpty, isTrue);
    });

    test('单节点放在画布中央附近（斥力没有对象可推）', () async {
      await seed('只有一条');
      final g = await db.loadGraph();
      final layout = ForceLayout.compute(g, size: const Size(600, 600));
      expect(layout.nodes.length, 1);
      final p = layout.nodes.first.position;
      // 单节点初始就在中心，且没有外力，应保持在中心附近
      expect(p.dx, closeTo(300, 60));
      expect(p.dy, closeTo(300, 60));
    });

    test('同一批数据重复计算结果一致（种子固定，避免每次打开图都变样）', () async {
      final a = await seed('A');
      final b = await seed('B');
      final c = await seed('C');
      await db.linkThoughts(a, b);
      await db.linkThoughts(b, c);
      final g = await db.loadGraph();

      final l1 = ForceLayout.compute(g, size: const Size(800, 800));
      final l2 = ForceLayout.compute(g, size: const Size(800, 800));
      for (var i = 0; i < l1.nodes.length; i++) {
        expect(l1.nodes[i].position.dx, closeTo(l2.nodes[i].position.dx, 0.001));
        expect(l1.nodes[i].position.dy, closeTo(l2.nodes[i].position.dy, 0.001));
      }
    });

    test('节点不会跑出画布（位移限幅 + 边界收拢）', () async {
      for (var i = 0; i < 10; i++) {
        await seed('节点 $i 号');
      }
      final g = await db.loadGraph();
      const size = Size(400, 400);
      final layout = ForceLayout.compute(g, size: size);
      for (final n in layout.nodes) {
        expect(n.position.dx, greaterThanOrEqualTo(0));
        expect(n.position.dx, lessThanOrEqualTo(size.width));
        expect(n.position.dy, greaterThanOrEqualTo(0));
        expect(n.position.dy, lessThanOrEqualTo(size.height));
      }
    });

    test('有连接的节点度数被统计，孤立节点为 0', () async {
      final a = await seed('A');
      final b = await seed('B');
      final c = await seed('C');
      await db.linkThoughts(a, b);
      await db.linkThoughts(a, c);
      final g = await db.loadGraph();
      final layout = ForceLayout.compute(g, size: const Size(600, 600));
      final byId = {for (final n in layout.nodes) n.thought.id: n};
      expect(byId[a]!.degree, 2);
      expect(byId[b]!.degree, 1);
    });

    test('度数高的节点半径更大，但有上限（避免少数点挤爆画面）', () {
      Thought t(int id) => Thought(
            id: id,
            uuid: 'u$id',
            title: 't$id',
            content: '',
            folderId: null,
            stageId: 1,
            isPinned: false,
            pinnedAt: null,
            isArchived: false,
            source: 'app',
            wordCount: 0,
            createdAt: 0,
            updatedAt: 0,
            completedAt: null,
            stageChangedAt: null,
            deletedAt: null,
          );
      final nodes = [t(1), t(2)];
      final snapshot = GraphSnapshot(nodes: nodes, edges: [
        ThoughtLink(
            id: 1,
            fromId: 1,
            toId: 2,
            kind: 'related',
            createdAt: 0,
            deletedAt: null),
      ]);
      final layout = ForceLayout.compute(snapshot, size: const Size(600, 600));
      for (final n in layout.nodes) {
        expect(n.radius, greaterThanOrEqualTo(10.0));
        expect(n.radius, lessThanOrEqualTo(18.0));
      }
    });
  });
}
