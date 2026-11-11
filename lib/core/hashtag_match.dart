/// `#` 快速打标的纯判定：光标前是否有一个「#片段」触发器。
///
/// **与标题语法的分工**（v2.7.0）：Markdown 小节用 `# 标题`（# 后必须跟
/// 空格，见 `Outline._heading` 的 `^(#{1,3})\s+`）；而 `#片段`（# 后紧跟
/// 非空白字符）被解释为「想给这条随记打个标签」，弹出联想条。两者靠
/// 「有没有空格」正交，互不干扰。
class HashtagMatch {
  /// `#` 在正文中的下标（连续 `##` 已归并到第一个）
  final int start;

  /// 片段结束（= 触发时的光标位置，开区间）
  final int end;

  /// `#` 后、光标前的片段（即用户的输入过滤器）
  final String query;

  const HashtagMatch({
    required this.start,
    required this.end,
    required this.query,
  });
}

/// 光标 [caret] 前是否存在有效的 `#片段` 触发器。
///
/// 规则：
/// - `#` 必须与光标同一行（跨行的 `#` 是很久以前的标题残留，不触发）；
/// - 连续 `##` 归并到第一个：`##标签` 视作未写完的二级标题，不触发；
/// - 片段非空且 ≤ 20（与标签名同长上限）：空片段不触发——正在敲
///   `# 标题` 的用户在空格前不该被打断；超长片段说明那只是普通文本；
/// - 片段里不允许空白或 `#`：`# a` 是标题，`#a#b` 在第二个 `#` 处作废。
HashtagMatch? hashtagTriggerAt(String text, int caret) {
  if (caret <= 0 || caret > text.length) return null;
  final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
  var hash = text.lastIndexOf('#', caret - 1);
  if (hash < lineStart) return null;
  while (hash > lineStart && text.codeUnitAt(hash - 1) == 0x23) {
    hash--; // 归并连续 #（## / ###）
  }
  final frag = text.substring(hash + 1, caret);
  if (frag.isEmpty || frag.length > 20) return null;
  for (var i = 0; i < frag.length; i++) {
    final cu = frag.codeUnitAt(i);
    if (cu == 0x20 || cu == 0x09 || cu == 0x0A || cu == 0x0D || cu == 0x23) {
      return null; // 空格 / 制表 / 换行 / 再一个 # 都终止触发
    }
  }
  return HashtagMatch(start: hash, end: caret, query: frag);
}
