import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// 随想随记 本地数据库（drift + sqlite3）
/// schemaVersion 从 1 起；结构变更必须步进并先做 JSON 快照（PRD §6.4）。
@DriftDatabase(
  tables: [Folders, Stages, Thoughts, Tags, ThoughtTags, Reminders, Attachments, Settings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'suixiang_note'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          // 索引（PRD §6.3，部分索引排除软删行）
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_thoughts_list ON thoughts(deleted_at, is_archived, is_pinned DESC, pinned_at DESC, updated_at DESC)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_thoughts_folder ON thoughts(folder_id) WHERE deleted_at IS NULL');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_thoughts_stage ON thoughts(stage_id) WHERE deleted_at IS NULL');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_tt_tag ON thought_tags(tag_id)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_reminders_due ON reminders(status, remind_at)');

          // 系统三态种子（PRD §6.2 stages 种子；固定 id 1/2/3）
          final now = DateTime.now().millisecondsSinceEpoch;
          await into(stages).insertOnConflictUpdate(StagesCompanion.insert(
              id: const Value(1),
              name: '灵感',
              kind: 'inspiration',
              color: '#A8B9E6',
              position: const Value(1.0).value,
              isSystem: const Value(true),
              createdAt: now));
          await into(stages).insertOnConflictUpdate(StagesCompanion.insert(
              id: const Value(2),
              name: '推进中',
              kind: 'in_progress',
              color: '#4C6FFF',
              position: const Value(2.0).value,
              isSystem: const Value(true),
              createdAt: now));
          await into(stages).insertOnConflictUpdate(StagesCompanion.insert(
              id: const Value(3),
              name: '已完成',
              kind: 'done',
              color: '#2FBF8F',
              position: const Value(3.0).value,
              isSystem: const Value(true),
              createdAt: now));
        },
      );

  // ═══════════════ 随记：列表与捕捉（M2 闭环的数据面） ═══════════════

  /// 主列表流：置顶优先，组内按更新时间倒序；软删与归档恒排除
  Stream<List<Thought>> watchList({bool archived = false}) {
    return (select(thoughts)
          ..where((t) => t.deletedAt.isNull() & t.isArchived.equals(archived))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.pinnedAt),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .watch();
  }

  /// 阶段全表（按 position 升序）
  Stream<List<Stage>> watchStages() =>
      (select(stages)..orderBy([(s) => OrderingTerm.asc(s.position)])).watch();

  /// 阶段推进：单击切下一态（循环），进入/离开「已完成」维护 completedAt（PRD §4.2）
  Future<void> advanceStage(int thoughtId) async {
    final all = await (select(stages)..orderBy([(s) => OrderingTerm.asc(s.position)])).get();
    if (all.isEmpty) return;
    final thought = await (select(thoughts)..where((t) => t.id.equals(thoughtId))).getSingle();
    final idx = all.indexWhere((s) => s.id == thought.stageId);
    final next = all[(idx + 1) % all.length];
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(thoughts)..where((t) => t.id.equals(thoughtId))).write(ThoughtsCompanion(
      stageId: Value(next.id),
      updatedAt: Value(now),
      completedAt: Value(next.kind == 'done' ? now : null),
    ));
  }

  /// 置顶/取消置顶（v1.0 仅置顶，归档暂缓 —— PM 结论）
  Future<void> togglePin(int thoughtId) async {
    final thought = await (select(thoughts)..where((t) => t.id.equals(thoughtId))).getSingle();
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(thoughts)..where((t) => t.id.equals(thoughtId))).write(ThoughtsCompanion(
      isPinned: Value(!thought.isPinned),
      pinnedAt: Value(thought.isPinned ? null : now),
    ));
  }

  /// 软删 → 回收站
  Future<void> softDelete(int thoughtId) async {
    await (update(thoughts)..where((t) => t.id.equals(thoughtId)))
        .write(ThoughtsCompanion(deletedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// 速记落库/更新：500ms 防抖后调用；标题=首行，空内容不留脏数据（§8 空内容验收）
  Future<int> saveDraft({int? id, required String content}) async {
    final trimmed = content.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id == null) {
      if (trimmed.isEmpty) return -1; // 空内容直接落库=脏数据，拒绝
      final firstLine = trimmed.split('\n').first;
      final companion = ThoughtsCompanion.insert(
        uuid: const Uuid().v4(),
        stageId: const Value(1).value, // 默认「灵感」
        title: Value(firstLine.length > 30 ? firstLine.substring(0, 30) : firstLine),
        content: Value(trimmed),
        wordCount: Value(trimmed.replaceAll(RegExp(r'\s'), '').length),
        createdAt: now,
        updatedAt: now,
      );
      return into(thoughts).insert(companion);
    }
    // 已有草稿：空内容 → 硬删草稿行；否则更新
    if (trimmed.isEmpty) {
      await (delete(thoughts)..where((t) => t.id.equals(id))).go();
      return -1;
    }
    final firstLine = trimmed.split('\n').first;
    await (update(thoughts)..where((t) => t.id.equals(id))).write(ThoughtsCompanion(
      title: Value(firstLine.length > 30 ? firstLine.substring(0, 30) : firstLine),
      content: Value(trimmed),
      wordCount: Value(trimmed.replaceAll(RegExp(r'\s'), '').length),
      updatedAt: Value(now),
    ));
    return id;
  }

  // ═══════════════ 文件夹（M4 整理闭环的数据面） ═══════════════

  /// 文件夹流：含未软删随记计数（收件箱计数由 UI 单独算）
  Stream<List<FolderWithCount>> watchFoldersWithCount() {
    final countExp = thoughts.id.count();
    final query = select(folders).join([
      leftOuterJoin(thoughts,
          thoughts.folderId.equalsExp(folders.id) & thoughts.deletedAt.isNull()),
    ])
      ..addColumns([countExp])
      ..groupBy([folders.id]);
    final stream = query
        .watch()
        .map((rows) => rows
            .map((r) => FolderWithCount(
                r.readTable(folders), r.read(countExp)!))
            .toList());
    return stream;
  }

  Future<void> createFolder(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(folders).insert(FoldersCompanion.insert(
        name: name.trim(), createdAt: now, updatedAt: now));
  }

  /// 删文件夹：软删 + 随记回收件箱（folder_id 置 NULL，PRD §4.4）
  Future<void> deleteFolder(int folderId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(thoughts)..where((t) => t.folderId.equals(folderId) & t.deletedAt.isNull()))
        .write(const ThoughtsCompanion(folderId: Value(null)));
    await (update(folders)..where((f) => f.id.equals(folderId)))
        .write(FoldersCompanion(deletedAt: Value(now)));
  }

  // ═══════════════ 设置 KV ═══════════════

  /// 清空回收站：物理删除已软删随记
  Future<int> purgeTrash() {
    return (delete(thoughts)..where((t) => t.deletedAt.isNotNull())).go();
  }

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: Value(value)));
  }
}

class FolderWithCount {
  final Folder folder;
  final int count;
  FolderWithCount(this.folder, this.count);
}
