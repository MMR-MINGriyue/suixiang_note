import 'package:flutter_test/flutter_test.dart';
import 'package:suixiang_note/core/outline.dart';

/// 大纲（分节）解析测试。
///
/// 这一层决定目录里显示什么、点了跳到哪。错了的表现是「目录里少一节」
/// 或「点了跳到别的节」，都是那种要盯着看半天才发现的问题。
void main() {
  group('Outline.parse 基础', () {
    test('空文本没有小节', () {
      expect(Outline.parse(''), isEmpty);
      expect(Outline.parse('   \n\n  '), isEmpty);
    });

    test('没有标题的纯文本没有小节', () {
      expect(Outline.parse('就是一段话\n第二行\n第三行'), isEmpty);
    });

    test('单个 # 标题被识别，层级为 1', () {
      final s = Outline.parse('# 标题\n正文');
      expect(s.length, 1);
      expect(s.first.title, '标题');
      expect(s.first.level, 1);
      expect(s.first.offset, 0);
    });

    test('三级标题的层级分别正确', () {
      final s = Outline.parse('# A\n## B\n### C');
      expect(s.map((e) => e.level).toList(), [1, 2, 3]);
      expect(s.map((e) => e.title).toList(), ['A', 'B', 'C']);
    });

    test('offset 指向标题行的绝对起点', () {
      const text = '前言\n# 标题\n正文';
      final s = Outline.parse(text);
      expect(s.length, 1);
      expect(text.substring(s.first.offset).startsWith('# 标题'), isTrue);
    });

    test('bodyLength 是本节正文长度，不含标题行', () {
      const text = '# A\n一二三\n# B\n四';
      final s = Outline.parse(text);
      // A 节正文 = "一二三"（3 字），B 节正文 = "四"（1 字）
      expect(s[0].bodyLength, 3);
      expect(s[1].bodyLength, 1);
    });

    test('最后一节的正文延伸到文末', () {
      const text = '# A\n12345';
      final s = Outline.parse(text);
      expect(s.first.bodyLength, 5);
    });

    test('空标题的节也保留，显示为（无标题小节）', () {
      final s = Outline.parse('#\n正文');
      // 「#」后面没空格，不算标题（避免把 markdown 里的 # 当所有标题）
      expect(s, isEmpty);

      final s2 = Outline.parse('#   \n正文');
      expect(s2.length, 1);
      expect(s2.first.isUntitled, isTrue);
      expect(s2.first.displayTitle, '（无标题小节）');
    });

    test('#### 四级不算标题（只支持三级）', () {
      expect(Outline.parse('#### 太深了'), isEmpty);
    });

    test('# 后面没有空格不算标题', () {
      expect(Outline.parse('#标签不是标题'), isEmpty);
    });

    test('代码块里的 # 不算标题（防止 shell 注释撑散目录）', () {
      const text = '# 真标题\n```\n# 这是注释\n# 也是注释\n```\n正文';
      final s = Outline.parse(text);
      expect(s.length, 1);
      expect(s.first.title, '真标题');
    });

    test('缩进的标题也能识别（手机输入法常带前导空格）', () {
      final s = Outline.parse('   ## 缩进的标题');
      expect(s.length, 1);
      expect(s.first.title, '缩进的标题');
      expect(s.first.level, 2);
    });
  });

  group('Outline.selectionFor / sectionAt', () {
    const text = '# 第一\n内容一\n## 第二\n内容二';

    test('selectionFor 选中整行标题（方便直接改写）', () {
      final s = Outline.parse(text);
      final sel = Outline.selectionFor(text, s[1]);
      expect(text.substring(sel.start, sel.end), '## 第二');
    });

    test('sectionAt：光标在第二个标题之后命中的是第二节', () {
      final s = Outline.parse(text);
      final pos = text.indexOf('内容二');
      expect(Outline.sectionAt(s, pos)!.title, '第二');
    });

    test('sectionAt：光标在第一个标题之前返回 null', () {
      const t = '前言\n# 标题';
      final s = Outline.parse(t);
      expect(Outline.sectionAt(s, 0), isNull);
    });

    test('sectionAt：光标正好在标题行首命中该节', () {
      final s = Outline.parse(text);
      expect(Outline.sectionAt(s, s[1].offset)!.title, '第二');
    });

    test('indentOf：一级 0，二级 12，三级 24', () {
      final s = Outline.parse('# A\n## B\n### C');
      expect(Outline.indentOf(s[0]), 0);
      expect(Outline.indentOf(s[1]), 12);
      expect(Outline.indentOf(s[2]), 24);
    });
  });

  group('回车续行规则（与 detail_page._maybeContinueList 同逻辑）', () {
    // 复刻：在列表行尾回车时，下一行自动带前缀
    String continueLine(String prevLine) {
      final m =
          RegExp(r'^(\s*)(- \[[ x]\] |- |\d+\. |> )(.*)$').firstMatch(prevLine);
      if (m == null) return '';
      final indent = m.group(1)!;
      final marker = m.group(2)!;
      final body = m.group(3)!;
      if (body.trim().isEmpty) return '';
      final next = marker.startsWith('- [x]') || marker.startsWith('- [ ]')
          ? '- [ ] '
          : (RegExp(r'^\d+\.\s?$').hasMatch(marker.trimRight())
              ? '${int.parse(marker.trimRight().replaceAll('.', '')) + 1}. '
              : marker);
      return '$indent$next';
    }

    test('无序列表续无序', () => expect(continueLine('- 买菜'), '- '));
    test('已勾选待办续成未勾选', () => expect(continueLine('- [x] 买牛奶'), '- [ ] '));
    test('未勾选待办续成未勾选', () => expect(continueLine('- [ ] 买牛奶'), '- [ ] '));
    test('有序列表编号递增', () => expect(continueLine('3. 第三步'), '4. '));
    test('引用续引用', () => expect(continueLine('> 一句引用'), '> '));
    test('缩进保留', () => expect(continueLine('  - 缩进项'), '  - '));
    test('普通段落不续', () => expect(continueLine('就是一句话'), ''));
    test('空项目不续（否则会无限套前缀）', () => expect(continueLine('- '), ''));
  });
}
