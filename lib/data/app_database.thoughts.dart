part of 'app_database.dart';

/// 随记域：列表 / 统一信息流 / 归档 / 回收站 / 三态推进 / 草稿落库
mixin _AppDatabaseThoughts on _$AppDatabase {
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

  /// 彻底删除单条（回收站内）。
  ///
  /// 架构复审 P0-1：thoughts 被 thoughtTags / reminders / attachments /
  /// thoughtLinks 四张子表引用，只删主表会留下孤儿行——FK 开启时直接抛约束
  /// 异常，FK 关闭时孤儿行被备份导出、恢复回灌时整事务回滚。所以按
  /// 「子表→主表」显式级联，且整段包事务，避免中途失败留下半截数据。
  Future<void> purgeThought(int thoughtId) {
    return transaction(() async {
      await (delete(thoughtLinks)
            ..where((l) =>
                l.fromId.equals(thoughtId) | l.toId.equals(thoughtId)))
          .go();
      await (delete(thoughtTags)..where((t) => t.thoughtId.equals(thoughtId)))
          .go();
      await (delete(reminders)..where((r) => r.thoughtId.equals(thoughtId)))
          .go();
      await (delete(attachments)..where((a) => a.thoughtId.equals(thoughtId)))
          .go();
      await (delete(thoughts)..where((t) => t.id.equals(thoughtId))).go();
    });
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
  ///
  /// 返回落定的新阶段，供调用方做反馈（SnackBar 文案、触觉、撤销条）；
  /// 原来返回 void，界面只能靠猜「应该变了吧」。
  /// 读-算-写包在事务里（架构评审 D3）：否则两个入口同时落态会互相覆盖。
  Future<Stage?> advanceStage(int thoughtId) {
    return transaction(() async {
      final all = await _orderedStages();
      if (all.isEmpty) return null;
      final thought = await _thoughtById(thoughtId);
      if (thought == null) return null;
      final next = nextStageOf(all, thought.stageId);
      if (next == null) return null;
      await _writeStage(thoughtId, next);
      return next;
    });
  }

  /// 退回上一态（长按 / 菜单用）。
  ///
  /// 单向循环逼得用户「已完成 → 灵感 → 推进中」绕两圈才能退一步，
  /// UX 评审 B3 点名过；但这是个人工具，不是工作流引擎，
  /// 与其做拖动排序不如把「反方向」直接给出来。
  Future<Stage?> previousStage(int thoughtId) {
    return transaction(() async {
      final all = await _orderedStages();
      if (all.isEmpty) return null;
      final thought = await _thoughtById(thoughtId);
      if (thought == null) return null;
      final prev = prevStageOf(all, thought.stageId);
      if (prev == null) return null;
      await _writeStage(thoughtId, prev);
      return prev;
    });
  }

  /// 直接落到指定态（三态菜单 / 批量操作 / 撤销用）。
  ///
  /// 与 advanceStage 的区别：不猜「下一个是谁」，由调用方给定目标，
  /// 因此同一条随记可以一步跳到「已完成」，也可以一步退回「灵感」。
  /// [stageId] 不存在时返回 null 且不写库（脏输入不落库）。
  Future<Stage?> setStage(int thoughtId, int stageId) {
    return transaction(() async {
      final all = await _orderedStages();
      final target = stageById(all, stageId);
      if (target == null || target.id != stageId) return null;
      final thought = await _thoughtById(thoughtId);
      if (thought == null) return null;
      if (thought.stageId == stageId) return target; // 同态不写库、不更新 updatedAt
      await _writeStage(thoughtId, target);
      return target;
    });
  }

  /// 批量落态；返回实际写入条数（同态被跳过的也计入，语义为「处理了」）
  Future<int> batchSetStage(List<int> thoughtIds, int stageId) async {
    if (thoughtIds.isEmpty) return 0;
    final all = await _orderedStages();
    final target = stageById(all, stageId);
    if (target == null || target.id != stageId) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(thoughts)..where((t) => t.id.isIn(thoughtIds))).write(
      ThoughtsCompanion(
        stageId: Value(target.id),
        updatedAt: Value(now),
        completedAt: Value(target.kind == 'done' ? now : null),
        stageChangedAt: Value(now),
      ),
    );
    return thoughtIds.length;
  }

  /// 阶段全序（position 升序）；推进相关方法共用，避免各写一份 orderBy
  Future<List<Stage>> _orderedStages() =>
      (select(stages)..orderBy([(s) => OrderingTerm.asc(s.position)])).get();

  Future<Thought?> _thoughtById(int thoughtId) =>
      (select(thoughts)..where((t) => t.id.equals(thoughtId))).getSingleOrNull();

  /// 落态写盘统一入口：completedAt 只在三态里那个 kind=='done' 的态上存在，
  /// 离开它即清空——否则「3 天前完成」会跟着一条又变回灵感的随记跑。
  /// stageChangedAt 每次都刷新：它记录「进入当前这一步」的时刻，
  /// 正是「在推进中卡了 N 天」这句话的唯一数据来源。
  Future<void> _writeStage(int thoughtId, Stage target) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(thoughts)..where((t) => t.id.equals(thoughtId))).write(
      ThoughtsCompanion(
        stageId: Value(target.id),
        updatedAt: Value(now),
        completedAt: Value(target.kind == 'done' ? now : null),
        stageChangedAt: Value(now),
      ),
    );
  }

  /// 置顶/取消置顶（v1.0 仅置顶，归档暂缓 —— PM 结论）
  /// 读-改-写包事务（架构评审 D3）：否则连点两次可能读到同一份旧状态。
  Future<void> togglePin(int thoughtId) {
    return transaction(() async {
      final thought =
          await (select(thoughts)..where((t) => t.id.equals(thoughtId)))
              .getSingle();
      final now = DateTime.now().millisecondsSinceEpoch;
      await (update(thoughts)..where((t) => t.id.equals(thoughtId)))
          .write(ThoughtsCompanion(
        isPinned: Value(!thought.isPinned),
        pinnedAt: Value(thought.isPinned ? null : now),
      ));
    });
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
        wordCount: Value(countWords(trimmed)),
        createdAt: now,
        updatedAt: now,
        stageChangedAt: Value(now), // 新建即「进入灵感」的时刻
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
      wordCount: Value(countWords(trimmed)),
      updatedAt: Value(now),
    ));
    return id;
  }

  /// 深链/通知点击后按 id 取随记
  Future<Thought?> getThought(int thoughtId) {
    return (select(thoughts)..where((t) => t.id.equals(thoughtId)))
        .getSingleOrNull();
  }

  /// 清空回收站：物理删除已软删随记，连同四张子表的关联行一起。
  ///
  /// 架构复审 P0-1：先取出全部待删 id，再用 isIn(ids) 批量级联；整段事务，
  /// 返回实际删掉的主表行数。子表顺序与 [purgeThought] 一致。
  Future<int> purgeTrash() {
    return transaction(() async {
      final rows = await (select(thoughts)
            ..where((t) => t.deletedAt.isNotNull()))
          .get();
      if (rows.isEmpty) return 0;
      final ids = rows.map((t) => t.id).toList();
      await (delete(thoughtLinks)
            ..where((l) => l.fromId.isIn(ids) | l.toId.isIn(ids)))
          .go();
      await (delete(thoughtTags)..where((t) => t.thoughtId.isIn(ids))).go();
      await (delete(reminders)..where((r) => r.thoughtId.isIn(ids))).go();
      await (delete(attachments)..where((a) => a.thoughtId.isIn(ids))).go();
      return (delete(thoughts)..where((t) => t.id.isIn(ids))).go();
    });
  }
}
