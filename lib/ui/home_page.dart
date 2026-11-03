import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../theme/tokens.dart';
import 'quick_capture_sheet.dart';
import 'detail_page.dart';
import 'trash_page.dart';

/// 首页「灵感流」：搜索栏 + 置顶优先列表；单击水滴切三态（主线 C：1 次点击推进）
class HomePage extends StatefulWidget {
  final AppDatabase db;
  const HomePage({super.key, required this.db});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _query = '';
  Timer? _debounce;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('随想'),
        backgroundColor: Colors.transparent,
        titleTextStyle:
            theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        actions: [
          // 回收站入口（软删数据不再只有「清空」一条路）
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '回收站',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => TrashPage(db: db))),
          ),
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
                hintText: '搜索随记…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Thought>>(
              stream: db.watchList(query: _query.isEmpty ? null : _query),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return _query.isEmpty
                      ? const _EmptyState()
                      : _SearchEmpty(query: _query);
                }
                return ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(T.pagePad, 8, T.pagePad, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _NoteCard(
                      db: db,
                      thought: list[i],
                      stagesStream: db.watchStages()),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => QuickCaptureSheet.open(context, db),
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

/// 搜索无结果空态
class _SearchEmpty extends StatelessWidget {
  final String query;
  const _SearchEmpty({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.search_off, size: 44, color: T.inkTertiary),
        const SizedBox(height: 12),
        Text('没有包含「$query」的随记', style: Theme.of(context).textTheme.titleMedium),
      ]),
    );
  }
}

/// 单卡：纸感卡片 + 标题/预览/时间 + 水滴三态徽章（点按切态）
class _NoteCard extends StatelessWidget {
  final AppDatabase db;
  final Thought thought;
  final Stream<List<Stage>> stagesStream;

  const _NoteCard({required this.db, required this.thought, required this.stagesStream});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = thought.content.replaceAll('\n', ' ');
    final previewText = preview.length > 60 ? preview.substring(0, 60) : preview;
    final timeText = DateFormat('MM/dd HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(thought.updatedAt));

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(T.rCard),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    DetailPage(db: db, thought: thought))),
        onLongPress: () => _showActions(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 水滴三态徽章（点击推进）
              StreamBuilder<List<Stage>>(
                stream: stagesStream,
                builder: (context, sSnap) {
                  final stages = sSnap.data ?? const <Stage>[];
                  Stage stage;
                  try {
                    stage = stages.firstWhere((s) => s.id == thought.stageId);
                  } on StateError {
                    stage = Stage(
                        id: 1,
                        name: '灵感',
                        kind: 'inspiration',
                        color: '#A8B9E6',
                        position: 1.0,
                        isSystem: true,
                        createdAt: 0);
                  }
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => db.advanceStage(thought.id),
                    child: Tooltip(
                      message: '${stage.name} · 点击推进',
                      child: _DropBadge(
                        kind: stage.kind,
                        color: Color(int.parse(stage.color.replaceFirst('#', '0xFF'))),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (thought.isPinned) ...[
                        const Icon(Icons.push_pin, size: 12, color: T.stageInProgress),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(thought.title.isEmpty ? '(无标题)' : thought.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall),
                      ),
                    ]),
                    if (previewText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(previewText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: T.inkSecondary)),
                    ],
                    const SizedBox(height: 6),
                    Text(timeText, style: const TextStyle(fontSize: 11, color: T.inkTertiary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(thought.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
            title: Text(thought.isPinned ? '取消置顶' : '置顶'),
            onTap: () {
              db.togglePin(thought.id);
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

/// 水滴徽章：灵感=空心轮廓 / 推进中=半实心 / 完成=实心
class _DropBadge extends StatelessWidget {
  final String kind;
  final Color color;
  const _DropBadge({required this.kind, required this.color});

  @override
  Widget build(BuildContext context) {
    Widget drop;
    switch (kind) {
      case 'in_progress':
        drop = CustomPaint(painter: _HalfDrop(color: color), size: const Size(32, 32));
        break;
      case 'done':
        drop = Icon(Icons.water_drop, size: 28, color: color);
        break;
      default:
        drop = CustomPaint(painter: _OutlineDrop(color), size: const Size(32, 32));
    }
    return SizedBox(width: 32, height: 32, child: Center(child: drop));
  }
}

class _OutlineDrop extends CustomPainter {
  final Color color;
  const _OutlineDrop(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
        _dropPath(size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _OutlineDrop old) => old.color != color;
}

class _HalfDrop extends CustomPainter {
  final Color color;
  _HalfDrop({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _dropPath(size);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2));
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HalfDrop old) => old.color != color;
}

Path _dropPath(Size size) {
  final w = size.width, h = size.height;
  return Path()
    ..moveTo(w / 2, 2)
    ..cubicTo(w / 2, 2, w - 4, h * 0.42, w - 4, h * 0.62)
    ..arcToPoint(Offset(4, h * 0.62), radius: Radius.circular((w - 8) / 2), clockwise: false)
    ..cubicTo(4, h * 0.42, w / 2, 2, w / 2, 2)
    ..close();
}

/// 空态：悬落水滴 + 引导文案
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CustomPaint(
            painter: _OutlineDrop(T.stageInspiration), size: Size(48, 48)),
        const SizedBox(height: 16),
        Text('第一个念头，从一颗水滴开始', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text('点右下角按钮，想到什么写什么',
            style: theme.textTheme.bodySmall?.copyWith(color: T.inkSecondary)),
      ]),
    );
  }
}
