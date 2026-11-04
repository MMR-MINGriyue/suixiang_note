import 'package:flutter/widgets.dart';

/// 编辑动作的产物：换过后的文本 + 应该恢复到的选区。
///
/// 为什么把「新选区」一起返回：所有格式操作都必须改光标位置，否则用户点完
/// 工具条光标会跳到末尾，下一次打字就写错地方。这是这类工具条最容易漏的一环。
class EditResult {
  final String text;
  final TextSelection selection;

  const EditResult(this.text, this.selection);
}

/// 一种格式的定义。
///
/// [inline] 非空表示行内包裹型（粗体/斜体…），[linePrefixes] 非空表示
/// 行首前缀型（标题/列表…）。两者互斥。
class MdFormat {
  final String id;
  final String label;
  final List<String> inline; // 对称标记，如 ['**','**']
  final List<String> linePrefixes; // 同族前缀，互相替换而非叠加
  final String placeholder;

  const MdFormat({
    required this.id,
    required this.label,
    this.inline = const [],
    this.linePrefixes = const [],
    this.placeholder = '',
  });

  bool get isInline => inline.isNotEmpty;
}

/// 工具条上的全部格式。顺序即展示顺序（先字重，再块级）。
const List<MdFormat> kFormats = [
  MdFormat(id: 'bold', label: 'B', inline: ['**', '**'], placeholder: '加粗'),
  MdFormat(id: 'italic', label: 'I', inline: ['*', '*'], placeholder: '斜体'),
  MdFormat(id: 'strike', label: 'S', inline: ['~~', '~~'], placeholder: '删除线'),
  MdFormat(id: 'code', label: '</>', inline: ['`', '`'], placeholder: 'code'),
  MdFormat(id: 'h1', label: 'H1', linePrefixes: ['# ', '## ', '### ']),
  MdFormat(id: 'bullet', label: '•', linePrefixes: ['- ', '1. ', '- [ ] ', '- [x] ']),
  MdFormat(id: 'quote', label: '❝', linePrefixes: ['> ']),
];

/// Markdown 文本变换。全是纯函数：输入文本+选区，输出新文本+新选区，
/// 不碰数据库也不碰 Controller，所以可以单独测到每个边界。
class MarkdownEdit {
  // ───────────────────────── 行内包裹 ─────────────────────────

  /// 行内标记切换：有选区就包裹，无选区插入占位符并选中它。
  /// 若选区紧邻的标记已存在，则视为「取消」，把标记去掉。
  static EditResult toggleInline(
      String text, TextSelection sel, List<String> markers, String placeholder) {
    if (markers.length != 2) {
      return EditResult(text, sel);
    }
    final open = markers[0];
    final close = markers[1];
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    final hasSel = end > start;

    // 情况一：选区本身已带标记 → 去掉
    if (hasSel) {
      final selected = text.substring(start, end);
      if (selected.length > open.length + close.length &&
          selected.startsWith(open) &&
          selected.endsWith(close)) {
        final inner = selected.substring(open.length, selected.length - close.length);
        final newText = text.replaceRange(start, end, inner);
        return EditResult(newText, TextSelection(baseOffset: start, extentOffset: start + inner.length));
      }
    }

    // 情况二：选区外侧紧邻标记 → 去掉（用户选中内容后想取消格式）
    if (hasSel &&
        start >= open.length &&
        end + close.length <= text.length &&
        text.substring(start - open.length, start) == open &&
        text.substring(end, end + close.length) == close) {
      final inner = text.substring(start, end);
      final newText = text.replaceRange(
          start - open.length, end + close.length, inner);
      final newStart = start - open.length;
      return EditResult(
          newText, TextSelection(baseOffset: newStart, extentOffset: newStart + inner.length));
    }

    // 情况三：正常包裹
    if (hasSel) {
      final selected = text.substring(start, end);
      final newText = '${text.substring(0, start)}$open$selected$close${text.substring(end)}';
      return EditResult(
        newText,
        TextSelection(baseOffset: start + open.length, extentOffset: end + open.length),
      );
    }

    // 情况四：无选区，插入占位
    final newText = '${text.substring(0, start)}$open$placeholder$close${text.substring(start)}';
    return EditResult(
      newText,
      TextSelection(baseOffset: start + open.length, extentOffset: start + open.length + placeholder.length),
    );
  }

  // ───────────────────────── 行首前缀 ─────────────────────────

  /// 行首前缀切换。
  ///
  /// 三类前缀行为不同，不能一概「有就剥」：
  /// - **待办**：整块都是待办行时翻转勾选态；混有普通行时都变成未勾选待办。
  ///   （若按「有就剥」，点第二次「待办」会把列表变回普通文字，用户的预期是勾上）
  /// - **有序**：整块都已有编号时去掉编号；否则逐行递增编号。
  /// - **其它**（无序/引用/标题/空前缀=清除）：整块都已带该前缀时去掉，
  ///   否则把族内其它前缀替换掉——不能叠加，否则会得到「- 1. xxx」。
  static EditResult toggleLinePrefix(
      String text, TextSelection sel, String prefix, List<String> family) {
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);

    final lineStart = _lineStart(text, start);
    // 选区末尾恰在行首时，不应把下一行也算进来（拖到下一行开头是常见操作）
    final lineEnd = _lineEnd(text, end > start && _isLineStart(text, end) ? end - 1 : end);

    final block = text.substring(lineStart, lineEnd);
    final lines = block.split('\n');

    final isCheckbox = prefix == '- [x] ' || prefix == '- [ ] ';
    final isOrdered = prefix == '1. ';
    final stripOnly = prefix.isEmpty;

    // 每行的缩进与去掉族内前缀后的正文
    final leads = <String>[];
    final bodies = <String>[];
    for (final l in lines) {
      final indent = l.length - l.trimLeft().length;
      leads.add(l.substring(0, indent));
      bodies.add(_stripFamily(l.substring(indent), family));
    }

    // 每行是否是待办行，以及是否已勾选
    final checkboxState = <bool?>[];
    for (final l in lines) {
      final m = RegExp(r'^\s*- \[([ x])\] ').firstMatch(l);
      checkboxState.add(m == null ? null : m.group(1) == 'x');
    }
    final allCheckbox = checkboxState.every((s) => s != null);

    final allOrdered = lines.every((l) => RegExp(r'^\s*\d+\.\s').hasMatch(l));
    final allHavePlain = !stripOnly && lines.every((l) => l.trimLeft().startsWith(prefix));

    final buf = StringBuffer();
    var numbered = 1;
    for (var i = 0; i < lines.length; i++) {
      final lead = leads[i];
      final body = bodies[i];
      String out;

      if (stripOnly) {
        out = '$lead$body';
      } else if (isCheckbox) {
        if (allCheckbox) {
          // 全部是待办：整体翻转
          out = '$lead${checkboxState[i]! ? '- [ ] ' : '- [x] '}$body';
        } else {
          out = '$lead- [ ] $body';
        }
      } else if (isOrdered) {
        out = allOrdered ? '$lead$body' : '$lead$numbered. $body';
        if (!allOrdered) numbered++;
      } else {
        out = allHavePlain ? '$lead$body' : '$lead$prefix$body';
      }

      if (i > 0) buf.write('\n');
      buf.write(out);
    }

    final newBlock = buf.toString();
    final newText = text.replaceRange(lineStart, lineEnd, newBlock);
    return EditResult(
      newText,
      TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + newBlock.length,
      ),
    );
  }

  /// 插入独立成行的内容（分割线）——确保前后有换行，否则 --- 会粘在正文里
  static EditResult insertLine(String text, TextSelection sel, String line) {
    final at = sel.start.clamp(0, text.length);
    final before = text.substring(0, at);
    final needsLeading = before.isNotEmpty && !before.endsWith('\n');
    final insert = '${needsLeading ? '\n' : ''}$line\n';
    final newText = '${text.substring(0, at)}$insert${text.substring(at)}';
    final caret = at + insert.length;
    return EditResult(newText, TextSelection.collapsed(offset: caret));
  }

  /// 在光标处插入一段文本（时间戳等），有选区时替换选区
  static EditResult insertText(String text, TextSelection sel, String snippet) {
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    final newText = '${text.substring(0, start)}$snippet${text.substring(end)}';
    final caret = start + snippet.length;
    return EditResult(newText, TextSelection.collapsed(offset: caret));
  }

  // ───────────────────────── 内部工具 ─────────────────────────

  static bool _isLineStart(String text, int pos) =>
      pos == 0 || (pos > 0 && pos < text.length && text[pos - 1] == '\n');

  static int _lineStart(String text, int pos) {
    if (pos <= 0) return 0;
    final idx = text.lastIndexOf('\n', pos - 1);
    return idx < 0 ? 0 : idx + 1;
  }

  static int _lineEnd(String text, int pos) {
    if (pos >= text.length) return text.length;
    final idx = text.indexOf('\n', pos);
    return idx < 0 ? text.length : idx;
  }

  /// 去掉族内任意一个前缀（按长度倒序匹配，避免 '- ' 吃掉 '- [ ] '）。
  ///
  /// 前缀自带尾随空格，所以要连空格一起剥——否则「- foo」剥成「 foo」，
  /// 再套新前缀就得到「-  foo」两个空格。
  /// 传入的 [body] 已去掉缩进（缩进由调用方保留，避免标题行缩进被吃掉）。
  static String _stripFamily(String body, List<String> family) {
    final numbered = RegExp(r'^\d+\.\s').firstMatch(body);
    if (numbered != null) return body.substring(numbered.end);
    final sorted = [...family]..sort((a, b) => b.length.compareTo(a.length));
    for (final p in sorted) {
      if (p.isNotEmpty && body.startsWith(p)) {
        return body.substring(p.length);
      }
    }
    return body;
  }
}
