import 'package:flutter_test/flutter_test.dart';
import 'package:suixiang_note/core/format.dart';

/// 字数 / 段落数口径测试（v2.7.0 详情页底栏「N 字 · M 段」）。
///
/// 口径一旦漂移，UI 上的数字就不可信——所以两处口径都钉死。
void main() {
  group('countWords 字数口径（去空白字符数）', () {
    test('中文按字计', () {
      expect(countWords('想法'), 2);
      expect(countWords('手工皮具'), 4);
    });

    test('空白不计入（空格/换行/制表）', () {
      expect(countWords('a b'), 2);
      expect(countWords('a\nb'), 2);
      expect(countWords('a\t b'), 2);
    });

    test('标点计入字数（口径是字符数不是词数）', () {
      expect(countWords('你好。'), 3);
    });

    test('空串为 0', () {
      expect(countWords(''), 0);
      expect(countWords('   \n\n'), 0);
    });
  });

  group('countParagraphs 段落数口径（非空行数）', () {
    test('单行为 1 段', () {
      expect(countParagraphs('只有一行'), 1);
    });

    test('多行按非空行计', () {
      expect(countParagraphs('第一行\n第二行\n第三行'), 3);
    });

    test('空行不计入段落', () {
      expect(countParagraphs('第一行\n\n\n第二行'), 2);
      expect(countParagraphs('第一行\n   \n第二行'), 2);
    });

    test('空文本为 0 段', () {
      expect(countParagraphs(''), 0);
      expect(countParagraphs('\n\n\n'), 0);
      expect(countParagraphs('   \n  \n'), 0);
    });

    test('首尾空行不计入', () {
      expect(countParagraphs('\n正文\n'), 1);
    });
  });

  group('两个口径配合：底栏展示', () {
    test('空正文显示 0 字（不显示段数）', () {
      expect(countWords(''), 0);
      expect(countParagraphs(''), 0);
    });

    test('多段短文两个口径独立', () {
      const text = '随手记一句\n再记一句';
      expect(countWords(text), 9); // 5 + 4 字（换行不计入）
      expect(countParagraphs(text), 2);
    });
  });
}
