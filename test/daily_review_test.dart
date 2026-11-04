import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:suixiang_note/data/app_database.dart';

/// path_provider 桩：drift_flutter 初始化需要 documents/support/temporary 三路径
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

void main() {
  late Directory tmp;
  late AppDatabase db;
  var created = false;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('suixiang_review_test');
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
    // 触发 beforeOpen：建索引 + 种入三态（stageId 1/2/3 依赖它存在）
    await db.select(db.stages).get();
  }

  /// 直接写库造数据：saveDraft 会自动把 updatedAt 设成「现在」，
  /// 而回顾的挑选逻辑正是按 updatedAt 排序，必须能控制它
  Future<int> seed(String content, {int? createdAt, int? updatedAt}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.into(db.thoughts).insert(ThoughtsCompanion.insert(
          uuid: 'uuid-${content.hashCode}-$now-${content.length}',
          content: Value(content),
          title: Value(content),
          stageId: 1,
          createdAt: createdAt ?? now,
          updatedAt: updatedAt ?? createdAt ?? now,
        ));
  }

  group('pickDailyReview', () {
    test('同一天多次调用返回同一批（不是每次刷新都抽奖）', () async {
      await freshDb();
      for (var i = 0; i < 12; i++) {
        await seed('老想法 $i',
            createdAt: DateTime.now()
                .subtract(Duration(days: 10 + i))
                .millisecondsSinceEpoch);
      }

      final a = await db.pickDailyReview(count: 3);
      final b = await db.pickDailyReview(count: 3);
      expect(a.map((t) => t.id).toList(), b.map((t) => t.id).toList());
      expect(a.length, 3);
    });

    test('rotation 自增会换一批，且换出来的确实不同', () async {
      await freshDb();
      for (var i = 0; i < 12; i++) {
        await seed('老想法 $i',
            createdAt: DateTime.now()
                .subtract(Duration(days: 10 + i))
                .millisecondsSinceEpoch);
      }

      final first = await db.pickDailyReview(count: 3, rotation: 0);
      final second = await db.pickDailyReview(count: 3, rotation: 1);
      expect(first.map((t) => t.id).toList(),
          isNot(second.map((t) => t.id).toList()));
    });

    test('今天新建的随记不参与回顾（它还在眼前）', () async {
      await freshDb();
      await seed('很久以前的', createdAt: DateTime.now()
          .subtract(const Duration(days: 40))
          .millisecondsSinceEpoch);
      await seed('刚刚记的');

      final picked = await db.pickDailyReview(count: 3);
      expect(picked.length, 1);
      expect(picked.first.content, '很久以前的');
    });

    test('已归档与回收站中的随记不参与回顾', () async {
      await freshDb();
      final old = DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;
      final keep = await seed('该被回顾的', createdAt: old);
      final archived = await seed('已归档的', createdAt: old);
      final trashed = await seed('已删除的', createdAt: old);
      await db.setArchived(archived, true);
      await db.softDelete(trashed);

      final picked = await db.pickDailyReview(count: 5);
      expect(picked.map((t) => t.id).toList(), [keep]);
    });

    test('池子不足一屏时按原顺序全给，不打乱', () async {
      await freshDb();
      final base = DateTime.now()
          .subtract(const Duration(days: 20))
          .millisecondsSinceEpoch;
      await seed('A', createdAt: base, updatedAt: base);
      await seed('B', createdAt: base + 1000, updatedAt: base + 1000);

      final picked = await db.pickDailyReview(count: 3);
      expect(picked.map((t) => t.content).toList(), ['A', 'B']);
    });

    test('空库返回空列表而不是抛异常', () async {
      await freshDb();
      expect(await db.pickDailyReview(), isEmpty);
    });
  });

  group('reviewedToday / markReviewedNow', () {
    test('首次是 false，标记当天后变 true', () async {
      await freshDb();
      expect(await db.reviewedToday(), isFalse);
      await db.markReviewedNow();
      expect(await db.reviewedToday(), isTrue);
    });

    test('昨天标记过，今天仍是 false（跨天重置）', () async {
      await freshDb();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await db.setSetting(
          'last_review_at', '${yesterday.millisecondsSinceEpoch}');
      expect(await db.reviewedToday(), isFalse);
      // 用「昨天那一刻」去问，应当是 true —— 证明判定用的是日期而不是简单布尔
      expect(await db.reviewedToday(now: yesterday), isTrue);
    });

    test('last_review_at 被写成脏值时不崩，按未回顾处理', () async {
      await freshDb();
      await db.setSetting('last_review_at', 'not-a-number');
      expect(await db.reviewedToday(), isFalse);
    });
  });

  group('reviewStats', () {
    test('统计排除归档与回收站，并算出最久那条的天数', () async {
      await freshDb();
      final old = DateTime.now()
          .subtract(const Duration(days: 100))
          .millisecondsSinceEpoch;
      await seed('最老的', createdAt: old);
      await seed('普通的一条');
      final done = await seed('做完了的');
      final archived = await seed('归档的');
      final trashed = await seed('删掉的');
      // 推进到已完成（advanceStage 每次只走一步：1→2→3）
      await db.advanceStage(done);
      await db.advanceStage(done);
      await db.setArchived(archived, true);
      await db.softDelete(trashed);

      final s = await db.reviewStats();
      expect(s.total, 3); // 最老的 + 普通 + 做完的
      expect(s.done, 1);
      expect(s.oldestDays, greaterThanOrEqualTo(99)); // 跨时区/夏令时不苛求正好 100
    });

    test('空库统计全 0，不除零不抛', () async {
      await freshDb();
      final s = await db.reviewStats();
      expect(s.total, 0);
      expect(s.done, 0);
      expect(s.oldestDays, 0);
    });
  });
}
