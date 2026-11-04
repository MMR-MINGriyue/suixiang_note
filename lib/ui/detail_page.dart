import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import '../data/app_database.dart';
import '../theme/tokens.dart';
import 'reminder_sheet.dart';
import 'widgets/color_palette.dart';
import 'widgets/drop_badge.dart';
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
            final stage = stageById(stages, widget.thought.stageId) ??
                Stage(
                    id: 1,
                    name: '灵感',
                    kind: 'inspiration',
                    color: '#A8B9E6',
                    position: 1.0,
                    isSystem: true,
                    createdAt: 0);
            // 原来这里是「点一下自动推进到下一态」的隐藏开关：用户看得见
            // 一滴水加一个 sync 图标，但不知道点一下会变成什么。改成点开
            // 三态菜单，把「推进」和「直接选」都摆在明面上。
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _pickStage(context, stages, stage),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  DropBadge(kind: stage.kind, color: hexToColor(stage.color), size: 18),
                  const SizedBox(width: 6),
                  Text(stage.name, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, size: 16, color: T.inkSecondary),
                ]),
              ),
            );
          },
        ),
        actions: [
          // 提醒（v1.6）：到点弹通知，支持每天/每周/每月重复
          StreamBuilder<List<Reminder>>(
            stream: db.watchActiveReminderOf(widget.thought.id),
            builder: (context, snap) {
              final hasReminder = (snap.data ?? const <Reminder>[]).isNotEmpty;
              return IconButton(
                icon: Icon(
                  hasReminder
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  color: hasReminder ? T.brandPrimary : null,
                ),
                tooltip: hasReminder ? '提醒已设定' : '提醒我',
                onPressed: () async {
                  await ReminderSheet.open(context, db, widget.thought);
                },
              );
            },
          ),
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

  /// 三态选择面板：列出当前所有阶段，选中即落库并弹撤销条。
  ///
  /// 用 bottom sheet 而不是 PopupMenu：手机上一行一个 48px 的行，
  /// 三态各带水滴徽章和一句「什么意思」，比小箭头菜单好点也好懂。
  Future<void> _pickStage(
      BuildContext context, List<Stage> stages, Stage current) async {
    if (stages.isEmpty) return;
    final picked = await showModalBottomSheet<Stage>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(children: [
              Text('推进到哪一步', style: Theme.of(ctx).textTheme.titleMedium),
              const Spacer(),
              Text('${stages.length} 个状态',
                  style: const TextStyle(fontSize: 11, color: T.inkTertiary)),
            ]),
          ),
          ...stages.map((s) {
            final active = s.id == current.id;
            return ListTile(
              leading: DropBadge(
                  kind: s.kind, color: hexToColor(s.color), size: 26),
              title: Text(s.name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? T.brandPrimary : null)),
              subtitle: Text(_stageHint(s.kind),
                  style: const TextStyle(fontSize: 12, color: T.inkTertiary)),
              trailing: active
                  ? const Icon(Icons.check, size: 18, color: T.brandPrimary)
                  : null,
              onTap: () => Navigator.pop(ctx, s),
            );
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null || picked.id == current.id) return;
    final before = current;
    await widget.db.setStage(widget.thought.id, picked.id);
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已改为「${picked.name}」'),
      duration: const Duration(seconds: 3),
      // 误触兜底：直接落态比「点一下循环」更容易点错目标，
      // 所以必须给一个明确的反悔入口，而不是让用户自己再点回去
      action: SnackBarAction(
          label: '撤回',
          onPressed: () {
            widget.db.setStage(widget.thought.id, before.id);
          }),
    ));
  }

  static String _stageHint(String kind) => switch (kind) {
        'inspiration' => '刚冒出来的念头，还没动手',
        'in_progress' => '正在做，需要推进',
        'done' => '已经落定，不再占注意力',
        _ => '',
      };

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
        // 提醒行：已设提醒时显示「几点响」+ 重复规则（v1.6）
        StreamBuilder<List<Reminder>>(
          stream: db.watchActiveReminderOf(thought.id),
          builder: (context, snap) {
            final list = snap.data ?? const <Reminder>[];
            if (list.isEmpty) return const SizedBox.shrink();
            final r = list.first;
            final at = DateTime.fromMillisecondsSinceEpoch(r.remindAt);
            final label = switch (r.repeatRule) {
              'daily' => '每天 ${DateFormat('HH:mm').format(at)}',
              'weekly' => '每周 ${DateFormat('E HH:mm').format(at)}',
              'monthly' => '每月 ${DateFormat('d日 HH:mm').format(at)}',
              _ => DateFormat('M月d日 HH:mm').format(at),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.alarm_on, size: 14, color: T.brandPrimary),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: T.brandPrimary)),
              ]),
            );
          },
        ),
        // 完成时间行：completedAt 从 v1.0 就在写，但界面一直没用过。
        // 「这件事什么时候做完的」是推进主线唯一的回顾价值。
        if (thought.completedAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Icon(Icons.check_circle_outline,
                  size: 14, color: T.stageDone),
              const SizedBox(width: 6),
              Text(completedLabel(thought.completedAt),
                  style:
                      const TextStyle(fontSize: 11, color: T.stageDone)),
              const SizedBox(width: 8),
              Text('（${shortAgeLabel(thought.completedAt)}落定）',
                  style:
                      const TextStyle(fontSize: 10, color: T.inkTertiary)),
            ]),
          ),
        // 「停在这里 N 天」：与首页卡片同一判断（stagnationLabel），
        // 只在推进中且卡满 3 天出现。详情页是用户决定「还要不要做下去」
        // 的地方，这个数字在这里比在列表里更有说服力。
        StreamBuilder<List<Stage>>(
          stream: db.watchStages(),
          builder: (context, sSnap) {
            final stage = stageOf(sSnap.data ?? const <Stage>[], thought);
            final label = stagnationLabel(thought.stageChangedAt, stage.kind);
            if (label.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.hourglass_bottom, size: 14, color: T.warning),
                const SizedBox(width: 6),
                Text(label,
                    style:
                        const TextStyle(fontSize: 11, color: T.warning)),
              ]),
            );
          },
        ),
        // 文件夹 + 时间戳行
        Row(children: [          StreamBuilder<List<FolderWithCount>>(
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
