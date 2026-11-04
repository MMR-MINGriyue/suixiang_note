import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:suixiang_note/data/app_database.dart';

/// path_provider 桌面测试桩（drift_flutter 需要 documents + temporary）
class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String root;
  _FakePathProvider(this.root);

  String _ensure(String sub) {
    final d = Directory('$root/$sub');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async => _ensure('Documents');

  @override
  Future<String?> getTemporaryPath() async => _ensure('tmp');

  @override
  Future<String?> getApplicationSupportPath() async => _ensure('support');
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  var created = false;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('suixiang_feed_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() async {
    if (created) await db.close();
    created = false;
  });

  tearDownAll(() async {
    tmp.deleteSync(recursive: true);
  });

  /// 每个 test 用独立内存库：磁盘文件会被上一个用例的数据污染，
  /// 而 NativeDatabase.memory() 每次都是干净 schema + 全新种子。
  Future<void> freshDb() async {
    if (created) await db.close();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    created = true;
    await db.select(db.stages).get(); // 等 beforeOpen 种子完成
  }

  group('watchFeed 三向过滤', () {
    test('搜索 / 状态 / 标签 正交组合', () async {
      await freshDb();
      final tag = await db.createTag('灵感标签');
      final idA = await db.saveDraft(content: '买牛奶记得看保质期');
      final idB = await db.saveDraft(content: '写周报，顺便提一下备份');
      final idC = await db.saveDraft(content: '买牛奶 第二件事');

      // 状态：把 C 推进到「推进中」
      await db.advanceStage(idC);
      await db.setThoughtTags(idA, [tag!.id]);

      // 1) 纯搜索
      var list = await db.watchFeed(query: '牛奶').first;
      expect(list.map((t) => t.id).toSet(), {idA, idC});

      // 2) 搜索 + 状态
      list = await db.watchFeed(query: '牛奶', stageId: 2).first;
      expect(list.map((t) => t.id).toList(), [idC]);

      // 3) 状态 + 标签
      list = await db.watchFeed(tagId: tag.id, stageId: 1).first;
      expect(list.map((t) => t.id).toList(), [idA]);

      // 4) 标签 + 搜索（join 分支走内存收窄）
      list = await db.watchFeed(tagId: tag.id, query: '牛奶').first;
      expect(list.map((t) => t.id).toList(), [idA]);

      // 5) 空结果
      list = await db.watchFeed(query: '不存在的词').first;
      expect(list, isEmpty);

      // B 在全部条件下都不该出现
      expect(list.any((t) => t.id == idB), isFalse);
    });

    test('LIKE 通配符被当普通字符（架构评审 D2）', () async {
      await freshDb();
      await db.saveDraft(content: '折扣 100% 到货');
      await db.saveDraft(content: '完全无关的一条记录');
      await db.saveDraft(content: '下划线测试 a_b');

      // 「100%」不该因为 % 变成通配而命中全部
      final hit = await db.watchFeed(query: '100%').first;
      expect(hit.length, 1);
      expect(hit.single.content.contains('100%'), isTrue);

      // 「a_b」里的 _ 不该匹配任意单字符
      final underscore = await db.watchFeed(query: 'a_b').first;
      expect(underscore.length, 1);
      expect(underscore.single.content.contains('a_b'), isTrue);

      // 「aXb」不该命中 a_b 那条
      final notMatch = await db.watchFeed(query: 'aXb').first;
      expect(notMatch, isEmpty);

      // 单独一个 % 也不该返回全部
      final percentOnly = await db.watchFeed(query: '%').first;
      expect(percentOnly.length, 1); // 只有含「100%」那条
    });
  });

  group('归档（区别于回收站）', () {
    test('归档移出主列表、进归档流、清置顶、可取消', () async {
      await freshDb();
      final id = await db.saveDraft(content: '一条会被归档的随记');
      await db.togglePin(id); // 先置顶

      var main = await db.watchFeed().first;
      expect(main.map((t) => t.id).toList(), [id]);
      expect(main.single.isPinned, isTrue);

      // 归档
      await db.setArchived(id, true);

      main = await db.watchFeed().first;
      expect(main, isEmpty, reason: '归档后不该出现在主列表');

      final archived = await db.watchArchived().first;
      expect(archived.map((t) => t.id).toList(), [id]);
      expect(archived.single.isArchived, isTrue);
      expect(archived.single.isPinned, isFalse, reason: '归档时清置顶');
      expect(archived.single.pinnedAt, isNull);

      // 归档 ≠ 删除：不在回收站
      final trash = await db.watchTrash().first;
      expect(trash, isEmpty);

      // 取消归档回到主列表（置顶不恢复——归档期间用户没再表达置顶意图）
      await db.setArchived(id, false);
      main = await db.watchFeed().first;
      expect(main.map((t) => t.id).toList(), [id]);
      expect(main.single.isPinned, isFalse);
    });

    test('批量归档 + 归档流支持状态过滤', () async {
      await freshDb();
      final a = await db.saveDraft(content: '甲');
      final b = await db.saveDraft(content: '乙');
      final c = await db.saveDraft(content: '丙');
      await db.advanceStage(b); // b → 推进中
      await db.advanceStage(c);
      await db.advanceStage(c); // c → 已完成

      await db.batchSetArchived([a, b, c], true);
      expect((await db.watchFeed().first).length, 0);

      final all = await db.watchArchived().first;
      expect(all.length, 3);

      final onlyDone = await db.watchArchived(stageId: 3).first;
      expect(onlyDone.map((t) => t.id).toList(), [c]);
    });
  });

  group('回收站与归档互不干扰', () {
    test('删除的进回收站，归档的只在归档区', () async {
      await freshDb();
      final keep = await db.saveDraft(content: '删掉的');
      final arch = await db.saveDraft(content: '归档的');
      await db.softDelete(keep);
      await db.setArchived(arch, true);

      expect((await db.watchFeed().first).length, 0);
      expect((await db.watchTrash().first).map((t) => t.id).toList(), [keep]);
      expect((await db.watchArchived().first).map((t) => t.id).toList(), [arch]);
    });
  });
}
