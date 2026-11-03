import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../theme/tokens.dart';

/// 标签管理页：列表（含使用计数）/ 重命名 / 换色 / 删除
/// 入口：「我的」页 → 标签管理
class TagManagePage extends StatefulWidget {
  final AppDatabase db;
  const TagManagePage({super.key, required this.db});

  @override
  State<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends State<TagManagePage> {
  static const _palette = [
    '#4C6FFF', '#2FBF8F', '#E5484D', '#F5A524', '#8B5CF6',
    '#06B6D4', '#EC4899', '#84CC16',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('标签管理')),
      body: StreamBuilder<List<TagWithCount>>(
        stream: widget.db.watchTagsWithCount(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tags = snap.data!;
          if (tags.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.label_off_outlined, size: 44, color: T.inkTertiary),
                const SizedBox(height: 12),
                const Text('还没有标签',
                    style: TextStyle(color: T.inkSecondary)),
                const SizedBox(height: 4),
                const Text('在随记详情页点「标签」图标创建',
                    style: TextStyle(fontSize: 12, color: T.inkTertiary)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: tags.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = tags[i];
              final color = Color(int.parse(item.tag.color.replaceFirst('#', '0xFF')));
              return Card(
                child: ListTile(
                  leading: Icon(Icons.label, color: color),
                  title: Text(item.tag.name),
                  subtitle: Text('${item.count} 条随记',
                      style: const TextStyle(fontSize: 12, color: T.inkTertiary)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') _rename(item.tag);
                      if (v == 'color') _pickColor(item.tag);
                      if (v == 'delete') _delete(item.tag);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: ListTile(
                          leading: Icon(Icons.edit_outlined), title: Text('重命名'),
                          contentPadding: EdgeInsets.zero)),
                      PopupMenuItem(value: 'color', child: ListTile(
                          leading: Icon(Icons.palette_outlined), title: Text('换颜色'),
                          contentPadding: EdgeInsets.zero)),
                      PopupMenuItem(value: 'delete', child: ListTile(
                          leading: Icon(Icons.delete_outline, color: T.danger),
                          title: Text('删除', style: TextStyle(color: T.danger)),
                          contentPadding: EdgeInsets.zero)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _rename(Tag tag) async {
    final ctrl = TextEditingController(text: tag.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名标签'),
        content: TextField(
          controller: ctrl,
          maxLength: 20,
          autofocus: true,
          decoration: const InputDecoration(hintText: '标签名（≤20 字）'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != tag.name) {
      await widget.db.updateTag(tag.id, name: name);
    }
  }

  Future<void> _pickColor(Tag tag) async {
    final color = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择颜色'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _palette
              .map((hex) => InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.pop(ctx, hex),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: hex == tag.color
                            ? Border.all(width: 3, color: T.inkPrimary)
                            : null,
                      ),
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
    if (color != null) await widget.db.updateTag(tag.id, color: color);
  }

  Future<void> _delete(Tag tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('删除「${tag.name}」后，随记本身不受影响，只是不再带这个标签。'),
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
    if (ok == true) await widget.db.deleteTag(tag.id);
  }
}
