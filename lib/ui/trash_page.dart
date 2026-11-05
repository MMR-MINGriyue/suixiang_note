import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../theme/tokens.dart';
import 'widgets/app_feedback.dart';
import 'widgets/empty_state.dart';

/// 回收站：软删随记列表，支持恢复 / 彻底删除 / 清空。
/// 美化 P2-⑥：恢复主按钮化、彻底删除收进菜单、删除时长纯陈述（PRD 无自动清除机制）。
class TrashPage extends StatelessWidget {
  final AppDatabase db;
  const TrashPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            tooltip: '清空回收站',
            onPressed: () => _purgeAll(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Thought>>(
        stream: db.watchTrash(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const EmptyState(
              illus: 'empty_trash.png',
              title: '都处理完了，纸面很干净',
              subtitle: '删除的随记会先在这里停留，随时可以恢复',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(T.pagePad, 8, T.pagePad, 32),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _TrashCard(db: db, thought: list[i]),
          );
        },
      ),
    );
  }

  Future<void> _purgeAll(BuildContext context) async {
    final ok = await AppFeedback.confirmDanger(
      context,
      title: '清空回收站',
      content: '将永久删除全部已删随记，此操作不可撤销。',
      confirmLabel: '清空',
    );
    if (ok && context.mounted) {
      final count = await db.purgeTrash();
      if (context.mounted) {
        AppFeedback.success(context, '回收站已清空 · $count 条');
      }
    }
  }
}

class _TrashCard extends StatelessWidget {
  final AppDatabase db;
  final Thought thought;
  const _TrashCard({required this.db, required this.thought});

  @override
  Widget build(BuildContext context) {
    final deletedAt = DateTime.fromMillisecondsSinceEpoch(thought.deletedAt ?? 0);
    final timeText = DateFormat('MM/dd HH:mm').format(deletedAt);
    final days = DateTime.now().difference(deletedAt).inDays;
    // 删除 30 天以上的行加 warning 描边：滞留最久的对象一眼可辨（纯陈述，无自动清除规则）
    final stale = days >= 30;
    final borderColor = Theme.of(context).dividerColor;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.rCard),
        side: BorderSide(
            color: stale ? T.warning : borderColor, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        title: Text(thought.title.isEmpty ? '(无标题)' : thought.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '删除于 $timeText · 已删除 $days 天',
            style: TextStyle(
                fontSize: 11, color: stale ? T.warning : T.inkTertiary)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          // 恢复为主按钮（tonal），彻底删除收进菜单，避免误触
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 34)),
            onPressed: () async {
              await db.restoreFromTrash(thought.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('已恢复「${thought.title}」')));
              }
            },
            child: const Text('恢复', style: TextStyle(fontSize: 13)),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (v) {
              if (v == 'purge') _purgeOne(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'purge', child: ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: T.danger),
                  title: Text('彻底删除', style: TextStyle(color: T.danger)),
                  contentPadding: EdgeInsets.zero)),
            ],
          ),
        ]),
      ),
    );
  }

  Future<void> _purgeOne(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('彻底删除'),
        content: Text('「${thought.title}」将被永久删除，此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: T.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await db.purgeThought(thought.id);
      if (context.mounted) {
        AppFeedback.success(context, '「${thought.title}」已彻底删除');
      }
    }
  }
}
