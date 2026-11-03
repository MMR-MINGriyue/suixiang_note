import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:suixiang_note/data/app_database.dart';
import 'package:suixiang_note/data/backup_service.dart';

/// path_provider 桌面测试桩：Documents → 临时目录
class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String root;
  _FakePathProvider(this.root);
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final d = Directory('$root/Documents');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d.path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    final d = Directory('$root/tmp');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    final d = Directory('$root/support');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d.path;
  }
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late BackupService backup;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('suixiang_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDownAll(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('M5 数据级闭环：记→备份→清库→恢复→对数', () async {
    db = AppDatabase();
    backup = BackupService(db);

    // 等待 beforeOpen（索引+三态种子）完成：发一条探测查询
    await db.select(db.stages).get();

    // 1) 记 3 条随记 + 建 1 个文件夹，其中 1 条归入文件夹
    await db.createFolder('工作');
    final folder = (await db.select(db.folders).get()).single;
    final folderId = folder.id;
    final id1 = await db.saveDraft(content: '第一条：电梯里的灵感\n第二行细节');
    final id2 = await db.saveDraft(content: '第二条：会议记录要点');
    await db.saveDraft(content: '第三条：今晚买水果');
    await (db.update(db.thoughts)..where((t) => t.id.equals(id1)))
        .write(ThoughtsCompanion(folderId: drift.Value(folderId)));
    await db.advanceStage(id2); // 推进到「推进中」

    // 2) 备份
    final backupPath = await backup.backupNow();
    final backupFile = File(backupPath);
    expect(backupFile.existsSync(), isTrue);
    final backups = await backup.listBackups();
    expect(backups.first.path, backupPath);

    // 3) 清库（模拟卸载重装后空库/误清空）：清空 thoughts + folders
    await (db.delete(db.thoughts)).go();
    await (db.delete(db.folders)).go();
    final afterWipe = await db.select(db.thoughts).get();
    expect(afterWipe, isEmpty);

    // 4) 恢复
    final restoredCount = await backup.restoreFrom(backupFile);

    // 5) 对数
    expect(restoredCount, 3);
    final thoughts = await db.select(db.thoughts).get();
    expect(thoughts.length, 3);

    final t1 = thoughts.firstWhere((t) => t.content.contains('第一条'));
    expect(t1.uuid, isNotEmpty);
    expect(t1.folderId, folderId); // 文件夹关系保住
    expect(t1.title, '第一条：电梯里的灵感'); // 首行标题派生保持

    final t2 = thoughts.firstWhere((t) => t.content.contains('第二条'));
    expect(t2.stageId, 2); // 推进过的状态保住
    expect(t2.completedAt, isNull);

    final folders = await db.select(db.folders).get();
    expect(folders.length, 1);
    expect(folders.first.name, '工作');

    // 恢复前快照应该也存在（防误恢复机制触发过）
    final backupsAfter = await backup.listBackups();
    expect(backupsAfter.length, greaterThanOrEqualTo(2));
  });
}
