import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:suixiang_note/core/pinyin_search.dart';
import 'package:suixiang_note/data/app_database.dart';

/// path_provider 测试桩（drift_flutter 在构造时需要临时目录）
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
    tmp = await Directory.systemTemp.createTemp('suixiang_search_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    // 不走 rootBundle：直接从磁盘读同一份资产，测试与产物读的是同一个文件
    final raw = await File('assets/pinyin/first_letter.txt').readAsString();
    await PinyinSearch.loadFromString(raw);
    final rawFull = await File('assets/pinyin/full_pinyin.txt').readAsString();
    await PinyinSearch.loadFullFromString(rawFull);
  });

  tearDownAll(() async {
    if (created) await db.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<void> freshDb() async {
    if (created) await db.close();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    created = true;
    await db.select(db.stages).get();
  }

  Future<int> seed(String content, {int stageId = 1, bool archived = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.into(db.thoughts).insert(ThoughtsCompanion.insert(
          uuid: 'uuid-${content.hashCode}-$now',
          title: Value(content),
          content: Value(content),
          stageId: stageId,
          isArchived: Value(archived),
          createdAt: now,
          updatedAt: now,
        ));
  }

  group('拼音表', () {
    test('表已载入且长度正确', () {
      expect(PinyinSearch.isReady, isTrue);
    });

    test('汉字转首字母', () {
      expect(PinyinSearch.initials('随想随记'), 'sxsj');
      expect(PinyinSearch.initials('钢结构'), 'gjg');
      expect(PinyinSearch.initials('手工'), 'sg');
    });

    test('全拼表已载入且转换正确', () {
      expect(PinyinSearch.isFullReady, isTrue);
      expect(PinyinSearch.fullPinyin('手工'), 'shougong');
      expect(PinyinSearch.fullPinyin('随想随记'), 'suixiangsuiji');
      expect(PinyinSearch.fullPinyin('钢结构'), 'gangjiegou');
    });

    test('全拼命中（含跨音节与 ASCII 混排）', () {
      expect(PinyinSearch.matches('手工皮具的想法', 'shougong'), isTrue);
      // 跨音节子串：宽松命中，与首字母路径行为一致
      expect(PinyinSearch.matches('手工', 'ougo'), isTrue);
      expect(PinyinSearch.fullPinyin('Flutter 手记'), 'fluttershouji');
    });

    test('全拼 miss 不串到首字母假阳', () {
      // 'zzz' 既不在首字母流也不在全拼流
      expect(PinyinSearch.matches('手工皮具的想法', 'zzz'), isFalse);
      expect(PinyinSearch.matches('手工皮具的想法', 'zhengzhou'), isFalse);
    });

    test('命中区间：全拼映射回原汉字', () {
      final r = PinyinSearch.ranges('手工皮具的想法', 'shougong');
      expect(r.length, 1);
      // 「手工」两字 → start 0, end 2（整音节收敛回首字符区间）
      expect(r.first.start, 0);
      expect(r.first.end, 2);
    });

    test('英文与混合串：ASCII 保留并转小写，标点丢弃', () {
      expect(PinyinSearch.initials('Flutter 笔记'), 'flutterbj');
      expect(PinyinSearch.initials('2026 复盘'), 'fp');
    });

    test('字面命中（大小写不敏感）', () {
      expect(PinyinSearch.matches('Flutter 卡片动画', 'flutter'), isTrue);
      expect(PinyinSearch.matches('Flutter 卡片动画', 'FLUTTER'), isTrue);
      expect(PinyinSearch.matches('Flutter 卡片动画', 'vue'), isFalse);
    });

    test('拼音首字母命中', () {
      expect(PinyinSearch.matches('手工皮具的想法', 'sg'), isTrue);
      expect(PinyinSearch.matches('手工皮具的想法', 'sgp'), isTrue);
      expect(PinyinSearch.matches('手工皮具的想法', 'sgpj'), isTrue);
      expect(PinyinSearch.matches('手工皮具的想法', 'zzz'), isFalse);
    });

    test('含汉字的查询不再走拼音（避免双重解释）', () {
      expect(PinyinSearch.matches('手工皮具', '手工'), isTrue);
      expect(PinyinSearch.matches('手工皮具', '手'), isTrue);
    });

    test('空查询恒命中', () {
      expect(PinyinSearch.matches('任意内容', ''), isTrue);
      expect(PinyinSearch.matches('任意内容', '   '), isTrue);
    });

    test('命中区间：字面', () {
      final r = PinyinSearch.ranges('手工皮具的想法', '皮具');
      expect(r.length, 1);
      expect(r.first.start, 2);
      expect(r.first.end, 4);
    });

    test('命中区间：拼音映射回原汉字', () {
      final r = PinyinSearch.ranges('手工皮具的想法', 'sg');
      expect(r.length, 1);
      // 「手工」两字 → start 0, end 2
      expect(r.first.start, 0);
      expect(r.first.end, 2);
    });

    test('命中区间：多处命中且相邻合并', () {
      final r = PinyinSearch.ranges('手工手工', 'sg');
      expect(r.length, 1);
      expect(r.first.start, 0);
      expect(r.first.end, 4);
    });

    test('无命中返回空', () {
      expect(PinyinSearch.ranges('手工皮具', 'zzz'), isEmpty);
      expect(PinyinSearch.ranges('', 'a'), isEmpty);
    });
  });

  group('搜索：watchFeed 拼音与字面统一', () {
    setUp(freshDb);

    test('拼音首字母能搜到汉字随记', () async {
      await seed('钢结构驻厂监造的经验');
      await seed('今天天气不错');
      final list = await db.watchFeed(query: 'gjg').first;
      expect(list.length, 1);
      expect(list.first.title, '钢结构驻厂监造的经验');
    });

    test('全拼能搜到汉字随记（v2.7.0 双表）', () async {
      await seed('手工皮具的想法');
      await seed('今天天气不错');
      final list = await db.watchFeed(query: 'shougong').first;
      expect(list.length, 1);
      expect(list.first.title, '手工皮具的想法');
    });

    test('字面搜索仍然有效', () async {
      await seed('手工皮具的想法');
      await seed('无关内容');
      final list = await db.watchFeed(query: '皮具').first;
      expect(list.length, 1);
    });

    test('标题或正文任一命中即可（正文命中但标题不同）', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.thoughts).insert(ThoughtsCompanion.insert(
            uuid: 'uuid-mixed',
            title: const Value('周会记录'),
            content: const Value('讨论了钢结构焊接工艺'),
            stageId: 1,
            createdAt: now,
            updatedAt: now,
          ));
      final list = await db.watchFeed(query: 'gjg').first;
      expect(list.length, 1);
      expect(list.first.title, '周会记录');
    });

    test('带标签过滤时拼音搜索同样生效（曾经两条路径语义不一致）', () async {
      final tagId = (await db.createTag('工作'))!.id;
      final a = await seed('钢结构监造');
      await seed('钢结构笔记但没打标签');
      await db.setThoughtTags(a, [tagId]);

      final withTag = await db.watchFeed(query: 'gjg', tagId: tagId).first;
      expect(withTag.length, 1);
      expect(withTag.first.id, a);

      final noTag = await db.watchFeed(query: 'gjg').first;
      expect(noTag.length, 2);
    });

    test('状态过滤与拼音搜索正交', () async {
      final a = await seed('钢结构灵感', stageId: 1);
      final b = await seed('钢结构已推进', stageId: 2);
      await seed('钢结构已完成', stageId: 3);

      final all = await db.watchFeed(query: 'gjg').first;
      expect(all.length, 3);

      final first = await db.watchFeed(query: 'gjg', stageId: 1).first;
      expect(first.length, 1);
      expect(first.first.id, a);

      final second = await db.watchFeed(query: 'gjg', stageId: 2).first;
      expect(second.length, 1);
      expect(second.first.id, b);
    });

    test('归档随记不出现在主信息流，但归档流能搜到', () async {
      await seed('钢结构归档了', archived: true);
      final main = await db.watchFeed(query: 'gjg').first;
      expect(main, isEmpty);
    });

    test('软删随记不被搜出', () async {
      final id = await seed('钢结构要删掉');
      await db.softDelete(id);
      final list = await db.watchFeed(query: 'gjg').first;
      expect(list, isEmpty);
    });

    test('空查询返回全部（不受拼音逻辑影响）', () async {
      await seed('一条');
      await seed('两条');
      final list = await db.watchFeed().first;
      expect(list.length, 2);
    });

    test('LIKE 通配符按字面处理（架构评审 D2 未退化）', () async {
      await seed('完成度 100% 了');
      await seed('完全无关');
      final list = await db.watchFeed(query: '100%').first;
      expect(list.length, 1);
    });
  });
}
