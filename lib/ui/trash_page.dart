import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../theme/tokens.dart';

/// 回收站：软删随记列表，支持恢复 / 彻底删除 / 清空
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
            return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_outline, size: 44, color: T.inkTertiary),
                    const SizedBox(height: 12),
                    Text('回收站是空的',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站'),
        content: const Text('将永久删除全部已删随记，此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: T.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await db.purgeTrash();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('回收站已清空')));
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
    return Card(
      child: ListTile(
        title: Text(thought.title.isEmpty ? '(无标题)' : thought.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('删除于 $timeText',
            style: const TextStyle(fontSize: 11, color: T.inkTertiary)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.restore, color: T.brandPrimary),
            tooltip: '恢复',
            onPressed: () async {
              await db.restoreFromTrash(thought.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('已恢复「${thought.title}」')));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined, color: T.danger),
            tooltip: '彻底删除',
            onPressed: () => _purgeOne(context),
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
    if (ok == true) await db.purgeThought(thought.id);
  }
}
