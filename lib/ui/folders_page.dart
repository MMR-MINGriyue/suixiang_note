import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../main.dart' show appDb;
import '../theme/tokens.dart';

/// Tab 1 文件夹（M4 整理闭环）：
/// 收件箱（未分类计数）+ 文件夹列表（含未软删随记计数）+ 新建/删除
class FoldersPage extends StatelessWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件夹'), backgroundColor: Colors.transparent),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'foldersFAB',
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('新建'),
      ),
      body: StreamBuilder<List<FolderWithCount>>(
        stream: appDb.watchFoldersWithCount(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            children: [
              _InboxRow(),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const _FoldersEmpty()
              else
                ...items.map((f) => _FolderCard(
                      name: f.folder.name,
                      count: f.count,
                      onDelete: () => _confirmDelete(context, f.folder.id, f.folder.name),
                    )),
            ],
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '文件夹名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) appDb.createFolder(name);
              Navigator.pop(ctx);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text('「$name」里的随记不会被删除，会回到收件箱（未分类）。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: T.danger),
            onPressed: () {
              appDb.deleteFolder(id);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 收件箱：folderId 为空的未分类随记
class _InboxRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final stream = appDb.watchList().map((list) =>
        list.where((t) => t.folderId == null).length);
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.inbox_outlined, color: T.brandPrimary),
            title: const Text('收件箱'),
            subtitle: const Text('未分类的随记'),
            trailing: count > 0
                ? Badge(label: Text('$count'), child: const SizedBox.shrink())
                : const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}

class _FolderCard extends StatelessWidget {
  final String name;
  final int count;
  final VoidCallback onDelete;
  const _FolderCard({required this.name, required this.count, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('folder-$name'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: T.danger,
          borderRadius: BorderRadius.circular(T.rCard),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // 删除走确认弹窗，由弹窗回调执行
      },
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.folder_outlined, color: T.brandPrimary),
          title: Text(name),
          trailing: Text('$count 条', style: TextStyle(color: T.inkTertiary)),
        ),
      ),
    );
  }
}

class _FoldersEmpty extends StatelessWidget {
  const _FoldersEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.water_drop_outlined, color: T.stageInspiration, size: 48),
          const SizedBox(height: 12),
          Text('还没有文件夹', style: TextStyle(color: T.inkTertiary)),
          const SizedBox(height: 4),
          Text('点右下角「新建」，把想法归拢到一起',
              style: TextStyle(color: T.inkTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}
