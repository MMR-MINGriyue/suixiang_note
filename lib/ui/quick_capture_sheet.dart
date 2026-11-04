import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../theme/tokens.dart';
import 'widgets/color_palette.dart';
import 'widgets/empty_state.dart';

/// 速记捕捉页：模态全屏，自动落库（500ms 防抖），无保存按钮（PRD §4.1）
class QuickCaptureSheet extends StatefulWidget {
  final AppDatabase db;
  const QuickCaptureSheet({super.key, required this.db});

  /// 统一入口：showModalBottomSheet 全屏弹层
  static Future<void> open(BuildContext context, AppDatabase db) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickCaptureSheet(db: db),
    );
  }

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  int? _savedId; // 首次落库后持有，后续防抖更新
  int _wordCount = 0;
  DateTime? _savedAt;
  final Set<int> _selectedTagIds = {}; // 创意 ②-3：速记时就能打标签
  int? _folderId;

  @override
  void initState() {
    super.initState();
    // 进场即聚焦：目标「点 FAB → 可输入 ≤600ms」
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onChanged(String text) {
    setState(() => _wordCount = text.replaceAll(RegExp(r'\s'), '').length);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final id = await widget.db.saveDraft(id: _savedId, content: text);
      if (!mounted) return;
      if (id > 0) {
        setState(() {
          _savedId = id;
          _savedAt = DateTime.now();
        });
        // 速记时选好的标签/文件夹在首次落库后同步（后续修改由 chip 即时写库）
        if (_selectedTagIds.isNotEmpty) {
          await widget.db.setThoughtTags(id, _selectedTagIds.toList());
        }
        if (_folderId != null) {
          await widget.db.moveToFolder(id, _folderId);
        }
      } else if (id == -1 && _savedId != null) {
        // 内容被清空：草稿已硬删，回到未落库态
        setState(() {
          _savedId = null;
          _savedAt = null;
        });
      }
    });
  }

  /// 防抖补写：关闭弹层时若还有未落库的最后输入，立即 flush
  /// （Architect P0-A1：防抖 dispose 不 flush → 丢最后 500ms 输入）
  void _flushPendingSave() {
    _debounce?.cancel();
    _debounce = null;
    final text = _controller.text;
    if (text.trim().isEmpty && _savedId == null) return; // 全空没落过库，无事可做
    widget.db.saveDraft(id: _savedId, content: text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _flushPendingSave();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(T.rSheet)),
        ),
        padding: const EdgeInsets.fromLTRB(T.pagePad, 12, T.pagePad, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部状态行：拖拽把手（创意 ②-1）+ 标题 + 自动保存指示
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: T.inkTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('随想速记', style: theme.textTheme.titleMedium),
              const Spacer(),
              _SavedIndicator(savedAt: _savedAt),
            ]),
            const SizedBox(height: 8),
            // 创意 ②-2：纸面放大——17px 正文 / 1.7 行高，写字像在纸上
            // 创意 ③-4：纸纹叠在静态容器，不进 TextField decoration
            PaperTexture(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                maxLines: null,
                minLines: 7,
                onChanged: _onChanged,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '第一个念头，从一颗水滴开始…',
                  hintStyle: const TextStyle(color: T.inkTertiary, fontSize: 16),
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                    fontSize: 17,
                    height: 1.7,
                    color: T.inkPrimary),
              ),
            ),
            // 创意 ②-3：快捷 chip 行——不打断书写就能打标签/归文件夹
            _QuickMetaChips(
              db: widget.db,
              selectedTagIds: _selectedTagIds,
              onTagsChanged: (ids) async {
                setState(() => _selectedTagIds
                  ..clear()
                  ..addAll(ids));
                if (_savedId != null) {
                  await widget.db.setThoughtTags(_savedId!, ids.toList());
                }
              },
              onFolderPicked: (id) async {
                setState(() => _folderId = id);
                if (_savedId != null) {
                  await widget.db.moveToFolder(_savedId!, id);
                }
              },
            ),
            // 分隔线 + 底部字数/完成行（层级三：背景层 11-12px）
            Divider(height: 1, thickness: 1, color: T.inkTertiary.withValues(alpha: 0.15)),
            const SizedBox(height: 4),
            Row(children: [
              Text('$_wordCount 字',
                  style: const TextStyle(color: T.inkTertiary, fontSize: 12)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 自动保存状态指示：未落库=隐藏；已落库=「已自动保存」
class _SavedIndicator extends StatelessWidget {
  final DateTime? savedAt;
  const _SavedIndicator({required this.savedAt});

  @override
  Widget build(BuildContext context) {
    if (savedAt == null) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      // 创意 ②-1：保存徽章水滴化「落珠」
      const Icon(Icons.water_drop, size: 14, color: T.stageDone),
      const SizedBox(width: 4),
      Text('已自动保存',
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? T.stageDone
                  : const Color(0xFF1E8A67))),
    ]);
  }
}

/// 快捷 chip 行（创意 ②-3）：标签 + 文件夹两枚 Ghost chip。
/// 取数用 watchX().first 一次性快照，不挂长连监听（性能守则 5）。
class _QuickMetaChips extends StatelessWidget {
  final AppDatabase db;
  final Set<int> selectedTagIds;
  final ValueChanged<Set<int>> onTagsChanged;
  final ValueChanged<int?> onFolderPicked;
  const _QuickMetaChips({
    required this.db,
    required this.selectedTagIds,
    required this.onTagsChanged,
    required this.onFolderPicked,
  });

  @override
  Widget build(BuildContext context) {
    final label = selectedTagIds.isEmpty ? '标签' : '标签 ${selectedTagIds.length}';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _ghostChip(
          icon: Icons.label_outline,
          label: label,
          onTap: () => _pickTags(context),
        ),
        const SizedBox(width: 8),
        _ghostChip(
          icon: Icons.folder_open_outlined,
          label: '文件夹',
          onTap: () => _pickFolder(context),
        ),
      ]),
    );
  }

  Widget _ghostChip(
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: T.inkSecondary),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: onTap,
    );
  }

  Future<void> _pickTags(BuildContext context) async {
    final allTags = await db.watchTags().first;
    if (!context.mounted) return;
    if (allTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('还没有标签，可先在随记详情页创建'),
          duration: Duration(seconds: 2)));
      return;
    }
    final selected = Set<int>.of(selectedTagIds);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('选择标签', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allTags
                    .map((t) => FilterChip(
                          label: Text(t.name),
                          selected: selected.contains(t.id),
                          avatar: Icon(Icons.label,
                              size: 16, color: hexToColor(t.color)),
                          onSelected: (on) => setSheetState(() =>
                              on ? selected.add(t.id) : selected.remove(t.id)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('完成（已选 ${selected.length} 个）'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ok == true) onTagsChanged(selected);
  }

  Future<void> _pickFolder(BuildContext context) async {
    final folders = await db.watchFoldersWithCount().first;
    if (!context.mounted) return;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('归入文件夹'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 0), // 0 = 收件箱
            child: const ListTile(
              leading: Icon(Icons.inbox_outlined),
              title: Text('收件箱（不归文件夹）'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          ...folders
              .where((f) => f.folder.deletedAt == null)
              .map((f) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, f.folder.id),
                    child: ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(f.folder.name),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )),
        ],
      ),
    );
    if (picked == null) return;
    onFolderPicked(picked == 0 ? null : picked);
  }
}
