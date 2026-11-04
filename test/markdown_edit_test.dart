import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suixiang_note/core/edit_history.dart';
import 'package:suixiang_note/core/markdown_edit.dart';

/// 编辑纯函数层测试：markdown_edit 的文本变换 + edit_history 的撤销栈。
///
/// 这两块是「详情页编辑能力」的全部逻辑，UI 只是把它们接到 Controller 上。
/// 逻辑错在界面上表现为「点加粗变成两个星号」「撤销撤到奇怪的地方」，
/// 只有在这里逐条盯才能保证不错。
void main() {
  // ───────────────────────── 行内包裹 ─────────────────────────

  group('toggleInline 行内标记', () {
    const bold = ['**', '**'];

    test('有选区：包裹选中文字，并选中原来那段', () {
      const text = '今天学到一件事';
      final r = MarkdownEdit.toggleInline(
          text, const TextSelection(baseOffset: 4, extentOffset: 6), bold, '加粗');
      expect(r.text, '今天学到**一件**事');
      // 关键：选区必须落回「一件」上，而不是跳到末尾
      expect(r.selection.start, 6);
      expect(r.selection.end, 8);
      expect(r.text.substring(r.selection.start, r.selection.end), '一件');
    });

    test('无选区：插入占位符并选中占位符，用户直接打字就替换掉', () {
      const text = '开头';
      final r = MarkdownEdit.toggleInline(
          text, const TextSelection.collapsed(offset: 2), bold, '加粗');
      expect(r.text, '开头**加粗**');
      expect(r.text.substring(r.selection.start, r.selection.end), '加粗');
    });

    test('选区本身已含标记：视为取消，去掉标记保留文字', () {
      const text = '前**重点**后';
      // 选中 "**重点**"
      final r = MarkdownEdit.toggleInline(
          text, const TextSelection(baseOffset: 1, extentOffset: 7), bold, '加粗');
      expect(r.text, '前重点后');
      expect(r.text.substring(r.selection.start, r.selection.end), '重点');
    });

    test('选区外侧紧邻标记：同样视为取消（用户只选中里面的字）', () {
      const text = '前**重点**后';
      // 只选中 "重点"
      final r = MarkdownEdit.toggleInline(
          text, const TextSelection(baseOffset: 3, extentOffset: 5), bold, '加粗');
      expect(r.text, '前重点后');
      expect(r.selection.start, 1);
      expect(r.selection.end, 3);
    });

    test('标记长度不一（~~删除线~~）也能正确解析', () {
      const text = 'abcdef';
      final r = MarkdownEdit.toggleInline(
          text, const TextSelection(baseOffset: 0, extentOffset: 3), ['~~', '~~'], '删除线');
      expect(r.text, '~~abc~~def');
      expect(r.text.substring(r.selection.start, r.selection.end), 'abc');
    });

    test('选区为空文本时不崩溃', () {
      final r = MarkdownEdit.toggleInline(
          '', const TextSelection.collapsed(offset: 0), bold, '加粗');
      expect(r.text, '**加粗**');
    });
  });

  // ───────────────────────── 行首前缀 ─────────────────────────

  group('toggleLinePrefix 行首前缀', () {
    const bullets = ['- ', '1. ', '- [ ] ', '- [x] '];

    test('单行加无序前缀', () {
      const text = '买菜';
      final r = MarkdownEdit.toggleLinePrefix(
          text, const TextSelection.collapsed(offset: 1), '- ', bullets);
      expect(r.text, '- 买菜');
    });

    test('多行选区：每行都加前缀', () {
      const text = '第一行\n第二行\n第三行';
      final r = MarkdownEdit.toggleLinePrefix(
          text, const TextSelection(baseOffset: 0, extentOffset: text.length), '- ', bullets);
      expect(r.text, '- 第一行\n- 第二行\n- 第三行');
    });

    test('全部已带前缀：再点一次全部去掉', () {
      const text = '- 第一行\n- 第二行';
      final r = MarkdownEdit.toggleLinePrefix(
          text, const TextSelection(baseOffset: 0, extentOffset: text.length), '- ', bullets);
      expect(r.text, '第一行\n第二行');
    });

    test('族内替换而不是叠加：无序 → 有序，不留「- 1.」', () {
      const text = '- 买菜';
      final r = MarkdownEdit.toggleLinePrefix(
          text, const TextSelection.collapsed(offset: 1), '1. ', bullets);
      expect(r.text, '1. 买菜');
      expect(r.text.contains('- 1.'), isFalse);
    });

    test('有序列表逐行递增编号', () {
      const text = '甲\n乙\n丙';
      final r = MarkdownEdit.toggleLinePrefix(
          text, const TextSelection(baseOffset: 0, extentOffset: text.length), '1. ', bullets);
      expect(r.text, '1. 甲\n2. 乙\n3. 丙');
    });

    test('「2. 」这种非 1 开头的有序列表也算已有前缀，能被清掉', () {
      const text = '2. 甲';
      final r = MarkdownEdit.toggleLinePrefix(
          text, const TextSelection.collapsed(offset: 1), '1. ', bullets);
      // 全部已带 → 剥掉
      expect(r.text, '甲');
    });

    test('待办勾选：未勾选 → 已勾选', () {
      const text = '- [ ] 买牛奶';
      final r = MarkdownEdit.toggleLinePrefix(
          text, const TextSelection.collapsed(offset: 1), '- [x] ', bullets);
      expect(r.text, '- [x] 买牛奶');
    });

    test('待办再点：已勾选 → 取消勾选（在两种状态间翻转）', () {
      const text = '- [x] 买牛奶';
      final r = MarkdownEdit.toggleLinePrefix(
          text, const TextSelection.collapsed(offset: 1), '- [x] ', bullets);
      expect(r.text, '- [ ] 买牛奶');
    });

    test('剥前缀时不留双空格（前缀自带尾空格必须一起剥）', () {
      const text = '- foo\n- bar';
      final r = MarkdownEdit.toggleLinePrefix(
          text, const TextSelection(baseOffset: 0, extentOffset: text.length), '- ', bullets);
      expect(r.text, 'foo\nbar');
      expect(r.text.contains('  '), isFalse);
    });

    test('选区末尾恰在下一行行首：不把下一行算进来', () {
      const text = 'AAA\nBBB';
      // 选区从 0 到 4（"AAA\n" 之后正好是 B 的位置）
      final r = MarkdownEdit.toggleLinePrefix(
          text, const TextSelection(baseOffset: 0, extentOffset: 4), '- ', bullets);
      expect(r.text, '- AAA\nBBB');
    });

    test('返回的选区覆盖整块，方便用户接着再点一次', () {
      const text = '甲\n乙';
      final r = MarkdownEdit.toggleLinePrefix(
          text, const TextSelection(baseOffset: 0, extentOffset: text.length), '- ', bullets);
      expect(r.selection.start, 0);
      expect(r.selection.end, r.text.length);
    });
  });

  // ───────────────────────── 插入 ─────────────────────────

  group('insertLine / insertText', () {
    test('分割线在行中插入时前后各补一个换行', () {
      const text = '上文';
      final r = MarkdownEdit.insertLine(
          text, const TextSelection.collapsed(offset: 2), '---');
      expect(r.text, '上文\n---\n');
    });

    test('分割线在空文本插入不加多余前导换行', () {
      final r = MarkdownEdit.insertLine(
          '', const TextSelection.collapsed(offset: 0), '---');
      expect(r.text, '---\n');
    });

    test('插入时间戳：光标落在插入内容之后', () {
      const text = '记录：';
      final r = MarkdownEdit.insertText(
          text, const TextSelection.collapsed(offset: 3), '2026/11/04 14:30');
      expect(r.text, '记录：2026/11/04 14:30');
      expect(r.selection.start, r.text.length);
    });

    test('有选区时插入内容替换选区', () {
      const text = '把这里换掉';
      final r = MarkdownEdit.insertText(
          text, const TextSelection(baseOffset: 1, extentOffset: 3), 'X');
      expect(r.text, '把X换掉');
    });
  });

  // ───────────────────────── 前缀轮转 ─────────────────────────

  group('nextPrefixFor 轮转（详情页点两次列表得到有序列表）', () {
    // 与 _DetailPageState._nextPrefixFor 同逻辑的公开复刻：
    // 找「最长的匹配前缀」（否则「- [ ] 买菜」会先命中「- 」而永远推不到待办），
    // 再按族内原顺序前进一位；已是最后一种则回到无前缀。
    String next(String line, List<String> family) {
      int? hit;
      for (var i = 0; i < family.length; i++) {
        if (line.startsWith(family[i])) {
          if (hit == null || family[i].length > family[hit].length) hit = i;
        }
      }
      if (hit == null) return family.first;
      final n = hit + 1;
      return n < family.length ? family[n] : '';
    }

    const bullets = ['- ', '1. ', '- [ ] ', '- [x] '];
    test('无前缀 → 无序', () => expect(next('买菜', bullets), '- '));
    test('无序 → 有序', () => expect(next('- 买菜', bullets), '1. '));
    test('有序 → 未勾选待办', () => expect(next('1. 买菜', bullets), '- [ ] '));
    test('未勾选 → 已勾选', () => expect(next('- [ ] 买菜', bullets), '- [x] '));
    test('已勾选 → 回到无前缀', () => expect(next('- [x] 买菜', bullets), ''));
  });

  // ───────────────────────── 撤销栈 ─────────────────────────

  group('EditHistory 撤销/重做', () {
    TextSelection at(int i) => TextSelection.collapsed(offset: i);

    test('初始状态不能撤销也不能重做', () {
      final h = EditHistory('起始');
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isFalse);
      expect(h.current.text, '起始');
    });

    test('一次编辑后可撤销，撤销回到原文', () {
      final h = EditHistory('a');
      h.record('ab', at(2), coalesce: false);
      expect(h.canUndo, isTrue);
      final s = h.undo();
      expect(s!.text, 'a');
      expect(h.canRedo, isTrue);
    });

    test('重做回到撤销前的状态', () {
      final h = EditHistory('a');
      h.record('ab', at(2), coalesce: false);
      h.undo();
      final s = h.redo();
      expect(s!.text, 'ab');
    });

    test('700ms 内的连续纯插入合并成一帧（撤销一次退回整段输入）', () {
      final h = EditHistory('');
      h.record('今', at(1));
      h.record('今天', at(2));
      h.record('今天学', at(3));
      // 三次输入只压了一帧（合并），因此撤销一次就回到空
      final s = h.undo();
      expect(s!.text, '');
      expect(h.canUndo, isFalse);
    });

    test('coalesce=false 的动作立即断帧（点加粗必须一步撤掉）', () {
      final h = EditHistory('');
      h.record('abc', at(3));
      h.record('**abc**', at(5), coalesce: false);
      // 第一帧是 ''（初始）→ 'abc'（合并后仍在同一帧?）
      // 这里验证的是：撤销一次必须回到 'abc'，而不是回到更早
      final s1 = h.undo();
      expect(s1!.text, 'abc');
    });

    test('删除不算纯插入，不与前面的输入合并', () {
      final h = EditHistory('abc');
      h.record('abcd', at(4));
      h.record('abc', at(3)); // 删掉 d
      final s = h.undo();
      expect(s!.text, 'abcd');
    });

    test('撤销后再编辑会丢弃 redo 分支', () {
      final h = EditHistory('a');
      h.record('ab', at(2), coalesce: false);
      h.record('abc', at(3), coalesce: false);
      h.undo(); // 回到 ab
      h.record('aX', at(2), coalesce: false);
      expect(h.canRedo, isFalse);
      expect(h.current.text, 'aX');
    });

    test('超出容量从头部丢弃，不会无限吃内存', () {
      final h = EditHistory('', capacity: 3);
      for (var i = 1; i <= 10; i++) {
        h.record('x' * i, at(i), coalesce: false);
      }
      var steps = 0;
      while (h.canUndo) {
        h.undo();
        steps++;
        if (steps > 100) break; // 死循环保护
      }
      expect(steps, lessThanOrEqualTo(3));
    });

    test('reset 清空历史只留当前文本', () {
      final h = EditHistory('a');
      h.record('ab', at(2), coalesce: false);
      h.reset('全新的');
      expect(h.canUndo, isFalse);
      expect(h.current.text, '全新的');
    });

    test('重复记录同一文本不会压帧', () {
      final h = EditHistory('abc');
      h.record('abc', at(3), coalesce: false);
      expect(h.canUndo, isFalse);
    });
  });
}
