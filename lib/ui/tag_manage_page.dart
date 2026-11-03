import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../theme/tokens.dart';
import 'widgets/color_palette.dart';

/// 标签管理页：色卡列表（含使用计数）/ 重命名 / 换色 / 删除。
/// 美化 P2-⑤：32×32 色卡 leading、长按换色 bottomSheet 带实时预览、未使用标签灰化分区。
class TagManagePage extends StatefulWidget {
  final AppDatabase db;
  const TagManagePage({super.key, required this.db});

  @override
  State<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends State<TagManagePage> {
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
          // 在用标签按计数降序，未使用（计数 0）沉底灰化
          final used = tags.where((t) => t.count > 0).toList()
            ..sort((a, b) => b.count.compareTo(a.count));
          final unused = tags.where((t) => t.count == 0).toList();
          final items = <Widget>[
            for (final t in used) _tagTile(t, used: true),
            if (unused.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Text('未使用',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: T.inkSecondary,
                        letterSpacing: 0.5)),
              ),
              for (final t in unused) _tagTile(t, used: false),
            ],
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: items,
          );
        },
      ),
    );
  }

  Widget _tagTile(TagWithCount item, {required bool used}) {
    final color = hexToColor(item.tag.color);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onLongPress: () => _pickColor(item.tag),
        leading: used
            ? Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.label, size: 18, color: color),
              )
            : Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  border: Border.all(color: T.inkTertiary, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.label_outline,
                    size: 18, color: T.inkTertiary),
              ),
        title: Text(item.tag.name,
            style: TextStyle(color: used ? null : T.inkSecondary)),
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

  /// 换色 bottomSheet：顶部成品 chip 实时预览，点色即改即存（灵感：试珠）
  Future<void> _pickColor(Tag tag) async {
    var selectedHex = tag.color;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final previewColor = hexToColor(selectedHex);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // 成品 chip 预览：色点 + 名称 + 色 12% 底
                Chip(
                  avatar: Icon(Icons.label, size: 16, color: previewColor),
                  label: Text(tag.name),
                  backgroundColor: previewColor.withValues(alpha: 0.12),
                  side: BorderSide.none,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: kPalette
                      .map((hex) => InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () async {
                              setSheetState(() => selectedHex = hex);
                              await widget.db.updateTag(tag.id, color: hex);
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: hexToColor(hex),
                                shape: BoxShape.circle,
                                border: hex == selectedHex
                                    ? Border.all(width: 3, color: T.inkPrimary)
                                    : null,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text('点选即换色，长按标签行也能快速打开这里',
                    style: TextStyle(fontSize: 11, color: T.inkTertiary)),
              ]),
            ),
          );
        },
      ),
    );
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
