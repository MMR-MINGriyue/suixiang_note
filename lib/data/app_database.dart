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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2：folders 加 color 列已有默认值（withDefault），drift 建表即含列，
          // 但存量库需要 ALTER TABLE 补列（美化 P1 ④-2 抽屉网格换色）。
          if (from < 2) {
            await m.addColumn(folders, folders.color);
          }
        },
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
  /// [query] 非空时做 LIKE 搜索（标题+内容，v1.0 降级方案 —— PM 评审结论）
  Stream<List<Thought>> watchList({bool archived = false, String? query}) {
    return (select(thoughts)
          ..where((t) {
            var expr = t.deletedAt.isNull() & t.isArchived.equals(archived);
            final q = query?.trim();
            if (q != null && q.isNotEmpty) {
              expr = expr &
                  (t.title.like('%$q%') | t.content.like('%$q%'));
            }
            return expr;
          })
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.pinnedAt),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .watch();
  }

  /// 回收站流：软删随记，按删除时间倒序
  Stream<List<Thought>> watchTrash() {
    return (select(thoughts)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .watch();
  }

  /// 从回收站恢复（清除软删标记）
  Future<void> restoreFromTrash(int thoughtId) async {
    await (update(thoughts)..where((t) => t.id.equals(thoughtId)))
        .write(const ThoughtsCompanion(deletedAt: Value(null)));
  }

  /// 彻底删除单条（回收站内）
  Future<void> purgeThought(int thoughtId) {
    return (delete(thoughts)..where((t) => t.id.equals(thoughtId))).go();
  }

  /// 移动随记到文件夹（null = 移出/收件箱）
  Future<void> moveToFolder(int thoughtId, int? folderId) async {
    await (update(thoughts)..where((t) => t.id.equals(thoughtId)))
        .write(ThoughtsCompanion(
            folderId: Value(folderId),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
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
    // 已有草稿：空内容 → 软删入回收站（Architect P0-A2：硬删绕过回收站，
    // 违背「删除可恢复」心智；且 saveDraft 可能在用户尚未意识到时触发）
    if (trimmed.isEmpty) {
      final row = await (select(thoughts)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row != null && row.deletedAt == null) {
        await (update(thoughts)..where((t) => t.id.equals(id)))
            .write(ThoughtsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now)));
      }
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

  /// 文件夹换色（美化 P1 ④-2）
  Future<void> setFolderColor(int folderId, String color) async {
    await (update(folders)..where((f) => f.id.equals(folderId)))
        .write(FoldersCompanion(
            color: Value(color),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
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

  Future<void> createFolder(String name, {String? color}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(folders).insert(FoldersCompanion.insert(
        name: name.trim(),
        createdAt: now,
        updatedAt: now,
        color: color != null ? Value(color) : const Value.absent()));
  }

  /// 删文件夹：软删 + 随记回收件箱（folder_id 置 NULL，PRD §4.4）
  Future<void> deleteFolder(int folderId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(thoughts)..where((t) => t.folderId.equals(folderId) & t.deletedAt.isNull()))
        .write(const ThoughtsCompanion(folderId: Value(null)));
    await (update(folders)..where((f) => f.id.equals(folderId)))
        .write(FoldersCompanion(deletedAt: Value(now)));
  }

  // ═══════════════ 标签（v1.2：多对多打标 + 过滤 + 管理） ═══════════════

  /// 标签流（未软删，按 sortWeight 升序）
  Stream<List<Tag>> watchTags() {
    return (select(tags)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortWeight), (t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  /// 标签 + 使用中的随记计数（管理页/过滤行展示）
  Stream<List<TagWithCount>> watchTagsWithCount() {
    final countExp = thoughts.id.count();
    final query = select(tags).join([
      leftOuterJoin(thoughtTags, thoughtTags.tagId.equalsExp(tags.id)),
      leftOuterJoin(thoughts,
          thoughts.id.equalsExp(thoughtTags.thoughtId) & thoughts.deletedAt.isNull()),
    ])
      ..addColumns([countExp])
      ..groupBy([tags.id]);
    return query.watch().map((rows) => rows
        .map((r) => TagWithCount(r.readTable(tags), r.read(countExp)!))
        .toList());
  }

  /// 新建标签（重名 NOCASE 拦截，返回 null=重名）
  Future<Tag?> createTag(String name, {String? color}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 20) return null;
    final dup = await (select(tags)
          ..where((t) => t.name.lower().equals(trimmed.toLowerCase()) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (dup != null) return dup; // 幂等：返回已有标签
    final id = await into(tags).insert(TagsCompanion.insert(
        name: trimmed,
        color: Value(color ?? '#4C6FFF'),
        createdAt: DateTime.now().millisecondsSinceEpoch));
    return (select(tags)..where((t) => t.id.equals(id))).getSingle();
  }

  /// 重命名/换色（管理页）
  Future<void> updateTag(int tagId, {String? name, String? color}) async {
    await (update(tags)..where((t) => t.id.equals(tagId)))
        .write(TagsCompanion(name: name == null ? const Value.absent() : Value(name.trim()), color: color == null ? const Value.absent() : Value(color)));
  }

  /// 删标签：软删 + 清掉随记关联（PRD：删除标签不影响随记本身）
  Future<void> deleteTag(int tagId) async {
    await (delete(thoughtTags)..where((tt) => tt.tagId.equals(tagId))).go();
    await (update(tags)..where((t) => t.id.equals(tagId)))
        .write(TagsCompanion(deletedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// 替换式设置某随记的标签集合（详情页 chip 编辑）
  Future<void> setThoughtTags(int thoughtId, List<int> tagIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      await (delete(thoughtTags)..where((tt) => tt.thoughtId.equals(thoughtId))).go();
      for (final tagId in tagIds) {
        await into(thoughtTags).insert(
            ThoughtTagsCompanion.insert(thoughtId: thoughtId, tagId: tagId, createdAt: now),
            mode: InsertMode.insertOrIgnore);
      }
      await (update(thoughts)..where((t) => t.id.equals(thoughtId)))
          .write(ThoughtsCompanion(updatedAt: Value(now)));
    });
  }

  /// 某随记当前的标签集合流（详情页展示）
  Stream<List<Tag>> watchTagsOfThought(int thoughtId) {
    final query = select(tags).join([
      innerJoin(thoughtTags, thoughtTags.tagId.equalsExp(tags.id)),
    ])
      ..where(thoughtTags.thoughtId.equals(thoughtId) & tags.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(tags.id)]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(tags)).toList());
  }

  /// watchList 的标签过滤：传 tagId 时仅显示打了该标签的随记
  Stream<List<Thought>> watchThoughtsByTag(int tagId) {
    final query = select(thoughts).join([
      innerJoin(thoughtTags, thoughtTags.thoughtId.equalsExp(thoughts.id)),
    ])
      ..where(thoughtTags.tagId.equals(tagId) &
          thoughts.deletedAt.isNull() &
          thoughts.isArchived.equals(false))
      ..orderBy([
        OrderingTerm.desc(thoughts.isPinned),
        OrderingTerm.desc(thoughts.updatedAt),
      ]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(thoughts)).toList());
  }
  // ═══════════════ 批量操作（v1.3：多选 → 批量打标/移动/置顶/删除） ═══════════════

  /// 批量追加标签（union 语义：每条随记在现有标签之上追加，不覆盖已有）
  Future<void> batchAppendTags(List<int> thoughtIds, List<int> tagIds) async {
    if (thoughtIds.isEmpty || tagIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      for (final thoughtId in thoughtIds) {
        for (final tagId in tagIds) {
          await into(thoughtTags).insert(
              ThoughtTagsCompanion.insert(
                  thoughtId: thoughtId, tagId: tagId, createdAt: now),
              mode: InsertMode.insertOrIgnore);
        }
        await (update(thoughts)..where((t) => t.id.equals(thoughtId)))
            .write(ThoughtsCompanion(updatedAt: Value(now)));
      }
    });
  }

  /// 批量移动到文件夹（null=收件箱）
  Future<void> batchMoveToFolder(List<int> thoughtIds, int? folderId) async {
    if (thoughtIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(thoughts)..where((t) => t.id.isIn(thoughtIds)))
        .write(ThoughtsCompanion(
            folderId: Value(folderId), updatedAt: Value(now)));
  }

  /// 批量软删 → 回收站
  Future<void> batchSoftDelete(List<int> thoughtIds) async {
    if (thoughtIds.isEmpty) return;
    await (update(thoughts)..where((t) => t.id.isIn(thoughtIds)))
        .write(ThoughtsCompanion(
            deletedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// 批量置顶/取消置顶（目标状态由调用方给定，按钮语义「全部置顶/全部取消」）
  Future<void> batchSetPinned(List<int> thoughtIds, bool pinned) async {
    if (thoughtIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(thoughts)..where((t) => t.id.isIn(thoughtIds))).write(
        ThoughtsCompanion(
            isPinned: Value(pinned),
            pinnedAt: Value(pinned ? now : null)));
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

class TagWithCount {
  final Tag tag;
  final int count;
  TagWithCount(this.tag, this.count);
}
