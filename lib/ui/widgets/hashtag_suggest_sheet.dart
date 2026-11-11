import 'package:flutter/material.dart';

import '../../core/pinyin_search.dart';
import '../../data/app_database.dart';
import '../../theme/tokens.dart';
import 'color_palette.dart';

/// `#片段` 标签联想条：正文里输入无空格的 `#xxx` 时浮出，选中即打标。
///
/// **设计决策**（v2.7.0）：`# ` 带空格是标题语法（Outline），`#xxx` 无空格
/// 是打标触发器，两者正交（见 `hashtagTriggerAt`）。选中标签后把 `#片段`
/// 从正文里移除——标签是元数据，不该残留在正文里；片段只是触发器不是内容。
///
/// 候选 = 现有标签按「前缀 → 子串 → 拼音（首字母/全拼）」排序，另给一条
/// 「新建“片段”」。打标动作由宿主回调完成（速记页写 pending 集合、详情页
/// 直接 setThoughtTags 追加），本组件不碰数据库写路径。
class HashtagSuggestSheet extends StatefulWidget {
  final AppDatabase db;
  final String query;

  /// 选中标签（含新建）后回调；宿主负责写库与移除正文片段
  final ValueChanged<Tag> onPicked;

  /// 关闭且未选中时回调（宿主可借此保留或清理正文片段）
  final VoidCallback? onDismissed;

  const HashtagSuggestSheet({
    super.key,
    required this.db,
    required this.query,
    required this.onPicked,
    this.onDismissed,
  });

  /// 在光标上方弹出的轻量浮层。
  static Future<void> show(
    BuildContext context, {
    required AppDatabase db,
    required String query,
    required ValueChanged<Tag> onPicked,
    VoidCallback? onDismissed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => HashtagSuggestSheet(
        db: db,
        query: query,
        onPicked: onPicked,
        onDismissed: onDismissed,
      ),
    );
  }

  @override
  State<HashtagSuggestSheet> createState() => _HashtagSuggestSheetState();
}

class _HashtagSuggestSheetState extends State<HashtagSuggestSheet> {
  Future<List<Tag>>? _tagsFuture;

  @override
  void initState() {
    super.initState();
    _tagsFuture = widget.db.watchTags().first;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: FutureBuilder<List<Tag>>(
        future: _tagsFuture,
        builder: (context, snap) {
          final all = snap.data ?? const <Tag>[];
          final items = _candidates(all, widget.query);
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 18),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Row(children: [
                  const Icon(Icons.label_outline,
                      size: 15, color: T.inkSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.query.isEmpty ? '打标签' : '标签匹配「${widget.query}」',
                      style: const TextStyle(
                          fontSize: 12, color: T.inkSecondary),
                    ),
                  ),
                ]),
              ),
              ...items,
              const SizedBox(height: 4),
            ]),
          );
        },
      ),
    );
  }

  /// 候选排序：新建项永远最后；现有标签按「名字前缀 → 名字子串 →
  /// 拼音首字母前缀 → 拼音首字母子串 → 全拼」评分，稳定且可预期。
  List<Widget> _candidates(List<Tag> all, String q) {
    final lower = q.toLowerCase();
    int score(Tag t) {
      final n = t.name.toLowerCase();
      if (lower.isNotEmpty && n.startsWith(lower)) return 0;
      if (n.contains(lower)) return 1;
      final ini = PinyinSearch.initials(t.name);
      if (ini.startsWith(lower)) return 2;
      if (ini.contains(lower)) return 3;
      if (PinyinSearch.isFullReady &&
          PinyinSearch.fullPinyin(t.name).contains(lower)) {
        return 4;
      }
      return 9; // 不匹配：不显示
    }

    final matched = all.where((t) => score(t) < 9).toList()
      ..sort((a, b) {
        final byScore = score(a).compareTo(score(b));
        if (byScore != 0) return byScore;
        return a.name.compareTo(b.name);
      });
    final tiles = matched
        .take(5)
        .map((t) => _tile(t))
        .toList();
    final canCreate =
        q.trim().isNotEmpty && q.trim().length <= 20 && !all.any((t) => t.name == q.trim());
    if (canCreate) {
      tiles.add(_createTile(q.trim()));
    }
    if (tiles.isEmpty) {
      tiles.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text('输入名字后回车创建', style: TextStyle(fontSize: 12, color: T.inkTertiary)),
      ));
    }
    return tiles;
  }

  Widget _tile(Tag t) {
    final color = hexToColor(t.color);
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        widget.onPicked(t);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          Icon(Icons.label, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(t.name, style: const TextStyle(fontSize: 14))),
        ]),
      ),
    );
  }

  Widget _createTile(String name) {
    return InkWell(
      onTap: () async {
        final tag = await widget.db.createTag(name);
        if (!mounted) return;
        Navigator.of(context).pop();
        if (tag != null) widget.onPicked(tag);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          const Icon(Icons.add_circle_outline, size: 16, color: T.brandPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('新建标签「$name」',
                style: const TextStyle(fontSize: 14, color: T.brandPrimary)),
          ),
        ]),
      ),
    );
  }
}
