import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/pinyin_search.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// 随想随记 本地数据库（drift + sqlite3）
/// schemaVersion 从 1 起；结构变更必须步进并先做 JSON 快照（PRD §6.4）。
@DriftDatabase(
  tables: [Folders, Stages, Thoughts, Tags, ThoughtTags, Reminders, Attachments, Settings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'suixiang_note'));

  /// 测试用：注入内存执行器，避免多个用例共享同一个磁盘文件互相污染
  AppDatabase.forTesting(super.executor);

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
            final q = _escapeLike(query);
            if (q != null) {
              expr = expr & _matches(t, q);
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

  /// LIKE 模式转义：用户输入的 `%` `_` `\` 必须当普通字符，否则搜「100%」会
  /// 变成通配匹配全库（架构评审 D2）。返回带 `%…%` 的模式串，空查询返回 null。
  static String? _escapeLike(String? raw) {
    final q = raw?.trim();
    if (q == null || q.isEmpty) return null;
    final escaped =
        q.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
    return '%$escaped%';
  }

  /// 标题或正文命中（配合 _escapeLike 生成的模式串）
  static Expression<bool> _matches($ThoughtsTable t, String pattern) =>
      t.title.like(pattern, escapeChar: '\\') |
      t.content.like(pattern, escapeChar: '\\');

  /// 统一的信息流：搜索 / 标签 / 状态三种过滤正交组合，单流驱动（首页只用这一个）
  ///
  /// 之前首页按「有无标签过滤」分成两条 StreamBuilder 分支，状态过滤一加就变成
  /// 2×N 分支；收成一个方法后，任意组合都只有一条流，状态也少一份。
  ///
  /// **搜索为什么全部放到内存里做**：v1.8 起搜索要支持拼音首字母（「sg」找
  /// 「手工」），而 SQLite 的 LIKE 只认字面。SQL 层先按归档/软删/标签收窄，
  /// 再由 [PinyinSearch.matchesAny] 统一判定字面 + 首字母。这样还顺手消灭了一个
  /// 老隐患：原来无标签走 SQL LIKE、有标签走 Dart `contains`，两条路径大小写与
  /// 通配符语义并不一致，同一次搜索在两种筛选下结果会不同。
  Stream<List<Thought>> watchFeed({
    bool archived = false,
    String? query,
    int? tagId,
    int? stageId,
  }) {
    final q = query?.trim() ?? '';

    if (tagId == null) {
      return (select(thoughts)
            ..where((t) =>
                t.deletedAt.isNull() & t.isArchived.equals(archived))
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPinned),
              (t) => OrderingTerm.desc(t.pinnedAt),
              (t) => OrderingTerm.desc(t.updatedAt),
            ]))
          .watch()
          .map((list) => _narrow(list, q, stageId));
    }

    // 有标签过滤 → inner join；join 查询的 orderBy 收 List<OrderingTerm>
    final joinQuery = select(thoughts).join([
      innerJoin(thoughtTags, thoughtTags.thoughtId.equalsExp(thoughts.id)),
    ])
      ..where(thoughtTags.tagId.equals(tagId) &
          thoughts.deletedAt.isNull() &
          thoughts.isArchived.equals(archived))
      ..orderBy([
        OrderingTerm.desc(thoughts.isPinned),
        OrderingTerm.desc(thoughts.pinnedAt),
        OrderingTerm.desc(thoughts.updatedAt),
      ]);
    return joinQuery.watch().map((rows) =>
        _narrow(rows.map((r) => r.readTable(thoughts)).toList(), q, stageId));
  }

  /// 状态 + 查询的内存收窄（两条分支共用，保证语义一致）
  static List<Thought> _narrow(List<Thought> list, String query, int? stageId) {
    if (stageId == null && query.isEmpty) return list;
    return list.where((t) {
      if (stageId != null && t.stageId != stageId) return false;
      if (query.isEmpty) return true;
      return PinyinSearch.matchesAny(t.title, t.content, query);
    }).toList();
  }

  /// 归档流：isArchived = true 且未删（「不做了但别删」的归处，区别于回收站）
  ///
  /// [query] 与主信息流同一套判定（[PinyinSearch]），否则在归档视图里搜索框
  /// 依然可见却毫无反应——那比没有搜索框更让人困惑。
  Stream<List<Thought>> watchArchived({int? stageId, String? query}) {
    final q = query?.trim() ?? '';
    return (select(thoughts)
          ..where((t) {
            var expr = t.deletedAt.isNull() & t.isArchived.equals(true);
            if (stageId != null) expr = expr & t.stageId.equals(stageId);
            return expr;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch()
        .map((list) => _narrow(list, q, null));
  }

  /// 归档 / 取消归档。归档时顺手清置顶：归档意味着「不再关心」，
  /// 保留置顶会让它继续占用置顶额度且语义矛盾。
  Future<void> setArchived(int thoughtId, bool archived) async {
    await (update(thoughts)..where((t) => t.id.equals(thoughtId))).write(
        _archiveCompanion(archived, DateTime.now().millisecondsSinceEpoch));
  }

  /// 批量归档 / 取消归档
  Future<void> batchSetArchived(List<int> thoughtIds, bool archived) async {
    if (thoughtIds.isEmpty) return;
    await (update(thoughts)..where((t) => t.id.isIn(thoughtIds))).write(
        _archiveCompanion(archived, DateTime.now().millisecondsSinceEpoch));
  }

  /// 归档写盘统一入口：归档时同步清置顶，取消归档时不动置顶字段
  ThoughtsCompanion _archiveCompanion(bool archived, int now) {
    return ThoughtsCompanion(
      isArchived: Value(archived),
      isPinned: archived ? const Value(false) : const Value.absent(),
      pinnedAt: archived ? const Value(null) : const Value.absent(),
      updatedAt: Value(now),
    );
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

  // ═══════════════ 提醒（v1.6，竞品分析短板②：字段早已齐全但 UI 零实现） ═══════════════

  /// 一条随记最多一个 active 提醒 —— 这是刻意的产品约束：
  /// 同一条想法挂多个闹钟，用户自己都记不清哪个会响，UI 也必然变复杂。
  Stream<List<Reminder>> watchActiveReminderOf(int thoughtId) {
    return (select(reminders)
          ..where((r) =>
              r.thoughtId.equals(thoughtId) & r.status.equals('active'))
          ..orderBy([(r) => OrderingTerm.asc(r.remindAt)]))
        .watch();
  }

  /// 全部待触发提醒（含随记正文，供「我的」页汇总和启动对账）
  Stream<List<ReminderWithThought>> watchUpcomingReminders() {
    final query = select(reminders).join([
      innerJoin(thoughts, thoughts.id.equalsExp(reminders.thoughtId)),
    ])
      ..where(reminders.status.equals('active') & thoughts.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(reminders.remindAt)]);
    return query.watch().map((rows) => rows
        .map((r) => ReminderWithThought(
            r.readTable(reminders), r.readTable(thoughts)))
        .toList());
  }

  /// 已到期但还没被系统通知过的提醒（启动/回前台时补提示，防 Doze 静默丢弃）
  Future<List<ReminderWithThought>> takeDueReminders({int? now}) async {
    final ts = now ?? DateTime.now().millisecondsSinceEpoch;
    final query = select(reminders).join([
      innerJoin(thoughts, thoughts.id.equalsExp(reminders.thoughtId)),
    ])
      ..where(reminders.status.equals('active') &
          reminders.remindAt.isSmallerOrEqualValue(ts) &
          thoughts.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(reminders.remindAt)]);
    final rows = await query.get();
    return rows
        .map((r) =>
            ReminderWithThought(r.readTable(reminders), r.readTable(thoughts)))
        .toList();
  }

  /// 落库一条提醒（同一条随记的旧 active 提醒先清掉，避免叠加多个闹钟）
  Future<int> upsertReminder({
    required int thoughtId,
    required int remindAt,
    String repeatRule = 'once',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (delete(reminders)
          ..where((r) =>
              r.thoughtId.equals(thoughtId) & r.status.equals('active')))
        .go();
    final unit = switch (repeatRule) {
      'daily' => 'day',
      'weekly' => 'week',
      'monthly' => 'month',
      _ => null,
    };
    return into(reminders).insert(RemindersCompanion.insert(
        thoughtId: thoughtId,
        remindAt: remindAt,
        repeatRule: Value(repeatRule),
        repeatInterval: Value(unit == null ? null : 1),
        repeatUnit: Value(unit),
        createdAt: now));
  }

  Future<void> deleteReminder(int reminderId) async {
    await (delete(reminders)..where((r) => r.id.equals(reminderId))).go();
  }

  /// 提醒已弹出：置为 fired 并记 lastFiredAt（保留行便于「我的」页展示历史）
  Future<void> markReminderFired(int reminderId) async {
    await (update(reminders)..where((r) => r.id.equals(reminderId))).write(
        RemindersCompanion(
            status: const Value('fired'),
            lastFiredAt:
                Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// 非重复提醒弹出后关闭；重复提醒由原生侧自己续期，这里只记 lastFiredAt
  Future<void> markReminderFiredKeepActive(int reminderId) async {
    await (update(reminders)..where((r) => r.id.equals(reminderId))).write(
        RemindersCompanion(
            lastFiredAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// 启动对账用：一次性取所有 active 提醒的完整信息（含正文首页行做通知标题）
  Future<List<ReminderWithThought>> snapshotActiveReminders() async {
    final query = select(reminders).join([
      innerJoin(thoughts, thoughts.id.equalsExp(reminders.thoughtId)),
    ])
      ..where(reminders.status.equals('active') & thoughts.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(reminders.remindAt)]);
    final rows = await query.get();
    return rows
        .map((r) =>
            ReminderWithThought(r.readTable(reminders), r.readTable(thoughts)))
        .toList();
  }

  /// 深链/通知点击后按 id 取随记
  Future<Thought?> getThought(int thoughtId) {
    return (select(thoughts)..where((t) => t.id.equals(thoughtId)))
        .getSingleOrNull();
  }

  // ═══════════════ 每日回顾（v1.7，竞品分析短板③：flomo 的粘性核心） ═══════════════

  /// 挑今天的回顾候选。
  ///
  /// 三个设计决策，都不是随意的：
  /// 1. **不纯随机**。几十条的规模下纯随机必然连续几天抽到同几条，而回顾的价值
  ///    恰恰在于把沉底的东西翻出来。所以先按 `updatedAt` 升序取一个 count×5 的
  ///    池子 —— 池子本身已经偏向「最久没碰过的」。
  /// 2. **用日期做随机种子**。同一天多次打开必须看到同一批，否则「回顾」会退化成
  ///    「刷新抽奖」，用户会一直点换一批直到抽到有意思的，反而不回顾了。
  /// 3. **排除今天创建的**。早上刚记的东西还在眼前，不需要回顾；而且它会让
  ///    「N 天前」的时间标注失去意义。
  Future<List<Thought>> pickDailyReview({
    int count = 3,
    DateTime? day,
    int rotation = 0,
  }) async {
    final now = day ?? DateTime.now();
    final dayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final pool = await (select(thoughts)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.isArchived.equals(false) &
              t.createdAt.isSmallerThanValue(dayStart))
          ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)])
          ..limit(count * 5))
        .get();

    // 池子本来就不够一屏：按原顺序给，不走打乱（否则「换一批」看着换过其实没变）
    if (pool.length <= count) return pool;

    // 日期 × 轮次 → 稳定种子；rotation 每点一次「换一批」自增
    final seed =
        now.year * 10000 + now.month * 100 + now.day + rotation * 7919;
    final shuffled = List<Thought>.of(pool)..shuffle(Random(seed));
    return shuffled.take(count).toList();
  }

  /// 今天是否已经回顾过（读 settings 的 last_review_at 与此前日期比对）
  Future<bool> reviewedToday({DateTime? now}) async {
    final raw = await getSetting('last_review_at');
    final ts = int.tryParse(raw ?? '');
    if (ts == null) return false;
    final t = now ?? DateTime.now();
    final last = DateTime.fromMillisecondsSinceEpoch(ts);
    return last.year == t.year && last.month == t.month && last.day == t.day;
  }

  Future<void> markReviewedNow() =>
      setSetting('last_review_at', '${DateTime.now().millisecondsSinceEpoch}');

  /// 回顾页顶部的一行事实：库里有多少条、多少条已完成
  Future<({int total, int done, int oldestDays})> reviewStats() async {
    final all = await (select(thoughts)
          ..where((t) => t.deletedAt.isNull() & t.isArchived.equals(false)))
        .get();
    final done = all.where((t) => t.stageId == 3).length;
    final oldest = all.isEmpty
        ? 0
        : DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(
                all.map((t) => t.createdAt).reduce((a, b) => a < b ? a : b)))
            .inDays;
    return (total: all.length, done: done, oldestDays: oldest);
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

/// 提醒 + 它指向的随记（通知标题要显示随记内容，所以总是一起取）
class ReminderWithThought {
  final Reminder reminder;
  final Thought thought;
  ReminderWithThought(this.reminder, this.thought);

  /// 通知标题：随记首行，超长截断（标题在通知栏只有一行可见宽度）
  String get headline {
    final first = thought.title.trim().isEmpty
        ? thought.content.trim()
        : thought.title.trim();
    final line = first.split('\n').first.trim();
    if (line.isEmpty) return '随想随记';
    return line.length > 40 ? '${line.substring(0, 40)}…' : line;
  }

  bool get isRepeating => reminder.repeatRule != 'once';
}
