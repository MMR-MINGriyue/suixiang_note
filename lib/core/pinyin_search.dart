import 'dart:convert';
import 'dart:ui' show TextRange;

import 'package:flutter/services.dart' show rootBundle;

/// 汉字 → 拼音首字母 离线索引（21KB，20992 字，99.7% 覆盖）
///
/// **为什么自己打表**：常见 pinyin 包（lpinyin 2.0.3 等）把 sdk 锁在
/// `>=2.12 <3.0.0`，在当前 Dart 3.x 上根本装不进依赖图。与其引一个拉不动的
/// 包，不如用 `tool/gen_pinyin.py`（pypinyin）离线生成一张首字母表打进 assets：
/// 运行时只是一次 O(1) 查表，零依赖、零 IO、零 GC 抖动。
///
/// **只做首字母，不做全拼**：全拼表要 20992 × 平均 3.2 字母 ≈ 68KB，且用户
/// 输全拼的意愿远低于输首字母（「sg」找「手工」）。首字母已覆盖真实检索习惯；
/// 全拼留作 v1.9 的可选项，不占首版包体。
class PinyinSearch {
  static const String assetPath = 'assets/pinyin/first_letter.txt';
  static const int base = 0x4E00; // CJK 统一汉字起始
  static const int length = 0x9FFF - 0x4E00 + 1; // 20992

  static String? _table;

  /// 表是否就绪。未就绪时 [matches] 自动退化为纯字面匹配，不会崩。
  static bool get isReady => _table != null;

  /// 从 asset 载入（启动时调一次）。失败保持 null → 退化模式。
  static Future<void> ensureLoaded() async {
    if (_table != null) return;
    try {
      await loadFromString(await rootBundle.loadString(assetPath));
    } catch (_) {
      // 表缺失不该让搜索整体失效，退化到字面匹配即可
      _table = null;
    }
  }

  /// 直接灌入表文本（测试用，也供 [ensureLoaded] 复用）
  ///
  /// 这里 `\r` 必须剔掉：Windows 上 git 若按 CRLF 检出该文件，每行都会多一个
  /// 字符，长度校验失败 → 静默退化成纯字面搜索。`.gitattributes` 已锁 LF，
  /// 这里是第二道防线（也不吃亏：一次 replaceAll 而已）。
  static Future<void> loadFromString(String raw) async {
    final buf = StringBuffer();
    for (final line in const LineSplitter().convert(raw)) {
      if (line.startsWith('#')) continue;
      buf.write(line.replaceAll('\r', ''));
    }
    final table = buf.toString();
    if (table.length == length) _table = table;
  }

  /// 整串转首字母：汉字取表内字母，ASCII 字母转小写保留，其余丢弃
  static String initials(String text) {
    final table = _table;
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final cu = text.codeUnitAt(i);
      if (cu >= base && cu < base + length) {
        final letter = table == null ? '?' : table[cu - base];
        if (letter != '?') buf.write(letter);
      } else if ((cu >= 65 && cu <= 90) || (cu >= 97 && cu <= 122)) {
        buf.writeCharCode(cu >= 65 && cu <= 90 ? cu + 32 : cu);
      }
    }
    return buf.toString();
  }

  /// 是否命中：[query] 空串视为命中；先试字面（大小写不敏感），
  /// 再试拼音首字母（仅当查询本身不含汉字）
  static bool matches(String text, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (text.toLowerCase().contains(q)) return true;
    if (_hasCjk(q)) return false;
    return initials(text).contains(q);
  }

  /// 标题或正文任一命中
  static bool matchesAny(String title, String content, String query) =>
      matches(title, query) || matches(content, query);

  /// 命中区间（代码元坐标），供 UI 上色。
  ///
  /// 字面命中按子串切；拼音命中要把「sg」映射回「手工」这两个**汉字字符**，
  /// 所以先把文本压成「字母流 + 原字符下标」再反查。
  static List<TextRange> ranges(String text, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || text.isEmpty) return const <TextRange>[];

    final hits = <TextRange>[];

    // ① 字面子串
    final lower = text.toLowerCase();
    var from = 0;
    while (hits.length < 20) {
      final i = lower.indexOf(q, from);
      if (i < 0) break;
      hits.add(TextRange(start: i, end: i + q.length));
      from = i + q.length;
    }

    // ② 拼音首字母（含汉字的查询不必再试，汉字不在字母流里）
    if (!_hasCjk(q)) {
      final letters = <String>[];
      final offsets = <int>[];
      final table = _table;
      for (var i = 0; i < text.length; i++) {
        final cu = text.codeUnitAt(i);
        if (cu >= base && cu < base + length) {
          final letter = table == null ? '?' : table[cu - base];
          if (letter != '?') {
            letters.add(letter);
            offsets.add(i);
          }
        } else if ((cu >= 65 && cu <= 90) || (cu >= 97 && cu <= 122)) {
          letters.add(String.fromCharCode(cu >= 65 && cu <= 90 ? cu + 32 : cu));
          offsets.add(i);
        }
      }
      final stream = letters.join();
      var start = 0;
      while (hits.length < 20) {
        final i = stream.indexOf(q, start);
        if (i < 0) break;
        hits.add(TextRange(
            start: offsets[i], end: offsets[i + q.length - 1] + 1));
        start = i + q.length;
      }
    }

    return _merge(hits);
  }

  static bool _hasCjk(String s) {
    for (var i = 0; i < s.length; i++) {
      final cu = s.codeUnitAt(i);
      if (cu >= base && cu < base + length) return true;
    }
    return false;
  }

  /// 合并重叠 / 相邻区间，按起点升序（TextSpan 拼接必须有序且不回退）
  static List<TextRange> _merge(List<TextRange> hits) {
    if (hits.length <= 1) return hits;
    hits.sort((a, b) => a.start.compareTo(b.start));
    final out = <TextRange>[hits.first];
    for (final r in hits.skip(1)) {
      final last = out.last;
      if (r.start <= last.end) {
        if (r.end > last.end) {
          out[out.length - 1] = TextRange(start: last.start, end: r.end);
        }
      } else {
        out.add(r);
      }
    }
    return out;
  }
}
