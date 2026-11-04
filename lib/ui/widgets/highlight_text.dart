import 'package:flutter/material.dart';

import '../../core/pinyin_search.dart';
import '../../theme/tokens.dart';

/// 搜索结果高亮：把查询命中的片段（字面 **或拼音首字母**）染色加粗。
///
/// 与 [PinyinSearch.ranges] 共用同一套定位逻辑，所以「高亮的范围」与
/// 「为什么这条被搜出来」永远一致 —— 若各写一份，迟早出现「搜到了但一行都没染色」
/// 的尴尬（用户会以为搜错了）。
class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color highlightColor;

  const HighlightText(
    this.text, {
    super.key,
    required this.query,
    this.style,
    this.maxLines,
    this.overflow,
    this.highlightColor = T.brandPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final ranges = PinyinSearch.ranges(text, query);
    if (ranges.isEmpty) {
      return Text(text,
          style: style, maxLines: maxLines, overflow: overflow);
    }

    final base = style ?? DefaultTextStyle.of(context).style;
    // 高亮用「同色更重」而不是换色：正文里插几段亮蓝会让纸感卡片显得花；
    // 加粗 + 品牌色淡淡压一层底，既认得出命中位置又不跳。
    final hit = base.copyWith(
      fontWeight: FontWeight.w700,
      color: highlightColor,
    );

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final r in ranges) {
      if (r.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, r.start), style: base));
      }
      spans.add(TextSpan(text: text.substring(r.start, r.end), style: hit));
      cursor = r.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: base));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
