import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../main.dart' show appDb;
import '../theme/tokens.dart';
import 'widgets/color_palette.dart';
import 'widgets/empty_state.dart';

/// Tab 1 文件夹（美化 P1 ④-1/④-2）：
/// 收件箱通栏头卡（计数徽章化）+ 2 列 8 色抽屉网格 + 新建选色/长按换色/左滑删除
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
          return StreamBuilder<int>(
            stream: _inboxCount(),
            builder: (context, inboxSnap) {
              final inboxCount = inboxSnap.data ?? 0;
              // 空态：仅有收件箱时展示插画引导（创意 ④-3）
              if (items.isEmpty) {
                return EmptyState(
                  illus: 'empty_folder.png',
                  title: '空空如也，去随记里挑几条住进来',
                  subtitle: '或点右下角「新建」，给想法安个家',
                  actionLabel: '新建文件夹',
                  onAction: () => _showCreateDialog(context),
                );
              }
              return GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _InboxCard(count: inboxCount),
                  ...items.map((f) => _FolderTile(
                        folder: f.folder,
                        count: f.count,
                        onDelete: () =>
                            _confirmDelete(context, f.folder.id, f.folder.name),
                        onRecolor: (hex) =>
                            appDb.setFolderColor(f.folder.id, hex),
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Stream<int> _inboxCount() =>
      appDb.watchList().map((l) => l.where((t) => t.folderId == null).length);

  void _showCreateDialog(BuildContext context) {
    final controller = TextEditingController();
    var selected = kPalette.first;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新建文件夹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 20,
                decoration: const InputDecoration(hintText: '文件夹名称'),
              ),
              const SizedBox(height: 8),
              const Text('颜色', style: TextStyle(fontSize: 13, color: T.inkSecondary)),
              const SizedBox(height: 8),
              ColorPickerRow(
                selected: selected,
                onSelect: (hex) => setDialogState(() => selected = hex),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) appDb.createFolder(name, color: selected);
                Navigator.pop(ctx);
              },
              child: const Text('创建'),
            ),
          ],
        ),
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

/// 收件箱通栏头卡（创意 ④-1）：网格第一格跨双列，大数字徽章
class _InboxCard extends StatelessWidget {
  final int count;
  const _InboxCard({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {}, // v1.4 候选：点开按 folderId==null 过滤的首页视图
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? T.brandContainer.withValues(alpha: 0.15) : T.brandContainer,
          borderRadius: BorderRadius.circular(T.rCard),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: T.brandPrimary, shape: BoxShape.circle),
              child: const Icon(Icons.inbox, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('收件箱',
                      style: theme.textTheme.titleSmall),
                  Text('未分类的随记',
                      style: TextStyle(
                          fontSize: 12, color: T.inkSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: count > 0 ? T.brandPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: count > 0
                    ? null
                    : Border.all(color: T.inkTertiary.withValues(alpha: 0.4)),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: count > 0 ? Colors.white : T.inkTertiary)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 文件夹抽屉卡（创意 ④-2）：色条 + 文件夹图形 + 计数；长按换色 / 左滑删除
class _FolderTile extends StatelessWidget {
  final Folder folder;
  final int count;
  final VoidCallback onDelete;
  final ValueChanged<String> onRecolor;

  const _FolderTile({
    required this.folder,
    required this.count,
    required this.onDelete,
    required this.onRecolor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = hexToColor(folder.color);
    return Dismissible(
      key: ValueKey('folder-${folder.id}'),
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
      child: GestureDetector(
        onLongPress: () => _showRecolorSheet(context),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? T.darkCard : T.paperCard,
            borderRadius: BorderRadius.circular(T.rCard),
            border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                // 色条：文件夹主色的 4×18 圆角条（低开销层级标记）
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(999)),
                ),
                const SizedBox(width: 8),
                Icon(Icons.folder_outlined, size: 20, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall),
                ),
              ]),
              const SizedBox(height: 8),
              Text('$count 条随记',
                  style: const TextStyle(fontSize: 12, color: T.inkTertiary)),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecolorSheet(BuildContext context) {
    var selected = folder.color;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('「${folder.name}」换色',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 14),
                ColorPickerRow(
                  selected: selected,
                  onSelect: (hex) => setSheetState(() => selected = hex),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      onRecolor(selected);
                      Navigator.pop(ctx);
                    },
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 空态插图占位（沿用 water_drop 轮廓，不引私有 painter）
class DropBadgeFallback extends StatelessWidget {
  final String? keyName;
  const DropBadgeFallback({super.key, this.keyName});

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.water_drop_outlined,
        color: T.stageInspiration, size: 48);
  }
}