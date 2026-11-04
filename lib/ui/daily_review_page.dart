import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import '../data/app_database.dart';
import '../theme/tokens.dart';
import 'detail_page.dart';
import 'widgets/drop_badge.dart';
import 'widgets/empty_state.dart';

/// 每日回顾（v1.7，竞品分析短板③）
///
/// 设计取舍：**不做「日历式回看」，也不做「无限刷」**。
/// flomo 的每日回顾之所以留人，不是因为功能多，而是因为它每天只给很少几条、
/// 且给的是「你早就忘了的」——一次看完不费劲，看完有「哦原来我这么想过」的收获。
/// 所以这里定死三件事：
///   1. 一次只给 3 条（`count = 3`），给多了就变成待办清单，没人看完；
///   2. 同一天多次进来是同一批（数据层用日期做随机种子），否则会退化成抽奖；
///   3. 「换一批」是显式动作且有次数概念（rotation 自增），不做下拉刷新无限刷。
class DailyReviewPage extends StatefulWidget {
  final AppDatabase db;
  const DailyReviewPage({super.key, required this.db});

  @override
  State<DailyReviewPage> createState() => _DailyReviewPageState();
}

class _DailyReviewPageState extends State<DailyReviewPage> {
  static const _batchSize = 3;

  int _rotation = 0;
  late Future<List<Thought>> _future;
  Future<({int total, int done, int oldestDays})>? _statsFuture;
  late final Stream<List<Stage>> _stageStream;
  bool _reviewedBefore = false;

  @override
  void initState() {
    super.initState();
    _stageStream = widget.db.watchStages();
    _load();
    _statsFuture = widget.db.reviewStats();
    // 进页先问一次「今天是否已回顾」：进来才想起「哦我已经看过了」比
    // 一进来就被强制弹「你今天已完成」要礼貌得多
    widget.db.reviewedToday().then((v) {
      if (mounted) setState(() => _reviewedBefore = v);
    });
  }

  void _load() {
    _future = widget.db.pickDailyReview(count: _batchSize, rotation: _rotation);
  }

  void _nextBatch() {
    setState(() {
      _rotation++;
      _load();
    });
  }

  Future<void> _finish() async {
    await widget.db.markReviewedNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('今天回顾完了。明天再来翻一翻。')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('每日回顾'),
        backgroundColor: Colors.transparent,
        titleTextStyle:
            theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      body: PaperTexture(
        child: FutureBuilder<List<Thought>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data ?? const <Thought>[];
            return Column(
              children: [
                _Header(
                  statsFuture: _statsFuture,
                  dark: dark,
                  reviewed: _reviewedBefore,
                ),
                Expanded(
                  child: items.isEmpty
                      ? const EmptyState(
                          illus: 'empty_home.png',
                          title: '还没有可以回顾的随记',
                          subtitle: '今天记下的东西明天才会出现在这里。先去记一条？',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              T.pagePad, 0, T.pagePad, 8),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final t = items[i];
                            return _ReviewCard(
                              db: widget.db,
                              thought: t,
                              stageStream: _stageStream,
                              index: i,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetailPage(db: widget.db, thought: t),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (items.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          T.pagePad, 4, T.pagePad, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _nextBatch,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('换一批'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _finish,
                              child: const Text('今天就到这'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 顶部一行事实：日期 + 库有多大 + 最久的一条多少天
class _Header extends StatelessWidget {
  final Future<({int total, int done, int oldestDays})>? statsFuture;
  final bool dark;
  final bool reviewed;

  const _Header({
    required this.statsFuture,
    required this.dark,
    required this.reviewed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateFormat('M月d日 EEEE', 'zh').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.pagePad, 4, T.pagePad, 16),
      child: FutureBuilder<({int total, int done, int oldestDays})>(
        future: statsFuture,
        builder: (context, snap) {
          final s = snap.data;
          final detail = s == null || s.total == 0
              ? '这里会翻出你以前记过、但很久没碰的想法'
              : '共 ${s.total} 条 · 已完成 ${s.done} 条 · 最久的一条 ${s.oldestDays} 天前';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                today,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: dark ? T.darkInkPrimary : T.inkPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: dark ? T.darkInkSecondary : T.inkSecondary,
                ),
              ),
              if (reviewed) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: T.stageDone),
                    const SizedBox(width: 6),
                    Text(
                      '今天已经回顾过了',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: T.stageDone),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 单张回顾卡：时间标注（N 天前）在上、正文为主体、状态水滴在左下。
/// 刻意不做「编辑」——回顾是读，想改就点进详情页，别在这页开第二个编辑入口。
class _ReviewCard extends StatelessWidget {
  final AppDatabase db;
  final Thought thought;
  final Stream<List<Stage>> stageStream;
  final int index;
  final VoidCallback onTap;

  const _ReviewCard({
    required this.db,
    required this.thought,
    required this.stageStream,
    required this.index,
    required this.onTap,
  });

  /// 「N 天前」比「2026/10/12」更能触发「哦这么久没碰了」的感觉
  String get _ageLabel {
    final days = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(thought.createdAt))
        .inDays;
    if (days <= 0) return '今天记的';
    if (days == 1) return '昨天记的';
    if (days < 30) return '$days 天前记的';
    if (days < 365) return '${days ~/ 30} 个月前记的';
    return '${days ~/ 365} 年前记的';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final body = thought.content.trim().isEmpty
        ? thought.title.trim()
        : thought.content.trim();
    return Material(
      color: dark ? T.darkCard : T.paperCard,
      borderRadius: BorderRadius.circular(T.rCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(T.rCard),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(T.rCard),
            border: Border.all(
                color: (dark ? T.darkInkPrimary : T.inkPrimary)
                    .withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _ageLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: dark ? T.darkInkTertiary : T.inkTertiary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body.isEmpty ? '（空随记）' : body,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: dark ? T.darkInkPrimary : T.inkPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  StreamBuilder<List<Stage>>(
                    stream: stageStream,
                    builder: (context, snap) {
                      final stages = snap.data ?? const <Stage>[];
                      final stage = stageOf(stages, thought);
                      return DropBadge(
                          kind: stage.kind,
                          color: _hex(stage.color),
                          size: 20);
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    thought.title.trim().isEmpty
                        ? '无标题'
                        : thought.title.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: dark ? T.darkInkSecondary : T.inkSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _hex(String raw) => parseHexColor(raw, fallback: T.brandPrimary);
}
