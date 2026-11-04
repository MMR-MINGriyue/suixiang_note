import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_info.dart';
import 'app_database.dart';

/// M5 安全网 —— 备份/恢复服务（PM+UX 评审共同点名的最大隐藏刚需）
///
/// 设计要点（对齐评审结论）：
/// - 备份写到**用户可见目录**（Windows: 我的文档\suixiang_note_backups），
///   绝不只写应用沙箱 —— 沙箱备份随卸载/清数据全失（PRD 原方案已被评审否决）。
/// - 保留最近 7 份，超出的按修改时间清理（PRD §4.7）。
/// - JSON 快照：formatVersion + schemaVersion + 全 8 表（键 = drift 生成 DataClass
///   toJson 的 camelCase 键；恢复走 fromJson → toCompanion → insertOnConflictUpdate，
///   全程生成代码，不手写字段映射）。
/// - 恢复策略 v1.0：整库替换 —— 事务内先清空 7 表（stages 保留种子行被覆盖），
///   再按备份重灌；恢复前自动把当前库再做一份快照（防误恢复）。
class BackupService {
  final AppDatabase db;
  BackupService(this.db);

  static const _keepCount = 7;
  static const _metaKeyLastBackup = 'last_backup_at';

  /// 备份目录：用户可见
  Future<Directory> backupDir() async {
    final docs = (await getApplicationDocumentsDirectory()).path;
    final dir = Directory(p.join(docs, kBackupFolderName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// 执行备份。返回备份文件绝对路径。
  Future<String> backupNow() async {
    final dir = await backupDir();
    final now = DateTime.now();
    // 同一秒可能发生多次备份（如恢复前快照），冲突时加序号后缀避免覆盖
    var stamp = '${now.year}${_two(now.month)}${_two(now.day)}'
        '_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    var file = File(p.join(dir.path, 'suixiang_backup_$stamp.json'));
    var seq = 1;
    while (file.existsSync()) {
      stamp = '${stamp}_$seq';
      file = File(p.join(dir.path, 'suixiang_backup_$stamp.json'));
      seq++;
    }

    final snapshot = {
      'app': 'suixiang_note',
      'formatVersion': 1,
      'schemaVersion': db.schemaVersion,
      'exportedAt': now.toIso8601String(),
      'folders': (await db.select(db.folders).get()).map((r) => r.toJson()).toList(),
      'stages': (await db.select(db.stages).get()).map((r) => r.toJson()).toList(),
      'thoughts': (await db.select(db.thoughts).get()).map((r) => r.toJson()).toList(),
      'tags': (await db.select(db.tags).get()).map((r) => r.toJson()).toList(),
      'thoughtTags': (await db.select(db.thoughtTags).get()).map((r) => r.toJson()).toList(),
      'reminders': (await db.select(db.reminders).get()).map((r) => r.toJson()).toList(),
      'attachments': (await db.select(db.attachments).get()).map((r) => r.toJson()).toList(),
      'settings': (await db.select(db.settings).get()).map((r) => r.toJson()).toList(),
    };

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(snapshot));

    // 清理旧份：只留最近 _keepCount 份
    final backups = _listBackups(dir);
    for (final old in backups.skip(_keepCount)) {
      try {
        old.deleteSync();
      } catch (_) {}
    }

    await db.setSetting(_metaKeyLastBackup, now.millisecondsSinceEpoch.toString());
    return file.path;
  }

  /// 列出全部备份（新→旧）
  Future<List<File>> listBackups() async => _listBackups(await backupDir());

  /// 恢复：整库替换。返回恢复的随记条数。
  /// 恢复前自动对当前库做一次「恢复前快照」。
  Future<int> restoreFrom(File backup) async {
    final raw = await backup.readAsString();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (map['app'] != 'suixiang_note') {
      throw const FormatException('不是随想随记的备份文件');
    }
    // Architect P0-A3：校验 schemaVersion —— 快照的库结构版本不能高于当前应用
    // （高版本快照的字段在旧版 fromJson 里会被静默丢弃，恢复即数据损失）
    final backupSchema = (map['schemaVersion'] as num?)?.toInt();
    if (backupSchema != null && backupSchema > db.schemaVersion) {
      throw FormatException(
          '备份文件结构版本（$backupSchema）高于当前应用（${db.schemaVersion}），'
          '请先升级应用再恢复');
    }

    // 恢复前快照（PRD §6.4 迁移前快照纪律的延伸）
    await backupNow();

    await db.transaction(() async {
      // 清空（子表→主表，规避外键）—— stages 不清，靠 upsert 覆盖系统三态
      await db.delete(db.thoughtTags).go();
      await db.delete(db.attachments).go();
      await db.delete(db.reminders).go();
      await db.delete(db.thoughts).go();
      await db.delete(db.tags).go();
      await db.delete(db.folders).go();
      await db.delete(db.settings).go();

      for (final r in (map['folders'] as List? ?? [])) {
        await db.into(db.folders).insertOnConflictUpdate(
            Folder.fromJson(r as Map<String, dynamic>).toCompanion(true));
      }
      for (final r in (map['stages'] as List? ?? [])) {
        await db.into(db.stages).insertOnConflictUpdate(
            Stage.fromJson(r as Map<String, dynamic>).toCompanion(true));
      }
      for (final r in (map['thoughts'] as List? ?? [])) {
        await db.into(db.thoughts).insertOnConflictUpdate(
            Thought.fromJson(r as Map<String, dynamic>).toCompanion(true));
      }
      for (final r in (map['tags'] as List? ?? [])) {
        await db.into(db.tags).insertOnConflictUpdate(
            Tag.fromJson(r as Map<String, dynamic>).toCompanion(true));
      }
      for (final r in (map['thoughtTags'] as List? ?? [])) {
        await db.into(db.thoughtTags).insertOnConflictUpdate(
            ThoughtTag.fromJson(r as Map<String, dynamic>).toCompanion(true));
      }
      for (final r in (map['reminders'] as List? ?? [])) {
        await db.into(db.reminders).insertOnConflictUpdate(
            Reminder.fromJson(r as Map<String, dynamic>).toCompanion(true));
      }
      for (final r in (map['attachments'] as List? ?? [])) {
        await db.into(db.attachments).insertOnConflictUpdate(
            Attachment.fromJson(r as Map<String, dynamic>).toCompanion(true));
      }
      // settings：跳过 last_backup_at（恢复后以恢复时刻重计）
      for (final r in (map['settings'] as List? ?? [])) {
        final row = r as Map<String, dynamic>;
        if (row['key'] == _metaKeyLastBackup) continue;
        await db.into(db.settings).insertOnConflictUpdate(
            Setting.fromJson(row).toCompanion(true));
      }
    });
    return (map['thoughts'] as List? ?? []).length;
  }

  // ─── 工具 ───

  List<File> _listBackups(Directory dir) {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
