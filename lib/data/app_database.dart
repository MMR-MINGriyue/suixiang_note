import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/format.dart';
import '../core/pinyin_search.dart';
import 'tables.dart';

part 'app_database.g.dart';
part 'app_database.thoughts.dart';
part 'app_database.folders_tags.dart';
part 'app_database.reminders.dart';

/// 随想随记 本地数据库（drift + sqlite3）
/// schemaVersion 从 1 起；结构变更必须步进并先做 JSON 快照（PRD §6.4）。
///
/// 业务方法按域拆在三个 part 文件里（架构评审 D1，本文件只留 schema 骨架）：
/// - [_AppDatabaseThoughts]   随记：列表/归档/回收站/三态/草稿
/// - [_AppDatabaseFoldersTags] 文件夹 / 标签 / 批量操作
/// - [_AppDatabaseReminders]   提醒 / 每日回顾 / 设置 KV / 关联图谱
@DriftDatabase(
  tables: [Folders, Stages, Thoughts, Tags, ThoughtTags, Reminders, Attachments, Settings, ThoughtLinks],
)
class AppDatabase extends _$AppDatabase
    with _AppDatabaseThoughts, _AppDatabaseFoldersTags, _AppDatabaseReminders {
  AppDatabase() : super(driftDatabase(name: 'suixiang_note'));

  /// 测试用：注入内存执行器，避免多个用例共享同一个磁盘文件互相污染
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2：folders 加 color 列已有默认值（withDefault），drift 建表即含列，
          // 但存量库需要 ALTER TABLE 补列（美化 P1 ④-2 抽屉网格换色）。
          if (from < 2) {
            await m.addColumn(folders, folders.color);
          }
          // v3：thoughts 加 stageChangedAt（进入当前阶段时刻）。
          // 补列后回填：老数据没有这个信息，只能用 updatedAt 近似——
          // 宁可给一个偏差值，也不要让「卡了几天」对全部存量显示空白。
          if (from < 3) {
            await m.addColumn(thoughts, thoughts.stageChangedAt);
            await customStatement(
                'UPDATE thoughts SET stage_changed_at = updated_at WHERE stage_changed_at IS NULL');
          }
          // v4：关联表（thought_links）。纯新增表，不触碰已有数据。
          if (from < 4) {
            await m.createTable(thoughtLinks);
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
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_links_from ON thought_links(from_id) WHERE deleted_at IS NULL');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_links_to ON thought_links(to_id) WHERE deleted_at IS NULL');

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
}

/// 一条关联 + 对端随记 + 方向
class LinkedThought {
  final ThoughtLink link;
  final Thought other;

  /// true = 这条关联是从当前随记指向对方（我 → 对端）
  final bool outgoing;
  LinkedThought({required this.link, required this.other, required this.outgoing});

  String get kindLabel => switch (link.kind) {
        'depends' => outgoing ? '依赖' : '被依赖',
        'parent' => outgoing ? '属于' : '包含',
        _ => '相关',
      };
}

/// 图谱数据快照
class GraphSnapshot {
  final List<Thought> nodes;
  final List<ThoughtLink> edges;
  GraphSnapshot({required this.nodes, required this.edges});

  bool get isEmpty => nodes.isEmpty;
  int get edgeCount => edges.length;

  /// 孤立节点数：如实告诉用户「图谱里有多少条还没连上」，
  /// 否则一张全是散点的图会让人以为功能坏了。
  int get isolatedCount {
    final touched = <int>{};
    for (final e in edges) {
      touched.add(e.fromId);
      touched.add(e.toId);
    }
    return nodes.where((n) => !touched.contains(n.id)).length;
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
