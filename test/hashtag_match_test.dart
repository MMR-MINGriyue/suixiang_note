import 'package:flutter_test/flutter_test.dart';

import 'package:suixiang_note/core/hashtag_match.dart';

/// `#片段` 触发器纯逻辑用例（v2.7.0 快速打标）。
///
/// 分界核心：`# 标题`（带空格）是 Markdown 语法不触发，`#片段`（无空格）
/// 才是打标触发器——与 Outline._heading 的 `^(#{1,3})\s+` 正交。
void main() {
  group('hashtagTriggerAt 基本触发', () {
    test('行内 #片段 命中', () {
      //             0123456789
      final m = hashtagTriggerAt('想法#手工', 5);
      expect(m, isNotNull);
      expect(m!.start, 2);
      expect(m.end, 5);
      expect(m.query, '手工');
    });

    test('英文片段同样命中', () {
      final m = hashtagTriggerAt('idea#work', 9);
      expect(m, isNotNull);
      expect(m!.query, 'work');
    });

    test('片段为空不触发（正在敲 # 后还没打字 / # 标题 前夜）', () {
      expect(hashtagTriggerAt('想法#', 3), isNull);
    });

    test('caret<=0 或越界不触发', () {
      expect(hashtagTriggerAt('#手工', 0), isNull);
      expect(hashtagTriggerAt('#手工', 9), isNull);
    });
  });

  group('hashtagTriggerAt 与标题语法正交', () {
    test('# 标题（带空格）不触发', () {
      final m = hashtagTriggerAt('# 手工', 5);
      // # 后是空格 → 片段含空格 → null
      expect(m, isNull);
    });

    test('行首 # 后跟空格再跟文字，光标在标题文字内不触发', () {
      final m = hashtagTriggerAt('# 标题内容', 6);
      expect(m, isNull);
    });

    test('##片段 归并到第一个 # 后仍是连续 # 开头 → 片段空，不触发', () {
      // 「##标签」：# 是未写完的二级标题，不触发打标
      final m = hashtagTriggerAt('##标签', 4);
      expect(m, isNull);
    });

    test('标题行里光标停在 # 与空格之间（片段空）不触发', () {
      expect(hashtagTriggerAt('# 标题', 1), isNull);
    });
  });

  group('hashtagTriggerAt 行边界', () {
    test('上一行的 # 不影响当前行（跨行不触发）', () {
      final m = hashtagTriggerAt('# 旧标题\n正文', 8);
      expect(m, isNull);
    });

    test('换行后的新片段正常触发', () {
      //              0: '#' 1: 'a' 2: '\n' 3: '#' 4: 'b'
      final m = hashtagTriggerAt('#a\n#b', 5);
      expect(m, isNotNull);
      expect(m!.start, 3);
      expect(m.query, 'b');
    });
  });

  group('hashtagTriggerAt 终止字符', () {
    test('片段含空格不触发（#a b）', () {
      final m = hashtagTriggerAt('#a b', 4);
      expect(m, isNull);
    });

    test('第二个 # 处片段清空 → 作废；继续输入重新锚定到第二个 #', () {
      // 刚敲完第二个 #：归并锚点到它，片段为空 → 不触发
      expect(hashtagTriggerAt('#a#', 3), isNull);
      // 继续输入 b：锚定到第二个 #，query='b'（用户改了主意，跟着新片段走）
      final m = hashtagTriggerAt('#a#b', 4);
      expect(m, isNotNull);
      expect(m!.start, 2);
      expect(m.query, 'b');
    });

    test('片段超长（>20）不触发', () {
      final long = 'x' * 21;
      final m = hashtagTriggerAt('#$long', 1 + long.length);
      expect(m, isNull);
    });

    test('片段恰好 20 字触发', () {
      final ok = 'x' * 20;
      final m = hashtagTriggerAt('#$ok', 1 + ok.length);
      expect(m, isNotNull);
      expect(m!.query, ok);
    });
  });

  group('hashtagTriggerAt 位置语义', () {
    test('start/end 正好框住 #片段（供移除正文用）', () {
      final text = '第一行\n标签#a1';
      final caret = text.length;
      final m = hashtagTriggerAt(text, caret)!;
      expect(text.substring(m.start, m.end), '#a1');
      // 移除后正文干净
      expect(text.replaceRange(m.start, m.end, ''), '第一行\n标签');
    });
  });
}
