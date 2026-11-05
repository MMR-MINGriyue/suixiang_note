import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:suixiang_note/core/pinyin_search.dart';
import 'package:suixiang_note/data/app_database.dart';

/// 架构复审 P1 回归测试：P1-5 回收站语义 / P1-6 墓碑与复活 / P1-7 状态下推。
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => tmp!.path;

  @override
  Future<String?> getApplicationSupportPath() async => tmp!.path;

  @override
  Future<String?> getTemporaryPath() async => tmp!.path;
}

Directory? tmp;
late AppDatabase db;
var created = false;

Future<void> freshDb() async {
  if (created) await db.close();
  db = AppDatabase.forTesting(NativeDatabase.memory());
  created = true;
  await db.select(db.stages).get(); // 触发 beforeOpen（索引 + 三态种子）
}

int ts(DateTime t) => t.millisecondsSinceEpoch;

Future<int> seed(String content,
    {int stageId = 1, bool archived = false, bool pinned = false}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  return db.into(db.thoughts).insert(ThoughtsCompanion.insert(
        uuid: 'uuid-$content-$now',
        stageId: stageId, // required 无默认值的列：insert 构造直接收值
        title: Value(content),
        content: Value(content),
        createdAt: now,
        updatedAt: now,
        isArchived: Value(archived),
        isPinned: Value(pinned),
      ));
}

void main() {
  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProvider();
    tmp = await Directory.systemTemp.createTemp('suixiang_p1_');
    // 拼音用例需要表：测试进程没有 rootBundle 资产，直接读盘上同一份
    final raw =
        File('assets/pinyin/first_letter.txt').readAsStringSync();
    PinyinSearch.loadFromString(raw);
  });
  tearDown(() async {
    if (created) await db.close();
    created = false;
  });
  tearDownAll(() async {
    try {
      tmp?.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('P1-5 回收站语义：软删清归档置顶，恢复回常规列表', () {
    test('软删归档+置顶随记后，恢复落到常规列表且不置顶', () async {
      await freshDb();
      final a = await seed('归档又置顶的随记', archived: true, pinned: true);

      await db.softDelete(a);
      var row = await (db.select(db.thoughts)
            ..where((t) => t.id.equals(a)))
          .getSingle();
      expect(row.deletedAt, isNotNull);
      expect(row.isArchived, isFalse, reason: '进回收站=清归档');
      expect(row.isPinned, isFalse, reason: '进回收站=清置顶');

      await db.restoreFromTrash(a);
      row = await (db.select(db.thoughts)..where((t) => t.id.equals(a)))
          .getSingle();
      expect(row.deletedAt, isNull);
      expect(row.isArchived, isFalse, reason: '恢复=回常规列表，不回归档视图');
      expect(row.isPinned, isFalse, reason: '恢复后不残留置顶');
    });

    test('恢复时指向已软删文件夹 → 回收件箱；有效文件夹保留', () async {
      await freshDb();
      final f = await db.into(db.folders).insert(FoldersCompanion.insert(
            name: '会留下的',
            createdAt: ts(DateTime.now()),
            updatedAt: ts(DateTime.now()),
          ));
      final f2 = await db.into(db.folders).insert(FoldersCompanion.insert(
            name: '会删掉的',
            createdAt: ts(DateTime.now()),
            updatedAt: ts(DateTime.now()),
          ));
      final keep = await seed('文件夹保留', stageId: 1);
      final gone = await seed('文件夹消失', stageId: 1);
      await db.moveToFolder(keep, f);
      await db.moveToFolder(gone, f2);

      await db.deleteFolder(f2); // 软删文件夹
      await db.softDelete(keep);
      await db.softDelete(gone);
      await db.restoreFromTrash(keep);
      await db.restoreFromTrash(gone);

      expect(
          (await db.getThought(keep))!.folderId, f,
          reason: '文件夹仍在，恢复后引用保留');
      expect((await db.getThought(gone))!.folderId, isNull,
          reason: '文件夹已软删，恢复后回收件箱');
    });

    test('恢复已彻底删除的随记是无操作（不抛异常）', () async {
      await freshDb();
      final a = await seed('会被彻底删除');
      await db.softDelete(a);
      await db.purgeThought(a);
      await db.restoreFromTrash(a); // 不应抛
      expect(await db.getThought(a), isNull);
    });
  });

  group('P1-6 name UNIQUE 与软删：墓碑 + 复活', () {
    test('删文件夹后同名新建=复活原行，不撞 UNIQUE', () async {
      await freshDb();
      final f = await db.into(db.folders).insert(FoldersCompanion.insert(
            name: '工作',
            color: const Value('#2FBF8F'),
            createdAt: ts(DateTime.now()),
            updatedAt: ts(DateTime.now()),
          ));
      await db.deleteFolder(f);

      // 软删行不占用用户视野
      final visible =
          await (db.select(db.folders)..where((x) => x.deletedAt.isNull()))
              .get();
      expect(visible, isEmpty);

      // 同名新建不再撞 UNIQUE，且是同一行复活
      await db.createFolder('工作', color: '#4C6FFF');
      final rows = await db.select(db.folders).get();
      expect(rows.length, 1, reason: '复活而不是新插一行');
      expect(rows.single.id, f);
      expect(rows.single.deletedAt, isNull);
      expect(rows.single.name, '工作');
      expect(rows.single.color, '#4C6FFF', reason: '复活时更新颜色');
    });

    test('删标签后同名新建=复活，且重建后可打标', () async {
      await freshDb();
      final tag = (await db.createTag('重要'))!;
      final a = await seed('要打标的随记');
      await db.setThoughtTags(a, [tag.id]);
      await db.deleteTag(tag.id);
      expect(
          (await db.createTag('重要'))!.id, tag.id,
          reason: '同名新建复活同一行');

      final reborn = (await db.createTag('重要'))!;
      await db.setThoughtTags(a, [reborn.id]);
      final tags = await db.watchTagsOfThought(a).first;
      expect(tags.map((t) => t.name), contains('重要'));
    });

    test('未删除时同名新建=幂等（不再报 UNIQUE 异常）', () async {
      await freshDb();
      final first = (await db.createTag('专注'))!;
      final again = await db.createTag('专注');
      expect(again!.id, first.id);
    });
  });

  group('P1-7 状态过滤下推 SQL（watchFeed 语义回归）', () {
    test('无标签分支：stageId 过滤结果与内存过滤一致', () async {
      await freshDb();
      final a = await seed('灵感一条', stageId: 1);
      final b = await seed('推进一条', stageId: 2);
      await seed('完成一条', stageId: 3);

      final list = await db
          .watchFeed(stageId: 2)
          .map((l) => l.map((t) => t.id).toList())
          .first;
      expect(list, contains(b));
      expect(list, isNot(contains(a)));
    });

    test('有标签分支：标签+状态正交组合仍成立', () async {
      await freshDb();
      final work = (await db.createTag('工作'))!;
      final a = await seed('工作的推进', stageId: 2);
      final b = await seed('工作的灵感', stageId: 1);
      await seed('无关的推进', stageId: 2);
      await db.setThoughtTags(a, [work.id]);
      await db.setThoughtTags(b, [work.id]);

      final list = await db
          .watchFeed(tagId: work.id, stageId: 2)
          .map((l) => l.map((t) => t.id).toList())
          .first;
      expect(list, [a]);
    });

    test('拼音搜索与状态过滤正交（下推后仍生效）', () async {
      await freshDb();
      await seed('手工活儿', stageId: 1);
      final b = await seed('手工的推进项', stageId: 2);
      await seed('别的事', stageId: 2);

      final list = await db
          .watchFeed(query: 'sg', stageId: 2)
          .map((l) => l.map((t) => t.id).toList())
          .first;
      expect(list, [b]);
    });
  });
}
