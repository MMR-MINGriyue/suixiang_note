part of 'app_database.dart';

/// 提醒 / 每日回顾 / 设置 KV / 关联图谱域
mixin _AppDatabaseReminders on _$AppDatabase, _AppDatabaseFoldersTags {
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
    final unit = switch (repeatRule) {
      'daily' => 'day',
      'weekly' => 'week',
      'monthly' => 'month',
      _ => null,
    };
    // 删旧 + 插新同一事务（架构评审 D3 同族）：一条随记只允许一个闹钟，
    // 中途失败不能出现「两个 active」或「零个 active」。
    return transaction(() async {
      await (delete(reminders)
            ..where((r) =>
                r.thoughtId.equals(thoughtId) & r.status.equals('active')))
          .go();
      return into(reminders).insert(RemindersCompanion.insert(
          thoughtId: thoughtId,
          remindAt: remindAt,
          repeatRule: Value(repeatRule),
          repeatInterval: Value(unit == null ? null : 1),
          repeatUnit: Value(unit),
          createdAt: now));
    });
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

  /// 重复提醒弹出后：推进 DB 侧的 remindAt，同时记 lastFiredAt。
  ///
  /// 架构复审 P0-2：原来只写 lastFiredAt，remindAt 永远停在首次设定的过去
  /// 时刻，导致 takeDueReminders 每次冷启动/回前台都把它判为到期、反复弹。
  /// 原生 AlarmManager 与 DB 是两套时钟，必须对账：这里把下一次触发时刻
  /// 按 nextRemindAtAfter 推进到严格晚于现在，与 Kotlin 的日历规则对齐。
  /// 若规则不可续期（或 512 步仍未跨过现在）则降级为 fired，绝不把
  /// active + 过去时刻的行留在库里。
  Future<void> markReminderFiredKeepActive(int reminderId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = await (select(reminders)
          ..where((r) => r.id.equals(reminderId)))
        .getSingleOrNull();
    if (row == null) return;
    final next = nextRemindAtAfter(row.remindAt, row.repeatRule, now);
    await (update(reminders)..where((r) => r.id.equals(reminderId))).write(
        RemindersCompanion(
      lastFiredAt: Value(now),
      remindAt: next != null ? Value(next) : const Value.absent(),
      status: next != null ? const Value.absent() : const Value('fired'),
    ));
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

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: Value(value)));
  }

  // ═══════════════ 关联：随记之间的有向边（v4） ═══════════════

  /// 双向取某条随记的全部关联。
  ///
  /// 为什么查询要双向：关联本身有方向（A 依赖 B ≠ B 依赖 A），但**查看时**
  /// 用户只想知道「这条跟谁有关」，两边都要列出来，并且在 UI 上用
  /// [LinkedThought.outgoing] 标明箭头指向，避免「我明明建的是依赖，怎么显示成被依赖」。
  Stream<List<LinkedThought>> watchLinksOf(int thoughtId) {
    return (select(thoughtLinks)
          ..where((l) =>
              l.deletedAt.isNull() &
              (l.fromId.equals(thoughtId) | l.toId.equals(thoughtId))))
        .watch()
        .asyncMap((links) async {
      final out = <LinkedThought>[];
      for (final l in links) {
        final otherId = l.fromId == thoughtId ? l.toId : l.fromId;
        final other = await getThought(otherId);
        // 对端已删（回收站/物理删）就不显示，避免点进去是空白
        if (other == null || other.deletedAt != null) continue;
        out.add(LinkedThought(
          link: l,
          other: other,
          outgoing: l.fromId == thoughtId,
        ));
      }
      return out;
    });
  }

  /// 建立关联。已存在同向同类边时不重复插入（UNIQUE 约束兜底）。
  /// 返回 false 表示 this 与 other 相同、或对端不存在。
  Future<bool> linkThoughts(int fromId, int toId, {String kind = 'related'}) async {
    if (fromId == toId) return false;
    final target = await getThought(toId);
    if (target == null || target.deletedAt != null) return false;
    await into(thoughtLinks).insert(
      ThoughtLinksCompanion.insert(
        fromId: fromId,
        toId: toId,
        kind: Value(kind),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return true;
  }

  Future<void> unlinkThought(int linkId) async {
    await (update(thoughtLinks)..where((l) => l.id.equals(linkId)))
        .write(ThoughtLinksCompanion(
      deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// 图谱快照：一次取全部节点与边，供可视化页做布局。
  ///
  /// 为什么不给「每个节点一条流」：力导向布局要全局迭代，逐点订阅会
  /// 让布局在每次局部变化时整体跳一次。图谱本来就是「看整体」的视图，
  /// 一次性取快照更稳，也更省订阅。
  Future<GraphSnapshot> loadGraph({int maxNodes = 300}) async {
    final nodes = await (select(thoughts)
          ..where((t) => t.deletedAt.isNull() & t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(maxNodes))
        .get();
    final ids = nodes.map((n) => n.id).toSet();

    final edges = await (select(thoughtLinks)
          ..where((l) => l.deletedAt.isNull()))
        .get();

    final kept = edges
        .where((e) => ids.contains(e.fromId) && ids.contains(e.toId))
        .toList(growable: false);
    return GraphSnapshot(nodes: nodes, edges: kept);
  }
}
