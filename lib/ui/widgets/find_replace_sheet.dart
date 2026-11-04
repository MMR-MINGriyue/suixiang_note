import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 查找替换的结果：由调用方决定怎么应用到文本
class FindReplaceResult {
  final String text;
  final int replaced;
  final int firstIndex;
  const FindReplaceResult(this.text, this.replaced, this.firstIndex);
}

/// 查找替换面板
///
/// 为什么做成半屏面板并实时显示「第 N / 共 M 处」：
/// 长文里替换是不可逆的（虽然有撤销），用户必须能先确认「找的是不是这些」。
/// 只给一个「全部替换」按钮而不显示命中数，等于让用户闭眼点。
class FindReplaceSheet extends StatefulWidget {
  final String text;
  const FindReplaceSheet({super.key, required this.text});

  /// 返回 (新文本, 替换处数, 首个命中位置)；取消返回 null
  static Future<FindReplaceResult?> open(BuildContext context, String text) {
    return showModalBottomSheet<FindReplaceResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: FindReplaceSheet(text: text),
      ),
    );
  }

  @override
  State<FindReplaceSheet> createState() => _FindReplaceSheetState();
}

class _FindReplaceSheetState extends State<FindReplaceSheet> {
  final _find = TextEditingController();
  final _replace = TextEditingController();
  bool _caseSensitive = false;
  List<int> _hits = const [];
  int _cursor = 0;

  @override
  void initState() {
    super.initState();
    _find.addListener(_recount);
  }

  @override
  void dispose() {
    _find.dispose();
    _replace.dispose();
    super.dispose();
  }

  void _recount() {
    final q = _find.text;
    if (q.isEmpty) {
      setState(() {
        _hits = const [];
        _cursor = 0;
      });
      return;
    }
    final hay = _caseSensitive ? widget.text : widget.text.toLowerCase();
    final needle = _caseSensitive ? q : q.toLowerCase();
    final hits = <int>[];
    var from = 0;
    while (true) {
      final i = hay.indexOf(needle, from);
      if (i < 0) break;
      hits.add(i);
      from = i + needle.length;
      if (hits.length > 5000) break; // 防病态输入把主线程拖死
    }
    setState(() {
      _hits = hits;
      _cursor = 0;
    });
  }

  /// 替换当前这一处，并把游标推到下一个
  void _replaceOne() {
    final q = _find.text;
    if (q.isEmpty || _hits.isEmpty || _cursor >= _hits.length) return;
    final at = _hits[_cursor];
    final newText = widget.text.replaceRange(at, at + q.length, _replace.text);
    // 替换后重新计数，游标停在原位置（也就是下一处的新起点）
    Navigator.pop(
        context, FindReplaceResult(newText, 1, at));
  }

  /// 全部替换：一次算完，返回结果
  void _replaceAll() {
    final q = _find.text;
    if (q.isEmpty || _hits.isEmpty) return;
    final hay = _caseSensitive ? widget.text : widget.text.toLowerCase();
    final needle = _caseSensitive ? q : q.toLowerCase();
    final buf = StringBuffer();
    var last = 0;
    var count = 0;
    var from = 0;
    while (true) {
      final i = hay.indexOf(needle, from);
      if (i < 0) break;
      buf.write(widget.text.substring(last, i));
      buf.write(_replace.text);
      last = i + q.length;
      from = last;
      count++;
    }
    buf.write(widget.text.substring(last));
    Navigator.pop(context, FindReplaceResult(buf.toString(), count, _hits.isEmpty ? -1 : _hits.first));
  }

  @override
  Widget build(BuildContext context) {
    final total = _hits.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('查找替换', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (_find.text.isNotEmpty)
              Text(
                total == 0 ? '没有找到' : '${(_cursor + 1).clamp(1, total)} / $total 处',
                style: TextStyle(
                  fontSize: 12,
                  color: total == 0 ? T.danger : T.inkSecondary,
                ),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _find,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '查找',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _find.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _find.clear(),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _replace,
            decoration: const InputDecoration(
              hintText: '替换为（留空即删除）',
              isDense: true,
              prefixIcon: Icon(Icons.swap_horiz, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(
              value: _caseSensitive,
              visualDensity: VisualDensity.compact,
              onChanged: (v) => setState(() {
                _caseSensitive = v ?? false;
                _recount();
              }),
            ),
            const Text('区分大小写', style: TextStyle(fontSize: 13)),
            const Spacer(),
            if (total > 0)
              TextButton(
                onPressed: _replaceOne,
                child: const Text('替换这一处'),
              ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: total == 0 ? null : _replaceAll,
                child: Text(total == 0 ? '全部替换' : '全部替换 $total 处'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
