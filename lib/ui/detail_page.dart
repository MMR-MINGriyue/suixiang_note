import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../theme/tokens.dart';
import 'widgets/color_palette.dart';
import 'widgets/empty_state.dart';

/// 详情/编辑页：复用速记的自动落库逻辑（500ms 防抖），增加文件夹归属切换
/// 打开方式：Navigator.push 全屏页（区别于速记的模态弹层）
class DetailPage extends StatefulWidget {
  final AppDatabase db;
  final Thought thought;
  const DetailPage({super.key, required this.db, required this.thought});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late final TextEditingController _controller;
  Timer? _debounce;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.thought.content);
    _wordCount =
        widget.thought.content.replaceAll(RegExp(r'\s'), '').length;
  }

  /// 防抖补写：退出页面时若还有未落库的最后输入，立即 flush
  /// （Architect P0-A1：防抖 dispose 不 flush → 丢最后 500ms 输入）
  void _flushPendingSave() {
    _debounce?.cancel();
    _debounce = null;
    widget.db.saveDraft(id: widget.thought.id, content: _controller.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _flushPendingSave();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() => _wordCount = text.replaceAll(RegExp(r'\s'), '').length);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.db.saveDraft(id: widget.thought.id, content: text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<Stage>>(
          stream: db.watchStages(),
          builder: (context, sSnap) {
            final stages = sSnap.data ?? const <Stage>[];
            Stage stage;
            try {
              stage = stages
                  .firstWhere((s) => s.id == widget.thought.stageId);
            } on StateError {
              stage = stages.isNotEmpty
                  ? stages.first
                  : Stage(
                      id: 1,
                      name: '灵感',
                      kind: 'inspiration',
                      color: '#A8B9E6',
                      position: 1.0,
                      isSystem: true,
                      createdAt: 0);
            }
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                await db.advanceStage(widget.thought.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('已推进到「${_nextStageName(stages, stage)}」'),
                      duration: const Duration(seconds: 1)));
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.water_drop,
                      size: 16,
                      color: Color(int.parse(
                          stage.color.replaceFirst('#', '0xFF')))),
                  const SizedBox(width: 6),
                  Text(stage.name,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  const Icon(Icons.sync_alt, size: 14, color: T.inkSecondary),
                ]),
              ),
            );
          },
        ),
        actions: [
          // 标签编辑
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: '标签',
            onPressed: () => _editTags(context),
          ),
          // 文件夹归属切换
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: '移动到文件夹',
            onPressed: () => _pickFolder(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: T.danger),
            tooltip: '删除',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            // 纸纹叠加在静态背景容器上（创意 ③-4），不进 TextField decoration
            child: PaperTexture(
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '想到什么写什么…',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          _MetaBar(db: db, thought: widget.thought),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Text('$_wordCount 字',
                  style: TextStyle(
                      fontSize: 11,
                      color: _wordCount > 9000 ? T.warning : T.inkTertiary)),
              const Spacer(),
              const Text('自动保存',
                  style: TextStyle(fontSize: 11, color: T.inkTertiary)),
            ]),
          ),
        ],
      ),
    );
  }

  String _nextStageName(List<Stage> stages, Stage current) {
    if (stages.isEmpty) return '';
    final idx = stages.indexWhere((s) => s.id == current.id);
    return stages[(idx + 1) % stages.length].name;
  }

  /// 标签编辑面板：勾选已有标签 + 内联新建，确认后替换式写回
  Future<void> _editTags(BuildContext context) async {
    final allTags = await widget.db.watchTags().first;
    final current = await widget.db.watchTagsOfThought(widget.thought.id).first;
    final selected = current.map((t) => t.id).toSet();
    if (!context.mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet))),
      builder: (ctx) => _TagPickerSheet(
        db: widget.db,
        allTags: allTags,
        selected: selected,
      ),
    );
    if (ok == true) {
      await widget.db.setThoughtTags(widget.thought.id, selected.toList());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('标签已更新'), duration: Duration(seconds: 1)));
      }
    }
  }

  Future<void> _pickFolder(BuildContext context) async {
    final folders = await widget.db
        .watchFoldersWithCount()
        .first; // 一次性取当前快照
    if (!context.mounted) return;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移动到'),
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
    await widget.db.moveToFolder(widget.thought.id, picked == 0 ? null : picked);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('已移动'),
          duration: Duration(seconds: 1)));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除随记'),
        content: const Text('将移入回收站，可在回收站恢复。'),
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
    if (ok == true) {
      await widget.db.saveDraft(id: widget.thought.id, content: _controller.text); // 先落最后草稿
      await widget.db.softDelete(widget.thought.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

/// 标签选择半屏面板：FilterChip 多选 + 新建标签输入行
class _TagPickerSheet extends StatefulWidget {
  final AppDatabase db;
  final List<Tag> allTags;
  final Set<int> selected;
  const _TagPickerSheet(
      {required this.db, required this.allTags, required this.selected});

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late List<Tag> _tags;
  late Set<int> _selected;
  final _newCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = List.of(widget.allTags);
    _selected = Set.of(widget.selected);
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  Color _tagColor(Tag t) => Color(int.parse(t.color.replaceFirst('#', '0xFF')));

  Future<void> _createTag() async {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) return;
    final tag = await widget.db.createTag(name);
    if (tag != null && !mounted) return;
    setState(() {
      if (!_tags.any((t) => t.id == tag!.id)) _tags.add(tag!);
      _selected.add(tag!.id);
      _newCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('选择标签', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (_tags.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('还没有标签，在下面输入名字创建第一个',
                  style: TextStyle(color: T.inkSecondary, fontSize: 13)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags
                  .map((t) => FilterChip(
                        label: Text(t.name),
                        selected: _selected.contains(t.id),
                        avatar: Icon(Icons.label, size: 16, color: _tagColor(t)),
                        onSelected: (on) =>
                            setState(() => on ? _selected.add(t.id) : _selected.remove(t.id)),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _newCtrl,
                maxLength: 20,
                decoration: const InputDecoration(
                  hintText: '新建标签（≤20 字）',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _createTag(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _createTag,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建'),
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('完成（已选 ${_selected.length} 个）'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 元数据分组卡（美化 P2-③）：标签 / 文件夹 / 时间戳三行，按纸面网格对齐。
class _MetaBar extends StatelessWidget {
  final AppDatabase db;
  final Thought thought;
  const _MetaBar({required this.db, required this.thought});

  @override
  Widget build(BuildContext context) {
    final created = DateTime.fromMillisecondsSinceEpoch(thought.createdAt);
    final updated = DateTime.fromMillisecondsSinceEpoch(thought.updatedAt);
    final fmt = DateFormat('yyyy/MM/dd HH:mm');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(children: [
        // 标签行：实时反映标签面板写回结果
        StreamBuilder<List<Tag>>(
          stream: db.watchTagsOfThought(thought.id),
          builder: (context, snap) {
            final tags = snap.data ?? const <Tag>[];
            if (tags.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.label_outline,
                    size: 14, color: T.inkTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: tags
                        .map((t) => Chip(
                              avatar: Icon(Icons.label,
                                  size: 12, color: hexToColor(t.color)),
                              label: Text(t.name,
                                  style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              backgroundColor: hexToColor(t.color)
                                  .withValues(alpha: 0.12),
                              side: BorderSide.none,
                            ))
                        .toList(),
                  ),
                ),
              ]),
            );
          },
        ),
        // 文件夹 + 时间戳行
        Row(children: [
          StreamBuilder<List<FolderWithCount>>(
            stream: db.watchFoldersWithCount(),
            builder: (context, snap) {
              final folders = snap.data ?? const <FolderWithCount>[];
              String name = '收件箱';
              Color color = T.inkTertiary;
              for (final f in folders) {
                if (f.folder.id == thought.folderId) {
                  name = f.folder.name;
                  color = hexToColor(f.folder.color);
                }
              }
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.folder_outlined, size: 14, color: color),
                const SizedBox(width: 4),
                Text(name,
                    style: const TextStyle(
                        fontSize: 11, color: T.inkSecondary)),
              ]);
            },
          ),
          const Spacer(),
          Text('记于 ${fmt.format(created)} · 改于 ${fmt.format(updated)}',
              style: const TextStyle(fontSize: 10, color: T.inkTertiary)),
        ]),
      ]),
    );
  }
}
