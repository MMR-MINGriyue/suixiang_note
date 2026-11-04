import 'dart:io';

import 'package:drift/drift.dart' show Value;
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
    tmp = Directory.systemTemp.createTempSync('suixiang_reminder_test');
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
    await db.select(db.stages).get(); // 等种子完成
  }

  int ts(DateTime t) => t.millisecondsSinceEpoch;

  group('upsertReminder', () {
    test('同一条随记只保留一个 active 提醒（重复设定会覆盖，不叠加）', () async {
      await freshDb();
      final id = await db.saveDraft(content: '交周报');

      final first = await db.upsertReminder(
          thoughtId: id, remindAt: ts(DateTime(2030, 1, 1, 9)));
      final second = await db.upsertReminder(
          thoughtId: id, remindAt: ts(DateTime(2030, 2, 1, 9)));

      final active = await db.watchActiveReminderOf(id).first;
      expect(active.length, 1, reason: '旧提醒应被删掉，同一条随记只允许一个闹钟');
      expect(active.single.remindAt, ts(DateTime(2030, 2, 1, 9)));
      expect(first, isNot(second));
    });

    test('repeatRule 映射到 repeatUnit / repeatInterval', () async {
      await freshDb();
      final id = await db.saveDraft(content: '每天喝一杯水');

      await db.upsertReminder(
          thoughtId: id,
          remindAt: ts(DateTime(2030, 1, 1, 9)),
          repeatRule: 'daily');
      var r = (await db.watchActiveReminderOf(id).first).single;
      expect(r.repeatUnit, 'day');
      expect(r.repeatInterval, 1);

      await db.upsertReminder(
          thoughtId: id,
          remindAt: ts(DateTime(2030, 1, 1, 9)),
          repeatRule: 'weekly');
      r = (await db.watchActiveReminderOf(id).first).single;
      expect(r.repeatUnit, 'week');

      await db.upsertReminder(
          thoughtId: id, remindAt: ts(DateTime(2030, 1, 1, 9)));
      r = (await db.watchActiveReminderOf(id).first).single;
      expect(r.repeatUnit, isNull, reason: '一次性提醒不该带重复单位');
      expect(r.repeatRule, 'once');
    });
  });

  group('takeDueReminders', () {
    test('只取「已过期 + active + 未被删」的提醒', () async {
      await freshDb();
      final now = DateTime(2030, 6, 1, 12); // 虚拟「此刻」，避免测试依赖真实时钟

      final past = await db.saveDraft(content: '过去该响的');
      final future = await db.saveDraft(content: '将来才响的');
      final deleted = await db.saveDraft(content: '已删随记的提醒');

      await db.upsertReminder(
          thoughtId: past, remindAt: ts(now.subtract(const Duration(hours: 1))));
      await db.upsertReminder(
          thoughtId: future, remindAt: ts(now.add(const Duration(hours: 1))));
      await db.upsertReminder(
          thoughtId: deleted,
          remindAt: ts(now.subtract(const Duration(hours: 2))));
      await db.softDelete(deleted);

      final due = await db.takeDueReminders(now: ts(now));
      expect(due.length, 1);
      expect(due.single.thought.id, past, reason: '未来提醒与已删随记的提醒都不应出现');
    });

    test('已 fired 的一次性提醒不再算到期', () async {
      await freshDb();
      final now = DateTime(2030, 6, 1, 12);
      final id = await db.saveDraft(content: '一次性的');
      final rid = await db.upsertReminder(
          thoughtId: id, remindAt: ts(now.subtract(const Duration(minutes: 5))));

      var due = await db.takeDueReminders(now: ts(now));
      expect(due.length, 1);

      await db.markReminderFired(rid);
      due = await db.takeDueReminders(now: ts(now));
      expect(due, isEmpty, reason: 'fired 后状态不再是 active');
    });

    test('重复提醒 markReminderFiredKeepActive 后仍是 active，只写 lastFiredAt', () async {
      await freshDb();
      final now = DateTime(2030, 6, 1, 12);
      final id = await db.saveDraft(content: '每天提醒我');
      final rid = await db.upsertReminder(
          thoughtId: id,
          remindAt: ts(now.subtract(const Duration(minutes: 1))),
          repeatRule: 'daily');

      await db.markReminderFiredKeepActive(rid);

      final active = await db.watchActiveReminderOf(id).first;
      expect(active.length, 1, reason: '重复提醒不该被关掉');
      expect(active.single.status, 'active');
      expect(active.single.lastFiredAt, isNotNull);
    });
  });

  group('提醒流与清理', () {
    test('软删随记后，其提醒从待提醒列表消失', () async {
      await freshDb();
      final keep = await db.saveDraft(content: '保留的');
      final gone = await db.saveDraft(content: '要删的');
      await db.upsertReminder(
          thoughtId: keep, remindAt: ts(DateTime(2030, 3, 1, 9)));
      await db.upsertReminder(
          thoughtId: gone, remindAt: ts(DateTime(2030, 3, 2, 9)));

      var upcoming = await db.watchUpcomingReminders().first;
      expect(upcoming.length, 2);

      await db.softDelete(gone);
      upcoming = await db.watchUpcomingReminders().first;
      expect(upcoming.length, 1);
      expect(upcoming.single.thought.id, keep);

      // 回收站里恢复回来，提醒也应随之复活
      await db.restoreFromTrash(gone);
      upcoming = await db.watchUpcomingReminders().first;
      expect(upcoming.length, 2);
    });

    test('deleteReminder 直接移除该条提醒', () async {
      await freshDb();
      final id = await db.saveDraft(content: '取消提醒');
      final rid = await db.upsertReminder(
          thoughtId: id, remindAt: ts(DateTime(2030, 4, 1, 9)));

      await db.deleteReminder(rid);
      final active = await db.watchActiveReminderOf(id).first;
      expect(active, isEmpty);
    });

    test('snapshotActiveReminders 只含 active 且按时间升序', () async {
      await freshDb();
      final a = await db.saveDraft(content: 'A');
      final b = await db.saveDraft(content: 'B');
      await db.upsertReminder(
          thoughtId: a, remindAt: ts(DateTime(2030, 5, 2, 9)));
      await db.upsertReminder(
          thoughtId: b, remindAt: ts(DateTime(2030, 5, 1, 9)));

      final snap = await db.snapshotActiveReminders();
      expect(snap.length, 2);
      expect(snap.first.thought.id, b, reason: '早的排前面');
    });
  });

  group('ReminderWithThought.headline', () {
    test('优先用标题、只取首行', () async {
      await freshDb();

      final multi = await db.saveDraft(content: '第一行标题\n第二行内容');
      await db.upsertReminder(
          thoughtId: multi, remindAt: ts(DateTime(2030, 7, 2, 9)));

      final list = await db.snapshotActiveReminders();
      final m = list.firstWhere((e) => e.thought.id == multi);
      expect(m.headline, '第一行标题', reason: '只取首行');
    });

    test('标题超 40 字时截断加省略号（防御旧数据/导入数据）', () async {
      await freshDb();
      final id = await db.saveDraft(content: '短内容');
      final longTitle =
          '这是一段被人为写得非常非常长的标题用来验证四十字截断分支是否正常工作需要超过四十个字';
      expect(longTitle.length, greaterThan(40));
      await (db.update(db.thoughts)..where((t) => t.id.equals(id))).write(
          ThoughtsCompanion(title: Value(longTitle)));
      await db.upsertReminder(
          thoughtId: id, remindAt: ts(DateTime(2030, 7, 1, 9)));

      final item = (await db.snapshotActiveReminders()).single;
      expect(item.headline.endsWith('…'), isTrue);
      expect(item.headline.length, 41, reason: '40 字 + 省略号');
      expect(item.headline, '${longTitle.substring(0, 40)}…');
    });

    test('标题与正文都为空时回落为「随想随记」', () async {
      await freshDb();
      final id = await db.saveDraft(content: '占位');
      await (db.update(db.thoughts)..where((t) => t.id.equals(id))).write(
          const ThoughtsCompanion(
              title: Value(''), content: Value('')));
      await db.upsertReminder(
          thoughtId: id, remindAt: ts(DateTime(2030, 7, 3, 9)));

      final item = (await db.snapshotActiveReminders()).single;
      expect(item.headline, '随想随记');
    });

    test('saveDraft 派生的标题上限 30 字，headline 直接复用', () async {
      await freshDb();
      final id = await db.saveDraft(
          content: '这是一个超过三十个字的标题会被 saveDraft 截断到三十字上限用于验证派生规则');
      await db.upsertReminder(
          thoughtId: id, remindAt: ts(DateTime(2030, 7, 4, 9)));

      final item = (await db.snapshotActiveReminders()).single;
      expect(item.thought.title.length, 30, reason: 'saveDraft 派生标题上限 30');
      expect(item.headline, item.thought.title,
          reason: '标题已 ≤30 字，headline 不会再截断');
    });
  });
}
