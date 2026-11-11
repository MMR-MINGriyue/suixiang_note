import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import '../core/pinyin_search.dart';
import '../data/app_database.dart';
import '../core/app_signals.dart';
import '../theme/tokens.dart';
import 'daily_review_page.dart';
import 'quick_capture_sheet.dart';
import 'detail_page.dart';
import 'trash_page.dart';
import 'widgets/drop_badge.dart';
import 'widgets/drop_shape.dart';
import 'widgets/empty_state.dart';
import 'widgets/highlight_text.dart';

/// 首页「灵感流」：搜索栏 + 置顶优先列表；单击水滴切三态（主线 C：1 次点击推进）
class HomePage extends StatefulWidget {
  final AppDatabase db;
  const HomePage({super.key, required this.db});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _query = '';
  int? _tagFilter; // 当前标签过滤（null=全部）
  int? _stageFilter; // 当前状态过滤（null=全部状态）
  bool _showArchived = false; // 归档视图（区别于回收站：未删，只是「不做了」）
  Timer? _debounce;
  final _searchCtrl = TextEditingController();
  final Set<int> _selected = {}; // 多选模式选中的随记 id
  List<int> _visibleIds = const []; // 当前可见列表 id（供全选用）
  bool get _multiSelect => _selected.isNotEmpty;
  // 架构复审 P1-7：信息流只在这里按过滤参数重建一次（提为 State 字段）。
  // 原来 StreamBuilder 的 stream 在 build 里现场调用 db.watchFeed(...)，
  // 任何 setState（多选勾选、防抖落字）都会生成新 Stream 对象，StreamBuilder
  // 检测到引用变化就退订重订 → 全表重读 + 拼音重算。
  late Stream<List<Thought>> _feedStream;

  /// 按当前过滤参数构造信息流（initState 与过滤变化时调用）
  Stream<List<Thought>> _makeFeedStream(AppDatabase db) => _showArchived
      ? db.watchArchived(
          stageId: _stageFilter, query: _query.isEmpty ? null : _query)
      : db.watchFeed(
          query: _query.isEmpty ? null : _query,
          tagId: _tagFilter,
          stageId: _stageFilter,
        );

  /// 过滤参数变化后的统一出口：赋值已由调用方完成，这里只重建流
  void _refreshFeed(AppDatabase db) {
    _feedStream = _makeFeedStream(db);
  }

  @override
  void initState() {
    super.initState();
    _feedStream = _makeFeedStream(widget.db);
    // 长按图标「归档」快捷方式唤起：外部信号到达时切到归档视图，
    // 而不是重建首页（重建会丢掉用户当前的搜索/筛选上下文）
    archivedRequestTicker.addListener(_onArchivedRequest);
  }

  void _onArchivedRequest() {
    if (!mounted) return;
    setState(() {
      _showArchived = true;
      _stageFilter = null;
      _tagFilter = null;
      _query = '';
      _searchCtrl.clear();
      _refreshFeed(widget.db);
    });
  }

  @override
  void dispose() {
    archivedRequestTicker.removeListener(_onArchivedRequest);
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = v.trim();
        _refreshFeed(widget.db);
      });
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _exitMultiSelect() => setState(() => _selected.clear());

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(        title: _multiSelect
            ? Text('已选 ${_selected.length} 项')
            : const Text('随想'),
        backgroundColor: Colors.transparent,
        titleTextStyle:
            theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        leading: _multiSelect
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: '退出多选',
                onPressed: _exitMultiSelect,
              )
            : null,
        actions: [
          if (_multiSelect)
            IconButton(
              // 图标规范②：全选/清空是「清单勾选」动作，checklist 比旧
              // select_all（方框带叉）语义更准，与多选卡的 check_circle 同族
              icon: const Icon(Icons.checklist),
              tooltip: '全选/清空',
              onPressed: () {
                setState(() {
                  if (_selected.length == _visibleIds.length) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(_visibleIds);
                  }
                });
              },
            )
          else ...[
            // 每日回顾入口（v1.7）：当天还没回顾时带一个小圆点，
            // 但不做强红点——回顾是「邀请」不是「待办」，逼着点会立刻被无视
            _ReviewEntry(db: db),
            // 回收站入口（软删数据不再只有「清空」一条路）
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '回收站',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => TrashPage(db: db))),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 搜索栏（300ms 防抖 LIKE 查询，标题+内容）
          Padding(
            padding: const EdgeInsets.fromLTRB(T.pagePad, 4, T.pagePad, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索随记，或拼音首字母…',
                // 创意 ①-5：搜索框降级为背景层——paperCardAlt 填充 + radius 14，不抢主层
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? T.darkCardAlt
                    : T.paperCardAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: T.brandPrimary, width: 1.5),
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: '清空搜索',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _query = '';
                            _refreshFeed(widget.db);
                          });
                        },
                      ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          // 过滤行：状态三态 + 「归档」入口（状态与标签正交组合）
          SizedBox(
            height: 44,
            child: StreamBuilder<List<Stage>>(
              stream: db.watchStages(),
              builder: (context, stageSnap) {
                final stages = stageSnap.data ?? const <Stage>[];
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: T.pagePad),
                  children: [
                    _FilterChip(
                      label: '全部',
                      selected: _stageFilter == null && !_showArchived,
                      onTap: () => setState(() {
                        _stageFilter = null;
                        _showArchived = false;
                        _refreshFeed(db);
                      }),
                    ),
                    ...stages.map((s) => _FilterChip(
                          label: s.name,
                          selected: _stageFilter == s.id && !_showArchived,
                          dotColor: parseHexColor(s.color),
                          onTap: () => setState(() {
                            // 再点一次取消，回到全部——与标签过滤同一心智
                            _stageFilter = _stageFilter == s.id ? null : s.id;
                            _showArchived = false;
                            _refreshFeed(db);
                          }),
                        )),
                    _FilterChip(
                      label: '归档',
                      icon: Icons.archive_outlined,
                      selected: _showArchived,
                      onTap: () => setState(() {
                        _showArchived = !_showArchived;
                        if (_showArchived) _stageFilter = null;
                        _refreshFeed(db);
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
          // 标签过滤行：横滚 chip，点选过滤；再点取消
          SizedBox(
            height: 40,
            child: StreamBuilder<List<Tag>>(
              stream: db.watchTags(),
              builder: (context, tagSnap) {
                final tags = tagSnap.data ?? const <Tag>[];
                if (tags.isEmpty) return const SizedBox.shrink();
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: T.pagePad),
                  children: tags
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(t.name, style: const TextStyle(fontSize: 12)),
                              selected: _tagFilter == t.id,
                              // 图标规范①：chip 选中态用 filled label，未选中 outlined
                              avatar: Icon(_tagFilter == t.id
                                  ? Icons.label
                                  : Icons.label_outline,
                                  size: 14,
                                  color: parseHexColor(t.color)),
                              onSelected: (on) => setState(() {
                                _tagFilter = on ? t.id : null;
                                _refreshFeed(db);
                              }),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ),
          Expanded(
            // 单流驱动：搜索 / 标签 / 状态 / 归档 任意组合都走 watchFeed；
            // stream 是 State 字段（P1-7），只在过滤参数变化时重建
            child: StreamBuilder<List<Thought>>(
              stream: _feedStream,
              builder: (context, snap) => _buildList(context, db, snap),
            ),
          ),
        ],
      ),
      floatingActionButton: _multiSelect
          ? null
          : _DropFab(onPressed: () => QuickCaptureSheet.open(context, db)),
      bottomNavigationBar: _multiSelect
          ? _BatchActionBar(db: db, selected: _selected, onDone: _exitMultiSelect)
          : null,
    );
  }

  Widget _buildList(BuildContext context, AppDatabase db,
      AsyncSnapshot<List<Thought>> snap) {
    if (!snap.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = snap.data!;
    // 供 AppBar 全选用：只在非 build 状态变化时更新（避免 build 中 setState）
    if (!_listEquals(_visibleIds, list.map((t) => t.id).toList())) {
      _visibleIds = list.map((t) => t.id).toList();
    }
    if (list.isEmpty) {
      if (_showArchived) {
        return const EmptyState(
          illus: 'empty_folder.png',
          title: '还没有归档的随记',
          subtitle: '长按随记可归档——「不做了，但不想删」',
        );
      }
      if (_stageFilter != null) {
        return const EmptyState(
          illus: 'empty_home.png',
          title: '这个状态还没有随记',
          subtitle: '点卡片左下角的水滴，就能把随记推进到下一态',
        );
      }
      return _query.isEmpty && _tagFilter == null
          ? const _EmptyState()
          : _SearchEmpty(query: _query.isEmpty ? '该标签' : _query);
    }
    return StreamBuilder<List<Stage>>(
      stream: db.watchStages(),
      builder: (context, stageSnap) {
        // 阶段列表提到列表级订阅一次：原来每张卡里各自 watchStages()，
        // 50 条就是 50 条订阅（加上水滴徽章与卡住提示各一条，共上百条）。
        // stages 只有三行且几乎不变，订阅一次、按值下发最省。
        final stages = stageSnap.data ?? const <Stage>[];
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(T.pagePad, 8, T.pagePad, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _NoteCard(
              db: db,
              thought: list[i],
              stages: stages,
              highlight: _query,
              multiSelect: _multiSelect,
              selected: _selected.contains(list[i].id),
              onToggleSelect: () => _toggleSelect(list[i].id)),
        );
      },
    );
  }
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 每日回顾入口（v1.7）：今天没回顾过时在图标右上角点一个小圆点。
/// 做成 StatefulWidget 是为了把 Future 存在 state 里——如果放在 build 里现取，
/// 每次首页重建（滚动、多选、搜索）都会打一次库，而答案一天只变一次。
/// 从回顾页返回后刷新一次，点完圆点立刻消失。
class _ReviewEntry extends StatefulWidget {
  final AppDatabase db;
  const _ReviewEntry({required this.db});

  @override
  State<_ReviewEntry> createState() => _ReviewEntryState();
}

class _ReviewEntryState extends State<_ReviewEntry> {
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.db.reviewedToday();
  }

  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DailyReviewPage(db: widget.db)),
    );
    if (!mounted) return;
    // 回来后重查：用户可能刚刚点了「今天就到这」
    setState(() => _future = widget.db.reviewedToday());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snap) {
        final pending = snap.data == false;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.auto_awesome_outlined),
              tooltip: '每日回顾',
              onPressed: _open,
            ),
            if (pending)
              Positioned(
                right: 8,
                top: 8,
                child: IgnorePointer(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: T.stageDone,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 状态过滤 chip：比 ChoiceChip 更紧凑（36 高），带可选色点表示三态颜色。
/// 用 InkWell 自绘而不是 ChoiceChip——过滤行要放 4-5 个 chip + 归档入口，
/// 默认 ChoiceChip 的 padding 会挤掉最后一个。
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? dotColor;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.dotColor,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected
        ? T.brandPrimary
        : (isDark ? T.darkInkSecondary : T.inkSecondary);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? T.brandPrimary.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark ? T.darkCardAlt : T.paperCardAlt),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected
                    ? T.brandPrimary.withValues(alpha: 0.5)
                    : Colors.transparent),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              // 尺寸阶梯②：chip 内图标 13px 非 ladder 值，归到 14px 档
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

/// 搜索无结果空态
class _SearchEmpty extends StatelessWidget {  final String query;
  const _SearchEmpty({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.search_off, size: 44, color: T.inkTertiary),
        const SizedBox(height: 12),
        Text('没有包含「$query」的随记', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text('试试更短的关键词，或换成拼音首字母（如 sg → 手工）',
            style: TextStyle(fontSize: 12, color: T.inkTertiary)),
      ]),
    );
  }
}

/// 单卡：纸感卡片 + 标题/预览/时间 + 水滴三态徽章（点按切态）
/// 多选模式：点按=勾选/取消，长按仍弹单条操作
class _NoteCard extends StatelessWidget {
  final AppDatabase db;
  final Thought thought;

  /// 阶段全表按值传入（由列表级 StreamBuilder 统一订阅一次）。
  /// 原来这里收的是 Stream，每张卡自己订阅，50 条列表就是 50+ 条订阅。
  final List<Stage> stages;
  final bool multiSelect;
  final bool selected;
  final VoidCallback onToggleSelect;

  /// 当前搜索词，用于标题/预览的高亮（空串=不高亮）
  final String highlight;

  const _NoteCard({
    required this.db,
    required this.thought,
    required this.stages,
    this.highlight = '',
    this.multiSelect = false,
    this.selected = false,
    required this.onToggleSelect,
  });

  /// 预览窗口：默认取正文前 60 字；但若命中位置在窗口之外，就把窗口
  /// 挪到命中处前面若干字 —— 否则用户搜「xxx」却看到一张一个 xxx 都没有的卡，
  /// 只能怀疑搜索坏了。
  static String _previewWindow(String body, String query) {
    const width = 60;
    if (body.length <= width) return body;
    final q = query.trim();
    if (q.isEmpty) return body.substring(0, width);
    final ranges = PinyinSearch.ranges(body, q);
    if (ranges.isEmpty || ranges.first.start < width) {
      return body.substring(0, width);
    }
    final start = ranges.first.start - 20;
    final end = start + width;
    return '…${body.substring(start, end > body.length ? body.length : end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final preview = thought.content.replaceAll('\n', ' ');
    final previewText = _previewWindow(preview, highlight);
    // 时间标签：完成态显示「N 天前完成」——这是完成这件事唯一值得回看的信息，
    // 比「最近改于几点」有用；其余状态仍按更新时间显示
    final timeText = thought.completedAt != null
        ? completedLabel(thought.completedAt)
        : DateFormat('MM/dd HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(thought.updatedAt));

    // 置顶卡用品牌微色底拉开层级（创意 ①-3：色差代替加重投影）
    final pinnedBg = thought.isPinned
        ? (isDark ? T.brandContainer : T.brandContainer.withValues(alpha: 0.45))
        : (isDark ? T.darkCard : T.paperCard);

    return Card(
      elevation: 0,
      color: pinnedBg,
      // 性能守则：每卡最多单层浅投影（T.shadowCard）
      shadowColor: Colors.transparent,
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(T.rCard),
              side: const BorderSide(color: T.brandPrimary, width: 2))
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(T.rCard),
              side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05))),
      child: InkWell(
        borderRadius: BorderRadius.circular(T.rCard),
        onTap: multiSelect
            ? onToggleSelect
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        DetailPage(db: db, thought: thought))),
        onLongPress: () =>
            multiSelect ? onToggleSelect : _showActions(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: multiSelect
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 24,
                      color: selected ? T.brandPrimary : T.inkTertiary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (thought.isPinned) ...[
                                const Icon(Icons.push_pin,
                                    size: 14, color: T.stageInProgress),
                                const SizedBox(width: 4),
                              ],
                              if (thought.isArchived) ...[
                                const Icon(Icons.archive_outlined,
                                    size: 14, color: T.inkTertiary),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: HighlightText(
                                    thought.title.isEmpty
                                        ? '(无标题)'
                                        : thought.title,
                                    query: highlight,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall),
                              ),
                              const SizedBox(width: 8),
                              Text(timeText,
                                  style: const TextStyle(
                                      fontSize: 11, color: T.inkTertiary)),
                            ],
                          ),
                          if (previewText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            HighlightText(previewText,
                                query: highlight,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: T.inkSecondary)),
                          ],
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 层级一：标题行 + 右上时间（创意 ①-2 构图）
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (thought.isPinned) ...[
                          const Icon(Icons.push_pin,
                              size: 14, color: T.stageInProgress),
                          const SizedBox(width: 4),
                        ],
                        if (thought.isArchived) ...[
                          const Icon(Icons.archive_outlined,
                              size: 14, color: T.inkTertiary),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: HighlightText(
                              thought.title.isEmpty
                                  ? '(无标题)'
                                  : thought.title,
                              query: highlight,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall),
                        ),
                        const SizedBox(width: 8),
                        Text(timeText,
                            style: const TextStyle(
                                fontSize: 11, color: T.inkTertiary)),
                      ],
                    ),
                    if (previewText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      // 层级二：预览文字（置顶卡加深一档，创意 ①-3）
                      HighlightText(previewText,
                          query: highlight,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: thought.isPinned
                                  ? (isDark
                                      ? T.inkSecondary
                                      : T.inkPrimary.withValues(alpha: 0.75))
                                  : T.inkSecondary)),
                    ],
                    // 「停在这里 N 天」：只对推进中且卡满 3 天的卡出现。
                    // 这是推进这条主线上唯一带压力的信息——灵感躺着正常、
                    // 完成躺着应该，只有推进中停住才值得被看见。
                    _StuckBadge(thought: thought, stages: stages),
                    const SizedBox(height: 8),
                    // 层级三：标签 chips + 左下水滴徽章
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: StreamBuilder<List<Tag>>(
                            stream: db.watchTagsOfThought(thought.id),
                            builder: (context, tSnap) {
                              final noteTags = tSnap.data ?? const <Tag>[];
                              if (noteTags.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: noteTags
                                    .map((t) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: parseHexColor(t.color
                                                    )
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(t.name,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Color(int.parse(
                                                      t.color.replaceFirst(
                                                          '#', '0xFF'))))),
                                        ))
                                    .toList(),
                              );
                            },
                          ),
                        ),
                        // 水滴三态徽章移到左下（点击推进，44px 触控区）
                        Builder(builder: (context) {
                          final stage = stageOf(stages, thought);
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _advance(context, stage),
                            onLongPress: () => _pickStage(context, stage),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: Tooltip(
                                  message: '${stage.name} · 点击推进，长按选',
                                  child: DropBadge(
                                    kind: stage.kind,
                                    color: parseHexColor(stage.color),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// 单击推进：落定后必须给出反馈，否则用户点完不知道有没有生效。
  /// 反馈三件套——触觉（手感）+ SnackBar 带新状态名（确认）+ 撤回（误触兜底）。
  Future<void> _advance(BuildContext context, Stage current) async {
    final next = nextStageOf(stages, current.id);
    if (next == null) return;
    await db.advanceStage(thought.id);
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${current.name} → ${next.name}'),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
          label: '撤回',
          onPressed: () => db.setStage(thought.id, current.id)),
    ));
  }

  /// 长按水滴：三态直接选。比「点两圈退一步」快，也比拖动排序好理解。
  Future<void> _pickStage(BuildContext context, Stage current) async {
    if (stages.isEmpty) return;
    final picked = await showModalBottomSheet<Stage>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Row(children: [
              Text('这条算哪一步',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const Spacer(),
              Text('点一下即可换过去',
                  style: TextStyle(fontSize: 11, color: T.inkTertiary)),
            ]),
          ),
          ...stages.map((s) => ListTile(
                leading: DropBadge(
                    kind: s.kind,
                    color: parseHexColor(s.color),
                    size: 26),
                title: Text(s.name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            s.id == current.id ? FontWeight.w600 : FontWeight.w400,
                        color: s.id == current.id ? T.brandPrimary : null)),
                trailing: s.id == current.id
                    ? const Icon(Icons.check, size: 18, color: T.brandPrimary)
                    : null,
                onTap: () => Navigator.pop(ctx, s),
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null || picked.id == current.id) return;
    await db.setStage(thought.id, picked.id);
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已改为「${picked.name}」'),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
          label: '撤回',
          onPressed: () => db.setStage(thought.id, current.id)),
    ));
  }

  void _showActions(BuildContext context) {
    final stage = stageOf(stages, thought);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 推进：长按菜单里也留一个入口。水滴角标只有 44px，
          // 手小的人容易点不准；菜单里这一行带状态名，认得出当前位置。
          ListTile(
            leading: DropBadge(
                kind: stage.kind,
                color: parseHexColor(stage.color),
                size: 24),
            title: Text('状态：${stage.name}'),
            subtitle: const Text('点开可选推进 / 退回',
                style: TextStyle(fontSize: 12, color: T.inkTertiary)),
            onTap: () {
              Navigator.pop(context);
              _pickStage(context, stage);
            },
          ),
          // 一步退回：单向循环要绕两圈才能退一格，这里给一个直达反向的入口。
          // 放在菜单里而不是角标上——它比「推进」低频，不该占主触控区。
          if (prevStageOf(stages, stage.id) case final prev?
              when prev.id != stage.id)
            ListTile(
              // 尺寸阶梯②：菜单 leading 统一 22px（与 BatchActionBar 同档）
              leading: const Icon(Icons.undo, size: 22, color: T.inkSecondary),
              title: Text('退回「${prev.name}」'),
              subtitle: const Text('打错了或者还没到时候',
                  style: TextStyle(fontSize: 12, color: T.inkTertiary)),
              onTap: () async {
                Navigator.pop(context);
                await db.previousStage(thought.id);
                if (!context.mounted) return;
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('已退回「${prev.name}」'),
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                      label: '撤回',
                      onPressed: () => db.setStage(thought.id, stage.id)),
                ));
              },
            ),
          ListTile(
            // 图标规范①：菜单展示的是「当前状态」，激活（已置顶）用 filled
            leading: Icon(thought.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(thought.isPinned ? '取消置顶' : '置顶'),
            onTap: () {
              db.togglePin(thought.id);
              Navigator.pop(context);
            },
          ),
          // 归档：介于「留着」和「删掉」之间的第三态——不做了但不想删，
          // 不占列表、不进回收站（竞品分析指出 flomo/Keep 都缺这一档）
          ListTile(
            // 图标规范①：菜单展示「当前状态」——已归档显示 filled unarchive
            //（代表可执行的反向操作），未归档显示 outlined archive
            leading: Icon(thought.isArchived
                ? Icons.unarchive
                : Icons.archive_outlined),
            title: Text(thought.isArchived ? '取消归档' : '归档'),
            subtitle: Text(
              thought.isArchived ? '放回灵感流' : '从列表移出，随时可在「归档」里找回',
              style: const TextStyle(fontSize: 12, color: T.inkTertiary),
            ),
            onTap: () {
              db.setArchived(thought.id, !thought.isArchived);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: T.danger),
            title: const Text('删除', style: TextStyle(color: T.danger)),
            onTap: () {
              db.softDelete(thought.id);
              Navigator.pop(context);
            },
          ),
        ]),
      ),
    );
  }
}

/// 「停在这里 N 天」小标：只在推进中且卡满 3 天时出现。
///
/// 为什么不放在时间位而是单独一行：时间位显示的是「最近改动」，
/// 一条在推进中停了 5 天但昨天补了个字的随记，时间位看上去很新，
/// 实际上这件事一直没往下走。这两个信息必须分开看。
class _StuckBadge extends StatelessWidget {
  final Thought thought;
  final List<Stage> stages;
  const _StuckBadge({required this.thought, required this.stages});

  @override
  Widget build(BuildContext context) {
    final stage = stageOf(stages, thought);
    final label = stagnationLabel(thought.stageChangedAt, stage.kind);
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.hourglass_bottom, size: 14, color: T.warning),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: T.warning)),
      ]),
    );
  }
}

/// 批量操作栏：多选模式底部常驻（打标/移动/状态/置顶/归档/删除）
class _BatchActionBar extends StatelessWidget {
  final AppDatabase db;
  final Set<int> selected;
  final VoidCallback onDone;

  const _BatchActionBar(
      {required this.db, required this.selected, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final ids = selected.toList();
    return SafeArea(
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
              top: BorderSide(color: T.inkTertiary.withValues(alpha: 0.2))),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _ActionItem(
            icon: Icons.label_outline,
            label: '打标签',
            onTap: () => _batchTags(context, ids),
          ),
          _ActionItem(
            icon: Icons.drive_file_move_outline,
            label: '移动到',
            onTap: () => _batchMove(context, ids),
          ),
          // 批量改状态：整理时常见动作用途是「这一批都做完了」，
          // 逐条点徽章要点 N 次，这里一次落定。
          _ActionItem(
            icon: Icons.science_outlined,
            label: '状态',
            onTap: () => _batchStage(context, ids),
          ),
          _ActionItem(
            icon: Icons.push_pin_outlined,
            label: '置顶',
            onTap: () async {
              await db.batchSetPinned(ids, true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已置顶 ${ids.length} 条')));
                onDone();
              }
            },
          ),
          _ActionItem(
            icon: Icons.archive_outlined,
            label: '归档',
            onTap: () async {
              await db.batchSetArchived(ids, true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('已归档 ${ids.length} 条（「归档」里可找回）')));
                onDone();
              }
            },
          ),
          _ActionItem(
            icon: Icons.delete_outline,
            label: '删除',
            danger: true,
            onTap: () => _batchDelete(context, ids),
          ),
        ]),
      ),
    );
  }

  /// 批量打标：弹层复用标签选择 UI，追加式语义（不覆盖已有标签）
  Future<void> _batchTags(BuildContext context, List<int> ids) async {
    final allTags = await db.watchTags().first;
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet))),
      builder: (ctx) => _BatchTagSheet(allTags: allTags),
    );
    if (picked == null || picked.isEmpty) return;
    await db.batchAppendTags(ids, picked.toList());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('已为 ${ids.length} 条随记追加 ${picked.length} 个标签')));
      onDone();
    }
  }

  /// 批量改状态
  Future<void> _batchStage(BuildContext context, List<int> ids) async {
    final stages = await db.watchStages().first;
    if (!context.mounted || stages.isEmpty) return;
    final picked = await showModalBottomSheet<Stage>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Row(children: [
              Text('把 ${ids.length} 条改到',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ]),
          ),
          ...stages.map((s) => ListTile(
                leading: DropBadge(
                    kind: s.kind,
                    color: parseHexColor(s.color),
                    size: 26),
                title: Text(s.name, style: const TextStyle(fontSize: 15)),
                onTap: () => Navigator.pop(ctx, s),
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null) return;
    await db.batchSetStage(ids, picked.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('已把 ${ids.length} 条改为「${picked.name}」')));
      onDone();
    }
  }

  /// 批量移动文件夹
  Future<void> _batchMove(BuildContext context, List<int> ids) async {
    final folders = await db.watchFoldersWithCount().first;
    if (!context.mounted) return;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('移动 ${ids.length} 条到'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 0),
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
    await db.batchMoveToFolder(ids, picked == 0 ? null : picked);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已移动 ${ids.length} 条')));
      onDone();
    }
  }

  /// 批量软删（回收站可恢复）
  Future<void> _batchDelete(BuildContext context, List<int> ids) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除 ${ids.length} 条随记？'),
        content: const Text('将移入回收站，可随时恢复。'),
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
    if (ok != true) return;
    await db.batchSoftDelete(ids);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 ${ids.length} 条（回收站可恢复）')));
      onDone();
    }
  }
}

/// 批量打标弹层（与详情页单条打标不同的语义：这里只有「勾选标签」没有新建，
/// 追加式不覆盖；保持轻量。新建/管理标签请走「标签管理」页）
class _BatchTagSheet extends StatefulWidget {
  final List<Tag> allTags;
  const _BatchTagSheet({required this.allTags});

  @override
  State<_BatchTagSheet> createState() => _BatchTagSheetState();
}

class _BatchTagSheetState extends State<_BatchTagSheet> {
  final Set<int> _picked = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('选择要追加的标签', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('不会覆盖随记已有的标签',
              style: TextStyle(fontSize: 12, color: T.inkSecondary)),
          const SizedBox(height: 12),
          if (widget.allTags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('还没有标签，先在「我的 → 标签管理」创建',
                  style: TextStyle(color: T.inkSecondary))),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.allTags
                  .map((t) => FilterChip(
                        label: Text(t.name),
                        selected: _picked.contains(t.id),
                        // 图标规范①：选中态 filled
                        avatar: Icon(_picked.contains(t.id)
                            ? Icons.label
                            : Icons.label_outline,
                            size: 16,
                            color: parseHexColor(t.color)),
                        onSelected: (on) =>
                            setState(() => on ? _picked.add(t.id) : _picked.remove(t.id)),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _picked),
              child: Text(_picked.isEmpty ? '取消' : '追加到已选随记（${_picked.length} 个标签）'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _ActionItem(
      {required this.icon, required this.label, this.danger = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = danger ? T.danger : T.inkSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ]),
      ),
    );
  }
}

/// 空态：「纸 + 水滴」线稿插画 + 引导文案（创意 ④-3 复用统一 EmptyState）
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      illus: 'empty_home.png',
      title: '第一颗灵感，落进瓶子里',
      subtitle: '点右下角按钮，想到什么写什么',
    );
  }
}

/// 捕获 FAB：「接住一滴灵感」。
///
/// 形状决策（v2.4 星雨落瓶）：**保留水滴**。瓶是「积累」的容器符号，
/// 归属列表/徽章；而捕获动作本身是「一滴灵感落下来」的瞬间，水滴的
/// 「将落未落」动势比瓶更贴切——积累用瓶、捕获用水滴，两个符号各司其职。
/// 轮廓由 widgets/drop_shape.dart 的 brandDropPath() 提供，与生成器同源：
/// 尖顶 + 收腰 + 正圆底，宽高比 0.76。投影走 Material.elevation
/// （PhysicalShape 沿 shape 裁剪），不用 BoxDecoration 的方形投影。
class _DropFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _DropFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '记一条',
      child: SizedBox(
        width: 60,
        height: 60,
        child: Material(
          color: T.brandPrimary,
          elevation: 6,
          shadowColor: T.brandPrimary.withValues(alpha: 0.35),
          clipBehavior: Clip.antiAlias,
          shape: const DropShapeBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const DropShapeBorder(),
            child: const Center(
              child: Padding(
                // 正圆底的重心在 rect 高度约 0.61 处，Center 默认 0.5，
                // 下移 12 让铅笔坐在圆底中心而不是收腰处。
                padding: EdgeInsets.only(top: 12),
                // 图标规范：FAB 内白色图标用 filled edit——底色已满，
                // outlined 白线在小尺寸下会糊
                child: Icon(Icons.edit, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
