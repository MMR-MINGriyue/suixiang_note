import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/edit_history.dart';
import '../core/format.dart';
import '../core/markdown_edit.dart';
import '../core/outline.dart';
import '../data/app_database.dart';
import '../theme/tokens.dart';
import 'reminder_sheet.dart';
import 'widgets/color_palette.dart';
import 'widgets/drop_badge.dart';
import 'widgets/edit_toolbar.dart';
import 'widgets/empty_state.dart';
import 'widgets/find_replace_sheet.dart';
import 'widgets/link_sheet.dart';
import 'widgets/markdown_preview.dart';

/// 详情/编辑页：复用速记的自动落库逻辑（500ms 防抖），增加文件夹归属切换
/// 打开方式：Navigator.push 全屏页（区别于速记的模态弹层）
///
/// v2.0 编辑能力扩展：撤销重做（含桌面快捷键）、Markdown 格式工具条、
/// 预览切换、查找替换、专注模式。所有文本变换走 core/markdown_edit.dart
/// 的纯函数，UI 层只负责把结果套回 Controller 并记录历史帧。
class DetailPage extends StatefulWidget {
  final AppDatabase db;
  final Thought thought;
  const DetailPage({super.key, required this.db, required this.thought});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  Timer? _debounce;
  int _wordCount = 0;

  /// 编辑历史：初始帧就是打开页面时的原文
  late final EditHistory _history;
  bool _canUndo = false;
  bool _canRedo = false;

  /// 预览态（只读渲染）；退出预览回到编辑态，文本不丢
  bool _previewing = false;
  /// 专注模式：隐藏 AppBar 与元数据，只剩正文
  bool _focusMode = false;

  /// 是否已设定提醒——PopupMenuButton 的 itemBuilder 只能返回
  /// PopupMenuEntry，塞不进 StreamBuilder，所以在这里订阅成字段。
  bool _hasReminder = false;
  StreamSubscription<List<Reminder>>? _reminderSub;

  /// 关联数量，同样因为 itemBuilder 拿不到 Stream
  int _linkCount = 0;
  StreamSubscription<List<LinkedThought>>? _linkSub;

  /// 当前正文解析出的小节（写一次解析一次；只有标题行变化才真的变）
  List<DocSection> _sections = const [];

  /// 光标当前所在小节，用于目录高亮
  int _caretSection = -1;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.thought.content);
    _wordCount = countWords(widget.thought.content);
    _history = EditHistory(widget.thought.content);
    _sections = Outline.parse(widget.thought.content);
    _reminderSub = widget.db
        .watchActiveReminderOf(widget.thought.id)
        .listen((list) {
      final has = list.isNotEmpty;
      if (has != _hasReminder && mounted) setState(() => _hasReminder = has);
    });
    _linkSub = widget.db.watchLinksOf(widget.thought.id).listen((list) {
      if (list.length != _linkCount && mounted) {
        setState(() => _linkCount = list.length);
      }
    });
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
    _reminderSub?.cancel();
    _linkSub?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {
      _wordCount = countWords(text);
      _history.record(text, _controller.selection);
      _canUndo = _history.canUndo;
      _canRedo = _history.canRedo;
      _sections = Outline.parse(text);
      _caretSection = _indexOfSectionAt(_sections, _controller.selection.start);
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.db.saveDraft(id: widget.thought.id, content: text);
    });
    _maybeContinueList(text);
  }

  /// 检测「用户刚敲了一个回车」，并在列表/待办/引用行后面自动续上同样的前缀。
  ///
  /// 为什么不在 onSubmitted 里做：`maxLines: null` 的多行 TextField 里
  /// 回车是换行而不是提交，onSubmitted 根本不会触发。只能在文本变化时
  /// 看「是不是刚好插入了一个 \n」。
  void _maybeContinueList(String text) {
    final sel = _controller.selection;
    if (!sel.isValid || !sel.isCollapsed) return;
    final caret = sel.start;
    // 光标必须在刚插入的换行之后
    if (caret == 0 || text[caret - 1] != '\n') return;
    // 只处理「上一行有列表标记」的情况，普通段落回车不加东西
    final prevEnd = caret - 1;
    final prevStart = prevEnd == 0 ? 0 : text.lastIndexOf('\n', prevEnd - 1) + 1;
    final prevLine = text.substring(prevStart, prevEnd);
    if (prevLine.trim().isEmpty) return;

    final m = RegExp(r'^(\s*)(- \[[ x]\] |- |\d+\. |> )(.*)$').firstMatch(prevLine);
    if (m == null) return;
    final indent = m.group(1)!;
    final marker = m.group(2)!;
    final body = m.group(3)!;
    if (body.trim().isEmpty) return; // 空项目后面回车 → 不再续

    final next = marker.startsWith('- [x]') || marker.startsWith('- [ ]')
        ? '- [ ] '
        : (RegExp(r'^\d+\.\s?$').hasMatch(marker.trimRight())
            ? '${int.parse(marker.trimRight().replaceAll('.', '')) + 1}. '
            : marker);
    final insert = '$indent$next';
    _applyEdit(EditResult(
      text.replaceRange(caret, caret, insert),
      TextSelection.collapsed(offset: caret + insert.length),
    ), coalesce: true);
  }

  /// 光标当前落在第几个小节（-1 = 在第一个标题之前）
  static int _indexOfSectionAt(List<DocSection> sections, int caret) {
    var hit = -1;
    for (var i = 0; i < sections.length; i++) {
      if (sections[i].offset <= caret) {
        hit = i;
      } else {
        break;
      }
    }
    return hit;
  }

  /// 跳到某一节：把光标放到标题行首尾之间的整行选区内，
  /// 用户可以直接改标题，也能立刻看到那一节的内容。
  void _jumpToSection(DocSection s) {
    _controller.selection = Outline.selectionFor(_controller.text, s);
    setState(() => _caretSection = _sections.indexOf(s));
    if (!_focusMode) _focusNode.requestFocus();
  }

  void _openOutline() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        decoration: BoxDecoration(
          color: dark ? T.darkBg : T.paperBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(T.rSheet)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: T.inkTertiary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(children: [
              const Expanded(
                child: Text('目录',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text('${_sections.length} 节',
                  style:
                      const TextStyle(fontSize: 11, color: T.inkTertiary)),
            ]),
          ),
          Flexible(
            child: _sections.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    child: Column(children: [
                      Icon(Icons.format_list_bulleted,
                          size: 28,
                          color: T.inkTertiary.withValues(alpha: 0.5)),
                      const SizedBox(height: 10),
                      const Text('这篇还没有分节',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('在正文里写「# 标题」就会自动生成一节，\n最多三级。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color:
                                  dark ? T.darkInkSecondary : T.inkSecondary)),
                    ]),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _sections.length,
                    itemBuilder: (c, i) {
                      final s = _sections[i];
                      final active = i == _caretSection;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _jumpToSection(s);
                        },
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              16 + Outline.indentOf(s), 9, 16, 9),
                          child: Row(children: [
                            Container(
                              width: 3,
                              height: 16,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: active
                                    ? T.brandPrimary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                s.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: s.level == 1 ? 13.5 : 12.5,
                                  fontWeight: s.level == 1
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: active
                                      ? T.brandPrimary
                                      : (dark
                                          ? T.darkInkPrimary
                                          : T.inkPrimary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              s.bodyLength > 0 ? '${s.bodyLength} 字' : '',
                              style: const TextStyle(
                                  fontSize: 10, color: T.inkTertiary),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  /// 把一次纯函数变换的结果套回界面：文本 + 光标 + 历史帧 + 落库
  void _applyEdit(EditResult r, {bool coalesce = false}) {
    _debounce?.cancel();
    _controller.value = TextEditingValue(text: r.text, selection: r.selection);
    setState(() {
      _wordCount = countWords(r.text);
      _history.record(r.text, r.selection, coalesce: coalesce);
      _canUndo = _history.canUndo;
      _canRedo = _history.canRedo;
      _sections = Outline.parse(r.text);
      _caretSection = _indexOfSectionAt(_sections, r.selection.start);
    });
    // 格式操作是一次完整动作，立刻落库，不等防抖
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.db.saveDraft(id: widget.thought.id, content: r.text);
    });
    if (!_focusMode) _focusNode.requestFocus();
  }

  void _undo() {
    final s = _history.undo();
    if (s == null) return;
    _debounce?.cancel();
    _controller.value = TextEditingValue(text: s.text, selection: s.selection);
    setState(() {
      _wordCount = countWords(s.text);
      _canUndo = _history.canUndo;
      _canRedo = _history.canRedo;
    });
    widget.db.saveDraft(id: widget.thought.id, content: s.text);
    HapticFeedback.selectionClick();
  }

  void _redo() {
    final s = _history.redo();
    if (s == null) return;
    _debounce?.cancel();
    _controller.value = TextEditingValue(text: s.text, selection: s.selection);
    setState(() {
      _wordCount = countWords(s.text);
      _canUndo = _history.canUndo;
      _canRedo = _history.canRedo;
    });
    widget.db.saveDraft(id: widget.thought.id, content: s.text);
    HapticFeedback.selectionClick();
  }

  void _applyFormat(MdFormat f) {
    final text = _controller.text;
    final sel = _controller.selection;
    if (f.id == 'hr') {
      _applyEdit(MarkdownEdit.insertLine(text, sel, '---'));
      return;
    }
    if (f.isInline) {
      _applyEdit(MarkdownEdit.toggleInline(text, sel, f.inline, f.placeholder));
      return;
    }
    // 行首前缀型：族内按「点击次数轮转」，第三次回到无前缀
    final prefix = _nextPrefixFor(text, sel, f.linePrefixes);
    _applyEdit(
        MarkdownEdit.toggleLinePrefix(text, sel, prefix, f.linePrefixes));
  }

  /// 同一族前缀轮转：无 → 第 1 种 → 第 2 种 → … → 无
  /// 这样用户点两次「列表」就得到有序列表，而不是要先取消再点另一个按钮。
  ///
  /// 匹配时必须**按长度倒序**：「- [ ] 买菜」以「- 」开头，若按族内原顺序
  /// 匹配就会命中「- 」而永远推不到待办状态。
  static String _nextPrefixFor(String text, TextSelection sel, List<String> family) {
    final at = sel.start.clamp(0, text.length);
    final lineStart = at == 0 ? 0 : (text.lastIndexOf('\n', at - 1) + 1);
    var lineEnd = text.indexOf('\n', at);
    if (lineEnd < 0) lineEnd = text.length;
    final line = text.substring(lineStart, lineEnd).trimLeft();

    if (sel.start != sel.end) {
      // 有选区时：全部已带某前缀 → 回到无前缀（toggleLinePrefix 自己判）
      return family.first;
    }
    final byLength = family.asMap().entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    for (final e in byLength) {
      if (line.startsWith(e.value)) {
        // 回到「族内原顺序」的下一项，保证轮转顺序符合工具条展示顺序
        final next = e.key + 1;
        return next < family.length ? family[next] : '';
      }
    }
    return family.first;
  }

  void _insertTimestamp() {
    final now = DateTime.now();
    final snippet = DateFormat('yyyy/MM/dd HH:mm').format(now);
    _applyEdit(MarkdownEdit.insertText(_controller.text, _controller.selection, snippet));
  }

  Future<void> _findReplace() async {
    final result = await FindReplaceSheet.open(context, _controller.text);
    if (result == null || !mounted) return;
    _applyEdit(EditResult(result.text, TextSelection.collapsed(offset: result.firstIndex)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.replaced == 0
            ? '没有替换任何内容'
            : '已替换 ${result.replaced} 处'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    // 桌面端快捷键：Ctrl+Z 撤销、Ctrl+Shift+Z / Ctrl+Y 重做、Ctrl+F 查找
    // 手机没有物理键盘，这层对 Windows 版才有意义（本项目主力调试平台）。
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _findReplace();
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          setState(() => _previewing = !_previewing);
        },
      },
      child: Focus(
        autofocus: false,
        child: Scaffold(
          appBar: _focusMode ? null : _buildAppBar(context, db),
          body: Column(
            children: [
              Expanded(
                child: _previewing
                    ? PaperTexture(child: MarkdownPreview(_controller.text))
                    : PaperTexture(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: _onChanged,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          // 桌面端 Tab 缩进；手机上 Tab 键不存在，无副作用
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                          decoration: const InputDecoration(
                            hintText: '想到什么写什么…\n\n可以用 # 标题、- 列表、> 引用',
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
              ),
              if (!_previewing && !_focusMode)
                _MetaBar(
                  db: db,
                  thought: widget.thought,
                  sections: _sections,
                  linkCount: _linkCount,
                  onOpenLinks: () =>
                      LinkSheet.open(context, widget.db, widget.thought),
                  onOpenOutline: _sections.isEmpty ? null : _openOutline,
                ),
              // 工具条：专注模式下也保留（专注是要写，不是要藏工具）
              if (!_previewing)
                EditToolbar(
                  onUndo: _canUndo ? _undo : null,
                  onRedo: _canRedo ? _redo : null,
                  onFormat: _applyFormat,
                  onFindReplace: _findReplace,
                  onInsertTime: _insertTimestamp,
                ),
              if (!_focusMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Row(children: [
                    Text('$_wordCount 字',
                        style: TextStyle(
                            fontSize: 11,
                            color: _wordCount > 9000 ? T.warning : T.inkTertiary)),
                    const SizedBox(width: 10),
                    if (_focusMode)
                      const Text('专注',
                          style: TextStyle(fontSize: 11, color: T.brandPrimary)),
                    const Spacer(),
                    const Text('自动保存',
                        style: TextStyle(fontSize: 11, color: T.inkTertiary)),
                  ]),
                ),
            ],
          ),
          // 专注模式退出按钮：AppBar 藏起来了，必须留一个明确的出口
          floatingActionButton: _focusMode
              ? FloatingActionButton.small(
                  tooltip: '退出专注',
                  backgroundColor: T.inkPrimary.withValues(alpha: 0.08),
                  foregroundColor: T.inkSecondary,
                  elevation: 0,
                  onPressed: () => setState(() => _focusMode = false),
                  child: const Icon(Icons.fullscreen_exit, size: 20),
                )
              : null,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppDatabase db) {
    return AppBar(
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
        // 目录：只在有分节时出现，没有分节的短文不该多一个按钮
        if (_sections.isNotEmpty)
          IconButton(
            icon: Badge(
              isLabelVisible: false,
              smallSize: 6,
              child: const Icon(Icons.format_list_bulleted),
            ),
            tooltip: '目录（${_sections.length} 节）',
            onPressed: _openOutline,
          ),
        // 预览 / 编辑切换
        IconButton(
          icon: Icon(_previewing ? Icons.edit_outlined : Icons.visibility_outlined),
          tooltip: _previewing ? '回到编辑' : '预览排版',
          onPressed: () => setState(() => _previewing = !_previewing),
        ),
        // 专注模式
        IconButton(
          icon: const Icon(Icons.fullscreen),
          tooltip: '专注模式',
          onPressed: () => setState(() => _focusMode = true),
        ),
        // 溢出菜单：把低频动作（提醒/标签/文件夹/删除）收进来，
        // 给上面的编辑类按钮腾出位置——之前 4 个 IconButton 挤在 375 宽上
        // 会把标题状态区压扁。
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) async {
            switch (v) {
              case 'reminder':
                await ReminderSheet.open(context, widget.db, widget.thought);
              case 'tag':
                await _editTags(context);
              case 'link':
                await LinkSheet.open(context, widget.db, widget.thought);
              case 'folder':
                await _pickFolder(context);
              case 'delete':
                await _delete(context);
            }
          },
          itemBuilder: (ctx) => [
            // 提醒状态下显式标出来，否则用户要知道自己设过没只能点进去看。
            // 这里不能用 StreamBuilder：PopupMenuButton.itemBuilder 要求返回
            // PopupMenuEntry 列表，而 StreamBuilder 是 Widget，塞不进去；
            // 所以提醒有无在 initState 里订阅成 _hasReminder 字段。
            PopupMenuItem(
              value: 'reminder',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    _hasReminder
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                    size: 20,
                    color: _hasReminder ? T.brandPrimary : T.inkSecondary),
                title: Text(_hasReminder ? '修改提醒' : '提醒我'),
              ),
            ),            const PopupMenuItem(
              value: 'tag',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.label_outline, size: 20),
                title: Text('标签'),
              ),
            ),
            PopupMenuItem(
              value: 'link',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    _linkCount > 0 ? Icons.hub : Icons.add_link,
                    size: 20,
                    color: _linkCount > 0 ? T.brandPrimary : T.inkSecondary),
                title: Text(_linkCount > 0 ? '关联（$_linkCount 条）' : '关联到别的随记'),
              ),
            ),
            const PopupMenuItem(
              value: 'folder',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.folder_open_outlined, size: 20),
                title: Text('移动到文件夹'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline, size: 20, color: T.danger),
                title: Text('删除', style: TextStyle(color: T.danger)),
              ),
            ),
          ],
        ),
      ],
    );
  }


  /// 三态选择面板：列出当前所有阶段，选中即落库并弹撤销条。
  ///
  /// 用 bottom sheet 而不是 PopupMenu：手机上一行一个 48px 的行，
  /// 三态各带星瓶徽章和一句「什么意思」，比小箭头菜单好点也好懂。
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

  Color _tagColor(Tag t) => parseHexColor(t.color);

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
  final List<DocSection> sections;
  final int linkCount;
  final VoidCallback onOpenLinks;
  final VoidCallback? onOpenOutline;
  const _MetaBar({
    required this.db,
    required this.thought,
    required this.sections,
    required this.linkCount,
    required this.onOpenLinks,
    this.onOpenOutline,
  });

  @override
  Widget build(BuildContext context) {
    final created = DateTime.fromMillisecondsSinceEpoch(thought.createdAt);
    final updated = DateTime.fromMillisecondsSinceEpoch(thought.updatedAt);
    final fmt = DateFormat('yyyy/MM/dd HH:mm');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(children: [
        // 结构行：分了几节 + 连了几条。这两件事决定「这是一篇短文还是
        // 一颗有位置的东西」，放在标签上面比放在最下面更容易被看到。
        if (sections.isNotEmpty || linkCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              if (sections.isNotEmpty) ...[
                InkWell(
                  onTap: onOpenOutline,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.format_list_bulleted,
                          size: 14, color: T.inkSecondary),
                      const SizedBox(width: 5),
                      Text('${sections.length} 节',
                          style: const TextStyle(
                              fontSize: 11, color: T.inkSecondary)),
                    ]),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              if (linkCount > 0) ...[
                InkWell(
                  onTap: onOpenLinks,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.hub_outlined,
                          size: 14, color: T.brandPrimary),
                      const SizedBox(width: 5),
                      Text('$linkCount 条关联',
                          style: const TextStyle(
                              fontSize: 11, color: T.brandPrimary)),
                    ]),
                  ),
                ),
              ] else ...[
                InkWell(
                  onTap: onOpenLinks,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.add_link, size: 14, color: T.inkTertiary),
                      SizedBox(width: 5),
                      Text('加关联',
                          style: TextStyle(
                              fontSize: 11, color: T.inkTertiary)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
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
