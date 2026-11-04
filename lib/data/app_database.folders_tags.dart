part of 'app_database.dart';

/// 文件夹 / 标签 / 批量操作域
mixin _AppDatabaseFoldersTags on _$AppDatabase, _AppDatabaseThoughts {
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
  /// 两步同事务（架构评审 D3 同族）：否则中途失败会出现
  /// 「文件夹已删但随记还指向它」的悬空引用。
  Future<void> deleteFolder(int folderId) {
    return transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (update(thoughts)
              ..where((t) =>
                  t.folderId.equals(folderId) & t.deletedAt.isNull()))
          .write(const ThoughtsCompanion(folderId: Value(null)));
      await (update(folders)..where((f) => f.id.equals(folderId)))
          .write(FoldersCompanion(deletedAt: Value(now)));
    });
  }

  /// 文件夹换色（美化 P1 ④-2）
  Future<void> setFolderColor(int folderId, String color) async {
    await (update(folders)..where((f) => f.id.equals(folderId)))
        .write(FoldersCompanion(
            color: Value(color),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
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
  /// 两步写在同一事务里（架构评审 D3 同族）：否则中途失败会留下
  /// 「标签已删但随记还挂着它」的悬空关联。
  Future<void> deleteTag(int tagId) {
    return transaction(() async {
      await (delete(thoughtTags)..where((tt) => tt.tagId.equals(tagId))).go();
      await (update(tags)..where((t) => t.id.equals(tagId))).write(
          TagsCompanion(
              deletedAt: Value(DateTime.now().millisecondsSinceEpoch)));
    });
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
    return watchFeed(tagId: tagId);
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
}
