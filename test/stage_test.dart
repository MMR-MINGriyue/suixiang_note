import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:suixiang_note/core/format.dart';
import 'package:suixiang_note/data/app_database.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  var created = false;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('suixiang_stage_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDownAll(() async {
    if (created) await db.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<void> freshDb() async {
    if (created) await db.close();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    created = true;
    await db.select(db.stages).get(); // 触发 beforeOpen 种子
  }

  Future<int> seed(String content, {int stageId = 1}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.into(db.thoughts).insert(ThoughtsCompanion.insert(
          uuid: 'uuid-${content.hashCode}-$now',
          title: Value(content),
          content: Value(content),
          stageId: stageId,
          createdAt: now,
          updatedAt: now,
        ));
  }

  Future<Thought> get(int id) =>
      (db.select(db.thoughts)..where((t) => t.id.equals(id))).getSingle();

  group('纯函数', () {
    test('nextStageOf 走 position 顺序并循环回到第一态', () async {
      await freshDb();
      final stages = await db.watchStages().first;
      expect(nextStageOf(stages, 1)?.id, 2);
      expect(nextStageOf(stages, 2)?.id, 3);
      expect(nextStageOf(stages, 3)?.id, 1, reason: '循环对称');
    });

    test('prevStageOf 与 nextStageOf 互为反函数', () async {
      await freshDb();
      final stages = await db.watchStages().first;
      for (final s in stages) {
        final next = nextStageOf(stages, s.id)!;
        expect(prevStageOf(stages, next.id)?.id, s.id);
      }
    });

    test('stageById 找不到时回退第一态（不返回 null 崩界面）', () async {
      await freshDb();
      final stages = await db.watchStages().first;
      expect(stageById(stages, 999)?.id, stages.first.id);
    });

    test('空 stages 一律返回 null', () {
      expect(nextStageOf(const [], 1), isNull);
      expect(prevStageOf(const [], 1), isNull);
      expect(stageById(const [], 1), isNull);
    });

    test('completedLabel 覆盖今天/昨天/N 天前/跨月', () {
      final now = DateTime(2026, 11, 4, 12);
      int ts(DateTime d) => d.millisecondsSinceEpoch;
      expect(completedLabel(null), '');
      expect(completedLabel(ts(DateTime(2026, 11, 4, 9)), now: now), '今天完成');
      expect(completedLabel(ts(DateTime(2026, 11, 3, 23)), now: now), '昨天完成');
      expect(completedLabel(ts(DateTime(2026, 10, 28)), now: now), '7 天前完成');
      expect(completedLabel(ts(DateTime(2026, 3, 4)), now: now), '2026/03/04 完成');
    });

    test('stagnationLabel 只对推进中且满 3 天生效', () {
      final now = DateTime(2026, 11, 4, 12);
      int ts(DateTime d) => d.millisecondsSinceEpoch;
      final five = ts(DateTime(2026, 10, 30));
      final one = ts(DateTime(2026, 11, 3));
      // 灵感躺着是正常的、完成躺着是应该的 —— 都不报
      expect(stagnationLabel(five, 'inspiration', now: now), '');
      expect(stagnationLabel(five, 'done', now: now), '');
      // 3 天以内不报，满 3 天才报
      expect(stagnationLabel(one, 'in_progress', now: now), '');
      expect(stagnationLabel(five, 'in_progress', now: now), '停在这里 5 天');
      // 没有记录时间就不瞎猜
      expect(stagnationLabel(null, 'in_progress', now: now), '');
    });

    test('stagnationLabel 边界：刚好第 3 天要报', () {
      final now = DateTime(2026, 11, 4, 0, 1);
      final threeDaysAgo = DateTime(2026, 11, 1, 23, 59).millisecondsSinceEpoch;
      expect(stagnationLabel(threeDaysAgo, 'in_progress', now: now),
          '停在这里 3 天');
    });
  });

  group('推进与落态', () {
    test('advanceStage 返回落定的阶段，并按循环走', () async {
      await freshDb();
      final id = await seed('钢结构监造方案');
      expect((await db.advanceStage(id))?.id, 2);
      expect((await get(id)).stageId, 2);
      expect((await db.advanceStage(id))?.id, 3);
      expect((await db.advanceStage(id))?.id, 1, reason: '从已完成回到灵感');
    });

    test('进入完成态写 completedAt，离开时清空', () async {
      await freshDb();
      final id = await seed('写年度总结');
      await db.advanceStage(id); // → 2
      await db.advanceStage(id); // → 3
      expect((await get(id)).completedAt, isNotNull);
      await db.advanceStage(id); // → 1
      expect((await get(id)).completedAt, isNull,
          reason: '回到灵感后还挂着完成时间会误导');
    });

    test('previousStage 一步退回（不必绕两圈）', () async {
      await freshDb();
      final id = await seed('学 Flutter');
      await db.advanceStage(id); // 2
      await db.advanceStage(id); // 3
      expect((await db.previousStage(id))?.id, 2);
      expect((await get(id)).completedAt, isNull);
    });

    test('setStage 可一步跳到任意态', () async {
      await freshDb();
      final id = await seed('买相机');
      expect((await db.setStage(id, 3))?.id, 3);
      expect((await get(id)).completedAt, isNotNull);
      expect((await db.setStage(id, 1))?.id, 1);
      expect((await get(id)).completedAt, isNull);
    });

    test('setStage 同态不写库、不刷新 updatedAt', () async {
      await freshDb();
      final id = await seed('保持原样');
      final before = await get(id);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.setStage(id, 1);
      final after = await get(id);
      expect(after.updatedAt, before.updatedAt,
          reason: '点当前态不该把「最近修改」顶上去');
    });

    test('setStage 传入不存在的阶段 id 不写库', () async {
      await freshDb();
      final id = await seed('别乱写');
      expect(await db.setStage(id, 999), isNull);
      expect((await get(id)).stageId, 1);
    });

    test('advanceStage 对不存在的随记返回 null 且不抛', () async {
      await freshDb();
      expect(await db.advanceStage(999999), isNull);
    });

    test('batchSetStage 一次改一批', () async {
      await freshDb();
      final a = await seed('A');
      final b = await seed('B');
      final c = await seed('C');
      expect(await db.batchSetStage([a, b, c], 3), 3);
      for (final id in [a, b, c]) {
        final t = await get(id);
        expect(t.stageId, 3);
        expect(t.completedAt, isNotNull);
      }
    });

    test('batchSetStage 空列表与非法态都不写库', () async {
      await freshDb();
      final id = await seed('X');
      expect(await db.batchSetStage(const [], 3), 0);
      expect(await db.batchSetStage([id], 999), 0);
      expect((await get(id)).stageId, 1);
    });

    test('stageChangedAt 每次落态都刷新，用于算「停了几天」', () async {
      await freshDb();
      // 用 saveDraft 走真实新建路径（seed 是直插，不写 stageChangedAt）
      final id = await db.saveDraft(content: '卡住的事');
      final t0 = (await get(id)).stageChangedAt;
      expect(t0, isNotNull, reason: '新建即有进入灵感的时刻');

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.setStage(id, 2);
      final t1 = (await get(id)).stageChangedAt!;
      expect(t1, greaterThan(t0!), reason: '换态必须刷新');

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.setStage(id, 2); // 同态
      expect((await get(id)).stageChangedAt, t1,
          reason: '点当前态不该重置「停了几天」的计时');
    });

    test('编辑正文不刷新 stageChangedAt（否则停住的计时会被写字洗掉）',
        () async {
      await freshDb();
      final id = await seed('写了一半的方案');
      await db.setStage(id, 2);
      final before = (await get(id)).stageChangedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.saveDraft(id: id, content: '写了一半的方案，又补了两行');
      expect((await get(id)).stageChangedAt, before);
    });

    test('批量落态也刷新 stageChangedAt', () async {
      await freshDb();
      final a = await seed('A');
      await db.batchSetStage([a], 2);
      expect((await get(a)).stageChangedAt, isNotNull);
      expect((await get(a)).stageId, 2);
    });

    test('并发落态互不覆盖（advanceStage/setStage 在事务里，架构评审 D3）',
        () async {
      await freshDb();
      final id = await seed('并发目标');
      // 同一条随记同时发起「推进」与「直达已完成」：串行化保证最终态必然是
      // 其中一个合法落点，且 completedAt 与 stageId 一致（不会出现
      // 「stageId=2 但 completedAt 有值」的错位行）。
      final results = await Future.wait(
          [db.advanceStage(id), db.setStage(id, 3)]);
      final t = await get(id);
      expect(t.stageId, isIn([2, 3]));
      if (t.stageId == 3) {
        expect(t.completedAt, isNotNull);
      } else {
        expect(t.completedAt, isNull);
      }
      expect(results.whereType<Stage>().isNotEmpty, isTrue);
    });

    test('togglePin 连点两次回到原状（事务内的读-改-写，架构评审 D3）',
        () async {
      await freshDb();
      final id = await seed('置顶对象');
      // 串行连点两次：如果读-改-写不在同一事务，两次都可能读到同一份旧值
      await db.togglePin(id);
      await db.togglePin(id);
      final t = await get(id);
      expect(t.isPinned, isFalse, reason: '两次 toggle 必须净效果为零');
      expect(t.pinnedAt, isNull);
    });
  });
}
