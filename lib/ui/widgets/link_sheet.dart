import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/tokens.dart';
import '../detail_page.dart';
import 'app_feedback.dart';

/// 关联面板：列出当前随记的所有关联，并允许新建/删除。
///
/// 三种关系不是凑数——它们对应三种真实心智：
/// - **相关**：说不清关系但就是有关（默认，最常用）
/// - **依赖**：这件事要先等那件事（有方向，画图谱时是箭头）
/// - **属于**：这件事是那件大事的一部分（有方向，构成层级感）
/// 只给「相关」一种会丢失方向信息，图谱就退化成一堆无线段；
/// 给太多类型（前置/后置/因果/参考…）则用户每次都要停下来想选哪个。
class LinkSheet extends StatefulWidget {
  final AppDatabase db;
  final Thought thought;
  const LinkSheet({super.key, required this.db, required this.thought});

  static Future<void> open(BuildContext context, AppDatabase db, Thought t) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LinkSheet(db: db, thought: t),
    );
  }

  @override
  State<LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<LinkSheet> {
  /// 正在选目标（null = 显示列表视图）
  bool _picking = false;
  String _kind = 'related';
  final _searchCtrl = TextEditingController();
  String _query = '';
  // 架构复审 P2-7：300ms 防抖——原来每个按键都 setState 改 _query，
  // build 里的 watchFeed(query: _query) 随之新建 Stream 退订重订
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
        decoration: BoxDecoration(
          color: dark ? T.darkBg : T.paperBg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(T.rSheet)),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(children: [
              if (_picking)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => setState(() => _picking = false),
                ),
              Expanded(
                child: Text(_picking ? '选择要关联的随记' : '关联',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              if (!_picking)
                TextButton.icon(
                  onPressed: () => setState(() => _picking = true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建关联'),
                ),
            ]),
          ),
          Flexible(
            child: _picking ? _buildPicker(dark) : _buildList(dark),
          ),
        ]),
      ),
    );
  }

  // ───────────── 已有列表 ─────────────

  Widget _buildList(bool dark) {
    return StreamBuilder<List<LinkedThought>>(
      stream: widget.db.watchLinksOf(widget.thought.id),
      builder: (context, snap) {
        final list = snap.data ?? const <LinkedThought>[];
        if (snap.connectionState != ConnectionState.done && list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(children: [
              Icon(Icons.link_off,
                  size: 30, color: T.inkTertiary.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              const Text('还没跟任何随记连起来',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('点右上「新建关联」把这条接到别处，\n图谱里就会多一条线。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: dark ? T.darkInkSecondary : T.inkSecondary)),
            ]),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: list.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: 16,
            color: T.inkTertiary.withValues(alpha: 0.12),
          ),
          itemBuilder: (context, i) {
            final item = list[i];
            return ListTile(
              leading: Icon(_kindIcon(item.link.kind),
                  size: 20, color: _kindColor(item.link.kind)),
              title: Text(
                item.other.title.trim().isEmpty
                    ? '（无标题）'
                    : item.other.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5),
              ),
              subtitle: Text(
                '${item.kindLabel}${item.outgoing ? '' : '（它指向这条）'}',
                style: const TextStyle(fontSize: 11, color: T.inkTertiary),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: '取消关联',
                onPressed: () async {
                  final ok = await AppFeedback.confirmDanger(
                    context,
                    title: '取消关联',
                    content: '只断开这两条随记的连线，不会删除任何一条随记。',
                    confirmLabel: '取消关联',
                  );
                  if (!ok || !context.mounted) return;
                  await widget.db.unlinkThought(item.link.id);
                  if (!context.mounted) return;
                  AppFeedback.success(context, '关联已取消');
                },
              ),
              onTap: () => _openOther(item.other),
            );
          },
        );
      },
    );
  }

  // ───────────── 选择目标 ─────────────

  Widget _buildPicker(bool dark) {
    return Column(children: [
      // 关系类型选择
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          for (final k in const ['related', 'depends', 'parent']) ...[
            Expanded(
              child: _KindChip(
                kind: k,
                selected: _kind == k,
                onTap: () => setState(() => _kind = k),
              ),
            ),
            if (k != 'parent') const SizedBox(width: 8),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _query = v.trim());
            });
          },
          decoration: InputDecoration(
            isDense: true,
            hintText: '搜索目标随记',
            prefixIcon: const Icon(Icons.search, size: 18),
            filled: true,
            fillColor: dark ? T.darkCardAlt : T.paperCardAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Flexible(
        child: StreamBuilder<List<Thought>>(
          stream: widget.db.watchFeed(
              query: _query.isEmpty ? null : _query),
          builder: (context, snap) {
            final all = snap.data ?? const <Thought>[];
            // 不能关联自己
            final candidates =
                all.where((t) => t.id != widget.thought.id).toList();
            if (candidates.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(28),
                child: Text('没有可选的随记',
                    style: TextStyle(fontSize: 12.5, color: T.inkTertiary)),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: candidates.length,
              itemBuilder: (context, i) {
                final t = candidates[i];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.description_outlined,
                      size: 18, color: T.inkTertiary),
                  title: Text(
                    t.title.trim().isEmpty ? '（无标题）' : t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () => _create(t),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _create(Thought target) async {
    final ok = await widget.db.linkThoughts(
        widget.thought.id, target.id, kind: _kind);
    if (!mounted) return;
    if (ok) {
      setState(() => _picking = false);
      AppFeedback.success(context,
          '已关联「${target.title.trim().isEmpty ? '无标题' : target.title}」');
    } else {
      AppFeedback.success(context, '这条已经关联过了');
    }
  }

  Future<void> _openOther(Thought t) async {
    final nav = Navigator.of(context);
    nav.pop();
    // Dart 允许循环 import：detail_page 引这里是为了打开面板，这里引
    // detail_page 是为了跳到对端随记，两者互不参与对方的初始化。
    await nav.push(MaterialPageRoute(
        builder: (_) => DetailPage(db: widget.db, thought: t)));
  }

  static IconData _kindIcon(String kind) => switch (kind) {
        'depends' => Icons.arrow_forward,
        'parent' => Icons.account_tree_outlined,
        _ => Icons.link,
      };

  static Color _kindColor(String kind) => switch (kind) {
        'depends' => T.stageDone,
        'parent' => T.warning,
        _ => T.brandPrimary,
      };
}

class _KindChip extends StatelessWidget {
  final String kind;
  final bool selected;
  final VoidCallback onTap;
  const _KindChip(
      {required this.kind, required this.selected, required this.onTap});

  static const _labels = {
    'related': ('相关', '说不清但有关'),
    'depends': ('依赖', '这条要先等它'),
    'parent': ('属于', '是它的一部分'),
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (label, hint) = _labels[kind]!;
    final color = _LinkSheetState._kindColor(kind);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: dark ? 0.22 : 0.12)
              : (dark ? T.darkCardAlt : T.paperCardAlt),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : null)),
          const SizedBox(height: 2),
          Text(hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: T.inkTertiary)),
        ]),
      ),
    );
  }
}

/// 从关联列表点进对端随记，直接复用 DetailPage。
/// （Dart 允许循环 import：detail_page 引这里是为了打开面板，
/// 这里引 detail_page 是为了跳到对端，两者互不参与对方初始化。）
