import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 轻量 Markdown 预览渲染器
///
/// 为什么自己写而不引 flutter_markdown：
/// 1. flutter_markdown 已进入维护停滞（官方建议改用 markdown_widget 之类），
///    引进来就得跟着社区包的生命周期走；
/// 2. 本应用只需要「能看懂自己写的东西」这一档能力——标题/列表/待办/引用/
///    强调/分割线，不需要表格、脚注、HTML 内嵌；
/// 3. 主题要跟着纸感 Token 走，第三方包的主题适配比自写更费事。
///
/// 支持范围（与服务端无关的纯本地解析）：
///   # ## ###  标题
///   - 1.      无序/有序列表
///   - [ ] [x] 待办
///   >         引用
///   ---       分割线
///   **b** *i* ~~s~~ `code`
class MarkdownPreview extends StatelessWidget {
  final String text;
  const MarkdownPreview(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (text.trim().isEmpty) {
      return Center(
        child: Text('空白的纸',
            style: TextStyle(fontSize: 13, color: T.inkTertiary)),
      );
    }
    final blocks = _parseBlocks(text);
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: blocks.length,
        itemBuilder: (context, i) => _buildBlock(context, blocks[i], dark),
      ),
    );
  }

  Widget _buildBlock(BuildContext context, _Block b, bool dark) {
    switch (b.type) {
      case _BlockType.h1:
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: _rich(b.content, size: 22, weight: FontWeight.w700, dark: dark),
        );
      case _BlockType.h2:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: _rich(b.content, size: 18, weight: FontWeight.w600, dark: dark),
        );
      case _BlockType.h3:
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: _rich(b.content, size: 16, weight: FontWeight.w600, dark: dark),
        );
      case _BlockType.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: T.brandPrimary.withValues(alpha: 0.45), width: 3)),
            color: dark ? T.darkCardAlt : T.paperCardAlt,
          ),
          child: _rich(b.content, size: 14, dark: dark, color: T.inkSecondary),
        );
      case _BlockType.hr:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1, color: T.inkTertiary.withValues(alpha: 0.3)),
        );
      case _BlockType.bullet:
        return _listRow(context, bullet: '•', content: b.content, dark: dark);
      case _BlockType.number:
        return _listRow(context, bullet: '${b.ordinal}.', content: b.content, dark: dark);
      case _BlockType.todo:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Icon(
                b.checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: b.checked ? T.stageDone : T.inkTertiary,
              ),
            ),
            Expanded(
              child: _rich(b.content,
                  size: 15,
                  dark: dark,
                  strike: b.checked,
                  color: b.checked ? T.inkTertiary : null),
            ),
          ]),
        );
      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: _rich(b.content, size: 15, dark: dark),
        );
    }
  }

  Widget _listRow(BuildContext context,
      {required String bullet, required String content, required bool dark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 22,
          child: Text(bullet,
              style: TextStyle(fontSize: 14, color: T.inkSecondary, height: 1.7)),
        ),
        Expanded(child: _rich(content, size: 15, dark: dark)),
      ]),
    );
  }

  /// 行内强调解析。嵌套只做一层（`**粗 *斜* **` 里的斜体不处理）——
  /// 单层足够覆盖随手记的用法，多层会让解析器复杂度不成比例地上升。
  Widget _rich(String s,
      {required double size,
      FontWeight weight = FontWeight.w400,
      required bool dark,
      Color? color,
      bool strike = false}) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|~~(.+?)~~|`(.+?)`|\*(.+?)\*');
    var idx = 0;
    for (final m in pattern.allMatches(s)) {
      if (m.start > idx) {
        spans.add(TextSpan(text: s.substring(idx, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
            text: m.group(2),
            style: const TextStyle(decoration: TextDecoration.lineThrough)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            text: m.group(3),
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: size - 1,
                backgroundColor: dark ? T.darkCardAlt : T.paperCardAlt)));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(
            text: m.group(4), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      idx = m.end;
    }
    if (idx < s.length) spans.add(TextSpan(text: s.substring(idx)));

    return Text.rich(
      TextSpan(
        children: spans,
        style: TextStyle(
          fontSize: size,
          height: 1.7,
          fontWeight: weight,
          color: color,
          decoration: strike ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }

  // ───────────────────── 解析 ─────────────────────

  static List<_Block> _parseBlocks(String text) {
    final lines = text.split('\n');
    final out = <_Block>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      final t = line.trimLeft();

      if (t.isEmpty) {
        out.add(_Block(_BlockType.paragraph, ''));
        continue;
      }
      if (RegExp(r'^-{3,}$').hasMatch(t) || RegExp(r'^\*{3,}$').hasMatch(t)) {
        out.add(_Block(_BlockType.hr, ''));
        continue;
      }
      final h = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(t);
      if (h != null) {
        final level = h.group(1)!.length;
        out.add(_Block(
            level == 1
                ? _BlockType.h1
                : level == 2
                    ? _BlockType.h2
                    : _BlockType.h3,
            h.group(2)!));
        continue;
      }
      final todo = RegExp(r'^-\s+\[([ xX])\]\s*(.*)$').firstMatch(t);
      if (todo != null) {
        out.add(_Block(_BlockType.todo, todo.group(2)!,
            checked: todo.group(1)!.toLowerCase() == 'x'));
        continue;
      }
      if (t.startsWith('> ')) {
        out.add(_Block(_BlockType.quote, t.substring(2)));
        continue;
      }
      final num = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(t);
      if (num != null) {
        out.add(_Block(_BlockType.number, num.group(2)!,
            ordinal: int.tryParse(num.group(1)!) ?? 1));
        continue;
      }
      if (RegExp(r'^[-*]\s+').hasMatch(t)) {
        out.add(_Block(_BlockType.bullet, t.replaceFirst(RegExp(r'^[-*]\s+'), '')));
        continue;
      }
      out.add(_Block(_BlockType.paragraph, line));
    }
    // 连续空行压成一个
    final cleaned = <_Block>[];
    for (final b in out) {
      if (b.type == _BlockType.paragraph &&
          b.content.isEmpty &&
          cleaned.isNotEmpty &&
          cleaned.last.type == _BlockType.paragraph &&
          cleaned.last.content.isEmpty) {
        continue;
      }
      cleaned.add(b);
    }
    return cleaned;
  }
}

enum _BlockType { paragraph, h1, h2, h3, bullet, number, todo, quote, hr }

class _Block {
  final _BlockType type;
  final String content;
  final bool checked;
  final int ordinal;
  const _Block(this.type, this.content,
      {this.checked = false, this.ordinal = 1});
}
