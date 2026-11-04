import 'package:flutter/widgets.dart';

/// 一篇文章里的一个「节」——由 Markdown 标题行切出来。
///
/// 为什么用正文里的标题当分节，而不是建一张「小节表」：
/// 1. 分节本来就长在文字里，用户写 `## 步骤` 的时候就默认下面归这一节；
///    再要求他额外在另一个界面维护小节，等于让同一件事写两遍。
/// 2. 剪贴、复制、备份都天然跟着走，不需要维护「正文改了但小节没改」。
/// 3. 缺点是无法给某一节单独挂属性（截止时间、负责人）——这在个人笔记里
///    用不上，真需要时那一节本就是一条独立的随记。
class DocSection {
  /// 标题文字（去掉 # 与首尾空白）
  final String title;

  /// 层级：1 = `#`，2 = `##`，3 = `###`
  final int level;

  /// 标题所在行在全文中的起始偏移（用于跳转定位光标）
  final int offset;

  /// 这一节正文的字符数（不含标题行），用来在目录里标「有多长」
  final int bodyLength;

  const DocSection({
    required this.title,
    required this.level,
    required this.offset,
    required this.bodyLength,
  });

  bool get isUntitled => title.trim().isEmpty;
  String get displayTitle => isUntitled ? '（无标题小节）' : title;
}

/// 从正文解析出小节列表。
///
/// 识别 `#` / `##` / `###` 开头（最多三个 `#`，后接空格）；代码块
/// （``` 围起来的部分）里的 `#` 不算标题——否则一段 shell 注释就会
/// 把目录撑散。
class Outline {
  static final RegExp _heading = RegExp(r'^(#{1,3})\s+(.*)$');

  static List<DocSection> parse(String text) {
    if (text.trim().isEmpty) return const [];
    final lines = text.split('\n');
    final result = <DocSection>[];
    var offset = 0;
    var inFence = false;

    // 先把标题行位置都找出来，再回填每节的正文长度
    final starts = <({String title, int level, int offset, int lineEnd})>[];
    for (final raw in lines) {
      final lineStart = offset;
      offset += raw.length + 1; // +1 是换行符
      final trimmed = raw.trimLeft();
      if (trimmed.startsWith('```')) {
        inFence = !inFence;
        continue;
      }
      if (inFence) continue;
      final m = _heading.firstMatch(trimmed);
      if (m == null) continue;
      final level = m.group(1)!.length;
      final title = m.group(2)!.trim();
      starts.add((
        title: title,
        level: level,
        offset: lineStart,
        lineEnd: lineStart + raw.length,
      ));
    }

    for (var i = 0; i < starts.length; i++) {
      final s = starts[i];
      final bodyEnd = i + 1 < starts.length ? starts[i + 1].offset : text.length;
      // 正文从标题行的换行之后开始；末尾的空白（含分隔用的空行）不计入，
      // 否则目录里每个小节都会莫名多出几个字。
      final bodyStart = (s.lineEnd + 1).clamp(0, text.length);
      final body = bodyEnd > bodyStart
          ? text.substring(bodyStart, bodyEnd).trimRight()
          : '';
      result.add(DocSection(
        title: s.title,
        level: s.level,
        offset: s.offset,
        bodyLength: body.length,
      ));
    }
    return result;
  }

  /// 光标所在的小节（取光标之前最后一个标题）；光标在第一个标题之前返回 null。
  /// 用于「当前在读哪一节」的目录高亮。
  static DocSection? sectionAt(List<DocSection> sections, int caret) {
    DocSection? hit;
    for (final s in sections) {
      if (s.offset <= caret) {
        hit = s;
      } else {
        break;
      }
    }
    return hit;
  }

  /// 目录里的缩进：每级 12px，让层级一眼可见又不吃掉标题宽度
  static double indentOf(DocSection s) => (s.level - 1) * 12.0;

  /// 光标落到某一节时应该给的选区：行首到行尾，方便用户直接改标题
  static TextSelection selectionFor(String text, DocSection s) {
    final lineEnd = text.indexOf('\n', s.offset);
    final end = lineEnd < 0 ? text.length : lineEnd;
    return TextSelection(baseOffset: s.offset, extentOffset: end);
  }
}
