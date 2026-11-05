import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:suixiang_note/core/format.dart';
import 'package:suixiang_note/data/app_database.dart';

/// path_provider 桌面测试桩（drift_flutter 需要 documents + temporary + support）
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
    tmp = Directory.systemTemp.createTempSync('suixiang_arch_p0_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() async {
    if (created) await db.close();
    created = false;
  });

  tearDownAll(() async {
    tmp.deleteSync(recursive: true);
  });

  Future<void> freshDb() async {
    if (created) await db.close();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    created = true;
    await db.select(db.stages).get(); // 等三态种子完成
  }

  int ts(DateTime t) => t.millisecondsSinceEpoch;

  /// 给一条随记造齐四张子表的数据（标签/提醒/附件/关联边），返回关联的对端 id。
  /// 这样 purge 前能断言「确实有子表引用」，purge 后能断言「一条不剩」。
  Future<int> seedChildren(int thoughtId, {required int otherId}) async {
    final tag = await db.createTag('工作');
    await db.setThoughtTags(thoughtId, [tag!.id]);
    await db.upsertReminder(
        thoughtId: thoughtId,
        remindAt: ts(DateTime(2030, 1, 1, 9)),
        repeatRule: 'daily');
    await db.into(db.attachments).insert(AttachmentsCompanion.insert(
        thoughtId: thoughtId,
        type: 'image',
        filePath: '/tmp/pic.png',
        createdAt: DateTime.now().millisecondsSinceEpoch));
    await db.linkThoughts(thoughtId, otherId);
    return otherId;
  }

  Future<bool> thoughtExists(int id) async =>
      (await (db.select(db.thoughts)..where((t) => t.id.equals(id))).get())
          .isNotEmpty;

  group('架构 P0-1 purge 级联删除四张子表', () {
    test('purgeThought 单条：清掉 thoughtTags/reminders/attachments/thoughtLinks'
        ' 且不影响其它随记', () async {
      await freshDb();
      final a = await db.saveDraft(content: '要彻底删掉的随记');
      final b = await db.saveDraft(content: '保留的随记');
      await seedChildren(a, otherId: b);

      // 前置：四张子表确实有 a 的引用（关联边 a→b 也算）
      expect((await db.select(db.thoughtTags).get())
          .where((r) => r.thoughtId == a), hasLength(1));
      expect((await db.select(db.reminders).get())
          .where((r) => r.thoughtId == a), hasLength(1));
      expect((await db.select(db.attachments).get())
          .where((r) => r.thoughtId == a), hasLength(1));
      expect((await db.select(db.thoughtLinks).get())
          .where((l) => l.fromId == a || l.toId == a), hasLength(1));

      await db.purgeThought(a);

      expect(await thoughtExists(a), isFalse, reason: '主表 a 已删');
      expect(await thoughtExists(b), isTrue, reason: '主表 b 保留');
      // 四张子表：a 相关全部清零（FK 开时不会抛约束；FK 关时不留孤儿行）
      expect((await db.select(db.thoughtTags).get())
          .where((r) => r.thoughtId == a), isEmpty);
      expect((await db.select(db.reminders).get())
          .where((r) => r.thoughtId == a), isEmpty);
      expect((await db.select(db.attachments).get())
          .where((r) => r.thoughtId == a), isEmpty);
      expect((await db.select(db.thoughtLinks).get())
          .where((l) => l.fromId == a || l.toId == a), isEmpty);
    });

    test('purgeTrash 批量：软删的随记连同四子表一起清，返回条数正确', () async {
      await freshDb();
      final a = await db.saveDraft(content: '回收站随记 A');
      final b = await db.saveDraft(content: '回收站随记 B');
      final c = await db.saveDraft(content: '正常随记 C');
      await seedChildren(a, otherId: b);
      await seedChildren(b, otherId: a);
      // a、b 进回收站，c 不动
      await db.softDelete(a);
      await db.softDelete(b);

      final count = await db.purgeTrash();
      expect(count, 2, reason: '实际删掉 2 条主表行');

      expect(await thoughtExists(a), isFalse);
      expect(await thoughtExists(b), isFalse);
      expect(await thoughtExists(c), isTrue, reason: '未软删的 c 不能误删');
      // 两个被删随记的子表数据全部清零（含 a→b、b→a 两条边）
      final aliveIds = [a, b];
      expect((await db.select(db.thoughtTags).get())
          .where((r) => aliveIds.contains(r.thoughtId)), isEmpty);
      expect((await db.select(db.reminders).get())
          .where((r) => aliveIds.contains(r.thoughtId)), isEmpty);
      expect((await db.select(db.attachments).get())
          .where((r) => aliveIds.contains(r.thoughtId)), isEmpty);
      expect((await db.select(db.thoughtLinks).get())
          .where((l) => aliveIds.contains(l.fromId) || aliveIds.contains(l.toId)),
          isEmpty);
    });

    test('purgeTrash 空回收站返回 0 且不触碰正常随记', () async {
      await freshDb();
      await db.saveDraft(content: '正常随记');
      expect(await db.purgeTrash(), 0);
      expect((await db.select(db.thoughts).get()), hasLength(1));
    });
  });

  group('架构 P0-2 重复提醒时钟对账', () {
    test('nextRemindAt 按本地日历推进，monthly 月末 clamp', () {
      // 2026-01-31 09:00 → daily 2/1 / weekly 2/7 / monthly 2/28（2 月无 31 日）
      final from = ts(DateTime(2026, 1, 31, 9));
      expect(
          DateTime.fromMillisecondsSinceEpoch(nextRemindAt(from, 'daily')!),
          DateTime(2026, 2, 1, 9));
      expect(
          DateTime.fromMillisecondsSinceEpoch(nextRemindAt(from, 'weekly')!),
          DateTime(2026, 2, 7, 9));
      expect(
          DateTime.fromMillisecondsSinceEpoch(nextRemindAt(from, 'monthly')!),
          DateTime(2026, 2, 28, 9),
          reason: '1/31 +1月 必须夹到 2 月最后一天，不能溢出到 3/3');
      expect(nextRemindAt(from, 'once'), isNull);
    });

    test('nextRemindAtAfter 十天没开 App 也一次推进到未来', () {
      final now = DateTime(2026, 6, 15, 10);
      final tenDaysAgo = ts(now.subtract(const Duration(days: 10)));
      final next = nextRemindAtAfter(tenDaysAgo, 'daily', ts(now));
      expect(next, isNotNull);
      expect(next! > ts(now), isTrue, reason: '严格晚于现在，否则下次启动还会判到期');
    });

    test('markReminderFiredKeepActive 后不再被 takeDueReminders 反复捞出', () async {
      await freshDb();
      final id = await db.saveDraft(content: '每天站会');
      // 设成 10 天前的「每天 09:00」，模拟长期没开 App
      final past = ts(DateTime.now().subtract(const Duration(days: 10)));
      await db.upsertReminder(thoughtId: id, remindAt: past, repeatRule: 'daily');

      final before = await db.takeDueReminders();
      expect(before, hasLength(1), reason: '第一次对账应捞出这条过期的重复提醒');

      await db.markReminderFiredKeepActive(before.single.reminder.id);

      // 关键回归：推进 remindAt 到未来后，再对账不能又弹一遍
      final after = await db.takeDueReminders();
      expect(after, isEmpty, reason: 'P0-2 修复前这里会永远返回 1 条，反复弹 SnackBar');

      final row = (await (db.select(db.reminders)
            ..where((r) => r.id.equals(before.single.reminder.id)))
          .getSingle());
      expect(row.status, 'active', reason: '重复提醒仍是 active，只是时刻推进了');
      expect(row.lastFiredAt, isNotNull);
      expect(row.remindAt > DateTime.now().millisecondsSinceEpoch, isTrue);
    });

    test('不可续期规则走 keepActive 时降级为 fired，不留 active+过去时刻',
        () async {
      await freshDb();
      final id = await db.saveDraft(content: '一次性提醒');
      final past = ts(DateTime.now().subtract(const Duration(days: 1)));
      await db.upsertReminder(
          thoughtId: id, remindAt: past, repeatRule: 'once');
      final due = await db.takeDueReminders();
      expect(due, hasLength(1));

      await db.markReminderFiredKeepActive(due.single.reminder.id);

      final row = (await (db.select(db.reminders)
            ..where((r) => r.id.equals(due.single.reminder.id)))
          .getSingle());
      expect(row.status, 'fired');
      expect(await db.takeDueReminders(), isEmpty);
    });
  });
}
